// Widget tests of the real app shell over an in-memory database. Widgets are
// found by visible text, tooltip or public widget type, never by tree shape.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/core/format.dart';
import 'package:gelir_cixar/core/prefs.dart';
import 'package:gelir_cixar/core/theme.dart';
import 'package:gelir_cixar/data/providers.dart';
import 'package:gelir_cixar/features/budgets/widgets/budget_progress_row.dart';
import 'package:gelir_cixar/features/transactions/widgets/tx_tile.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gelir_cixar/app.dart';
import 'package:gelir_cixar/core/app_info.dart';
import 'package:gelir_cixar/core/notifications.dart';
import 'package:gelir_cixar/features/onboarding/onboarding_screen.dart';
import 'package:gelir_cixar/features/settings/rate_confirm_dialog.dart';
import 'package:gelir_cixar/features/settings/rate_sync_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_harness.dart';
import 'helpers/test_db.dart';

Finder inTxTile(String text) =>
    find.descendant(of: find.byType(TxTile), matching: find.text(text));

void main() {
  group('home', () {
    testWidgets('shows the empty state, then a transaction once inserted', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      expect(find.text(h.az.emptyTransactionsTitle), findsOneWidget);
      expect(find.byType(TxTile), findsNothing);

      await h.write((AppDatabase db) => db.addExpense(1250, thisMonth(), categoryId: Seed.food));

      expect(find.text(h.az.emptyTransactionsTitle), findsNothing);
      expect(find.byType(TxTile), findsOneWidget);
      expect(inTxTile('Yemək'), findsOneWidget);
      expect(inTxTile(Fmt.signed(1250, 'AZN', TxType.expense, 'az')), findsOneWidget);
      // Total balance on the card: 0 − 12,50.
      expect(find.text(Fmt.base(-1250, 'az')), findsWidgets);
      await h.dispose();
    });
  });

  group('add transaction', () {
    testWidgets('keypad amount + category + save adds the row', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);

      await tester.tap(find.byTooltip(h.az.addTransaction));
      await h.settle();
      expect(find.text(h.az.newTransaction), findsOneWidget);

      for (final String k in <String>['1', '2', '5']) {
        await tester.tap(find.text(k));
        await tester.pump();
      }
      expect(find.textContaining('125'), findsOneWidget, reason: 'amount display');

      await tester.tap(find.byTooltip(h.az.category));
      await h.settle();
      await tester.tap(find.text('Nəqliyyat'));
      await h.settle();

      await tester.tap(find.text(h.az.save));
      await h.settle();

      // Back on Home with the new row.
      expect(find.text(h.az.newTransaction), findsNothing);
      expect(inTxTile('Nəqliyyat'), findsOneWidget);
      expect(inTxTile(Fmt.signed(12500, 'AZN', TxType.expense, 'az')), findsOneWidget);

      final List<MoneyTx> rows = await h.db.select(h.db.transactions).get();
      expect(rows.single.amount, 12500);
      expect(rows.single.categoryId, Seed.transport);
      expect(rows.single.type, TxType.expense);
      await h.dispose();
    });

    testWidgets('saving without a category is refused', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      await tester.tap(find.byTooltip(h.az.addTransaction));
      await h.settle();
      await tester.tap(find.text('7'));
      await tester.pump();
      await tester.tap(find.text(h.az.save));
      await h.settle();

      expect(find.text(h.az.selectCategory), findsOneWidget);
      expect(find.text(h.az.newTransaction), findsOneWidget, reason: 'still open');
      expect(await h.db.select(h.db.transactions).get(), isEmpty);
      await h.dispose();
    });
  });

  group('settings', () {
    testWidgets('switching the language changes visible labels from az to en', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      await h.tapTab(h.az.navSettings);
      expect(find.text('Ayarlar'), findsWidgets);

      await tester.tap(find.text(h.az.language));
      await h.settle();
      await tester.tap(find.text('English'));
      await h.settle();

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Ayarlar'), findsNothing);
      expect(find.text(h.en.navHome), findsOneWidget, reason: 'bottom bar relabelled');
      expect(h.prefs.getString(PrefKeys.language), 'en');
      await h.dispose();
    });
  });

  group('budgets', () {
    Finder rowOf(String category) => find.ancestor(
          of: find.text(category),
          matching: find.byType(BudgetProgressRow),
        );

    Color? textColor(WidgetTester tester, Finder row, String text) =>
        tester.widget<Text>(find.descendant(of: row, matching: find.text(text))).style?.color;

    Color? barColor(WidgetTester tester, Finder row) => tester
        .widget<LinearProgressIndicator>(
            find.descendant(of: row, matching: find.byType(LinearProgressIndicator)))
        .color;

    testWidgets('warning colour from 80 %, danger from 100 %, normal below', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      await h.write((AppDatabase db) async {
        final String m = monthKey(thisMonth());
        final BudgetRepository b = BudgetRepository(db);
        await b.upsert(categoryId: Seed.food, month: m, limitAmount: 10000);
        await b.upsert(categoryId: Seed.transport, month: m, limitAmount: 10000);
        await b.upsert(categoryId: Seed.shopping, month: m, limitAmount: 10000);
        await b.upsert(categoryId: Seed.health, month: m, limitAmount: 10000);
        await db.addExpense(8000, thisMonth(), categoryId: Seed.food); // exactly 80 %
        await db.addExpense(7900, thisMonth(), categoryId: Seed.transport); // 79 %
        await db.addExpense(10000, thisMonth(), categoryId: Seed.shopping); // 100 %
        await db.addExpense(9500, thisMonth(), categoryId: Seed.health); // 95 %
      });
      await h.tapTab(h.az.navBudgets);

      final AppColors c = AppColors.of(tester.element(find.byType(BudgetProgressRow).first));

      final Finder food = rowOf('Yemək');
      expect(food, findsOneWidget);
      expect(textColor(tester, food, '80%'), c.warning);
      expect(barColor(tester, food), c.warningFill);
      expect(find.descendant(of: food, matching: find.byIcon(Icons.warning_amber)), findsOneWidget);

      final Finder health = rowOf('Sağlamlıq');
      expect(textColor(tester, health, '95%'), c.warning);

      final Finder shopping = rowOf('Alış-veriş');
      expect(textColor(tester, shopping, '100%'), c.danger);
      expect(barColor(tester, shopping), c.danger);

      final Finder transport = rowOf('Nəqliyyat');
      expect(textColor(tester, transport, '79%'), isNot(anyOf(c.warning, c.danger)));
      expect(find.descendant(of: transport, matching: find.byIcon(Icons.warning_amber)), findsNothing);
      await h.dispose();
    });
  });

  group('reports', () {
    // Eight expense categories (never the seeded "Digər" one, so the merged
    // slice's label is unambiguous).
    const List<int> cats = <int>[
      Seed.food, Seed.transport, Seed.utilities, Seed.shopping,
      Seed.health, Seed.fun, Seed.education, Seed.rent,
    ];
    const List<String> names = <String>[
      'Yemək', 'Nəqliyyat', 'Kommunal', 'Alış-veriş',
      'Sağlamlıq', 'Əyləncə', 'Təhsil', 'Kirayə',
    ];
    const List<int> amounts = <int>[80000, 70000, 60000, 50000, 40000, 30000, 2000, 1000];

    Future<void> seed(AppHarness h, int n) => h.write((AppDatabase db) async {
          for (int i = 0; i < n; i++) {
            await db.addExpense(amounts[i], thisMonth(), categoryId: cats[i]);
          }
        });

    testWidgets('more than 7 categories: top 6 + merged "Digər"', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      await seed(h, 8);
      await h.tapTab(h.az.navReports);

      for (int i = 0; i < 6; i++) {
        expect(find.text(names[i]), findsOneWidget, reason: names[i]);
      }
      expect(find.text(names[6]), findsNothing);
      expect(find.text(names[7]), findsNothing);
      expect(find.text(h.az.otherCategories), findsOneWidget);
      expect(find.text(Fmt.base(2000 + 1000, 'az')), findsOneWidget, reason: 'merged amount');
      await h.dispose();
    });

    testWidgets('exactly 7 categories are all shown, nothing merged', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      await seed(h, 7);
      await h.tapTab(h.az.navReports);

      for (int i = 0; i < 7; i++) {
        expect(find.text(names[i]), findsOneWidget, reason: names[i]);
      }
      expect(find.text(h.az.otherCategories), findsNothing);
      await h.dispose();
    });

    testWidgets('the 6/12-month toggle switches the series', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      await seed(h, 1);
      await h.tapTab(h.az.navReports);
      await tester.tap(find.text(h.az.monthsN(12)));
      await h.settle();
      final SegmentedButton<int> toggle = tester.widget<SegmentedButton<int>>(
          find.ancestor(of: find.text(h.az.monthsN(12)), matching: find.byType(SegmentedButton<int>)));
      expect(toggle.selected, <int>{12});
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('onboarding', () {
    /// Like pumpApp, but with the given prefs (no "already onboarded" flag)
    /// and an optional data step before the app starts.
    Future<AppHarness> pumpFresh(
      WidgetTester tester, {
      Map<String, Object> prefs = const <String, Object>{},
      Future<void> Function(AppDatabase db)? before,
    }) async {
      await initializeDateFormatting('az');
      await initializeDateFormatting('en');
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{
        PrefKeys.notificationsEnabled: false,
        ...prefs,
      });
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final SharedPreferences p = await SharedPreferences.getInstance();
      final AppDatabase db = openTestDb();
      await before?.call(db);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(p),
          notificationServiceProvider.overrideWithValue(FakeNotifications()),
          packageInfoProvider.overrideWith(
            (Ref ref) async => PackageInfo(appName: 'x', packageName: 'x', version: '0', buildNumber: '0'),
          ),
        ],
        child: const GelirCixarApp(),
      ));
      final AppHarness h = AppHarness(tester, db, p);
      await h.settle();
      return h;
    }

    testWidgets('first launch shows onboarding; "Keç" twice finishes into Home', (WidgetTester tester) async {
      final AppHarness h = await pumpFresh(tester);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text(h.az.onb1Title), findsOneWidget);

      // "Keç" on an intro page jumps to the language step…
      await tester.tap(find.text(h.az.onboardingSkip));
      await h.settle();
      expect(find.text(h.az.chooseLanguage), findsOneWidget);

      // …and on a setup step applies the defaults and enters the app.
      await tester.tap(find.text(h.az.onboardingSkip));
      await h.settle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(h.prefs.getBool(PrefKeys.onboardingDone), isTrue);
      expect(h.prefs.getBool(PrefKeys.lockOnboarded), isTrue, reason: 'no forced PIN screen afterwards');
      await h.dispose();
    });

    testWidgets('an upgrade from v1.0 with existing data never sees onboarding', (WidgetTester tester) async {
      final AppHarness h = await pumpFresh(
        tester,
        before: (AppDatabase db) => db.addExpense(1250, thisMonth()),
      );
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(h.prefs.getBool(PrefKeys.onboardingDone), isTrue);
      await h.dispose();
    });

    testWidgets('an upgrade that completed the v1.0 PIN step skips onboarding', (WidgetTester tester) async {
      final AppHarness h = await pumpFresh(tester, prefs: <String, Object>{PrefKeys.lockOnboarded: true});
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      await h.dispose();
    });
  });

  group('home holdings', () {
    testWidgets('no holdings: no Kənarda row; with one: row + net worth, tap opens the list',
        (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      expect(find.text(h.az.holdingsElsewhere), findsNothing);
      expect(find.text(h.az.netWorth), findsNothing);

      await h.write((AppDatabase db) async {
        await db.addIncome(100000, thisMonth());
        await HoldingRepository(db).create(
          name: 'Sandıq',
          placeType: HoldingPlace.homeCash,
          currency: 'AZN',
          initialAmount: 45000,
        );
      });
      expect(find.text(h.az.holdingsElsewhere), findsOneWidget);
      expect(find.text(h.az.netWorth), findsOneWidget);
      expect(find.text(Fmt.base(45000, 'az')), findsWidgets);
      expect(find.text(Fmt.base(145000, 'az')), findsOneWidget, reason: 'net worth = 1000 + 450');

      await tester.tap(find.text(h.az.holdingsElsewhere));
      await h.settle();
      expect(find.text('Sandıq'), findsWidgets);
      expect(find.text(h.az.holdings), findsWidgets);
      await h.dispose();
    });
  });

  group('rate jump confirmation', () {
    Future<double> usdAfterRefresh({required bool answer, required List<List<String>> asked}) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences p = await SharedPreferences.getInstance();
      final AppDatabase db = openTestDb();
      addTearDown(db.close);
      // A previous CBAR value of 1.00 for USD; the fixture says 1.70 (+70 %).
      await RateRepository(db).applyCbar(
        CbarBulletin(date: DateTime(2026, 10, 20), rates: <String, double>{'USD': 1.0}),
      );
      final List<int> xml = File('test/fixtures/cbar_27.10.2026.xml').readAsBytesSync();
      final ProviderContainer c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(p),
        databaseProvider.overrideWithValue(db),
        cbarClientProvider.overrideWithValue(
          CbarClient(client: MockClient((http.Request r) async => http.Response.bytes(xml, 200))),
        ),
        rateJumpConfirmerProvider.overrideWithValue((List<RateChange> changes) async {
          asked.add(<String>[for (final RateChange x in changes) x.currency]);
          return answer;
        }),
      ]);
      addTearDown(c.dispose);
      expect(await c.read(rateSyncProvider.notifier).refresh(now: DateTime(2026, 10, 28)), isNull);
      return (await RateRepository(db).watch().first).rateOf('USD');
    }

    test('a > 50 % jump is held back when the user declines', () async {
      final List<List<String>> asked = <List<String>>[];
      expect(await usdAfterRefresh(answer: false, asked: asked), 1.0);
      expect(asked.single, contains('USD'));
    });

    test('and applied when the user confirms', () async {
      final List<List<String>> asked = <List<String>>[];
      expect(await usdAfterRefresh(answer: true, asked: asked), 1.7);
    });

    test('the dialog line shows previous → next with the signed change', () {
      expect(
        rateChangeLine(const RateChange(currency: 'USD', previous: 1.0, next: 1.7), 'az'),
        'USD 1 → 1,7 (+70 %)',
      );
    });
  });
}
