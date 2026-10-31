import 'package:flutter/services.dart';

/// State of the enrollment tripwire key (see [BiometricKeyStore]).
enum BioKeyStatus {
  /// The key exists and `Cipher.init` succeeds: enrollment unchanged.
  valid,

  /// `KeyPermanentlyInvalidatedException`: a fingerprint / face was added
  /// (or the screen lock removed) since the key was created.
  invalidated,

  /// No key (biometrics enabled before v1.2, or the Keystore was cleared).
  missing,

  /// Keystore error; treated like [missing] (PIN once, then re-create).
  error,

  /// No platform support (tests, non-Android).
  unsupported,
}

/// Result of creating the tripwire key.
enum BioKeyCreate {
  created,

  /// No strong biometric is enrolled, so an auth-bound key cannot exist.
  noBiometrics,

  /// The device has no secure lock screen.
  notSecure,
  error,
  unsupported,
}

/// AndroidKeyStore AES key created with `setUserAuthenticationRequired(true)`
/// and `setInvalidatedByBiometricEnrollment(true)` (MainActivity.kt).
///
/// The key never encrypts anything. It is a tripwire: Android permanently
/// invalidates it when a new biometric is enrolled, so a person who learns
/// the phone's screen-lock code and adds their own fingerprint cannot use it
/// to open this app. local_auth only returns a boolean (no CryptoObject), so
/// this is a detection mechanism, not a cryptographic binding of the unlock.
class BiometricKeyStore {
  const BiometricKeyStore([this._channel = channel]);

  static const MethodChannel channel = MethodChannel('az.vaqif.gelir_cixar/keystore');

  final MethodChannel _channel;

  Future<BioKeyStatus> check() async {
    final String? r = await _invoke('bioKeyCheck');
    return switch (r) {
      'valid' => BioKeyStatus.valid,
      'invalidated' => BioKeyStatus.invalidated,
      'missing' => BioKeyStatus.missing,
      null => BioKeyStatus.unsupported,
      _ => BioKeyStatus.error,
    };
  }

  /// Deletes any old key and creates a fresh one.
  Future<BioKeyCreate> create() async {
    final String? r = await _invoke('bioKeyCreate');
    return switch (r) {
      'created' => BioKeyCreate.created,
      'noBiometrics' => BioKeyCreate.noBiometrics,
      'notSecure' => BioKeyCreate.notSecure,
      null => BioKeyCreate.unsupported,
      _ => BioKeyCreate.error,
    };
  }

  Future<void> delete() async => _invoke('bioKeyDelete');

  /// `KeyguardManager.isDeviceSecure()`: a PIN, pattern or password is set.
  /// Null when unknown (tests, non-Android).
  Future<bool?> isDeviceSecure() async {
    try {
      return await _channel.invokeMethod<bool>('isDeviceSecure');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Null only when the platform side is missing; a platform error is
  /// reported as 'error'.
  Future<String?> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<String>(method) ?? 'error';
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return 'error';
    }
  }
}
