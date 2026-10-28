import 'package:drift/drift.dart';

import '../database.dart';
import '../holding_math.dart';
import '../models.dart';

/// "Kənar yerlər": money held outside the spendable accounts.
class HoldingRepository {
  HoldingRepository(this._db);

  final AppDatabase _db;

  JoinedSelectStatement<HasResultSet, dynamic> _joined({bool includeArchived = false}) {
    final JoinedSelectStatement<HasResultSet, dynamic> q = _db.select(_db.holdings).join(
      <Join<HasResultSet, dynamic>>[
        leftOuterJoin(
          _db.holdingEntries,
          _db.holdingEntries.holdingId.equalsExp(_db.holdings.id),
        ),
      ],
    )..orderBy(<OrderingTerm>[
        OrderingTerm.asc(_db.holdings.isArchived),
        OrderingTerm.asc(_db.holdings.sortOrder),
        OrderingTerm.asc(_db.holdings.id),
      ]);
    if (!includeArchived) q.where(_db.holdings.isArchived.equals(false));
    return q;
  }

  List<HoldingWithValue> _fold(List<TypedResult> rows, Rates rates) {
    final Map<int, Holding> holdings = <int, Holding>{};
    final Map<int, List<HoldingEntry>> entries = <int, List<HoldingEntry>>{};
    for (final TypedResult r in rows) {
      final Holding h = r.readTable(_db.holdings);
      holdings[h.id] = h;
      final List<HoldingEntry> list = entries.putIfAbsent(h.id, () => <HoldingEntry>[]);
      final HoldingEntry? e = r.readTableOrNull(_db.holdingEntries);
      if (e != null) list.add(e);
    }
    return <HoldingWithValue>[
      for (final Holding h in holdings.values)
        () {
          final List<HoldingEntry> list = entries[h.id]!;
          final int amount = HoldingMath.tryCurrent(list) ?? 0;
          DateTime last = h.createdAt;
          for (final HoldingEntry e in list) {
            if (e.date.isAfter(last)) last = e.date;
          }
          return HoldingWithValue(h, amount, rates.toBase(amount, h.currency), lastChange: last);
        }(),
    ];
  }

  /// Holdings with current amount and AZN value.
  Stream<List<HoldingWithValue>> watchHoldings(Rates rates, {bool includeArchived = false}) =>
      _joined(includeArchived: includeArchived)
          .watch()
          .map((List<TypedResult> r) => _fold(r, rates));

  Future<List<HoldingWithValue>> getHoldings(Rates rates, {bool includeArchived = false}) async =>
      _fold(await _joined(includeArchived: includeArchived).get(), rates);

  /// Sum of active holdings in AZN.
  Stream<int> watchTotal(Rates rates) => watchHoldings(rates).map(
        (List<HoldingWithValue> l) => l.fold(0, (int s, HoldingWithValue h) => s + h.azn),
      );

  Future<Holding?> byId(int id) =>
      (_db.select(_db.holdings)..where((h) => h.id.equals(id))).getSingleOrNull();

  Future<List<HoldingEntry>> _entries(int holdingId) =>
      (_db.select(_db.holdingEntries)..where((e) => e.holdingId.equals(holdingId))).get();

  Future<bool> _referencedByTransactions(int holdingId) async {
    final Expression<int> n = _db.transactions.id.count();
    final TypedResult row = await (_db.selectOnly(_db.transactions)
          ..addColumns(<Expression<Object>>[n])
          ..where(_db.transactions.holdingId.equals(holdingId)))
        .getSingle();
    return (row.read(n) ?? 0) > 0;
  }

  /// One holding with history, value series and current amount.
  Stream<HoldingDetail?> watchDetail(int id) {
    final JoinedSelectStatement<HasResultSet, dynamic> q = _db.select(_db.holdings).join(
      <Join<HasResultSet, dynamic>>[
        leftOuterJoin(
          _db.holdingEntries,
          _db.holdingEntries.holdingId.equalsExp(_db.holdings.id),
        ),
      ],
    )..where(_db.holdings.id.equals(id));
    return q.watch().asyncMap((List<TypedResult> rows) async {
      if (rows.isEmpty) return null;
      final Holding h = rows.first.readTable(_db.holdings);
      final List<HoldingEntry> entries = <HoldingEntry>[
        for (final TypedResult r in rows)
          if (r.readTableOrNull(_db.holdingEntries) case final HoldingEntry e) e,
      ];
      List<HoldingPoint> series;
      try {
        series = HoldingMath.replay(entries);
      } on HoldingAmountException {
        series = <HoldingPoint>[];
      }
      return HoldingDetail(
        holding: h,
        entries: HoldingMath.sorted(entries).reversed.toList(),
        series: series,
        amount: series.isEmpty ? 0 : series.last.amount,
        usedByTransactions: await _referencedByTransactions(h.id),
        linkedAccounts: await _linkedAccounts(h.id),
      );
    });
  }

  Future<Map<int, String>> _linkedAccounts(int holdingId) async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT e.id AS id, a.name AS name FROM holding_entries e '
      'JOIN transactions t ON t.id = e.transaction_id '
      'JOIN accounts a ON a.id = t.account_id WHERE e.holding_id = ?',
      variables: <Variable<Object>>[Variable<int>(holdingId)],
    ).get();
    return <int, String>{for (final QueryRow r in rows) r.read<int>('id'): r.read<String>('name')};
  }

  /// Changes an entry's date and note, keeping the history >= 0. A linked
  /// account move gets the same date and note.
  Future<void> updateEntry(int entryId, {required DateTime date, required String note}) =>
      _db.transaction(() async {
        final HoldingEntry? e = await (_db.select(_db.holdingEntries)
              ..where((x) => x.id.equals(entryId)))
            .getSingleOrNull();
        if (e == null) throw const HoldingAmountException(HoldingAmountFailure.notFound);
        final HoldingEntry changed = e.copyWith(date: date, note: note);
        HoldingMath.replay(<HoldingEntry>[
          for (final HoldingEntry x in await _entries(e.holdingId)) x.id == entryId ? changed : x,
        ]);
        await _db.update(_db.holdingEntries).replace(changed);
        if (e.transactionId != null) {
          await (_db.update(_db.transactions)..where((t) => t.id.equals(e.transactionId!)))
              .write(TransactionsCompanion(date: Value<DateTime>(date), note: Value<String>(note)));
        }
      });

  /// Creates a holding; a non-null [initialAmount] is recorded as a
  /// setValue entry dated [date].
  Future<int> create({
    required String name,
    required HoldingPlace placeType,
    required String currency,
    String note = '',
    double? interestRate,
    DateTime? maturityDate,
    int colorIndex = 0,
    int? initialAmount,
    DateTime? date,
  }) =>
      _db.transaction(() async {
        if (initialAmount != null) HoldingMath.checkAmount(HoldingEntryKind.setValue, initialAmount);
        final Expression<int> maxOrder = _db.holdings.sortOrder.max();
        final TypedResult row = await (_db.selectOnly(_db.holdings)
              ..addColumns(<Expression<Object>>[maxOrder]))
            .getSingle();
        final bool deposit = placeType == HoldingPlace.bankDeposit;
        final int id = await _db.into(_db.holdings).insert(HoldingsCompanion.insert(
              name: name,
              placeType: placeType,
              currency: currency,
              note: Value<String>(note),
              interestRate: Value<double?>(deposit ? interestRate : null),
              maturityDate: Value<DateTime?>(deposit ? maturityDate : null),
              colorIndex: Value<int>(colorIndex),
              sortOrder: Value<int>((row.read(maxOrder) ?? 0) + 1),
            ));
        if (initialAmount != null && initialAmount > 0) {
          await _db.into(_db.holdingEntries).insert(HoldingEntriesCompanion.insert(
                holdingId: id,
                kind: HoldingEntryKind.setValue,
                amount: initialAmount,
                date: date ?? DateTime.now(),
              ));
        }
        return id;
      });

  /// Saves edits. The currency is locked once the holding has entries.
  Future<void> update(Holding h) => _db.transaction(() async {
        final Holding? old = await byId(h.id);
        if (old == null) throw const HoldingAmountException(HoldingAmountFailure.notFound);
        if (old.currency != h.currency && (await _entries(h.id)).isNotEmpty) {
          throw const HoldingAmountException(HoldingAmountFailure.currencyLocked);
        }
        final bool deposit = h.placeType == HoldingPlace.bankDeposit;
        await _db.update(_db.holdings).replace(h.copyWith(
              interestRate: Value<double?>(deposit ? h.interestRate : null),
              maturityDate: Value<DateTime?>(deposit ? h.maturityDate : null),
            ));
      });

  /// Adds a manual entry after checking the whole history stays >= 0.
  Future<int> addEntry({
    required int holdingId,
    required HoldingEntryKind kind,
    required int amount,
    required DateTime date,
    String note = '',
  }) =>
      _db.transaction(() async {
        if (await byId(holdingId) == null) {
          throw const HoldingAmountException(HoldingAmountFailure.notFound);
        }
        final List<HoldingEntry> existing = await _entries(holdingId);
        HoldingMath.replay(<HoldingEntry>[
          ...existing,
          HoldingEntry(
            id: HoldingMath.pendingId,
            holdingId: holdingId,
            kind: kind,
            amount: amount,
            date: date,
            note: note,
          ),
        ]);
        return _db.into(_db.holdingEntries).insert(HoldingEntriesCompanion.insert(
              holdingId: holdingId,
              kind: kind,
              amount: amount,
              date: date,
              note: Value<String>(note),
            ));
      });

  /// Deletes an entry if the remaining history stays valid. An entry created
  /// by an account move deletes that transaction too, so the account
  /// balance and the holding stay consistent.
  Future<void> deleteEntry(int entryId) => _db.transaction(() async {
        final HoldingEntry? e = await (_db.select(_db.holdingEntries)
              ..where((x) => x.id.equals(entryId)))
            .getSingleOrNull();
        if (e == null) return;
        final List<HoldingEntry> rest =
            (await _entries(e.holdingId)).where((HoldingEntry x) => x.id != entryId).toList();
        HoldingMath.replay(rest);
        if (e.transactionId != null) {
          await (_db.delete(_db.transactions)..where((t) => t.id.equals(e.transactionId!))).go();
        }
        await (_db.delete(_db.holdingEntries)..where((x) => x.id.equals(entryId))).go();
      });

  /// Moves money between an account and a holding as one DB transaction:
  /// a [TxType.toHolding] / [TxType.fromHolding] transaction on the account
  /// plus a linked add / withdraw entry on the holding.
  ///
  /// [amount] is in the account's currency; [holdingAmount] in the
  /// holding's currency (required when the currencies differ).
  Future<int> move({
    required int accountId,
    required int holdingId,
    required bool toHolding,
    required int amount,
    int? holdingAmount,
    required DateTime date,
    String note = '',
  }) =>
      _db.transaction(() async {
        final Account? account = await (_db.select(_db.accounts)
              ..where((a) => a.id.equals(accountId)))
            .getSingleOrNull();
        final Holding? holding = await byId(holdingId);
        if (account == null || holding == null) {
          throw const HoldingAmountException(HoldingAmountFailure.notFound);
        }
        final bool sameCurrency = account.currency == holding.currency;
        final int inHolding = sameCurrency ? amount : (holdingAmount ?? 0);
        HoldingMath.checkAmount(HoldingEntryKind.add, amount);
        HoldingMath.checkAmount(HoldingEntryKind.add, inHolding);
        final HoldingEntryKind kind = toHolding ? HoldingEntryKind.add : HoldingEntryKind.withdraw;
        HoldingMath.replay(<HoldingEntry>[
          ...await _entries(holdingId),
          HoldingEntry(
            id: HoldingMath.pendingId,
            holdingId: holdingId,
            kind: kind,
            amount: inHolding,
            date: date,
            note: note,
          ),
        ]);
        final int txId = await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
              type: toHolding ? TxType.toHolding : TxType.fromHolding,
              accountId: accountId,
              holdingId: Value<int?>(holdingId),
              amount: amount,
              toAmount: Value<int?>(sameCurrency ? null : inHolding),
              date: date,
              note: Value<String>(note),
            ));
        await _db.into(_db.holdingEntries).insert(HoldingEntriesCompanion.insert(
              holdingId: holdingId,
              kind: kind,
              amount: inHolding,
              date: date,
              note: Value<String>(note),
              transactionId: Value<int?>(txId),
            ));
        return txId;
      });

  Future<void> setArchived(int id, bool archived) =>
      (_db.update(_db.holdings)..where((h) => h.id.equals(id)))
          .write(HoldingsCompanion(isArchived: Value<bool>(archived)));

  /// Same rule as accounts: a holding referenced by account moves is
  /// archived (deleting it would break those account balances); otherwise it
  /// is deleted together with its own entries. Returns true when deleted.
  Future<bool> deleteOrArchive(int id) => _db.transaction(() async {
        if (await _referencedByTransactions(id)) {
          await setArchived(id, true);
          return false;
        }
        await (_db.delete(_db.holdings)..where((h) => h.id.equals(id))).go();
        return true;
      });
}
