import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'models.dart';
import 'backup.dart';
import 'repositories/account_repository.dart';
import 'repositories/budget_repository.dart';
import 'cbar/cbar_client.dart';
import 'repositories/category_repository.dart';
import 'repositories/holding_repository.dart';
import 'repositories/rate_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/transaction_repository.dart';

export 'database.dart';
export 'models.dart';
export 'backup.dart';
export 'repositories/account_repository.dart';
export 'repositories/budget_repository.dart';
export 'cbar/cbar_client.dart';
export 'cbar/cbar_parser.dart';
export 'holding_math.dart';
export 'repositories/category_repository.dart';
export 'repositories/holding_repository.dart';
export 'repositories/rate_repository.dart';
export 'repositories/report_repository.dart';
export 'repositories/transaction_repository.dart';

final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final Provider<AccountRepository> accountRepositoryProvider =
    Provider<AccountRepository>(
  (Ref ref) => AccountRepository(ref.watch(databaseProvider)),
);

final Provider<CategoryRepository> categoryRepositoryProvider =
    Provider<CategoryRepository>(
  (Ref ref) => CategoryRepository(ref.watch(databaseProvider)),
);

final Provider<TransactionRepository> transactionRepositoryProvider =
    Provider<TransactionRepository>(
  (Ref ref) => TransactionRepository(ref.watch(databaseProvider)),
);

final Provider<RateRepository> rateRepositoryProvider =
    Provider<RateRepository>(
  (Ref ref) => RateRepository(ref.watch(databaseProvider)),
);

// ---------------------------------------------------------------------------
// Reactive queries
// ---------------------------------------------------------------------------

final StreamProvider<Rates> ratesProvider = StreamProvider<Rates>(
  (Ref ref) => ref.watch(rateRepositoryProvider).watch(),
);

/// Active (non-archived) accounts with balances.
final StreamProvider<List<AccountWithBalance>> accountBalancesProvider =
    StreamProvider<List<AccountWithBalance>>(
  (Ref ref) => ref.watch(accountRepositoryProvider).watchWithBalances(),
);

/// All accounts including archived ones, with balances.
final StreamProvider<List<AccountWithBalance>> allAccountBalancesProvider =
    StreamProvider<List<AccountWithBalance>>(
  (Ref ref) => ref
      .watch(accountRepositoryProvider)
      .watchWithBalances(includeArchived: true),
);

/// Every account (archived included), for resolving names and pickers.
final StreamProvider<List<Account>> allAccountsProvider =
    StreamProvider<List<Account>>(
  (Ref ref) => ref.watch(accountRepositoryProvider).watchAll(),
);

/// Total balance of active accounts in AZN minor units.
final Provider<AsyncValue<int>> totalBalanceProvider =
    Provider<AsyncValue<int>>((Ref ref) {
  final AsyncValue<List<AccountWithBalance>> accounts =
      ref.watch(accountBalancesProvider);
  final Rates rates = ref.watch(ratesProvider).value ?? Rates.defaults;
  return accounts.whenData(
    (List<AccountWithBalance> list) => list.fold<int>(
      0,
      (int sum, AccountWithBalance a) =>
          sum + rates.toBase(a.balance, a.account.currency),
    ),
  );
});

/// Categories, optionally by type, archived included when requested.
typedef CategoryQuery = ({CategoryType? type, bool includeArchived});

final categoriesProvider = StreamProvider.family<List<TxCategory>, CategoryQuery>(
  (Ref ref, CategoryQuery q) => ref.watch(categoryRepositoryProvider).watch(
        type: q.type,
        includeArchived: q.includeArchived,
      ),
);

final StreamProvider<Map<int, int>> categoryUsageProvider =
    StreamProvider<Map<int, int>>(
  (Ref ref) => ref.watch(categoryRepositoryProvider).watchUsageCounts(),
);

final transactionsProvider = StreamProvider.family<List<TxDetails>, TxFilter>(
  (Ref ref, TxFilter f) => ref.watch(transactionRepositoryProvider).watch(f),
);

/// Income/expense totals in AZN for a date window.
final periodTotalsProvider = StreamProvider.family<PeriodTotals, DateWindow>((Ref ref, DateWindow w) {
  final Rates rates = ref.watch(ratesProvider).value ?? Rates.defaults;
  return ref.watch(transactionRepositoryProvider).watchTotals(w, rates);
});

final Provider<BudgetRepository> budgetRepositoryProvider = Provider<BudgetRepository>(
  (Ref ref) => BudgetRepository(ref.watch(databaseProvider)),
);

final Provider<ReportRepository> reportRepositoryProvider = Provider<ReportRepository>(
  (Ref ref) => ReportRepository(ref.watch(databaseProvider)),
);

final Provider<BackupService> backupServiceProvider = Provider<BackupService>(
  (Ref ref) => BackupService(ref.watch(databaseProvider)),
);

/// Budgets of a `yyyy-MM` month with spending in AZN.
final budgetProgressProvider =
    StreamProvider.family<List<BudgetProgress>, String>((Ref ref, String month) {
  final Rates rates = ref.watch(ratesProvider).value ?? Rates.defaults;
  return ref.watch(budgetRepositoryProvider).watchMonth(month, rates);
});

typedef CategoryTotalsQuery = ({DateWindow window, TxType type});

/// Category totals in AZN for the Reports pie chart.
final categoryTotalsProvider =
    StreamProvider.family<List<CategoryTotal>, CategoryTotalsQuery>(
        (Ref ref, CategoryTotalsQuery q) {
  final Rates rates = ref.watch(ratesProvider).value ?? Rates.defaults;
  return ref.watch(reportRepositoryProvider).watchCategoryTotals(q.window, q.type, rates);
});

/// Monthly income/expense for the last N months (ending with the current one).
final monthlySeriesProvider = StreamProvider.family<MonthlySeries, int>((Ref ref, int count) {
  final Rates rates = ref.watch(ratesProvider).value ?? Rates.defaults;
  return ref.watch(reportRepositoryProvider).watchMonthly(DateTime.now(), count, rates);
});

// ---------------------------------------------------------------------------
// Kənar yerlər (holdings) and net worth
// ---------------------------------------------------------------------------

final Provider<HoldingRepository> holdingRepositoryProvider = Provider<HoldingRepository>(
  (Ref ref) => HoldingRepository(ref.watch(databaseProvider)),
);

/// Active holdings with amount and AZN value.
final StreamProvider<List<HoldingWithValue>> holdingsProvider =
    StreamProvider<List<HoldingWithValue>>((Ref ref) {
  final Rates rates = ref.watch(ratesProvider).value ?? Rates.defaults;
  return ref.watch(holdingRepositoryProvider).watchHoldings(rates);
});

/// Holdings including archived ones.
final StreamProvider<List<HoldingWithValue>> allHoldingsProvider =
    StreamProvider<List<HoldingWithValue>>((Ref ref) {
  final Rates rates = ref.watch(ratesProvider).value ?? Rates.defaults;
  return ref.watch(holdingRepositoryProvider).watchHoldings(rates, includeArchived: true);
});

final holdingDetailProvider = StreamProvider.family<HoldingDetail?, int>(
  (Ref ref, int id) => ref.watch(holdingRepositoryProvider).watchDetail(id),
);

/// Sum of active holdings in AZN ("Kənarda").
final Provider<AsyncValue<int>> holdingsTotalProvider = Provider<AsyncValue<int>>(
  (Ref ref) => ref.watch(holdingsProvider).whenData(
        (List<HoldingWithValue> l) => l.fold<int>(0, (int s, HoldingWithValue h) => s + h.azn),
      ),
);

/// Spendable balance + holdings ("Ümumi sərvət").
final Provider<AsyncValue<NetWorth>> netWorthProvider = Provider<AsyncValue<NetWorth>>((Ref ref) {
  final AsyncValue<int> accounts = ref.watch(totalBalanceProvider);
  final AsyncValue<int> holdings = ref.watch(holdingsTotalProvider);
  if (accounts.hasValue && holdings.hasValue) {
    return AsyncData<NetWorth>(
      NetWorth(accounts: accounts.requireValue, holdings: holdings.requireValue),
    );
  }
  if (accounts.hasError) return AsyncError<NetWorth>(accounts.error!, accounts.stackTrace!);
  if (holdings.hasError) return AsyncError<NetWorth>(holdings.error!, holdings.stackTrace!);
  return const AsyncLoading<NetWorth>();
});

/// Exchange-rate rows with source / manual flag / CBAR date.
final StreamProvider<List<ExchangeRate>> rateRowsProvider = StreamProvider<List<ExchangeRate>>(
  (Ref ref) => ref.watch(rateRepositoryProvider).watchRows(),
);

final Provider<CbarClient> cbarClientProvider = Provider<CbarClient>((Ref ref) {
  final CbarClient c = CbarClient();
  ref.onDispose(c.close);
  return c;
});

/// Expense per day for the last 14 days ending today (oldest first, AZN):
/// the Home weekly chart uses the last 7 and compares with the 7 before.
final StreamProvider<List<int>> dailyExpensesProvider = StreamProvider<List<int>>((Ref ref) {
  final Rates rates = ref.watch(ratesProvider).value ?? Rates.defaults;
  return ref.watch(reportRepositoryProvider).watchDailyExpenses(DateTime.now(), 14, rates);
});
