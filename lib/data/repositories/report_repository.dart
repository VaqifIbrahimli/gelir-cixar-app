import 'package:drift/drift.dart';

import '../database.dart';
import '../models.dart';

/// Aggregations for the Reports tab. Every amount is converted to AZN
/// through the stored rates; transfers are never counted.
class ReportRepository {
  ReportRepository(this._db);

  final AppDatabase _db;

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables =>
      <ResultSetImplementation<dynamic, dynamic>>{_db.transactions, _db.accounts};

  /// Totals per category for [type] (income or expense) in [window],
  /// sorted by amount, descending.
  Stream<List<CategoryTotal>> watchCategoryTotals(
    DateWindow window,
    TxType type,
    Rates rates,
  ) {
    assert(type != TxType.transfer);
    return _db
        .customSelect(
          '''
SELECT t.category_id AS cid, a.currency AS currency, SUM(t.amount) AS total
FROM transactions t JOIN accounts a ON a.id = t.account_id
WHERE t.type = ? AND t.date >= ? AND t.date < ?
GROUP BY t.category_id, a.currency
''',
          variables: <Variable<Object>>[
            Variable<String>(type.name),
            Variable<DateTime>(window.start),
            Variable<DateTime>(window.end),
          ],
          readsFrom: _tables,
        )
        .watch()
        .map((List<QueryRow> rows) {
      final Map<int?, int> sums = <int?, int>{};
      for (final QueryRow r in rows) {
        final int? cid = r.readNullable<int>('cid');
        sums[cid] = (sums[cid] ?? 0) +
            rates.toBase(r.read<int>('total'), r.read<String>('currency'));
      }
      final List<CategoryTotal> list = <CategoryTotal>[
        for (final MapEntry<int?, int> e in sums.entries)
          if (e.value > 0) CategoryTotal(e.key, e.value),
      ]..sort((CategoryTotal a, CategoryTotal b) => b.amount.compareTo(a.amount));
      return list;
    });
  }

  /// Income/expense per month for the [count] months ending with the month
  /// of [lastMonth], plus the net of everything dated after that month.
  Stream<MonthlySeries> watchMonthly(DateTime lastMonth, int count, Rates rates) {
    final DateTime end = DateTime(lastMonth.year, lastMonth.month + 1);
    final DateTime start = DateTime(end.year, end.month - count);
    return _db
        .customSelect(
          '''
SELECT strftime('%Y-%m', t.date, 'unixepoch', 'localtime') AS ym,
       a.currency AS currency, t.type AS type, SUM(t.amount) AS total
FROM transactions t JOIN accounts a ON a.id = t.account_id
WHERE t.type IN ('income', 'expense') AND t.date >= ?
GROUP BY ym, a.currency, t.type
''',
          variables: <Variable<Object>>[Variable<DateTime>(start)],
          readsFrom: _tables,
        )
        .watch()
        .map((List<QueryRow> rows) {
      final Map<String, (int, int)> byMonth = <String, (int, int)>{};
      final String endKey = monthKey(end);
      int netAfter = 0;
      for (final QueryRow r in rows) {
        final String ym = r.read<String>('ym');
        final int v = rates.toBase(r.read<int>('total'), r.read<String>('currency'));
        final bool income = r.read<String>('type') == TxType.income.name;
        if (ym.compareTo(endKey) >= 0) {
          netAfter += income ? v : -v;
          continue;
        }
        final (int i, int e) = byMonth[ym] ?? (0, 0);
        byMonth[ym] = income ? (i + v, e) : (i, e + v);
      }
      return MonthlySeries(
        <MonthTotals>[
          for (int k = 0; k < count; k++)
            () {
              final DateTime m = DateTime(start.year, start.month + k);
              final (int i, int e) = byMonth[monthKey(m)] ?? (0, 0);
              return MonthTotals(m, PeriodTotals(income: i, expense: e));
            }(),
        ],
        netAfter,
      );
    });
  }

  /// Transport spending in [window] (DESIGN.md §18.10): AZN per mode, and
  /// bus routes / metro stations by trips, then amount.
  Stream<TransportReport> watchTransport(DateWindow window, Rates rates, {int topRoutes = 5}) {
    return _db
        .customSelect(
          '''
SELECT t.transport_mode AS mode, t.route_code AS code, a.currency AS currency,
       SUM(t.amount) AS total, SUM(t.trips) AS trips
FROM transactions t JOIN accounts a ON a.id = t.account_id
WHERE t.type = 'expense' AND t.transport_mode IS NOT NULL AND t.date >= ? AND t.date < ?
GROUP BY t.transport_mode, t.route_code, a.currency
''',
          variables: <Variable<Object>>[Variable<DateTime>(window.start), Variable<DateTime>(window.end)],
          readsFrom: _tables,
        )
        .watch()
        .map((List<QueryRow> rows) {
      final Map<TransportMode, int> byMode = <TransportMode, int>{};
      final Map<(TransportMode, String), (int, int)> routes = <(TransportMode, String), (int, int)>{};
      for (final QueryRow r in rows) {
        final TransportMode? mode =
            TransportMode.values.where((TransportMode m) => m.name == r.read<String>('mode')).firstOrNull;
        if (mode == null) continue;
        final int v = rates.toBase(r.read<int>('total'), r.read<String>('currency'));
        byMode[mode] = (byMode[mode] ?? 0) + v;
        final String? code = r.readNullable<String>('code');
        if (code != null && (mode == TransportMode.bus || mode == TransportMode.metro)) {
          final (int trips, int amount) = routes[(mode, code)] ?? (0, 0);
          routes[(mode, code)] = (trips + r.read<int>('trips'), amount + v);
        }
      }
      byMode.removeWhere((TransportMode _, int v) => v <= 0);
      final List<RouteUsage> list = <RouteUsage>[
        for (final MapEntry<(TransportMode, String), (int, int)> e in routes.entries)
          if (e.value.$1 >= 1)
            RouteUsage(mode: e.key.$1, code: e.key.$2, trips: e.value.$1, amount: e.value.$2),
      ]..sort((RouteUsage a, RouteUsage b) {
          final int c = b.trips.compareTo(a.trips);
          return c != 0 ? c : b.amount.compareTo(a.amount);
        });
      return TransportReport(byMode: byMode, routes: list.take(topRoutes).toList(growable: false));
    });
  }

  /// Expense per local day for the [days] days ending with [today]
  /// (oldest first), in AZN. Moves and transfers are not expenses.
  Stream<List<int>> watchDailyExpenses(DateTime today, int days, Rates rates) {
    final DateTime end = DateTime(today.year, today.month, today.day + 1);
    final DateTime start = DateTime(end.year, end.month, end.day - days);
    return _db
        .customSelect(
          '''
SELECT strftime('%Y-%m-%d', t.date, 'unixepoch', 'localtime') AS d,
       a.currency AS currency, SUM(t.amount) AS total
FROM transactions t JOIN accounts a ON a.id = t.account_id
WHERE t.type = 'expense' AND t.date >= ? AND t.date < ?
GROUP BY d, a.currency
''',
          variables: <Variable<Object>>[Variable<DateTime>(start), Variable<DateTime>(end)],
          readsFrom: _tables,
        )
        .watch()
        .map((List<QueryRow> rows) {
      final Map<String, int> byDay = <String, int>{};
      for (final QueryRow r in rows) {
        final String d = r.read<String>('d');
        byDay[d] = (byDay[d] ?? 0) + rates.toBase(r.read<int>('total'), r.read<String>('currency'));
      }
      String key(DateTime x) =>
          '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
      return <int>[
        for (int k = 0; k < days; k++) byDay[key(DateTime(start.year, start.month, start.day + k))] ?? 0,
      ];
    });
  }
}
