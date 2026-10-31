import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/platform_window.dart';
import '../../core/prefs.dart';
import '../settings/settings_controller.dart';
import 'biometric_key.dart';
import 'lock_settings.dart';
import 'pin_service.dart';
import 'system_dialog_guard.dart';

export 'lock_settings.dart' show LockTimeout;
export 'system_dialog_guard.dart' show SystemDialogGuard;

enum LockStatus {
  /// Reading secure storage.
  loading,

  /// First run: the user must create a PIN.
  setupRequired,

  /// PIN (or biometrics) needed. Also used for PIN recovery
  /// ([AppLockState.recovery]), which the lock screen renders itself.
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
    this.timeout = LockTimeout.defaultValue,
    this.recovery = false,
    this.biometricEnrollmentChanged = false,
  });

  final LockStatus status;

  /// App lock switched on (a PIN exists, or existed and must be recovered).
  final bool enabled;
  final bool biometricEnabled;
  final int pinLength;

  /// Auto-lock delay after the app goes to the background.
  final LockTimeout timeout;

  /// The lock was configured but the PIN is gone from secure storage (wiped
  /// or reset). The app stays locked until the user re-authenticates with
  /// the device credential (or deliberately restores access on a device
  /// without a screen lock) and sets a new PIN.
  final bool recovery;

  /// A biometric was enrolled since biometric unlock was turned on: the
  /// lock screen explains why only the PIN is offered.
  final bool biometricEnrollmentChanged;

  bool get isBlocking => status != LockStatus.unlocked;

  AppLockState copyWith({
    LockStatus? status,
    bool? enabled,
    bool? biometricEnabled,
    int? pinLength,
    LockTimeout? timeout,
    bool? recovery,
    bool? biometricEnrollmentChanged,
  }) =>
      AppLockState(
        status: status ?? this.status,
        enabled: enabled ?? this.enabled,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        pinLength: pinLength ?? this.pinLength,
        timeout: timeout ?? this.timeout,
        recovery: recovery ?? this.recovery,
        biometricEnrollmentChanged: biometricEnrollmentChanged ?? this.biometricEnrollmentChanged,
      );
}

/// Outcome of a device-credential prompt (PIN / pattern / biometric of the
/// phone itself).
enum DeviceAuthResult { success, failed, notSecure }

/// Lock-owned shared-preferences keys (core prefs are not touched).
abstract final class LockPrefKeys {
  /// Non-secure marker that a PIN was configured on this install. Kept in
  /// plain shared_preferences on purpose: it must survive a reset of
  /// flutter_secure_storage, which is exactly when it is needed.
  static const String pinConfigured = 'lock.pinConfigured';
}

/// Wall and boot clocks, injectable for tests.
@immutable
class LockClock {
  const LockClock({
    this.now = DateTime.now,
    this.uptime = PlatformWindow.elapsedRealtime,
  });

  final DateTime Function() now;
  final UptimeClock uptime;
}

final Provider<PinService> pinServiceProvider =
    Provider<PinService>((Ref ref) => PinService());

final Provider<LocalAuthentication> localAuthProvider =
    Provider<LocalAuthentication>((Ref ref) => LocalAuthentication());

final Provider<LockSettings> lockSettingsProvider =
    Provider<LockSettings>((Ref ref) => LockSettings());

final Provider<BiometricKeyStore> biometricKeyStoreProvider =
    Provider<BiometricKeyStore>((Ref ref) => const BiometricKeyStore());

final Provider<LockClock> lockClockProvider = Provider<LockClock>((Ref ref) => const LockClock());

/// Owns the app-lock state and re-locks after [AppLockState.timeout] in the
/// background.
class LockController extends Notifier<AppLockState> {
  DateTime? _backgroundedAt;
  int? _backgroundedUptime;

  /// The app went to the background while one of its own system dialogs was
  /// open (see [SystemDialogGuard]).
  bool _backgroundedInDialog = false;

  /// Biometric unlock is suspended until the next correct PIN, after which
  /// the tripwire key is re-created and biometrics come back.
  bool _bioReenrollPending = false;

  /// Recovery: the user proved possession of the device (or acknowledged the
  /// warning on an insecure device), so a new PIN may be set.
  bool _recoveryAuthorized = false;

  /// local_auth reported that no device credential is set.
  bool _credentialReportedMissing = false;

  PinService get _pins => ref.read(pinServiceProvider);
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  LockSettings get _settings => ref.read(lockSettingsProvider);
  BiometricKeyStore get _bioKey => ref.read(biometricKeyStoreProvider);
  LockClock get _clock => ref.read(lockClockProvider);

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
    final bool marker = _prefs.getBool(LockPrefKeys.pinConfigured) ?? false;
    // v1.1 installs have no marker yet, but `lock.enabled == true` is only
    // ever written next to a PIN.
    final bool configured = marker || _prefs.getBool(PrefKeys.lockEnabled) == true;
    final LockTimeout timeout = await _settings.timeout();

    if (!hasPin && configured) {
      // Fail closed: secure storage lost the PIN, the lock was on.
      state = AppLockState(
        status: LockStatus.locked,
        enabled: true,
        timeout: timeout,
        recovery: true,
      );
      return;
    }
    if (hasPin && !marker) await _prefs.setBool(LockPrefKeys.pinConfigured, true);

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
      timeout: timeout,
    );
  }

  // ---- auto-lock -------------------------------------------------------------

  /// Delay for the current background period: a guarded system dialog never
  /// locks sooner than [SystemDialogGuard.grace].
  Duration get _relockAfter {
    final Duration t = state.timeout.duration;
    if (!_backgroundedInDialog) return t;
    return t > SystemDialogGuard.grace ? t : SystemDialogGuard.grace;
  }

  void _onLifecycle(AppLifecycleState s) {
    switch (s) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_backgroundedAt == null) {
          _backgroundedAt = _clock.now();
          _backgroundedInDialog = SystemDialogGuard.isActive;
          _recordBackgroundUptime();
          // "Immediately": lock now, so the first frame after resuming
          // already shows the lock screen.
          if (_relockAfter == Duration.zero) _relock();
        }
      case AppLifecycleState.resumed:
        final DateTime? since = _backgroundedAt;
        final int? sinceUptime = _backgroundedUptime;
        final Duration after = _relockAfter;
        _backgroundedAt = null;
        _backgroundedUptime = null;
        _backgroundedInDialog = false;
        if (since == null) break;
        // Fast path on the wall clock, so the content is covered before the
        // first resumed frame...
        if (_clock.now().difference(since) >= after) {
          _relock();
        } else if (sinceUptime != null) {
          // ...and a check on the boot clock, which cannot be set back to
          // dodge the re-lock.
          _clock.uptime().then((int? now) {
            if (now != null && (now < sinceUptime || now - sinceUptime >= after.inMilliseconds)) {
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
    final DateTime? at = _backgroundedAt;
    final int? up = await _clock.uptime();
    // Still the same background period (no resume in between).
    if (at != null && identical(_backgroundedAt, at)) _backgroundedUptime = up;
  }

  void _relock() {
    if (state.enabled && state.status == LockStatus.unlocked) {
      state = state.copyWith(status: LockStatus.locked);
    }
  }

  /// Changes the auto-lock delay. Caller must re-verify first (PIN or
  /// biometrics), as for [disable]; [LockTimeoutTile] does.
  Future<void> setTimeout(LockTimeout t) async {
    await _settings.setTimeout(t);
    state = state.copyWith(timeout: t);
  }

  // ---- PIN -------------------------------------------------------------------

  /// Checks [pin]; unlocks on success.
  Future<PinCheck> unlockWithPin(String pin) async {
    if (state.recovery) return const PinCheck.wrong(0, null);
    final PinCheck r = await _pins.verify(pin);
    if (r.ok) {
      state = state.copyWith(status: LockStatus.unlocked, biometricEnrollmentChanged: false);
      if (_bioReenrollPending) await _reenrollBiometrics();
    }
    return r;
  }

  /// Checks [pin] without changing the lock status (settings re-auth).
  Future<PinCheck> verifyPin(String pin) async {
    final PinCheck r = await _pins.verify(pin);
    if (r.ok && _bioReenrollPending) await _reenrollBiometrics();
    return r;
  }

  Future<DateTime?> lockedUntil() => _pins.lockedUntil();

  /// Creates or replaces the PIN and turns the lock on. In recovery this is
  /// refused until the user re-authenticated ([recoverWithDeviceCredential]
  /// or [authorizeInsecureRecovery]).
  Future<void> setPin(String pin) async {
    final bool recovering = state.recovery;
    if (recovering && !_recoveryAuthorized) {
      throw StateError('PIN recovery requires re-authentication first');
    }
    await _pins.setPin(pin);
    await _prefs.setBool(LockPrefKeys.pinConfigured, true);
    await _prefs.setBool(PrefKeys.lockEnabled, true);
    await _prefs.setBool(PrefKeys.lockOnboarded, true);
    if (recovering) {
      // Nothing about the old biometric setup can be trusted.
      await _prefs.setBool(PrefKeys.biometricEnabled, false);
      await _bioKey.delete();
      _recoveryAuthorized = false;
      _bioReenrollPending = false;
    }
    state = state.copyWith(
      status: LockStatus.unlocked,
      enabled: true,
      pinLength: pin.length,
      recovery: false,
      biometricEnabled: recovering ? false : null,
      biometricEnrollmentChanged: false,
    );
  }

  /// End of onboarding without a PIN ("Sonra" / "Keç"): stop asking for the
  /// first-run PIN; it can be turned on later in Settings.
  Future<void> completeOnboarding() async {
    await _prefs.setBool(PrefKeys.lockOnboarded, true);
    if (state.status == LockStatus.setupRequired || state.status == LockStatus.loading) {
      state = state.copyWith(status: state.enabled ? LockStatus.locked : LockStatus.unlocked);
    }
  }

  /// Turns the lock off and wipes the PIN. Caller must re-verify first.
  Future<void> disable() async {
    // Markers first: a kill half-way leaves "off" with a stale PIN (harmless,
    // the user verified), never "configured" without a PIN (recovery).
    await _prefs.setBool(LockPrefKeys.pinConfigured, false);
    await _prefs.setBool(PrefKeys.lockEnabled, false);
    await _prefs.setBool(PrefKeys.biometricEnabled, false);
    await _prefs.setBool(PrefKeys.lockOnboarded, true);
    await _pins.clearPin();
    await _bioKey.delete();
    _bioReenrollPending = false;
    state = state.copyWith(
      status: LockStatus.unlocked,
      enabled: false,
      biometricEnabled: false,
      biometricEnrollmentChanged: false,
    );
  }

  // ---- PIN recovery (secure storage lost the PIN) -----------------------------

  /// `true` / `false` when Android reports whether a screen lock is set;
  /// null when unknown.
  Future<bool?> isDeviceSecure() => _bioKey.isDeviceSecure();

  /// Asks for the phone's own credential (biometricOnly: false). On success
  /// the recovery flow may set a new PIN.
  Future<DeviceAuthResult> recoverWithDeviceCredential(String reason) async {
    if (!state.recovery) return DeviceAuthResult.failed;
    final DeviceAuthResult r = await authenticateDeviceCredential(reason);
    if (r == DeviceAuthResult.success) _recoveryAuthorized = true;
    if (r == DeviceAuthResult.notSecure) _credentialReportedMissing = true;
    return r;
  }

  /// Device without a secure lock screen: after the explicit warning the
  /// user may set a new PIN. Refused when the device does have a screen lock
  /// (then [recoverWithDeviceCredential] is the only way).
  Future<bool> authorizeInsecureRecovery() async {
    if (!state.recovery) return false;
    final bool? secure = await isDeviceSecure();
    final bool insecure = secure == false || (secure == null && _credentialReportedMissing);
    if (insecure) _recoveryAuthorized = true;
    return insecure;
  }

  Future<DeviceAuthResult> authenticateDeviceCredential(String reason) async {
    try {
      final bool ok = await SystemDialogGuard.run(
        () => ref.read(localAuthProvider).authenticate(
              localizedReason: reason,
              biometricOnly: false,
              persistAcrossBackgrounding: true,
            ),
      );
      return ok ? DeviceAuthResult.success : DeviceAuthResult.failed;
    } on LocalAuthException catch (e) {
      return e.code == LocalAuthExceptionCode.noCredentialsSet
          ? DeviceAuthResult.notSecure
          : DeviceAuthResult.failed;
    } on PlatformException {
      return DeviceAuthResult.failed;
    }
  }

  // ---- biometrics ------------------------------------------------------------

  /// Biometric unlock. Returns true when the app was unlocked. Checks the
  /// enrollment tripwire first; when a new biometric was enrolled, biometric
  /// unlock is suspended and the PIN is required once.
  Future<bool> unlockWithBiometrics(String reason) async {
    if (state.recovery || !await _biometricUsable()) return false;
    final bool ok = await authenticateBiometric(reason);
    if (ok) state = state.copyWith(status: LockStatus.unlocked);
    return ok;
  }

  /// Settings re-auth with biometrics (tripwire checked). False when
  /// biometrics are off, invalidated or the prompt failed: fall back to PIN.
  Future<bool> reauthenticateWithBiometrics(String reason) async {
    if (!await _biometricUsable()) return false;
    return authenticateBiometric(reason);
  }

  Future<bool> _biometricUsable() async {
    if (!state.biometricEnabled) return false;
    switch (await _bioKey.check()) {
      case BioKeyStatus.valid:
      case BioKeyStatus.unsupported:
        return true;
      case BioKeyStatus.invalidated:
        _bioReenrollPending = true;
        state = state.copyWith(biometricEnabled: false, biometricEnrollmentChanged: true);
        return false;
      case BioKeyStatus.missing:
      case BioKeyStatus.error:
        // Enabled before v1.2 (no key yet) or Keystore trouble: the
        // enrollment cannot be vouched for, so PIN once, then a fresh key.
        _bioReenrollPending = true;
        state = state.copyWith(biometricEnabled: false);
        return false;
    }
  }

  Future<void> _reenrollBiometrics() async {
    _bioReenrollPending = false;
    final BioKeyCreate r = await _bioKey.create();
    final bool ok = r == BioKeyCreate.created || r == BioKeyCreate.unsupported;
    if (!ok) {
      // No biometric enrolled any more, or no screen lock: stay on PIN.
      await _prefs.setBool(PrefKeys.biometricEnabled, false);
      await _bioKey.delete();
    }
    state = state.copyWith(biometricEnabled: ok && state.enabled, biometricEnrollmentChanged: false);
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
      return await SystemDialogGuard.run(
        () => ref.read(localAuthProvider).authenticate(
              localizedReason: reason,
              biometricOnly: true,
              persistAcrossBackgrounding: true,
            ),
      );
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  /// Turns biometric unlock on or off. Turning it on creates the enrollment
  /// tripwire key; returns false (and stays off) when that is impossible
  /// (no biometric enrolled, no screen lock, Keystore error).
  Future<bool> setBiometricEnabled(bool on) async {
    if (on) {
      final BioKeyCreate r = await _bioKey.create();
      if (r != BioKeyCreate.created && r != BioKeyCreate.unsupported) {
        await _prefs.setBool(PrefKeys.biometricEnabled, false);
        state = state.copyWith(biometricEnabled: false);
        return false;
      }
    } else {
      await _bioKey.delete();
    }
    _bioReenrollPending = false;
    await _prefs.setBool(PrefKeys.biometricEnabled, on);
    state = state.copyWith(biometricEnabled: on && state.enabled, biometricEnrollmentChanged: false);
    return on;
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
