// LockController v1.2: configurable auto-lock on the wall + boot clocks,
// system-dialog suppression, fail-closed PIN recovery and the biometric
// enrollment tripwire. Platform pieces are faked (see lock_fakes.dart).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/core/prefs.dart';
import 'package:gelir_cixar/features/lock/lock_controller.dart';
import 'package:gelir_cixar/features/lock/lock_settings.dart';
import 'package:gelir_cixar/features/lock/pin_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lock_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secure;
  late FakeClocks clocks;
  late FakeLocalAuth auth;
  late FakeKeystore keystore;
  late ProviderContainer container;

  setUp(() {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
    clocks = FakeClocks();
    auth = FakeLocalAuth();
    keystore = FakeKeystore()..install();
    SystemDialogGuard.reset();
    SystemDialogGuard.now = () => clocks.wall;
    Lifecycle.ensureResumed();
  });

  tearDown(() {
    container.dispose();
    FakeKeystore.uninstall();
    SystemDialogGuard.reset();
    Lifecycle.ensureResumed();
  });

  PinService pinService() => PinService(null, 1000, clocks.uptime);

  /// Starts a controller over [prefs] and waits for its async init.
  Future<LockController> start({Map<String, Object> prefs = const <String, Object>{}}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{PrefKeys.lockOnboarded: true, ...prefs});
    final SharedPreferences p = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(p),
      pinServiceProvider.overrideWithValue(pinService()),
      lockClockProvider.overrideWithValue(clocks.clock),
      localAuthProvider.overrideWithValue(auth),
    ]);
    container.read(lockControllerProvider);
    for (int i = 0; i < 50 && container.read(lockControllerProvider).status == LockStatus.loading; i++) {
      await pumpEventQueue();
    }
    return container.read(lockControllerProvider.notifier);
  }

  AppLockState lock() => container.read(lockControllerProvider);

  /// A configured lock (PIN 1234), unlocked, with [timeout].
  Future<LockController> unlockedWith(LockTimeout timeout, {bool biometric = false}) async {
    await pinService().setPin('1234');
    await LockSettings().setTimeout(timeout);
    if (biometric) keystore.keyState = 'valid';
    final LockController c = await start(prefs: <String, Object>{
      PrefKeys.lockEnabled: true,
      LockPrefKeys.pinConfigured: true,
      PrefKeys.biometricEnabled: biometric,
    });
    expect(lock().status, LockStatus.locked);
    expect((await c.unlockWithPin('1234')).ok, isTrue);
    expect(lock().status, LockStatus.unlocked);
    return c;
  }

  Future<void> background() async {
    Lifecycle.toBackground();
    await pumpEventQueue(); // boot clock read at pause
  }

  Future<void> foreground() async {
    Lifecycle.toForeground();
    await pumpEventQueue(); // boot clock check at resume
  }

  group('auto-lock timeout', () {
    test('default is one minute (v1.1 behaviour) and is persisted securely', () async {
      await start();
      expect(lock().timeout, LockTimeout.minute1);
      expect(LockTimeout.values.map((LockTimeout t) => t.duration.inSeconds),
          <int>[0, 30, 60, 300, 600, 1800, 3600]);
    });

    test('setTimeout persists in secure storage, not in shared preferences', () async {
      final LockController c = await unlockedWith(LockTimeout.minute1);
      await c.setTimeout(LockTimeout.minutes10);
      expect(lock().timeout, LockTimeout.minutes10);
      expect(await LockSettings().timeout(), LockTimeout.minutes10);
      final SharedPreferences p = await SharedPreferences.getInstance();
      expect(p.getKeys().where((String k) => k.contains('timeout')), isEmpty);
    });

    test('an unknown stored value fails closed to "Immediately"', () async {
      secure['lock.timeoutSeconds'] = '86400';
      expect(await LockSettings().timeout(), LockTimeout.immediately);
      secure.remove('lock.timeoutSeconds');
      FlutterSecureStorage.setMockInitialValues(secure);
      expect(await LockSettings().timeout(), LockTimeout.defaultValue);
    });

    test('"Immediately" locks as soon as the app is paused', () async {
      await unlockedWith(LockTimeout.immediately);
      Lifecycle.toBackground();
      expect(lock().status, LockStatus.locked, reason: 'locked on pause, before any resume');
      await foreground();
      expect(lock().status, LockStatus.locked);
    });

    test('"Immediately" does not lock for an overlay that only makes the app inactive', () async {
      await unlockedWith(LockTimeout.immediately);
      Lifecycle.overlayShown();
      clocks.advanceBoth(const Duration(minutes: 5));
      Lifecycle.overlayHidden();
      await pumpEventQueue();
      expect(lock().status, LockStatus.unlocked);
    });

    test('5 min: not at 4:59, locked at 5:00 (boot clock, wall clock set back)', () async {
      await unlockedWith(LockTimeout.minutes5);

      await background();
      clocks.advanceUptimeOnly(const Duration(minutes: 4, seconds: 59));
      await foreground();
      expect(lock().status, LockStatus.unlocked, reason: '4:59 < 5:00');

      await background();
      clocks.advanceUptimeOnly(const Duration(minutes: 5));
      await foreground();
      expect(lock().status, LockStatus.locked, reason: 'boot clock reached 5:00');
    });

    test('5 min on the wall clock locks on the resume event itself', () async {
      await unlockedWith(LockTimeout.minutes5);
      await background();
      clocks.advanceBoth(const Duration(minutes: 4, seconds: 59));
      Lifecycle.toForeground();
      expect(lock().status, LockStatus.unlocked);
      await pumpEventQueue();
      expect(lock().status, LockStatus.unlocked);

      await background();
      clocks.advanceBoth(const Duration(minutes: 5));
      Lifecycle.toForeground();
      expect(lock().status, LockStatus.locked, reason: 'synchronous, before the first frame');
    });

    test('a reboot during the background period (boot clock went back) locks', () async {
      await unlockedWith(LockTimeout.hour1);
      await background();
      clocks.uptimeMs = 1000;
      await foreground();
      expect(lock().status, LockStatus.locked);
    });

    test('"Immediately" + a guarded system dialog: no lock under one minute', () async {
      await unlockedWith(LockTimeout.immediately);
      SystemDialogGuard.begin(); // e.g. file_picker is open
      await background();
      expect(lock().status, LockStatus.unlocked);
      clocks.advanceBoth(const Duration(seconds: 59));
      await foreground();
      SystemDialogGuard.end();
      expect(lock().status, LockStatus.unlocked);

      // Leaving through the dialog for good still locks.
      SystemDialogGuard.begin();
      await background();
      clocks.advanceUptimeOnly(const Duration(minutes: 1));
      await foreground();
      SystemDialogGuard.end();
      expect(lock().status, LockStatus.locked);
    });

    test('the guard covers a pause that arrives just after the dialog future completed', () async {
      await unlockedWith(LockTimeout.immediately);
      await SystemDialogGuard.run(() async => 'shared');
      clocks.advanceBoth(const Duration(milliseconds: 500));
      await background();
      expect(lock().status, LockStatus.unlocked);
      await foreground();

      // ...but not a deliberate Home press later on.
      clocks.advanceBoth(const Duration(seconds: 2));
      await background();
      expect(lock().status, LockStatus.locked);
    });

    test('a guarded dialog never shortens a longer user timeout', () async {
      await unlockedWith(LockTimeout.minutes10);
      SystemDialogGuard.begin();
      await background();
      clocks.advanceBoth(const Duration(minutes: 9));
      await foreground();
      SystemDialogGuard.end();
      expect(lock().status, LockStatus.unlocked);
    });

    test('biometric prompts run inside the guard', () async {
      final LockController c = await unlockedWith(LockTimeout.immediately, biometric: true);
      auth.result = true;
      expect(await c.reauthenticateWithBiometrics('r'), isTrue);
      expect(await c.authenticateDeviceCredential('r'), DeviceAuthResult.success);
      expect(auth.biometricOnlyCalls, <bool>[true, false]);
      expect(auth.guardDepthAtCall, <int>[1, 1]);
      expect(SystemDialogGuard.debugDepth, 0);
    });
  });

  group('fail-open fix: PIN lost from secure storage', () {
    Future<LockController> wiped({bool? deviceSecure = true}) async {
      keystore.deviceSecure = deviceSecure;
      // The marker survived in shared_preferences; secure storage is empty.
      final LockController c = await start(prefs: <String, Object>{
        LockPrefKeys.pinConfigured: true,
        PrefKeys.lockEnabled: true,
        PrefKeys.biometricEnabled: true,
      });
      expect(await pinService().hasPin(), isFalse);
      return c;
    }

    test('opens locked in recovery instead of unlocked', () async {
      final LockController c = await wiped();
      expect(lock().status, LockStatus.locked);
      expect(lock().recovery, isTrue);
      expect(lock().isBlocking, isTrue);
      expect(lock().biometricEnabled, isFalse);
      expect((await c.unlockWithPin('1234')).ok, isFalse);
      expect(await c.unlockWithBiometrics('r'), isFalse);
      expect(auth.biometricOnlyCalls, isEmpty, reason: 'no biometric shortcut in recovery');
    });

    test('a v1.1 install without the new marker is detected via lock.enabled', () async {
      await start(prefs: <String, Object>{PrefKeys.lockEnabled: true});
      expect(lock().recovery, isTrue);
      expect(lock().status, LockStatus.locked);
    });

    test('a new PIN cannot be set before re-authentication', () async {
      final LockController c = await wiped();
      await expectLater(c.setPin('5678'), throwsStateError);
      expect(await pinService().hasPin(), isFalse);
      expect(lock().status, LockStatus.locked);
    });

    test('failed device authentication keeps it locked', () async {
      final LockController c = await wiped();
      auth.result = false;
      expect(await c.recoverWithDeviceCredential('r'), DeviceAuthResult.failed);
      await expectLater(c.setPin('5678'), throwsStateError);
      expect(lock().status, LockStatus.locked);
    });

    test('device credential (biometricOnly: false), then a new PIN, unlocks', () async {
      final LockController c = await wiped();
      auth.result = true;
      expect(await c.recoverWithDeviceCredential('r'), DeviceAuthResult.success);
      expect(auth.biometricOnlyCalls, <bool>[false]);
      await c.setPin('5678');
      expect(lock().status, LockStatus.unlocked);
      expect(lock().recovery, isFalse);
      expect(lock().biometricEnabled, isFalse, reason: 'biometrics must be re-enabled by the user');
      expect((await pinService().verify('5678')).ok, isTrue);
      final SharedPreferences p = await SharedPreferences.getInstance();
      expect(p.getBool(PrefKeys.biometricEnabled), isFalse);
    });

    test('the insecure-device path is refused while the phone has a screen lock', () async {
      final LockController c = await wiped(deviceSecure: true);
      expect(await c.authorizeInsecureRecovery(), isFalse);
      await expectLater(c.setPin('5678'), throwsStateError);
    });

    test('no screen lock: allowed only after the deliberate restore step', () async {
      final LockController c = await wiped(deviceSecure: false);
      await expectLater(c.setPin('5678'), throwsStateError);
      expect(await c.authorizeInsecureRecovery(), isTrue);
      await c.setPin('5678');
      expect(lock().status, LockStatus.unlocked);
    });

    test('unknown device state: local_auth "no credentials" enables the insecure path', () async {
      final LockController c = await wiped(deviceSecure: null);
      expect(await c.authorizeInsecureRecovery(), isFalse);
      auth.result = const LocalAuthException(code: LocalAuthExceptionCode.noCredentialsSet);
      expect(await c.recoverWithDeviceCredential('r'), DeviceAuthResult.notSecure);
      expect(await c.authorizeInsecureRecovery(), isTrue);
    });

    test('turning the lock off clears the marker: no recovery afterwards', () async {
      final LockController c = await unlockedWith(LockTimeout.minute1);
      await c.disable();
      container.dispose();
      await start();
      expect(lock().recovery, isFalse);
      expect(lock().status, LockStatus.unlocked);
      expect(c, isNotNull);
    });

    test('a fresh install without a PIN is not mistaken for a wipe', () async {
      await start();
      expect(lock().recovery, isFalse);
      expect(lock().status, LockStatus.unlocked);
    });
  });

  group('biometric enrollment tripwire', () {
    test('enabling biometrics creates the Keystore key', () async {
      final LockController c = await unlockedWith(LockTimeout.minute1);
      keystore.calls.clear();
      expect(await c.setBiometricEnabled(true), isTrue);
      expect(keystore.calls, contains('bioKeyCreate'));
      expect(lock().biometricEnabled, isTrue);
    });

    test('enabling fails gracefully without enrolled biometrics or screen lock', () async {
      final LockController c = await unlockedWith(LockTimeout.minute1);
      for (final String r in <String>['noBiometrics', 'notSecure', 'error']) {
        keystore.createResult = r;
        expect(await c.setBiometricEnabled(true), isFalse, reason: r);
        expect(lock().biometricEnabled, isFalse, reason: r);
      }
    });

    test('a valid key: biometric unlock works', () async {
      final LockController c = await unlockedWith(LockTimeout.immediately, biometric: true);
      await background();
      await foreground();
      expect(lock().status, LockStatus.locked);
      auth.result = true;
      expect(await c.unlockWithBiometrics('r'), isTrue);
      expect(lock().status, LockStatus.unlocked);
    });

    test('invalidated key: biometrics off, PIN once with notice, then key re-created', () async {
      final LockController c = await unlockedWith(LockTimeout.immediately, biometric: true);
      await background();
      await foreground();
      keystore.keyState = 'invalidated'; // a fingerprint was added meanwhile
      auth.result = true;

      expect(await c.unlockWithBiometrics('r'), isFalse);
      expect(auth.biometricOnlyCalls, isEmpty, reason: 'the prompt is never shown');
      expect(lock().status, LockStatus.locked);
      expect(lock().biometricEnabled, isFalse);
      expect(lock().biometricEnrollmentChanged, isTrue);

      keystore.calls.clear();
      expect((await c.unlockWithPin('1234')).ok, isTrue);
      expect(keystore.calls, contains('bioKeyCreate'));
      expect(keystore.keyState, 'valid');
      expect(lock().biometricEnabled, isTrue, reason: 're-enabled after the PIN');
      expect(lock().biometricEnrollmentChanged, isFalse);

      await background();
      await foreground();
      expect(await c.unlockWithBiometrics('r'), isTrue);
    });

    test('a wrong PIN does not re-enable biometrics', () async {
      final LockController c = await unlockedWith(LockTimeout.immediately, biometric: true);
      await background();
      await foreground();
      keystore.keyState = 'invalidated';
      await c.unlockWithBiometrics('r');
      expect((await c.unlockWithPin('0000')).ok, isFalse);
      expect(lock().biometricEnabled, isFalse);
      expect(keystore.keyState, 'invalidated');
    });

    test('invalidated and no biometric left to re-create: stays on PIN, setting off', () async {
      final LockController c = await unlockedWith(LockTimeout.immediately, biometric: true);
      await background();
      await foreground();
      keystore.keyState = 'invalidated';
      keystore.createResult = 'noBiometrics';
      await c.unlockWithBiometrics('r');
      expect((await c.unlockWithPin('1234')).ok, isTrue);
      expect(lock().biometricEnabled, isFalse);
      final SharedPreferences p = await SharedPreferences.getInstance();
      expect(p.getBool(PrefKeys.biometricEnabled), isFalse);
    });

    test('the invalidation survives an app restart until the PIN is entered', () async {
      keystore.keyState = 'invalidated';
      await pinService().setPin('1234');
      final LockController c = await start(prefs: <String, Object>{
        PrefKeys.lockEnabled: true,
        LockPrefKeys.pinConfigured: true,
        PrefKeys.biometricEnabled: true,
      });
      expect(lock().biometricEnabled, isTrue, reason: 'checked when offered');
      expect(await c.unlockWithBiometrics('r'), isFalse);
      expect(lock().biometricEnrollmentChanged, isTrue);
    });

    test('a missing key (biometrics enabled before v1.2) needs the PIN once, silently', () async {
      final LockController c = await unlockedWith(LockTimeout.immediately, biometric: true);
      await background();
      await foreground();
      keystore.keyState = 'missing';
      expect(await c.unlockWithBiometrics('r'), isFalse);
      expect(lock().biometricEnrollmentChanged, isFalse);
      expect((await c.unlockWithPin('1234')).ok, isTrue);
      expect(lock().biometricEnabled, isTrue);
    });

    test('settings re-auth checks the tripwire too', () async {
      final LockController c = await unlockedWith(LockTimeout.minute1, biometric: true);
      keystore.keyState = 'invalidated';
      auth.result = true;
      expect(await c.reauthenticateWithBiometrics('r'), isFalse);
      expect(auth.biometricOnlyCalls, isEmpty);
      expect((await c.verifyPin('1234')).ok, isTrue);
      expect(lock().biometricEnabled, isTrue);
    });

    test('no keystore channel (other platforms): biometrics keep working', () async {
      FakeKeystore.uninstall();
      final LockController c = await unlockedWith(LockTimeout.minute1);
      expect(await c.setBiometricEnabled(true), isTrue);
      auth.result = true;
      expect(await c.reauthenticateWithBiometrics('r'), isTrue);
    });
  });
}
