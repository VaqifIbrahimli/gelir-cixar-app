import 'package:drift/drift.dart';

import '../database.dart';
import '../models.dart';

class AccountRepository {
  AccountRepository(this._db);

  final AppDatabase _db;

  // Balance = initial + incomes − expenses − outgoing transfers
  //           + incoming transfers (toAmount ?? amount)
  //           − moves into holdings + moves out of holdings.
  // `amount` of a holding move is always in the account's currency.
  static const String _balanceSql = '''
SELECT a.*,
  a.initial_balance
  + COALESCE((SELECT SUM(t.amount) FROM transactions t
              WHERE t.account_id = a.id AND t.type IN ('income', 'fromHolding')), 0)
  - COALESCE((SELECT SUM(t.amount) FROM transactions t
              WHERE t.account_id = a.id AND t.type IN ('expense', 'transfer', 'toHolding')), 0)
  + COALESCE((SELECT SUM(COALESCE(t.to_amount, t.amount)) FROM transactions t
              WHERE t.to_account_id = a.id AND t.type = 'transfer'), 0)
  AS balance
FROM accounts a
''';

  /// Accounts with live balances. Archived ones are included only when
  /// [includeArchived] is true.
  Stream<List<AccountWithBalance>> watchWithBalances({
    bool includeArchived = false,
  }) {
    final String where = includeArchived ? '' : 'WHERE a.is_archived = 0';
    return _db
        .customSelect(
          '$_balanceSql $where ORDER BY a.is_archived, a.id',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.accounts,
            _db.transactions,
          },
        )
        .watch()
        .map(
          (List<QueryRow> rows) => rows
              .map(
                (QueryRow r) => AccountWithBalance(
                  _db.accounts.map(r.data),
                  r.read<int>('balance'),
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<List<Account>> watchAll({bool includeArchived = true}) {
    final SimpleSelectStatement<$AccountsTable, Account> q =
        _db.select(_db.accounts)
          ..orderBy(<OrderClauseGenerator<$AccountsTable>>[
            (a) => OrderingTerm.asc(a.isArchived),
            (a) => OrderingTerm.asc(a.id),
          ]);
    if (!includeArchived) q.where((a) => a.isArchived.equals(false));
    return q.watch();
  }

  Future<Account?> byId(int id) => (_db.select(_db.accounts)
        ..where((a) => a.id.equals(id)))
      .getSingleOrNull();

  Future<int> create({
    required String name,
    required AccountType type,
    required String currency,
    required int initialBalance,
    required int colorIndex,
  }) =>
      _db.into(_db.accounts).insert(
            AccountsCompanion.insert(
              name: name,
              type: type,
              currency: currency,
              initialBalance: Value(initialBalance),
              colorIndex: Value(colorIndex),
            ),
          );

  /// Saves edits. The currency is locked once the account has transactions
  /// (the editor greys it out): amounts and the toAmount of transfers and
  /// holding moves are stored in the account's currency.
  Future<void> update(Account a) => _db.transaction(() async {
        final Account? old = await byId(a.id);
        if (old != null && old.currency != a.currency && await isUsed(a.id)) {
          throw StateError('account currency is locked once used');
        }
        await _db.update(_db.accounts).replace(a);
      });

  Future<void> setArchived(int id, bool archived) =>
      (_db.update(_db.accounts)..where((a) => a.id.equals(id)))
          .write(AccountsCompanion(isArchived: Value(archived)));

  Future<bool> isUsed(int id) async {
    final Expression<int> c = _db.transactions.id.count();
    final TypedResult row = await (_db.selectOnly(_db.transactions)
          ..addColumns(<Expression<Object>>[c])
          ..where(
            _db.transactions.accountId.equals(id) |
                _db.transactions.toAccountId.equals(id),
          ))
        .getSingle();
    return (row.read(c) ?? 0) > 0;
  }

  /// Hard-deletes an unused account; otherwise archives it.
  /// Returns true when the row was really deleted.
  Future<bool> deleteOrArchive(int id) => _db.transaction(() async {
        if (await isUsed(id)) {
          await setArchived(id, true);
          return false;
        }
        await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
        return true;
      });
}
