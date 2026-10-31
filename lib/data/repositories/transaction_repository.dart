import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../database.dart';
import '../holding_math.dart';
import '../models.dart';

class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;

  late final $AccountsTable _toAccounts = _db.alias(_db.accounts, 'to_acc');

  /// Joined, filtered list ordered newest first.
  Stream<List<TxDetails>> watch(TxFilter f) {
    final $TransactionsTable t = _db.transactions;
    final JoinedSelectStatement<HasResultSet, dynamic> q = _db.select(t).join(
      <Join<HasResultSet, dynamic>>[
        innerJoin(_db.accounts, _db.accounts.id.equalsExp(t.accountId)),
        leftOuterJoin(_toAccounts, _toAccounts.id.equalsExp(t.toAccountId)),
        leftOuterJoin(
          _db.categories,
          _db.categories.id.equalsExp(t.categoryId),
        ),
        leftOuterJoin(_db.holdings, _db.holdings.id.equalsExp(t.holdingId)),
      ],
    );

    final List<Expression<bool>> conds = <Expression<bool>>[];
    if (f.types.isNotEmpty) {
      conds.add(t.type.isIn(f.types.map((TxType e) => e.name)));
    }
    if (f.accountId != null) {
      conds.add(
        t.accountId.equals(f.accountId!) | t.toAccountId.equals(f.accountId!),
      );
    }
    if (f.categoryId != null) conds.add(t.categoryId.equals(f.categoryId!));
    if (f.window != null) {
      conds.add(t.date.isBiggerOrEqualValue(f.window!.start));
      conds.add(t.date.isSmallerThanValue(f.window!.end));
    }
    if (f.transportMode != null) conds.add(t.transportMode.equalsValue(f.transportMode));
    if (f.routeCode != null) conds.add(t.routeCode.equals(f.routeCode!));
    if (conds.isNotEmpty) q.where(conds.reduce((a, b) => a & b));

    q.orderBy(<OrderingTerm>[
      OrderingTerm.desc(t.date),
      OrderingTerm.desc(t.id),
    ]);
    // Note search runs in Dart: SQLite's LOWER() only folds ASCII, which
    // would miss Azerbaijani letters (Ə/ə, Ö/ö, Ü/ü ...).
    // The time-of-day window also runs in Dart: it must use the device's
    // local time exactly like the tiles show it.
    final String needle = f.query.trim().toLowerCase();
    final TimeOfDayRange? tod = f.timeOfDay;
    final bool dartFilter = needle.isNotEmpty || tod != null;
    if (f.limit != null && !dartFilter) q.limit(f.limit!);

    return q.watch().map(
          (List<TypedResult> rows) => rows
              .where(
                (TypedResult r) =>
                    (needle.isEmpty ||
                        r.readTable(t).note.toLowerCase().contains(needle)) &&
                    (tod == null || tod.contains(r.readTable(t).date)),
              )
              .take(f.limit != null && dartFilter ? f.limit! : rows.length)
              .map(
                (TypedResult r) => TxDetails(
                  tx: r.readTable(t),
                  account: r.readTable(_db.accounts),
                  toAccount: r.readTableOrNull(_toAccounts),
                  category: r.readTableOrNull(_db.categories),
                  holding: r.readTableOrNull(_db.holdings),
                ),
              )
              .toList(growable: false),
        );
  }

  /// Codes of the [mode] routes (or stations) used most recently, newest
  /// first, at most [limit].
  Stream<List<String>> watchRecentRoutes(TransportMode mode, {int limit = 5}) => _db
      .customSelect(
        'SELECT route_code AS code, MAX(date) AS last FROM transactions '
        'WHERE transport_mode = ? AND route_code IS NOT NULL '
        'GROUP BY route_code ORDER BY last DESC LIMIT ?',
        variables: <Variable<Object>>[Variable<String>(mode.name), Variable<int>(limit)],
        readsFrom: <ResultSetImplementation<dynamic, dynamic>>{_db.transactions},
      )
      .watch()
      .map((List<QueryRow> rows) => <String>[for (final QueryRow r in rows) r.read<String>('code')]);

  /// The most recently used transport mode, for preselecting the picker.
  Future<TransportMode?> lastTransportMode() async {
    final QueryRow? r = await _db
        .customSelect(
          'SELECT transport_mode AS m FROM transactions WHERE transport_mode IS NOT NULL '
          'ORDER BY date DESC, id DESC LIMIT 1',
        )
        .getSingleOrNull();
    final String? name = r?.readNullable<String>('m');
    return TransportMode.values.where((TransportMode m) => m.name == name).firstOrNull;
  }

  /// Other rows sharing [tx]'s link group (a bonus transfer and its loss).
  Future<List<MoneyTx>> linkedOf(MoneyTx tx) async {
    final String? g = tx.linkGroupId;
    if (g == null) return const <MoneyTx>[];
    return (_db.select(_db.transactions)
          ..where((x) => x.linkGroupId.equals(g) & x.id.equals(tx.id).not()))
        .get();
  }

  static final math.Random _rng = math.Random.secure();

  /// Random 128-bit hex id for a link group.
  static String newLinkGroupId() => <String>[
        for (int i = 0; i < 16; i++) _rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ].join();

  /// Writes a transfer out of a bonus account (DESIGN.md §18.6): the
  /// transfer carries only [received] (it arrives in full on [toId]); the
  /// difference [sent] − [received] is an expense on the bonus account in
  /// the "Bonus itkisi" system category. Both rows share a linkGroupId and
  /// are written in one transaction, so the bonus account goes down by
  /// [sent] and the target up by [received].
  ///
  /// With [transferId] the existing pair is rewritten in place (ids kept);
  /// the loss row is added or removed as needed. Same-currency accounts
  /// only (the UI says so). Returns the transfer id.
  Future<int> saveBonusTransfer({
    int? transferId,
    required int fromId,
    required int toId,
    required int sent,
    required int received,
    required DateTime date,
    String note = '',
  }) =>
      _db.transaction(() async {
        if (fromId == toId) throw ArgumentError('same account');
        if (received <= 0 || received > sent) throw ArgumentError('received out of range');
        final Account from =
            await (_db.select(_db.accounts)..where((a) => a.id.equals(fromId))).getSingle();
        final Account to = await (_db.select(_db.accounts)..where((a) => a.id.equals(toId))).getSingle();
        if (from.type != AccountType.bonus) throw ArgumentError('source is not a bonus account');
        if (from.currency != to.currency) throw ArgumentError('bonus transfers need one currency');

        final int loss = sent - received;
        MoneyTx? old;
        List<MoneyTx> partners = const <MoneyTx>[];
        if (transferId != null) {
          old = await byId(transferId);
          if (old == null) throw ArgumentError('transfer not found');
          if (old.type.isHoldingMove) throw ArgumentError('holding moves are edited elsewhere');
          partners = await linkedOf(old);
        }
        final String? group = loss > 0 ? (old?.linkGroupId ?? newLinkGroupId()) : null;
        final DateTime now = DateTime.now();

        final int id;
        if (old == null) {
          id = await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
                type: TxType.transfer,
                accountId: fromId,
                toAccountId: Value<int?>(toId),
                amount: received,
                date: date,
                note: Value<String>(note),
                linkGroupId: Value<String?>(group),
              ));
        } else {
          id = old.id;
          await _db.update(_db.transactions).replace(old.copyWith(
                type: TxType.transfer,
                accountId: fromId,
                toAccountId: Value<int?>(toId),
                categoryId: const Value<int?>(null),
                amount: received,
                toAmount: const Value<int?>(null),
                date: date,
                note: note,
                linkGroupId: Value<String?>(group),
                transportMode: const Value<TransportMode?>(null),
                routeCode: const Value<String?>(null),
                trips: 1,
                updatedAt: Value<DateTime?>(now),
              ));
        }

        final MoneyTx? oldLoss =
            loss > 0 ? partners.where((MoneyTx p) => p.type == TxType.expense).firstOrNull : null;
        for (final MoneyTx p in partners) {
          if (p.id != oldLoss?.id) {
            await (_db.delete(_db.transactions)..where((x) => x.id.equals(p.id))).go();
          }
        }
        if (loss > 0) {
          final int cat = await _db.ensureBonusLossCategory();
          if (oldLoss == null) {
            await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
                  type: TxType.expense,
                  accountId: fromId,
                  categoryId: Value<int?>(cat),
                  amount: loss,
                  date: date,
                  note: Value<String>(note),
                  linkGroupId: Value<String?>(group),
                ));
          } else {
            await _db.update(_db.transactions).replace(oldLoss.copyWith(
                  accountId: fromId,
                  categoryId: Value<int?>(cat),
                  amount: loss,
                  date: date,
                  note: note,
                  linkGroupId: Value<String?>(group),
                  updatedAt: Value<DateTime?>(now),
                ));
          }
        }
        return id;
      });

  /// Income/expense totals in AZN for [window]. Transfers are excluded.
  Stream<PeriodTotals> watchTotals(DateWindow window, Rates rates) {
    return _db
        .customSelect(
          '''
SELECT a.currency AS currency, t.type AS type, SUM(t.amount) AS total
FROM transactions t JOIN accounts a ON a.id = t.account_id
WHERE t.type IN ('income', 'expense') AND t.date >= ? AND t.date < ?
GROUP BY a.currency, t.type
''',
          variables: <Variable<Object>>[
            Variable<DateTime>(window.start),
            Variable<DateTime>(window.end),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.transactions,
            _db.accounts,
          },
        )
        .watch()
        .map((List<QueryRow> rows) {
      int income = 0;
      int expense = 0;
      for (final QueryRow r in rows) {
        final int v =
            rates.toBase(r.read<int>('total'), r.read<String>('currency'));
        if (r.read<String>('type') == TxType.income.name) {
          income += v;
        } else {
          expense += v;
        }
      }
      return PeriodTotals(income: income, expense: expense);
    });
  }

  Future<MoneyTx?> byId(int id) => (_db.select(_db.transactions)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();

  /// Income / expense / transfer only. Holding moves have a linked holding
  /// entry and are created through HoldingRepository.move, so the two sides
  /// can never disagree.
  Future<int> insert(TransactionsCompanion c) {
    final TxType? type = c.type.present ? c.type.value : null;
    if (type == null || type.isHoldingMove || (c.holdingId.present && c.holdingId.value != null)) {
      throw ArgumentError('holding moves are created by HoldingRepository.move');
    }
    return _db.into(_db.transactions).insert(c);
  }

  /// Edits income / expense / transfer rows. A holding move (before or
  /// after) is refused: its amount and date live in the holding entry too
  /// and are edited through HoldingRepository.
  Future<void> update(MoneyTx tx) => _db.transaction(() async {
        final MoneyTx? old = await byId(tx.id);
        if (old == null) return;
        if (old.type.isHoldingMove || tx.type.isHoldingMove || tx.holdingId != null) {
          throw ArgumentError('holding moves are edited through HoldingRepository');
        }
        // A row saved on its own leaves its link group: the partner (the
        // bonus loss of a transfer) is removed so the pair never disagrees.
        for (final MoneyTx p in await linkedOf(old)) {
          await (_db.delete(_db.transactions)..where((x) => x.id.equals(p.id))).go();
        }
        await _db.update(_db.transactions).replace(tx.copyWith(
              linkGroupId: const Value<String?>(null),
              updatedAt: Value<DateTime?>(DateTime.now()),
            ));
      });

  /// Deletes a transaction together with its linked partner (bonus loss),
  /// and the holding entries of a holding move. Everything removed is
  /// returned for [restoreDeleted]. Throws [HoldingAmountException] like
  /// [delete].
  Future<DeletedTransactions> deleteWithLinked(int id) => _db.transaction(() async {
        final MoneyTx? tx = await byId(id);
        if (tx == null) return const DeletedTransactions(<MoneyTx>[], <HoldingEntry>[]);
        final List<MoneyTx> partners = await linkedOf(tx);
        final List<HoldingEntry> entries = await delete(id);
        for (final MoneyTx p in partners) {
          await (_db.delete(_db.transactions)..where((x) => x.id.equals(p.id))).go();
        }
        return DeletedTransactions(<MoneyTx>[tx, ...partners], entries);
      });

  /// Undo of [deleteWithLinked]: every row comes back with its id.
  Future<void> restoreDeleted(DeletedTransactions d) => _db.transaction(() async {
        if (d.transactions.isEmpty) return;
        await restore(d.transactions.first, entries: d.entries);
        for (final MoneyTx p in d.transactions.skip(1)) {
          await _db.into(_db.transactions).insert(p, mode: InsertMode.insertOrReplace);
        }
      });

  /// Deletes a transaction. A holding move takes its holding entry with it
  /// (ON DELETE CASCADE); those entries are returned so undo can put them
  /// back through [restore].
  ///
  /// Throws [HoldingAmountException] (nothing deleted) when removing a
  /// move would push the holding's history below zero, e.g. the money moved
  /// in was withdrawn later. Same rule as HoldingRepository.deleteEntry.
  Future<List<HoldingEntry>> delete(int id) => _db.transaction(() async {
        final List<HoldingEntry> linked = await (_db.select(_db.holdingEntries)
              ..where((e) => e.transactionId.equals(id)))
            .get();
        for (final int h in linked.map((HoldingEntry e) => e.holdingId).toSet()) {
          HoldingMath.replay(<HoldingEntry>[
            for (final HoldingEntry e in await _entriesOf(h))
              if (e.transactionId != id) e,
          ]);
        }
        await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
        return linked;
      });

  /// Re-inserts a deleted row (undo), keeping its id, plus any holding
  /// entries [delete] removed with it. Throws [HoldingAmountException]
  /// (nothing restored) if the holding changed meanwhile so that putting the
  /// entries back would make its history invalid.
  Future<void> restore(MoneyTx tx, {List<HoldingEntry> entries = const <HoldingEntry>[]}) =>
      _db.transaction(() async {
        for (final int h in entries.map((HoldingEntry e) => e.holdingId).toSet()) {
          HoldingMath.replay(<HoldingEntry>[
            for (final HoldingEntry e in await _entriesOf(h))
              if (!entries.any((HoldingEntry x) => x.id == e.id)) e,
            ...entries.where((HoldingEntry e) => e.holdingId == h),
          ]);
        }
        await _db.into(_db.transactions).insert(tx, mode: InsertMode.insertOrReplace);
        for (final HoldingEntry e in entries) {
          await _db.into(_db.holdingEntries).insert(e, mode: InsertMode.insertOrReplace);
        }
      });

  Future<List<HoldingEntry>> _entriesOf(int holdingId) =>
      (_db.select(_db.holdingEntries)..where((e) => e.holdingId.equals(holdingId))).get();
}
