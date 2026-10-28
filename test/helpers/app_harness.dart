// Pumps the real app (router, theme, l10n, lock gate) over an in-memory
// database, with every platform-backed provider stubbed:
//   * shared_preferences: mock store, lock onboarding already done
//   * flutter_secure_storage: empty mock store, so no PIN and no lock screen
//   * notifications / package info: fakes (no plugin channels)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/app.dart';
import 'package:gelir_cixar/core/app_info.dart';
import 'package:gelir_cixar/core/notifications.dart';
import 'package:gelir_cixar/core/prefs.dart';
import 'package:gelir_cixar/data/providers.dart';
import 'package:gelir_cixar/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_db.dart';

class FakeNotifications implements NotificationService {
  final List<String> shown = <String>[];

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async =>
      shown.add(title);
}

class AppHarness {
  AppHarness(this.tester, this.db, this.prefs);

  final WidgetTester tester;
  final AppDatabase db;
  final SharedPreferences prefs;

  AppLocalizations get az => lookupAppLocalizations(const Locale('az'));
  AppLocalizations get en => lookupAppLocalizations(const Locale('en'));

  /// Lets drift streams emit and the UI rebuild. Bounded, so a never-ending
  /// animation fails loudly instead of hanging.
  Future<void> settle() async {
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10));
  }

  /// Runs a database write (in-memory drift completes on microtasks), then
  /// lets the UI react.
  Future<T> write<T>(Future<T> Function(AppDatabase db) body) async {
    final T r = await body(db);
    await settle();
    return r;
  }

  /// Call at the end of every test body: unmounting cancels the drift
  /// stream subscriptions, whose zero-delay cleanup timers must fire before
  /// the binding checks for pending timers (that check runs before tearDown).
  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 10));
    await db.close();
  }

  Future<void> tapTab(String label) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
    await settle();
  }
}

Future<AppHarness> pumpApp(WidgetTester tester, {String lang = 'az'}) async {
  await initializeDateFormatting('az');
  await initializeDateFormatting('en');

  // A tall phone so every section of a screen is laid out without scrolling.
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{
    PrefKeys.lockOnboarded: true,
    PrefKeys.language: lang,
    PrefKeys.notificationsEnabled: false,
  });
  FlutterSecureStorage.setMockInitialValues(<String, String>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final AppDatabase db = openTestDb();

  await tester.pumpWidget(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(FakeNotifications()),
      packageInfoProvider.overrideWith(
        (Ref ref) async => PackageInfo(
          appName: 'Gəlir-Çıxar',
          packageName: 'test',
          version: '0.0.0-test',
          buildNumber: '0',
        ),
      ),
    ],
    child: const GelirCixarApp(),
  ));

  final AppHarness h = AppHarness(tester, db, prefs);
  await h.settle();
  return h;
}

/// A date inside the current month that is never in a different month than
/// `DateTime.now()`, whatever the time of day the suite runs.
DateTime thisMonth({int day = 1, int hour = 12}) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, day, hour);
}
