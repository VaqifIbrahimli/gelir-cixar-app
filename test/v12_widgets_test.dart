// v1.2 widget tests over the real app: budgets switch, double-back-to-exit,
// the transport picker's fare auto-fill, the detail sheet and the carousel.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/core/format.dart';
import 'package:gelir_cixar/core/prefs.dart';
import 'package:gelir_cixar/data/providers.dart';
import 'package:gelir_cixar/features/accounts/widgets/account_card.dart';
import 'package:gelir_cixar/features/home/widgets/home_cards.dart';
import 'package:gelir_cixar/features/settings/settings_controller.dart';
import 'package:gelir_cixar/features/shell/floating_nav.dart';
import 'package:gelir_cixar/features/transactions/widgets/route_sheets.dart';
import 'package:gelir_cixar/features/transactions/widgets/tx_detail_sheet.dart';
import 'package:gelir_cixar/features/transactions/widgets/tx_tile.dart';

import 'helpers/app_harness.dart';
import 'helpers/test_db.dart';

/// The label the floating nav shows under the selected tab.
Finder selectedTab(String label) => find.byKey(ValueKey<String>('navLabel.$label'));

Finder navTab(String label) => find.descendant(of: find.byType(AppFloatingNav), matching: find.byTooltip(label));

/// Sends the Android system back action.
Future<void> systemBack(AppHarness h) async {
  final ByteData msg = const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute'));
  await h.tester.binding.defaultBinaryMessenger.handlePlatformMessage('flutter/navigation', msg, (_) {});
  await h.settle();
}

void main() {
  // Asset I/O does not complete inside testWidgets' fake async zone.
  setUpAll(() => TransportCatalog.debugCache =
      TransportCatalog.parse(File('assets/transport/baku.json').readAsStringSync()));

  group('budgets on/off', () {
    testWidgets('on by default: Home budget card and the Budgets tab', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      expect(find.byType(BudgetSummaryCard), findsOneWidget);
      expect(navTab(h.az.navBudgets), findsOneWidget);
      expect(find.descendant(of: find.byType(AppFloatingNav), matching: find.byType(Tooltip)), findsNWidgets(6),
          reason: '5 tabs + "+"');
      await h.dispose();
    });

    testWidgets('off: no Home budget card, no Budgets tab (4 tabs), data kept', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester, prefs: <String, Object>{PrefKeys.budgetsEnabled: false});
      await h.write((AppDatabase db) =>
          BudgetRepository(db).upsert(categoryId: Seed.food, month: monthKey(thisMonth()), limitAmount: 10000));
      expect(find.byType(BudgetSummaryCard), findsNothing);
      expect(navTab(h.az.navBudgets), findsNothing);
      expect(navTab(h.az.navReports), findsOneWidget);
      expect(find.descendant(of: find.byType(AppFloatingNav), matching: find.byType(Tooltip)), findsNWidgets(5),
          reason: '4 tabs + "+"');
      expect(await h.db.select(h.db.budgets).get(), hasLength(1));
      await h.dispose();
    });

    testWidgets('switching off in Settings hides them; switching off on the Budgets tab goes Home',
        (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      await h.tapTab(h.az.navSettings);
      await tester.tap(find.text(h.az.budgetsEnabled));
      await h.settle();
      expect(find.text(h.az.budgetsHidden), findsOneWidget, reason: 'snackbar');
      expect(navTab(h.az.navBudgets), findsNothing);
      expect(h.prefs.getBool(PrefKeys.budgetsEnabled), isFalse);

      final ProviderContainer c = ProviderScope.containerOf(tester.element(find.byType(AppFloatingNav)));
      await c.read(settingsProvider.notifier).setBudgetsEnabled(true);
      await h.settle();
      await h.tapTab(h.az.navBudgets);
      expect(selectedTab(h.az.navBudgets), findsOneWidget);
      await c.read(settingsProvider.notifier).setBudgetsEnabled(false);
      await h.settle();
      expect(selectedTab(h.az.navHome), findsOneWidget);
      expect(find.byType(BudgetSummaryCard), findsNothing);
      await h.dispose();
    });
  });

  group('double back to exit', () {
    late List<String> platformCalls;

    Future<AppHarness> pump(WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      platformCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
          (MethodCall call) async {
        platformCalls.add(call.method);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      return h;
    }

    testWidgets('another tab goes Home first, without a snackbar', (WidgetTester tester) async {
      final AppHarness h = await pump(tester);
      await h.tapTab(h.az.navReports);
      expect(selectedTab(h.az.navReports), findsOneWidget);
      await systemBack(h);
      expect(selectedTab(h.az.navHome), findsOneWidget);
      expect(find.text(h.az.pressBackAgainToExit), findsNothing);
      expect(platformCalls, isNot(contains('SystemNavigator.pop')));
      await h.dispose();
    });

    testWidgets('on Home: first back shows the hint, a second one within 2 s exits', (WidgetTester tester) async {
      final AppHarness h = await pump(tester);
      await systemBack(h);
      expect(find.text(h.az.pressBackAgainToExit), findsOneWidget);
      expect(platformCalls, isNot(contains('SystemNavigator.pop')));
      await systemBack(h);
      expect(platformCalls, contains('SystemNavigator.pop'));
      await h.dispose();
    });

    testWidgets('a pushed route or an open sheet pops first', (WidgetTester tester) async {
      final AppHarness h = await pump(tester);
      await tester.tap(find.byTooltip(h.az.addTransaction));
      await h.settle();
      expect(find.text(h.az.newTransaction), findsOneWidget);
      await systemBack(h);
      expect(find.text(h.az.newTransaction), findsNothing);
      expect(find.text(h.az.pressBackAgainToExit), findsNothing);

      await h.write((AppDatabase db) => db.addExpense(1250, thisMonth()));
      await tester.tap(find.byType(TxTile));
      await h.settle();
      expect(find.byType(TxDetailSheet), findsOneWidget);
      await systemBack(h);
      expect(find.byType(TxDetailSheet), findsNothing);
      expect(find.text(h.az.pressBackAgainToExit), findsNothing);
      expect(platformCalls, isNot(contains('SystemNavigator.pop')));
      await h.dispose();
    });
  });

  group('transport picker', () {
    testWidgets('a bus route fills fare × trips; the row keeps mode, route and trips', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      await tester.tap(find.byTooltip(h.az.addTransaction));
      await h.settle();
      await tester.tap(find.byTooltip(h.az.category));
      await h.settle();
      await tester.tap(find.text('Nəqliyyat'));
      await h.settle();

      await tester.tap(find.text(h.az.transportBus));
      await h.settle();
      await tester.tap(find.text(h.az.chooseRoute));
      await h.settle();
      await tester.tap(find
          .byWidgetPredicate((Widget w) => w is RouteBadge && w.code == '1', skipOffstage: false)
          .first);
      await h.settle();
      final String fare = Fmt.money(60, 'AZN', 'az');
      expect(find.text(h.az.fareHint(fare, 1)), findsOneWidget);

      await tester.tap(find.byTooltip('+'));
      await h.settle();
      expect(find.text(h.az.fareHint(fare, 2)), findsOneWidget);

      await tester.tap(find.text(h.az.save));
      await h.settle();
      final MoneyTx tx = (await h.db.select(h.db.transactions).get()).single;
      expect(tx.amount, 120, reason: '0,60 ₼ × 2');
      expect(tx.transportMode, TransportMode.bus);
      expect(tx.routeCode, '1');
      expect(tx.trips, 2);
      expect(tx.categoryId, Seed.transport);
      // The tile carries the route chip.
      expect(find.descendant(of: find.byType(TxTile), matching: find.text('1 ×2')), findsOneWidget);
      await h.dispose();
    });

    testWidgets('typing an amount makes it manual; "Tarifə qaytar" restores the fare', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      await tester.tap(find.byTooltip(h.az.addTransaction));
      await h.settle();
      await tester.tap(find.byTooltip(h.az.category));
      await h.settle();
      await tester.tap(find.text('Nəqliyyat'));
      await h.settle();
      await tester.tap(find.text(h.az.transportMetro));
      await h.settle();
      expect(find.text(h.az.fareHint(Fmt.money(60, 'AZN', 'az'), 1)), findsOneWidget);
      await tester.tap(find.text('5'));
      await h.settle();
      expect(find.text(h.az.resetToFare), findsOneWidget);
      await tester.tap(find.text(h.az.resetToFare));
      await h.settle();
      await tester.tap(find.text(h.az.save));
      await h.settle();
      final MoneyTx tx = (await h.db.select(h.db.transactions).get()).single;
      expect(tx.amount, 60);
      expect(tx.transportMode, TransportMode.metro);
      await h.dispose();
    });
  });

  group('reports transport card', () {
    testWidgets('spend by mode and the top routes; hidden without transport spending', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      await h.tapTab(h.az.navReports);
      expect(find.text(h.az.reportByMode), findsNothing);
      await h.write((AppDatabase db) => db.into(db.transactions).insert(TransactionsCompanion.insert(
            type: TxType.expense,
            accountId: Seed.cashAccount,
            categoryId: const Value<int?>(Seed.transport),
            amount: 120,
            date: thisMonth(),
            transportMode: const Value<TransportMode?>(TransportMode.bus),
            routeCode: const Value<String?>('1'),
            trips: const Value<int>(2),
          )));
      expect(find.text(h.az.reportByMode), findsOneWidget);
      expect(find.text(h.az.reportTopRoutes), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose();
    });
  });

  group('home and details', () {
    testWidgets('the carousel shows a card per account; a tile opens the detail sheet', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      expect(find.byType(AccountCardView), findsWidgets);
      expect(find.text(h.az.spendableBalance), findsOneWidget, reason: 'page 0 is the totals card');

      await h.write((AppDatabase db) => db.addExpense(1250, DateTime.now().subtract(const Duration(minutes: 5))));
      await tester.tap(find.byType(TxTile));
      await h.settle();
      expect(find.byType(TxDetailSheet), findsOneWidget);
      expect(find.text(h.az.duplicate), findsOneWidget);
      expect(find.text(h.az.edit), findsOneWidget);
      expect(find.textContaining(h.az.addedAt('').trim()), findsOneWidget);

      await tester.tap(find.text(h.az.edit));
      await h.settle();
      expect(find.text(h.az.editTransaction), findsOneWidget);
      expect(find.byTooltip(h.az.time), findsOneWidget, reason: 'time chip next to the date');
      await h.dispose();
    });

    testWidgets('a bonus transfer pair is one grouped item; deleting it removes both', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester);
      await h.write((AppDatabase db) async {
        final int bonus = await db.into(db.accounts).insert(AccountsCompanion.insert(
              name: 'Bonus',
              type: AccountType.bonus,
              currency: 'AZN',
            ));
        await TransactionRepository(db).saveBonusTransfer(
          fromId: bonus,
          toId: Seed.cashAccount,
          sent: 500,
          received: 250,
          date: DateTime.now().subtract(const Duration(minutes: 1)),
        );
      });
      expect(find.byType(TxTile), findsOneWidget, reason: 'transfer + loss shown as one item');
      expect(find.text(h.az.bonusLossLabel), findsOneWidget);
      expect(find.text(h.az.sentSubtitle(Fmt.money(500, 'AZN', 'az'))), findsOneWidget);

      await tester.tap(find.byType(TxTile));
      await h.settle();
      await tester.tap(find.descendant(of: find.byType(TxDetailSheet), matching: find.text(h.az.delete)));
      await h.settle();
      expect(await h.db.select(h.db.transactions).get(), isEmpty);
      expect(find.text(h.az.pairDeleted), findsOneWidget);
      await tester.tap(find.text(h.az.undo));
      await h.settle();
      expect(await h.db.select(h.db.transactions).get(), hasLength(2));
      await h.dispose();
    });
  });
}
