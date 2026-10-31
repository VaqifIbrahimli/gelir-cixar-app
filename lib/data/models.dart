import 'package:flutter/foundation.dart' show immutable, listEquals;

import 'database.dart';

export 'enums.dart';

/// Exchange rates to the base currency (AZN). AZN is always 1.0.
@immutable
class Rates {
  const Rates(this._toAzn);

  static const Rates defaults = Rates(<String, double>{});

  final Map<String, double> _toAzn;

  double rateOf(String currency) {
    if (currency == Currency.base.code) return 1.0;
    return _toAzn[currency] ?? 1.0;
  }

  /// Converts minor units of [currency] to AZN minor units.
  int toBase(int minor, String currency) =>
      (minor * rateOf(currency)).round();

  Map<String, double> get asMap => Map<String, double>.unmodifiable(_toAzn);
}

/// An account and its live balance (in the account's own currency).
@immutable
class AccountWithBalance {
  const AccountWithBalance(this.account, this.balance);

  final Account account;

  /// Minor units in [Account.currency].
  final int balance;
}

/// A transaction joined with its accounts and category.
@immutable
class TxDetails {
  const TxDetails({
    required this.tx,
    required this.account,
    this.toAccount,
    this.category,
    this.holding,
    this.linkedLoss,
  });

  final MoneyTx tx;
  final Account account;
  final Account? toAccount;
  final TxCategory? category;

  /// The holding of a toHolding / fromHolding move.
  final Holding? holding;

  /// Bonus-loss expense written with this transfer (same linkGroupId),
  /// when the list grouped them (DESIGN.md §18.6.3).
  final TxDetails? linkedLoss;

  TxDetails withLinkedLoss(TxDetails? loss) => TxDetails(
        tx: tx,
        account: account,
        toAccount: toAccount,
        category: category,
        holding: holding,
        linkedLoss: loss,
      );

  /// Sent amount of a bonus transfer (arrived + loss).
  int get sentAmount => tx.amount + (linkedLoss?.tx.amount ?? 0);

  /// "Nağd → Ev seyfi" style label for transfers and holding moves.
  String? get moveLabel => switch (tx.type) {
        TxType.transfer => '${account.name} → ${toAccount?.name ?? '?'}',
        TxType.toHolding => '${account.name} → ${holding?.name ?? '?'}',
        TxType.fromHolding => '${holding?.name ?? '?'} → ${account.name}',
        TxType.income || TxType.expense => null,
      };
}

/// Income / expense totals for a period in AZN minor units. Transfers are
/// never included.
@immutable
class PeriodTotals {
  const PeriodTotals({this.income = 0, this.expense = 0});

  final int income;
  final int expense;

  int get net => income - expense;
}

/// Inclusive-exclusive date window [start, end).
@immutable
class DateWindow {
  const DateWindow(this.start, this.end);

  factory DateWindow.month(DateTime anyDay) {
    final DateTime s = DateTime(anyDay.year, anyDay.month);
    return DateWindow(s, DateTime(s.year, s.month + 1));
  }

  /// Whole days from [first] to [last], both inclusive.
  factory DateWindow.days(DateTime first, DateTime last) => DateWindow(
        DateTime(first.year, first.month, first.day),
        DateTime(last.year, last.month, last.day + 1),
      );

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is DateWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Minutes since midnight (0..1439) of a local time, e.g. 22:00 -> 1320.
int minuteOfDay(DateTime d) => d.hour * 60 + d.minute;

/// A time-of-day window in minutes since midnight, both ends inclusive.
/// When [from] > [to] it wraps midnight: 22:00–06:00 matches 23:15 and 05:59.
@immutable
class TimeOfDayRange {
  const TimeOfDayRange(this.from, this.to)
      : assert(from >= 0 && from < 1440),
        assert(to >= 0 && to < 1440);

  final int from;
  final int to;

  bool get wraps => from > to;

  bool containsMinute(int m) => wraps ? (m >= from || m <= to) : (m >= from && m <= to);

  bool contains(DateTime d) => containsMinute(minuteOfDay(d));

  @override
  bool operator ==(Object other) => other is TimeOfDayRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Transaction list query. Value-equal so it can key a provider family.
@immutable
class TxFilter {
  const TxFilter({
    this.types = const <TxType>[],
    this.accountId,
    this.categoryId,
    this.window,
    this.query = '',
    this.limit,
    this.transportMode,
    this.routeCode,
    this.timeOfDay,
  });

  /// Empty means all types.
  final List<TxType> types;
  final int? accountId;
  final int? categoryId;
  final DateWindow? window;

  /// Case-insensitive substring of the note.
  final String query;
  final int? limit;

  /// v1.2: transport sub-mode / route code (bus) or station (metro).
  final TransportMode? transportMode;
  final String? routeCode;

  /// v1.2: local time-of-day window (may wrap midnight).
  final TimeOfDayRange? timeOfDay;

  bool get isActive =>
      types.isNotEmpty ||
      accountId != null ||
      categoryId != null ||
      window != null ||
      query.trim().isNotEmpty ||
      transportMode != null ||
      routeCode != null ||
      timeOfDay != null;

  TxFilter copyWith({
    List<TxType>? types,
    int? Function()? accountId,
    int? Function()? categoryId,
    DateWindow? Function()? window,
    String? query,
    TransportMode? Function()? transportMode,
    String? Function()? routeCode,
    TimeOfDayRange? Function()? timeOfDay,
  }) =>
      TxFilter(
        types: types ?? this.types,
        accountId: accountId != null ? accountId() : this.accountId,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        window: window != null ? window() : this.window,
        query: query ?? this.query,
        limit: limit,
        transportMode: transportMode != null ? transportMode() : this.transportMode,
        routeCode: routeCode != null ? routeCode() : this.routeCode,
        timeOfDay: timeOfDay != null ? timeOfDay() : this.timeOfDay,
      );

  @override
  bool operator ==(Object other) =>
      other is TxFilter &&
      listEquals(other.types, types) &&
      other.accountId == accountId &&
      other.categoryId == categoryId &&
      other.window == window &&
      other.query == query &&
      other.limit == limit &&
      other.transportMode == transportMode &&
      other.routeCode == routeCode &&
      other.timeOfDay == timeOfDay;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(types),
        accountId,
        categoryId,
        window,
        query,
        limit,
        transportMode,
        routeCode,
        timeOfDay,
      );
}

/// Rows removed together by TransactionRepository.deleteWithLinked (a
/// transaction, its linked bonus-loss partner, and holding entries of a
/// holding move), so undo can put all of them back.
@immutable
class DeletedTransactions {
  const DeletedTransactions(this.transactions, this.entries);

  final List<MoneyTx> transactions;
  final List<HoldingEntry> entries;

  /// True when more than one transaction went (a bonus transfer pair).
  bool get isPair => transactions.length > 1;
}

/// Transport spending of a period (Reports card, DESIGN.md §18.10).
@immutable
class TransportReport {
  const TransportReport({required this.byMode, required this.routes});

  static const TransportReport empty =
      TransportReport(byMode: <TransportMode, int>{}, routes: <RouteUsage>[]);

  /// AZN minor units per mode, modes with spending only.
  final Map<TransportMode, int> byMode;

  /// Bus routes and metro stations, most trips first.
  final List<RouteUsage> routes;

  int get total => byMode.values.fold<int>(0, (int s, int v) => s + v);
}

@immutable
class RouteUsage {
  const RouteUsage({required this.mode, required this.code, required this.trips, required this.amount});

  final TransportMode mode;
  final String code;
  final int trips;

  /// AZN minor units.
  final int amount;
}

extension TxCategoryName on TxCategory {
  String localizedName(String languageCode) =>
      languageCode == 'en' && nameEn.trim().isNotEmpty ? nameEn : nameAz;

  /// The seeded "Bonus itkisi" category: never deleted, archived or budgeted.
  bool get isSystem => specialKind == CategorySpecialKind.bonusLoss;

  bool get isTransport => specialKind == CategorySpecialKind.transport;
}

/// Received amount of a bonus transfer: [sent] × [ratePercent] %, rounded
/// half up to the qəpik (DESIGN.md §18.6.2). The loss is sent − received.
int bonusReceived(int sent, int ratePercent) => (sent * ratePercent + 50) ~/ 100;

/// `yyyy-MM` key of a month, as stored in `budgets.month`.
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Parses a `yyyy-MM` key into the first day of that month.
DateTime monthFromKey(String key) {
  final List<String> p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]));
}

/// Usage of a budget is green below 80 %, a warning from 80 %, and over
/// budget from 100 % (DESIGN.md §2.2).
abstract final class BudgetThresholds {
  static const int warning = 80;
  static const int danger = 100;
}

/// A budget with the amount spent in its month (AZN minor units).
@immutable
class BudgetProgress {
  const BudgetProgress(this.budget, this.spent);

  final Budget budget;
  final int spent;

  int get limit => budget.limitAmount;
  int get remaining => limit - spent;
  double get ratio => limit <= 0 ? 0 : spent / limit;
}

/// Sum per category for a period, in AZN minor units. `categoryId` is null
/// for transactions without a category.
@immutable
class CategoryTotal {
  const CategoryTotal(this.categoryId, this.amount);

  final int? categoryId;
  final int amount;
}

/// Income / expense of one calendar month (AZN minor units).
@immutable
class MonthTotals {
  const MonthTotals(this.month, this.totals);

  /// First day of the month.
  final DateTime month;
  final PeriodTotals totals;
}

/// Monthly series for the reports bar / line charts.
@immutable
class MonthlySeries {
  const MonthlySeries(this.months, this.netAfter);

  final List<MonthTotals> months;

  /// Net (income − expense) of transactions dated after the last month,
  /// used to walk the balance trend backwards from today's balance.
  final int netAfter;
}

/// A threshold crossed by a saved transaction.
@immutable
class BudgetAlertEvent {
  const BudgetAlertEvent({
    required this.budget,
    required this.threshold,
    required this.spent,
  });

  final Budget budget;

  /// 80 or 100.
  final int threshold;
  final int spent;
}

/// A holding with its current amount (own currency) and AZN value.
@immutable
class HoldingWithValue {
  const HoldingWithValue(this.holding, this.amount, this.azn, {this.lastChange});

  /// Date of the latest entry (or creation), for "3 gün əvvəl yeniləndi".
  final DateTime? lastChange;

  final Holding holding;

  /// Minor units in [Holding.currency].
  final int amount;

  /// Minor units in AZN.
  final int azn;
}

/// A holding with its entries (newest first) and the value after each one
/// (oldest first, for charts).
@immutable
class HoldingDetail {
  const HoldingDetail({
    required this.holding,
    required this.entries,
    required this.series,
    required this.amount,
    required this.usedByTransactions,
    this.linkedAccounts = const <int, String>{},
  });

  /// Entry id → account name, for entries created by an account move.
  final Map<int, String> linkedAccounts;

  final Holding holding;
  final List<HoldingEntry> entries;
  final List<({DateTime date, int amount})> series;
  final int amount;

  /// True when account moves reference it (then it can only be archived).
  final bool usedByTransactions;
}

/// Spendable balance, holdings and their sum (all AZN minor units).
@immutable
class NetWorth {
  const NetWorth({required this.accounts, required this.holdings});

  final int accounts;
  final int holdings;

  int get total => accounts + holdings;
}

/// Folds each bonus-loss expense into the transfer it was written with
/// (same linkGroupId, DESIGN.md §18.6.3), keeping the list order. A loss
/// whose transfer is not in [items] (e.g. filtered out) stays on its own.
List<TxDetails> groupBonusPairs(List<TxDetails> items) {
  final Map<String, TxDetails> losses = <String, TxDetails>{};
  final Set<String> transfers = <String>{};
  for (final TxDetails t in items) {
    final String? g = t.tx.linkGroupId;
    if (g == null) continue;
    if (t.tx.type == TxType.transfer) transfers.add(g);
    if (t.tx.type == TxType.expense) losses[g] = t;
  }
  if (losses.isEmpty) return items;
  return <TxDetails>[
    for (final TxDetails t in items)
      if (t.tx.linkGroupId case final String g? when t.tx.type == TxType.transfer && losses.containsKey(g))
        t.withLinkedLoss(losses[g])
      else if (!(t.tx.type == TxType.expense && t.tx.linkGroupId != null && transfers.contains(t.tx.linkGroupId)))
        t,
  ];
}
