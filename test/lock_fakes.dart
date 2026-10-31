// Fakes for the lock tests: wall / boot clocks driven by hand, a scripted
// local_auth and the keystore MethodChannel answered in Dart.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/features/lock/biometric_key.dart';
import 'package:gelir_cixar/features/lock/lock_controller.dart';
import 'package:local_auth/local_auth.dart';

/// Wall clock and boot clock, advanced independently.
class FakeClocks {
  DateTime wall = DateTime(2026, 10, 31, 12);
  int uptimeMs = 5000000;

  LockClock get clock => LockClock(now: () => wall, uptime: () async => uptimeMs);

  Future<int?> uptime() async => uptimeMs;

  void advanceBoth(Duration d) {
    wall = wall.add(d);
    uptimeMs += d.inMilliseconds;
  }

  /// The user set the system clock back: only real (boot) time passes.
  void advanceUptimeOnly(Duration d) => uptimeMs += d.inMilliseconds;
}

/// Scripted local_auth. Implemented through noSuchMethod so the test does
/// not depend on local_auth's platform-interface types.
class FakeLocalAuth implements LocalAuthentication {
  /// Answer for the next `authenticate` calls, or an exception to throw.
  Object result = true;
  final List<bool> biometricOnlyCalls = <bool>[];

  /// SystemDialogGuard depth seen by each prompt (must be > 0).
  final List<int> guardDepthAtCall = <int>[];

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authenticate) {
      biometricOnlyCalls.add(invocation.namedArguments[#biometricOnly] as bool? ?? false);
      guardDepthAtCall.add(SystemDialogGuard.debugDepth);
      final Object r = result;
      if (r is Exception) return Future<bool>.error(r);
      return Future<bool>.value(r as bool);
    }
    if (invocation.memberName == #getAvailableBiometrics) {
      return Future<List<BiometricType>>.value(<BiometricType>[BiometricType.fingerprint]);
    }
    return super.noSuchMethod(invocation);
  }
}

/// Answers `az.vaqif.gelir_cixar/keystore` like MainActivity would.
class FakeKeystore {
  /// What bioKeyCheck returns: valid / invalidated / missing / error.
  String keyState = 'missing';

  /// What bioKeyCreate returns: created / noBiometrics / notSecure / error.
  String createResult = 'created';
  bool? deviceSecure = true;
  final List<String> calls = <String>[];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BiometricKeyStore.channel, (MethodCall call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'bioKeyCheck':
          return keyState;
        case 'bioKeyCreate':
          if (createResult == 'created') keyState = 'valid';
          return createResult;
        case 'bioKeyDelete':
          keyState = 'missing';
          return null;
        case 'isDeviceSecure':
          return deviceSecure;
      }
      return null;
    });
  }

  static void uninstall() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(BiometricKeyStore.channel, null);
}

/// Drives the app lifecycle through valid transitions only (the
/// AppLifecycleListener asserts on impossible ones).
abstract final class Lifecycle {
  static void _go(List<AppLifecycleState> states) {
    for (final AppLifecycleState s in states) {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(s);
    }
  }

  static void ensureResumed() {
    final AppLifecycleState? s = WidgetsBinding.instance.lifecycleState;
    if (s == AppLifecycleState.resumed) return;
    if (s == null || s == AppLifecycleState.inactive) {
      _go(<AppLifecycleState>[AppLifecycleState.resumed]);
    } else {
      toForeground();
    }
  }

  /// Home button / another activity on top.
  static void toBackground() => _go(<AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);

  static void toForeground() => _go(<AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);

  /// A dialog drawn over the activity (BiometricPrompt): inactive only.
  static void overlayShown() => _go(<AppLifecycleState>[AppLifecycleState.inactive]);
  static void overlayHidden() => _go(<AppLifecycleState>[AppLifecycleState.resumed]);
}
