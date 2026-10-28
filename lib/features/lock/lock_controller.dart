import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/platform_window.dart';
import '../../core/prefs.dart';
import '../settings/settings_controller.dart';
import 'pin_service.dart';

enum LockStatus {
  /// Reading secure storage.
  loading,

  /// First run: the user must create a PIN.
  setupRequired,

  /// PIN (or biometrics) needed.
  locked,

  /// App content is visible.
  unlocked,
}

@immutable
class AppLockState {
  const AppLockState({
    this.status = LockStatus.loading,
    this.enabled = false,
    this.biometricEnabled = false,
    this.pinLength = PinService.minLength,
  });

  final LockStatus status;

  /// App lock switched on (a PIN exists).
  final bool enabled;
  final bool biometricEnabled;
  final int pinLength;

  bool get isBlocking => status != LockStatus.unlocked;

  AppLockState copyWith({
    LockStatus? status,
    bool? enabled,
    bool? biometricEnabled,
    int? pinLength,
  }) =>
      AppLockState(
        status: status ?? this.status,
        enabled: enabled ?? this.enabled,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        pinLength: pinLength ?? this.pinLength,
      );
}

final Provider<PinService> pinServiceProvider =
    Provider<PinService>((Ref ref) => PinService());

final Provider<LocalAuthentication> localAuthProvider =
    Provider<LocalAuthentication>((Ref ref) => LocalAuthentication());

/// Owns the app-lock state and re-locks after [relockAfter] in background.
class LockController extends Notifier<AppLockState> {
  static const Duration relockAfter = Duration(minutes: 1);

  DateTime? _backgroundedAt;
  int? _backgroundedUptime;

  PinService get _pins => ref.read(pinServiceProvider);
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppLockState build() {
    final AppLifecycleListener listener = AppLifecycleListener(
      onStateChange: _onLifecycle,
    );
    ref.onDispose(listener.dispose);
    Future<void>.microtask(_init);
    return const AppLockState();
  }

  Future<void> _init() async {
    final bool hasPin = await _pins.hasPin();
    final bool enabled = hasPin && (_prefs.getBool(PrefKeys.lockEnabled) ?? true);
    final bool onboarded = _prefs.getBool(PrefKeys.lockOnboarded) ?? false;
    final int len = await _pins.pinLength();
    final bool bio = enabled && (_prefs.getBool(PrefKeys.biometricEnabled) ?? false);

    final LockStatus status;
    if (!hasPin && !onboarded) {
      status = LockStatus.setupRequired;
    } else if (enabled) {
      status = LockStatus.locked;
    } else {
      status = LockStatus.unlocked;
    }
    state = AppLockState(
      status: status,
      enabled: enabled,
      biometricEnabled: bio,
      pinLength: len,
    );
  }

  void _onLifecycle(AppLifecycleState s) {
    switch (s) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_backgroundedAt == null) {
          _backgroundedAt = DateTime.now();
          _recordBackgroundUptime();
        }
      case AppLifecycleState.resumed:
        final DateTime? since = _backgroundedAt;
        final int? sinceUptime = _backgroundedUptime;
        _backgroundedAt = null;
        _backgroundedUptime = null;
        if (since == null) break;
        // Fast path on the wall clock, so the content is covered before the
        // first resumed frame...
        if (DateTime.now().difference(since) >= relockAfter) {
          _relock();
        } else if (sinceUptime != null) {
          // ...and a check on the boot clock, which cannot be set back to
          // dodge the re-lock.
          PlatformWindow.elapsedRealtime().then((int? now) {
            if (now != null &&
                (now < sinceUptime || now - sinceUptime >= relockAfter.inMilliseconds)) {
              _relock();
            }
          });
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _recordBackgroundUptime() async {
    final int? up = await PlatformWindow.elapsedRealtime();
    // Still in the background (no resume in between).
    if (_backgroundedAt != null) _backgroundedUptime = up;
  }

  void _relock() {
    if (state.enabled && state.status == LockStatus.unlocked) {
      state = state.copyWith(status: LockStatus.locked);
    }
  }

  /// Checks [pin]; unlocks on success.
  Future<PinCheck> unlockWithPin(String pin) async {
    final PinCheck r = await _pins.verify(pin);
    if (r.ok) state = state.copyWith(status: LockStatus.unlocked);
    return r;
  }

  /// Checks [pin] without changing the lock status (settings re-auth).
  Future<PinCheck> verifyPin(String pin) => _pins.verify(pin);

  Future<DateTime?> lockedUntil() => _pins.lockedUntil();

  /// Biometric unlock. Returns true when the app was unlocked.
  Future<bool> unlockWithBiometrics(String reason) async {
    if (!state.biometricEnabled) return false;
    final bool ok = await authenticateBiometric(reason);
    if (ok) state = state.copyWith(status: LockStatus.unlocked);
    return ok;
  }

  Future<bool> canUseBiometrics() async {
    try {
      final LocalAuthentication auth = ref.read(localAuthProvider);
      if (!await auth.isDeviceSupported()) return false;
      if (!await auth.canCheckBiometrics) return false;
      return (await auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await ref.read(localAuthProvider).authenticate(
            localizedReason: reason,
            biometricOnly: true,
            persistAcrossBackgrounding: true,
          );
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  /// Creates or replaces the PIN and turns the lock on.
  Future<void> setPin(String pin) async {
    await _pins.setPin(pin);
    await _prefs.setBool(PrefKeys.lockEnabled, true);
    await _prefs.setBool(PrefKeys.lockOnboarded, true);
    state = state.copyWith(
      status: LockStatus.unlocked,
      enabled: true,
      pinLength: pin.length,
    );
  }

  /// Turns the lock off and wipes the PIN. Caller must re-verify first.
  /// End of onboarding without a PIN ("Sonra" / "Keç"): stop asking for the
  /// first-run PIN; it can be turned on later in Settings.
  Future<void> completeOnboarding() async {
    await _prefs.setBool(PrefKeys.lockOnboarded, true);
    if (state.status == LockStatus.setupRequired || state.status == LockStatus.loading) {
      state = state.copyWith(status: state.enabled ? LockStatus.locked : LockStatus.unlocked);
    }
  }

  Future<void> disable() async {
    await _pins.clearPin();
    await _prefs.setBool(PrefKeys.lockEnabled, false);
    await _prefs.setBool(PrefKeys.biometricEnabled, false);
    await _prefs.setBool(PrefKeys.lockOnboarded, true);
    state = state.copyWith(
      status: LockStatus.unlocked,
      enabled: false,
      biometricEnabled: false,
    );
  }

  Future<void> setBiometricEnabled(bool on) async {
    await _prefs.setBool(PrefKeys.biometricEnabled, on);
    state = state.copyWith(biometricEnabled: on && state.enabled);
  }
}

final NotifierProvider<LockController, AppLockState> lockControllerProvider =
    NotifierProvider<LockController, AppLockState>(LockController.new);

/// Whether the window should carry FLAG_SECURE: always while the lock or PIN
/// setup covers the app, otherwise per the "block screenshots" setting.
final Provider<bool> secureWindowProvider = Provider<bool>(
  (Ref ref) =>
      ref.watch(settingsProvider.select((AppSettings s) => s.blockScreenshots)) ||
      ref.watch(lockControllerProvider.select((AppLockState s) => s.isBlocking)),
);
