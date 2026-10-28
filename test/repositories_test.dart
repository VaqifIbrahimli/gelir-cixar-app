// Data-layer rules: balances, archive-vs-delete, budgets and reports.
// Every test opens its own seeded in-memory database (see helpers/test_db.dart).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/data/providers.dart';

import 'helpers/test_db.dart';

void main() {
  late AppDatabase db;
  const Rates rates = Rates(<String, double>{'USD': 1.7, 'EUR': 1.85});

  setUp(() => db = openTestDb());
  tearDown(() => db.close());

  Future<Map<int, int>> balances({bool includeArchived = false}) async {
    final List<AccountWithBalance> list = await AccountRepository(db)
        .watchWithBalances(includeArchived: includeArchived)
        .first;
    return <int, int>{for (final AccountWithBalance a in list) a.account.id: a.balance};
  }

  // ---------------------------------------------------------------------------
  group('balances', () {
    final DateTime d = DateTime(2026, 10, 10, 12);

    test('initial + income − expense ± same- and cross-currency transfers', () async {
      final int azCard = await db.addAccount(name: 'Kart', initialBalance: 2000);
      final int usd = await db.addAccount(name: 'USD', currency: 'USD', initialBalance: 10000);
      await db.addIncome(50000, d);
      await db.addExpense(12000, d);
      // Same currency: destination receives `amount`.
      await db.addTransfer(5000, d, from: Seed.cashAccount, to: azCard);
      // Cross currency: 170.00 ₼ out, 100.00 $ in.
      await db.addTransfer(17000, d, from: Seed.cashAccount, to: usd, toAmount: 10000);

      final Map<int, int> b = await balances();
      expect(b[Seed.cashAccount], 50000 - 12000 - 5000 - 17000);
      expect(b[azCard], 2000 + 5000);
      expect(b[usd], 10000 + 10000, reason: 'credited toAmount, in USD');
    });

    test('initial balance alone, and a negative balance', () async {
      final int acc = await db.addAccount(initialBalance: 1500);
      await db.addExpense(4000, d, accountId: acc);
      expect((await balances())[acc], -2500);
    });

    test('total balance is converted to AZN through exchange_rates', () async {
      final int usd = await db.addAccount(name: 'USD', currency: 'USD', initialBalance: 10000);
      final int eur = await db.addAccount(name: 'EUR', currency: 'EUR', initialBalance: 20000);
      await db.addIncome(3000, d); // cash AZN

      final ProviderContainer c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      Future<int> total() async {
        await c.read(ratesProvider.future);
        await c.read(accountBalancesProvider.future);
        return c.read(totalBalanceProvider).requireValue;
      }

      final ProviderSubscription<AsyncValue<int>> sub =
          c.listen(totalBalanceProvider, (_, _) {});
      addTearDown(sub.close);
      // Seeded rates: USD 1.70, EUR 1.85.
      expect(await total(), 3000 + 17000 + 37000);

      await RateRepository(db).setRate('USD', 2.0);
      await pumpEventQueue();
      expect(await total(), 3000 + 20000 + 37000);

      // Archived accounts are not part of the total.
      await AccountRepository(db).setArchived(eur, true);
      await pumpEventQueue();
      expect(await total(), 3000 + 20000);
      expect(usd, isPositive);
    });

    test('an unknown currency falls back to rate 1.0', () {
      expect(const Rates(<String, double>{}).toBase(1234, 'GBP'), 1234);
      expect(rates.toBase(1000, 'AZN'), 1000);
      expect(rates.toBase(1, 'USD'), 2, reason: '1.7 rounds to 2');
    });

    test('transfers are excluded from income/expense totals', () async {
      final int usd = await db.addAccount(currency: 'USD');
      await db.addIncome(50000, d);
      await db.addExpense(12000, d);
      await db.addExpense(1000, d, accountId: usd); // 10 $ = 17 ₼
      await db.addTransfer(9999, d, from: Seed.cashAccount, to: usd, toAmount: 5000);

      final PeriodTotals t = await TransactionRepository(db)
          .watchTotals(DateWindow.month(d), rates)
          .first;
      expect(t.income, 50000);
      expect(t.expense, 12000 + 1700);
      expect(t.net, 50000 - 13700);

      final MonthlySeries s = await ReportRepository(db).watchMonthly(d, 1, rates).first;
      expect(s.months.single.totals.income, 50000);
      expect(s.months.single.totals.expense, 13700);

      final List<CategoryTotal> cats = await ReportRepository(db)
          .watchCategoryTotals(DateWindow.month(d), TxType.expense, rates)
          .first;
      expect(cats.fold<int>(0, (int s, CategoryTotal c) => s + c.amount), 13700);
    });
  });

  // ---------------------------------------------------------------------------
  group('archive vs delete', () {
    final DateTime d = DateTime(2026, 10, 10);

    test('an account without transactions is deleted', () async {
      final AccountRepository repo = AccountRepository(db);
      final int id = await db.addAccount();
      expect(await repo.isUsed(id), isFalse);
      expect(await repo.deleteOrArchive(id), isTrue);
      expect(await repo.byId(id), isNull);
    });

    test('an account with transactions is archived, not deleted', () async {
      final AccountRepository repo = AccountRepository(db);
      final int id = await db.addAccount();
      await db.addExpense(100, d, accountId: id);
      expect(await repo.deleteOrArchive(id), isFalse);
      final Account? a = await repo.byId(id);
      expect(a, isNotNull);
      expect(a!.isArchived, isTrue);
      expect((await balances()).containsKey(id), isFalse);
      expect((await balances(includeArchived: true))[id], -100);
      expect(await db.select(db.transactions).get(), hasLength(1));
    });

    test('an account used only as a transfer destination is archived', () async {
      final AccountRepository repo = AccountRepository(db);
      final int id = await db.addAccount();
      await db.addTransfer(100, d, from: Seed.cashAccount, to: id);
      expect(await repo.deleteOrArchive(id), isFalse);
      expect((await repo.byId(id))!.isArchived, isTrue);
    });

    test('an unused category is deleted', () async {
      final CategoryRepository repo = CategoryRepository(db);
      final int id = await repo.create(
        nameAz: 'Test',
        nameEn: 'Test',
        iconCodePoint: 0xe000,
        colorIndex: 0,
        type: CategoryType.expense,
      );
      expect(await repo.deleteOrArchive(id), isTrue);
      expect(await repo.deleteOrArchive(Seed.telecom), isTrue);
      final List<TxCategory> all = await repo.watch(includeArchived: true).first;
      expect(all.map((TxCategory c) => c.id), isNot(contains(id)));
      expect(all.map((TxCategory c) => c.id), isNot(contains(Seed.telecom)));
    });

    test('a category with transactions is archived', () async {
      final CategoryRepository repo = CategoryRepository(db);
      await db.addExpense(100, d, categoryId: Seed.food);
      expect(await repo.deleteOrArchive(Seed.food), isFalse);
      expect((await repo.watch().first).map((TxCategory c) => c.id), isNot(contains(Seed.food)));
      final TxCategory food = (await repo.watch(includeArchived: true).first)
          .firstWhere((TxCategory c) => c.id == Seed.food);
      expect(food.isArchived, isTrue);
    });

    test('a category with only a budget is archived', () async {
      final CategoryRepository repo = CategoryRepository(db);
      await BudgetRepository(db).upsert(categoryId: Seed.rent, month: '2026-10', limitAmount: 100);
      expect(await repo.isUsed(Seed.rent), isTrue);
      expect(await repo.deleteOrArchive(Seed.rent), isFalse);
      expect(await db.select(db.budgets).get(), hasLength(1));
    });

    test('a category becomes deletable once its last transaction is gone', () async {
      final CategoryRepository repo = CategoryRepository(db);
      final int tx = await db.addExpense(100, d, categoryId: Seed.fun);
      await TransactionRepository(db).delete(tx);
      expect(await repo.deleteOrArchive(Seed.fun), isTrue);
    });

    test('usage counts per category', () async {
      await db.addExpense(100, d, categoryId: Seed.food);
      await db.addExpense(100, d, categoryId: Seed.food);
      await db.addIncome(100, d, categoryId: Seed.salary);
      await db.addTransfer(100, d, from: Seed.cashAccount, to: await db.addAccount());
      final Map<int, int> n = await CategoryRepository(db).watchUsageCounts().first;
      expect(n, <int, int>{Seed.food: 2, Seed.salary: 1});
    });
  });

  // ---------------------------------------------------------------------------
  group('budgets', () {
    late BudgetRepository repo;
    setUp(() => repo = BudgetRepository(db));

    Future<BudgetProgress> progress(String month, {int categoryId = Seed.food}) async =>
        (await repo.getMonth(month, rates))
            .firstWhere((BudgetProgress p) => p.budget.categoryId == categoryId);

    test('usage %, remaining and over-budget remaining', () async {
      final DateTime d = DateTime(2026, 10, 5);
      await repo.upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 20000);
      expect((await progress('2026-10')).spent, 0);
      expect((await progress('2026-10')).ratio, 0);

      await db.addExpense(5000, d);
      BudgetProgress p = await progress('2026-10');
      expect(p.spent, 5000);
      expect(p.ratio, closeTo(0.25, 1e-9));
      expect(p.remaining, 15000);

      await db.addExpense(20000, d);
      p = await progress('2026-10');
      expect(p.ratio, closeTo(1.25, 1e-9));
      expect(p.remaining, -5000);
    });

    test('only expenses of the budget category count, in AZN', () async {
      final DateTime d = DateTime(2026, 10, 5);
      final int usd = await db.addAccount(currency: 'USD');
      await repo.upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 100000);
      await db.addExpense(1000, d); // 10 ₼
      await db.addExpense(1000, d, accountId: usd); // 10 $ = 17 ₼
      await db.addExpense(9999, d, categoryId: Seed.transport); // other category
      await db.addIncome(9999, d, categoryId: Seed.food); // wrong type (forced)
      expect((await progress('2026-10')).spent, 1000 + 1700);
    });

    test('a zero limit never divides by zero nor alerts', () async {
      final DateTime d = DateTime(2026, 10, 5);
      await repo.upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 0);
      await db.addExpense(100, d);
      expect((await progress('2026-10')).ratio, 0);
      expect(await repo.checkThresholds(categoryId: Seed.food, date: d, rates: rates), isNull);
    });

    test('80 % fires exactly at 80 %, not at 79.99 %', () async {
      final DateTime d = DateTime(2026, 10, 5);
      await repo.upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 10000);
      await db.addExpense(7999, d);
      expect(await repo.checkThresholds(categoryId: Seed.food, date: d, rates: rates), isNull);
      await db.addExpense(1, d);
      final BudgetAlertEvent? ev =
          await repo.checkThresholds(categoryId: Seed.food, date: d, rates: rates);
      expect(ev?.threshold, BudgetThresholds.warning);
      expect(ev?.spent, 8000);
    });

    test('100 % fires exactly at the limit; jumping straight there marks 80 % too', () async {
      final DateTime d = DateTime(2026, 10, 5);
      await repo.upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 10000);
      await db.addExpense(10000, d);
      expect((await repo.checkThresholds(categoryId: Seed.food, date: d, rates: rates))!.threshold,
          BudgetThresholds.danger);
      // Neither threshold fires again this month.
      await db.addExpense(5000, d);
      expect(await repo.checkThresholds(categoryId: Seed.food, date: d, rates: rates), isNull);
      final List<BudgetAlert> fired = await db.select(db.budgetAlerts).get();
      expect(fired.map((BudgetAlert a) => a.threshold).toSet(), <int>{80, 100});
    });

    test('changing the limit re-arms the alerts; the same limit does not', () async {
      final DateTime d = DateTime(2026, 10, 5);
      await repo.upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 10000);
      await db.addExpense(8500, d);
      expect((await repo.checkThresholds(categoryId: Seed.food, date: d, rates: rates))!.threshold, 80);

      // Re-saving the same limit keeps the fired alert.
      await repo.upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 10000);
      expect(await repo.checkThresholds(categoryId: Seed.food, date: d, rates: rates), isNull);

      // Raising the limit to 200 ₼ (42.5 %) re-arms; reaching 80 % fires again.
      await repo.upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 20000);
      expect(await db.select(db.budgetAlerts).get(), isEmpty);
      expect(await repo.checkThresholds(categoryId: Seed.food, date: d, rates: rates), isNull);
      await db.addExpense(7500, d); // 16000 / 20000 = 80 %
      expect((await repo.checkThresholds(categoryId: Seed.food, date: d, rates: rates))!.threshold, 80);
      expect(await db.select(db.budgets).get(), hasLength(1), reason: 'upsert, not insert');
    });

    test('deleting a budget removes its alerts', () async {
      final DateTime d = DateTime(2026, 10, 5);
      await repo.upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 100);
      await db.addExpense(100, d);
      await repo.checkThresholds(categoryId: Seed.food, date: d, rates: rates);
      final Budget b = (await db.select(db.budgets).get()).single;
      await repo.delete(b.id);
      expect(await db.select(db.budgets).get(), isEmpty);
      expect(await db.select(db.budgetAlerts).get(), isEmpty);
    });

    test('month boundaries: last day 23:59 and first day 00:00', () async {
      for (final String m in <String>['2026-09', '2026-10', '2026-11']) {
        await repo.upsert(categoryId: Seed.food, month: m, limitAmount: 100000);
      }
      await db.addExpense(1, DateTime(2026, 9, 30, 23, 59, 59)); // September
      await db.addExpense(10, DateTime(2026, 10, 1, 0, 0)); // October, first instant
      await db.addExpense(100, DateTime(2026, 10, 31, 23, 59)); // October, last minute
      await db.addExpense(1000, DateTime(2026, 11, 1, 0, 0)); // November

      expect((await progress('2026-09')).spent, 1);
      expect((await progress('2026-10')).spent, 110);
      expect((await progress('2026-11')).spent, 1000);
    });

    test('year rollover and leap February', () async {
      for (final String m in <String>['2026-12', '2027-01', '2028-02', '2028-03']) {
        await repo.upsert(categoryId: Seed.food, month: m, limitAmount: 100000);
      }
      await db.addExpense(1, DateTime(2026, 12, 31, 23, 59));
      await db.addExpense(10, DateTime(2027, 1, 1));
      await db.addExpense(100, DateTime(2028, 2, 29, 23, 59));
      await db.addExpense(1000, DateTime(2028, 3, 1));
      expect((await progress('2026-12')).spent, 1);
      expect((await progress('2027-01')).spent, 10);
      expect((await progress('2028-02')).spent, 100);
      expect((await progress('2028-03')).spent, 1000);
    });

    test('an expense at 23:59 on the last day alerts the budget of its own month', () async {
      await repo.upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 10000);
      await repo.upsert(categoryId: Seed.food, month: '2026-11', limitAmount: 10000);
      final DateTime late = DateTime(2026, 10, 31, 23, 59);
      await db.addExpense(9000, late);
      expect((await repo.checkThresholds(categoryId: Seed.food, date: late, rates: rates))!
          .budget.month, '2026-10');
      final DateTime early = DateTime(2026, 11, 1);
      expect(await repo.checkThresholds(categoryId: Seed.food, date: early, rates: rates), isNull);
    });

    test('copyMonth skips existing and archived categories', () async {
      await repo.upsert(categoryId: Seed.food, month: '2026-10', limitAmount: 100);
      await repo.upsert(categoryId: Seed.transport, month: '2026-10', limitAmount: 200);
      await repo.upsert(categoryId: Seed.shopping, month: '2026-10', limitAmount: 300);
      await repo.upsert(categoryId: Seed.food, month: '2026-11', limitAmount: 999);
      await CategoryRepository(db).setArchived(Seed.shopping, true);

      expect(await repo.copyMonth(from: '2026-10', to: '2026-11'), 1);
      final List<BudgetProgress> nov = await repo.getMonth('2026-11', rates);
      expect(<int, int>{for (final BudgetProgress p in nov) p.budget.categoryId: p.limit},
          <int, int>{Seed.food: 999, Seed.transport: 200});
      expect(await repo.copyMonth(from: '2026-10', to: '2026-11'), 0);
    });
  });

  // ---------------------------------------------------------------------------
  group('reports', () {
    test('category breakdown: AZN, sorted, window-bounded, uncategorized kept', () async {
      final DateWindow oct = DateWindow.month(DateTime(2026, 10));
      final int usd = await db.addAccount(currency: 'USD');
      await db.addExpense(1000, DateTime(2026, 10, 2), categoryId: Seed.food);
      await db.addExpense(2000, DateTime(2026, 10, 3), categoryId: Seed.food);
      await db.addExpense(1000, DateTime(2026, 10, 4), categoryId: Seed.rent, accountId: usd);
      await db.addExpense(500, DateTime(2026, 10, 5), categoryId: null);
      await db.addExpense(99999, DateTime(2026, 9, 30, 23, 59), categoryId: Seed.health);
      await db.addExpense(99999, DateTime(2026, 11, 1), categoryId: Seed.health);
      await db.addIncome(77777, DateTime(2026, 10, 6));

      final List<CategoryTotal> t = await ReportRepository(db)
          .watchCategoryTotals(oct, TxType.expense, rates)
          .first;
      expect(t.map((CategoryTotal c) => (c.categoryId, c.amount)).toList(),
          <(int?, int)>[(Seed.food, 3000), (Seed.rent, 1700), (null, 500)]);

      final List<CategoryTotal> inc = await ReportRepository(db)
          .watchCategoryTotals(oct, TxType.income, rates)
          .first;
      expect(inc.single.amount, 77777);
    });

    test('6-month series ends with the given month, oldest first, zero-filled', () async {
      await db.addExpense(100, DateTime(2026, 4, 30, 23, 59)); // before the window
      await db.addIncome(1000, DateTime(2026, 5, 1));
      await db.addExpense(300, DateTime(2026, 7, 15));
      await db.addExpense(400, DateTime(2026, 10, 31, 23, 59));
      await db.addIncome(5000, DateTime(2026, 11, 2)); // after: only in netAfter
      await db.addExpense(2000, DateTime(2026, 12, 1));

      final MonthlySeries s =
          await ReportRepository(db).watchMonthly(DateTime(2026, 10, 15), 6, rates).first;
      expect(s.months.map((MonthTotals m) => monthKey(m.month)),
          <String>['2026-05', '2026-06', '2026-07', '2026-08', '2026-09', '2026-10']);
      expect(s.months.map((MonthTotals m) => m.totals.income), <int>[1000, 0, 0, 0, 0, 0]);
      expect(s.months.map((MonthTotals m) => m.totals.expense), <int>[0, 0, 300, 0, 0, 400]);
      expect(s.netAfter, 5000 - 2000);
    });

    test('12-month series crosses the year boundary', () async {
      await db.addExpense(100, DateTime(2025, 11, 1)); // first month
      await db.addExpense(200, DateTime(2026, 1, 31, 23, 59));
      await db.addExpense(999, DateTime(2025, 10, 31, 23, 59)); // just outside
      final MonthlySeries s =
          await ReportRepository(db).watchMonthly(DateTime(2026, 10), 12, rates).first;
      expect(s.months, hasLength(12));
      expect(monthKey(s.months.first.month), '2025-11');
      expect(monthKey(s.months.last.month), '2026-10');
      expect(s.months.first.totals.expense, 100);
      expect(s.months[2].totals.expense, 200); // 2026-01
      expect(s.months.fold<int>(0, (int a, MonthTotals m) => a + m.totals.expense), 300);
    });
  });

  // ---------------------------------------------------------------------------
  group('transaction list', () {
    test('note search folds Azerbaijani letters and filters by account', () async {
      final int card = await db.addAccount();
      await db.addExpense(100, DateTime(2026, 10, 1), note: 'ƏRZAQ bazarı');
      await db.addExpense(200, DateTime(2026, 10, 2), note: 'taksi', accountId: card);
      await db.addTransfer(300, DateTime(2026, 10, 3), from: Seed.cashAccount, to: card);
      final TransactionRepository repo = TransactionRepository(db);

      final List<TxDetails> hit = await repo.watch(const TxFilter(query: 'ərzaq')).first;
      expect(hit.single.tx.amount, 100);

      final List<TxDetails> byCard = await repo.watch(TxFilter(accountId: card)).first;
      expect(byCard.map((TxDetails t) => t.tx.amount), <int>[300, 200],
          reason: 'newest first, includes incoming transfer');
      expect(byCard.first.toAccount?.id, card);
    });
  });
}
