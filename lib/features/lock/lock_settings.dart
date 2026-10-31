import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// How long the app may stay in the background before it locks again.
enum LockTimeout {
  immediately(Duration.zero),
  seconds30(Duration(seconds: 30)),
  minute1(Duration(minutes: 1)),
  minutes5(Duration(minutes: 5)),
  minutes10(Duration(minutes: 10)),
  minutes30(Duration(minutes: 30)),
  hour1(Duration(hours: 1));

  const LockTimeout(this.duration);

  final Duration duration;

  /// v1.1 behaviour, used until the user picks something else.
  static const LockTimeout defaultValue = LockTimeout.minute1;

  String get _stored => '${duration.inSeconds}';

  static LockTimeout? _parse(String raw) {
    for (final LockTimeout t in values) {
      if (t._stored == raw) return t;
    }
    return null;
  }
}

/// Persists the auto-lock timeout.
///
/// Stored in flutter_secure_storage (Keystore-wrapped), not in
/// shared_preferences: the preferences XML is plain text, so anyone who can
/// write the app's files (root, a forensic tool, a debuggable build) could
/// raise the timeout to an hour without knowing the PIN. A forged value here
/// does not decrypt: the plugin then resets the store (resetOnError), which
/// also drops the PIN, and the lock enters recovery (see LockController).
/// Any other read error or an unknown value counts as "Immediately" (fail
/// closed); only a missing value means the default.
class LockSettings {
  LockSettings([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _kTimeout = 'lock.timeoutSeconds';

  Future<LockTimeout> timeout() async {
    try {
      final String? raw = await _storage.read(key: _kTimeout);
      if (raw == null) return LockTimeout.defaultValue;
      return LockTimeout._parse(raw) ?? LockTimeout.immediately;
    } on PlatformException {
      return LockTimeout.immediately;
    }
  }

  Future<void> setTimeout(LockTimeout t) => _storage.write(key: _kTimeout, value: t._stored);

  Future<void> clear() => _storage.delete(key: _kTimeout);
}
