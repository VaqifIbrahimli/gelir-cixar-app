// Lock UI v1.2: the PIN-recovery screen, the enrollment notice and
// LockTimeoutTile (bottom sheet + re-authentication).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/core/prefs.dart';
import 'package:gelir_cixar/core/theme.dart';
import 'package:gelir_cixar/features/lock/lock_controller.dart';
import 'package:gelir_cixar/features/lock/lock_screen.dart';
import 'package:gelir_cixar/features/lock/lock_settings.dart';
import 'package:gelir_cixar/features/lock/lock_timeout_tile.dart';
import 'package:gelir_cixar/features/lock/pin_flow_screen.dart';
import 'package:gelir_cixar/features/lock/pin_service.dart';
import 'package:gelir_cixar/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lock_fakes.dart';

void main() {
  late FakeClocks clocks;
  late FakeLocalAuth auth;
  late FakeKeystore keystore;
  final AppLocalizations az = lookupAppLocalizations(const Locale('az'));

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    clocks = FakeClocks();
    auth = FakeLocalAuth();
    keystore = FakeKeystore()..install();
    SystemDialogGuard.reset();
  });

  tearDown(() {
    FakeKeystore.uninstall();
    SystemDialogGuard.reset();
  });

  PinService pins() => PinService(null, 1000, clocks.uptime);

  /// The lock gate in miniature: LockScreen while blocking, else the app.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required Map<String, Object> prefs,
    Widget app = const Text('APP'),
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{PrefKeys.lockOnboarded: true, ...prefs});
    final SharedPreferences p = await SharedPreferences.getInstance();
    final ProviderContainer c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(p),
      pinServiceProvider.overrideWithValue(pins()),
      lockClockProvider.overrideWithValue(clocks.clock),
      localAuthProvider.overrideWithValue(auth),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('az'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          // Like app.dart's _LockGate: blank while loading.
          builder: (BuildContext context, WidgetRef ref, _) =>
              switch (ref.watch(lockControllerProvider.select((AppLockState s) => s.status))) {
                LockStatus.loading || LockStatus.setupRequired => const SizedBox.shrink(),
                LockStatus.locked => const LockScreen(),
                LockStatus.unlocked => Scaffold(body: app),
              },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> enter(WidgetTester tester, String pin, {bool confirmKey = false}) async {
    for (final String d in pin.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
    if (confirmKey) await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
  }

  const Map<String, Object> wipedPrefs = <String, Object>{
    LockPrefKeys.pinConfigured: true,
    PrefKeys.lockEnabled: true,
  };

  group('recovery after a secure-storage wipe', () {
    testWidgets('locked; device credential, then a new PIN opens the app', (WidgetTester tester) async {
      keystore.deviceSecure = true;
      final ProviderContainer c = await pump(tester, prefs: wipedPrefs);
      expect(find.text('APP'), findsNothing);
      expect(find.text(az.lockRecoveryTitle), findsOneWidget);
      expect(find.text(az.lockRecoveryRestoreButton), findsNothing, reason: 'no shortcut on a secure phone');

      auth.result = false;
      await tester.tap(find.text(az.lockRecoveryConfirmButton));
      await tester.pumpAndSettle();
      expect(find.text(az.lockRecoveryAuthFailed), findsOneWidget);
      expect(find.byType(PinFlowScreen), findsNothing);

      auth.result = true;
      await tester.tap(find.text(az.lockRecoveryConfirmButton));
      await tester.pumpAndSettle();
      expect(auth.biometricOnlyCalls, <bool>[false, false]);
      expect(find.byType(PinFlowScreen), findsOneWidget);

      await enter(tester, '2468', confirmKey: true);
      await enter(tester, '2468');
      expect(find.text('APP'), findsOneWidget);
      expect(c.read(lockControllerProvider).recovery, isFalse);
      expect((await pins().verify('2468')).ok, isTrue);
    });

    testWidgets('no screen lock: explanation, deliberate warning, then a new PIN', (WidgetTester tester) async {
      keystore.deviceSecure = false;
      await pump(tester, prefs: wipedPrefs);
      expect(find.text(az.lockRecoveryInsecureBody), findsOneWidget);
      expect(find.text(az.lockRecoveryConfirmButton), findsNothing);

      await tester.tap(find.text(az.lockRecoveryRestoreButton));
      await tester.pumpAndSettle();
      expect(find.text(az.lockRecoveryWarningBody), findsOneWidget);
      await tester.tap(find.text(az.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(PinFlowScreen), findsNothing, reason: 'cancel keeps it locked');

      await tester.tap(find.text(az.lockRecoveryRestoreButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(az.lockRecoveryWarningConfirm));
      await tester.pumpAndSettle();
      expect(find.byType(PinFlowScreen), findsOneWidget);
      await enter(tester, '1357', confirmKey: true);
      await enter(tester, '1357');
      expect(find.text('APP'), findsOneWidget);
    });
  });

  testWidgets('enrollment change: notice, no fingerprint key, PIN unlocks', (WidgetTester tester) async {
    await pins().setPin('1234');
    keystore.keyState = 'invalidated';
    final ProviderContainer c = await pump(tester, prefs: <String, Object>{
      ...wipedPrefs,
      PrefKeys.biometricEnabled: true,
    });
    expect(find.text(az.lockBiometricEnrollmentChanged), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsNothing);
    expect(auth.biometricOnlyCalls, isEmpty);
    await enter(tester, '1234');
    expect(find.text('APP'), findsOneWidget);
    expect(c.read(lockControllerProvider).biometricEnabled, isTrue, reason: 'key re-created');
    expect(keystore.keyState, 'valid');
  });

  group('LockTimeoutTile', () {
    Future<ProviderContainer> settings(WidgetTester tester, {bool biometric = false}) async {
      await pins().setPin('1234');
      if (biometric) keystore.keyState = 'valid';
      final ProviderContainer c = await pump(
        tester,
        prefs: <String, Object>{...wipedPrefs, PrefKeys.biometricEnabled: biometric},
        app: const Material(child: LockTimeoutTile()),
      );
      if (biometric) {
        auth.result = true;
        await tester.pumpAndSettle(); // the lock screen auto-prompts
      } else {
        await enter(tester, '1234');
      }
      expect(find.byType(LockTimeoutTile), findsOneWidget);
      return c;
    }

    testWidgets('shows the current value; picking needs the PIN', (WidgetTester tester) async {
      final ProviderContainer c = await settings(tester);
      expect(find.text(az.lockTimeoutMinutes(1)), findsOneWidget);

      await tester.tap(find.byType(LockTimeoutTile));
      await tester.pumpAndSettle();
      for (final LockTimeout t in LockTimeout.values) {
        expect(find.widgetWithText(RadioListTile<LockTimeout>, lockTimeoutLabel(az, t)), findsOneWidget);
      }
      await tester.tap(find.text(az.lockTimeoutMinutes(5)));
      await tester.pumpAndSettle();
      expect(find.byType(PinFlowScreen), findsOneWidget);
      expect(c.read(lockControllerProvider).timeout, LockTimeout.minute1, reason: 'not before the PIN');

      await enter(tester, '1234');
      expect(find.byType(PinFlowScreen), findsNothing);
      expect(c.read(lockControllerProvider).timeout, LockTimeout.minutes5);
      expect(await LockSettings().timeout(), LockTimeout.minutes5);
      expect(find.text(az.lockTimeoutMinutes(5)), findsOneWidget);
    });

    testWidgets('cancelling the PIN keeps the old value', (WidgetTester tester) async {
      final ProviderContainer c = await settings(tester);
      await tester.tap(find.byType(LockTimeoutTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(az.lockTimeoutImmediately));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(c.read(lockControllerProvider).timeout, LockTimeout.minute1);
    });

    testWidgets('a wrong PIN changes nothing', (WidgetTester tester) async {
      final ProviderContainer c = await settings(tester);
      await tester.tap(find.byType(LockTimeoutTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(az.lockTimeoutHours(1)));
      await tester.pumpAndSettle();
      await enter(tester, '9999');
      expect(find.byType(PinFlowScreen), findsOneWidget);
      expect(c.read(lockControllerProvider).timeout, LockTimeout.minute1);
    });

    testWidgets('with biometrics enabled, a biometric confirms the change', (WidgetTester tester) async {
      final ProviderContainer c = await settings(tester, biometric: true);
      auth.biometricOnlyCalls.clear();
      await tester.tap(find.byType(LockTimeoutTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(az.lockTimeoutImmediately));
      await tester.pumpAndSettle();
      expect(auth.biometricOnlyCalls, <bool>[true]);
      expect(find.byType(PinFlowScreen), findsNothing);
      expect(c.read(lockControllerProvider).timeout, LockTimeout.immediately);
    });

    testWidgets('disabled while the app lock is off', (WidgetTester tester) async {
      await pump(tester, prefs: const <String, Object>{}, app: const Material(child: LockTimeoutTile()));
      expect(tester.widget<ListTile>(find.byType(ListTile)).enabled, isFalse);
    });
  });
}
