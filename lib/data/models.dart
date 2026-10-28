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
  });

  final MoneyTx tx;
  final Account account;
  final Account? toAccount;
  final TxCategory? category;

  /// The holding of a toHolding / fromHolding move.
  final Holding? holding;

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
  });

  /// Empty means all types.
  final List<TxType> types;
  final int? accountId;
  final int? categoryId;
  final DateWindow? window;

  /// Case-insensitive substring of the note.
  final String query;
  final int? limit;

  bool get isActive =>
      types.isNotEmpty ||
      accountId != null ||
      categoryId != null ||
      window != null ||
      query.trim().isNotEmpty;

  TxFilter copyWith({
    List<TxType>? types,
    int? Function()? accountId,
    int? Function()? categoryId,
    DateWindow? Function()? window,
    String? query,
  }) =>
      TxFilter(
        types: types ?? this.types,
        accountId: accountId != null ? accountId() : this.accountId,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        window: window != null ? window() : this.window,
        query: query ?? this.query,
        limit: limit,
      );

  @override
  bool operator ==(Object other) =>
      other is TxFilter &&
      listEquals(other.types, types) &&
      other.accountId == accountId &&
      other.categoryId == categoryId &&
      other.window == window &&
      other.query == query &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(types),
        accountId,
        categoryId,
        window,
        query,
        limit,
      );
}

extension TxCategoryName on TxCategory {
  String localizedName(String languageCode) =>
      languageCode == 'en' && nameEn.trim().isNotEmpty ? nameEn : nameAz;
}

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
