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
    if (conds.isNotEmpty) q.where(conds.reduce((a, b) => a & b));

    q.orderBy(<OrderingTerm>[
      OrderingTerm.desc(t.date),
      OrderingTerm.desc(t.id),
    ]);
    // Note search runs in Dart: SQLite's LOWER() only folds ASCII, which
    // would miss Azerbaijani letters (Ə/ə, Ö/ö, Ü/ü ...).
    final String needle = f.query.trim().toLowerCase();
    if (f.limit != null && needle.isEmpty) q.limit(f.limit!);

    return q.watch().map(
          (List<TypedResult> rows) => rows
              .where(
                (TypedResult r) =>
                    needle.isEmpty ||
                    r.readTable(t).note.toLowerCase().contains(needle),
              )
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
        await _db.update(_db.transactions).replace(tx);
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
