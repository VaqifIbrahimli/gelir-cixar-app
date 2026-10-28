import 'package:drift/drift.dart';

import '../database.dart';
import '../models.dart';

/// Monthly category budgets (limits in AZN) and their one-shot alerts.
class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  // Spent = expenses of the budget's category in its month, per account
  // currency (converted to AZN in Dart through the rates).
  static const String _progressSql = '''
SELECT b.*, a.currency AS currency, COALESCE(SUM(t.amount), 0) AS spent
FROM budgets b
LEFT JOIN transactions t
  ON t.category_id = b.category_id AND t.type = 'expense'
  AND t.date >= ? AND t.date < ?
LEFT JOIN accounts a ON a.id = t.account_id
WHERE b.month = ?
GROUP BY b.id, a.currency
''';

  Selectable<QueryRow> _progressQuery(String month) {
    final DateWindow w = DateWindow.month(monthFromKey(month));
    return _db.customSelect(
      _progressSql,
      variables: <Variable<Object>>[
        Variable<DateTime>(w.start),
        Variable<DateTime>(w.end),
        Variable<String>(month),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.budgets,
        _db.transactions,
        _db.accounts,
      },
    );
  }

  List<BudgetProgress> _fold(List<QueryRow> rows, Rates rates) {
    final Map<int, Budget> budgets = <int, Budget>{};
    final Map<int, int> spent = <int, int>{};
    for (final QueryRow r in rows) {
      final Budget b = _db.budgets.map(r.data);
      budgets[b.id] = b;
      final String? currency = r.readNullable<String>('currency');
      final int v = currency == null ? 0 : rates.toBase(r.read<int>('spent'), currency);
      spent[b.id] = (spent[b.id] ?? 0) + v;
    }
    return <BudgetProgress>[
      for (final Budget b in budgets.values) BudgetProgress(b, spent[b.id] ?? 0),
    ];
  }

  /// Budgets of [month] (`yyyy-MM`) with their spending.
  Stream<List<BudgetProgress>> watchMonth(String month, Rates rates) =>
      _progressQuery(month).watch().map((List<QueryRow> r) => _fold(r, rates));

  Future<List<BudgetProgress>> getMonth(String month, Rates rates) async =>
      _fold(await _progressQuery(month).get(), rates);

  /// Creates or replaces the limit of [categoryId] in [month]. Changing a
  /// limit re-arms its alerts.
  Future<void> upsert({
    required int categoryId,
    required String month,
    required int limitAmount,
  }) =>
      _db.transaction(() async {
        final Budget? existing = await (_db.select(_db.budgets)
              ..where((b) => b.categoryId.equals(categoryId) & b.month.equals(month)))
            .getSingleOrNull();
        if (existing == null) {
          await _db.into(_db.budgets).insert(BudgetsCompanion.insert(
                categoryId: categoryId,
                month: month,
                limitAmount: limitAmount,
              ));
          return;
        }
        if (existing.limitAmount != limitAmount) {
          await (_db.delete(_db.budgetAlerts)
                ..where((a) => a.budgetId.equals(existing.id)))
              .go();
        }
        await _db.update(_db.budgets).replace(existing.copyWith(limitAmount: limitAmount));
      });

  Future<void> delete(int id) => _db.transaction(() async {
        await (_db.delete(_db.budgetAlerts)..where((a) => a.budgetId.equals(id))).go();
        await (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();
      });

  /// Copies the budgets of [from] into [to], skipping categories that already
  /// have a budget in [to] or are archived. Returns how many were copied.
  Future<int> copyMonth({required String from, required String to}) =>
      _db.transaction(() async {
        final List<Budget> source =
            await (_db.select(_db.budgets)..where((b) => b.month.equals(from))).get();
        final Set<int> existing = (await (_db.select(_db.budgets)
                  ..where((b) => b.month.equals(to)))
                .get())
            .map((Budget b) => b.categoryId)
            .toSet();
        final Set<int> archived = (await (_db.select(_db.categories)
                  ..where((c) => c.isArchived.equals(true)))
                .get())
            .map((TxCategory c) => c.id)
            .toSet();
        int n = 0;
        for (final Budget b in source) {
          if (existing.contains(b.categoryId) || archived.contains(b.categoryId)) continue;
          await _db.into(_db.budgets).insert(BudgetsCompanion.insert(
                categoryId: b.categoryId,
                month: to,
                limitAmount: b.limitAmount,
              ));
          n++;
        }
        return n;
      });

  /// Records thresholds newly crossed by the budget of [categoryId] in the
  /// month of [date] and returns them (at most one event: the highest).
  /// Crossing straight to 100 % also marks 80 % as fired.
  Future<BudgetAlertEvent?> checkThresholds({
    required int categoryId,
    required DateTime date,
    required Rates rates,
  }) =>
      _db.transaction(() async {
        final String month = monthKey(date);
        final BudgetProgress? p = (await getMonth(month, rates))
            .where((BudgetProgress p) => p.budget.categoryId == categoryId)
            .firstOrNull;
        if (p == null || p.limit <= 0) return null;
        final double pct = p.ratio * 100;
        final List<int> reached = <int>[
          if (pct >= BudgetThresholds.warning) BudgetThresholds.warning,
          if (pct >= BudgetThresholds.danger) BudgetThresholds.danger,
        ];
        if (reached.isEmpty) return null;
        final Set<int> fired = (await (_db.select(_db.budgetAlerts)
                  ..where((a) => a.budgetId.equals(p.budget.id) & a.month.equals(month)))
                .get())
            .map((BudgetAlert a) => a.threshold)
            .toSet();
        final List<int> fresh = reached.where((int t) => !fired.contains(t)).toList();
        if (fresh.isEmpty) return null;
        for (final int t in fresh) {
          await _db.into(_db.budgetAlerts).insert(
                BudgetAlertsCompanion.insert(budgetId: p.budget.id, month: month, threshold: t),
              );
        }
        return BudgetAlertEvent(budget: p.budget, threshold: fresh.last, spent: p.spent);
      });
}
