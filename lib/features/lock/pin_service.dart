import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/platform_window.dart';

/// Result of a PIN check.
class PinCheck {
  const PinCheck._(this.ok, this.lockedUntil, this.failedAttempts);

  const PinCheck.success() : this._(true, null, 0);
  const PinCheck.wrong(int failed, DateTime? until) : this._(false, until, failed);

  final bool ok;

  /// Non-null when input is blocked until this moment.
  final DateTime? lockedUntil;
  final int failedAttempts;
}

/// Milliseconds on a clock the user cannot set; null when unavailable.
typedef UptimeClock = Future<int?> Function();

/// Stores the PIN as PBKDF2-HMAC-SHA256 with a random 16-byte salt in
/// flutter_secure_storage (Android Keystore-backed). The plain PIN is never
/// persisted. Also tracks failed attempts and the progressive lockout.
///
/// Hash format (one value, written atomically):
/// `pbkdf2-sha256$<iterations>$<base64url salt>$<base64url key>`.
/// Hashes from 1.0.0 (`hex(SHA-256(salt + pin))` plus a separate salt key)
/// still verify and are upgraded on the next successful check.
///
/// A 4–6 digit PIN has at most 10^6 values, so no KDF makes an offline
/// attack impossible; the iterations turn microseconds per guess into
/// ~0.2 s of CPU, and the real protection is the Keystore-wrapped storage
/// plus the attempt counter below.
///
/// The lockout runs on [UptimeClock] (time since boot, including sleep), not
/// the wall clock, so moving the system clock forward does not end it.
class PinService {
  PinService([
    FlutterSecureStorage? storage,
    int iterations = defaultIterations,
    UptimeClock? uptime,
  ])  : _storage = storage ?? const FlutterSecureStorage(),
        _iterations = iterations,
        _uptime = uptime ?? PlatformWindow.elapsedRealtime;

  final FlutterSecureStorage _storage;
  final int _iterations;
  final UptimeClock _uptime;

  static const String _kHash = 'pin.hash';
  static const String _kLength = 'pin.length';
  static const String _kFailed = 'pin.failed';

  /// Uptime (ms) when the current lockout started, and its length (ms).
  static const String _kLockStart = 'pin.lockStart';
  static const String _kLockMs = 'pin.lockMs';

  // Legacy (1.0.0) keys, read for migration and then removed.
  static const String _kSalt = 'pin.salt';
  static const String _kUntil = 'pin.lockedUntil';

  static const String _scheme = 'pbkdf2-sha256';

  /// PBKDF2 rounds for new hashes. Stored with each hash, so raising it later
  /// upgrades existing PINs on their next successful check.
  static const int defaultIterations = 100000;

  static const int minLength = 4;
  static const int maxLength = 6;

  /// Wrong attempts allowed before the first lockout.
  static const int freeAttempts = 5;
  static const Duration baseLockout = Duration(seconds: 30);
  static const Duration maxLockout = Duration(hours: 1);

  /// Serialises every read-modify-write of the attempt counter, so two quick
  /// submissions cannot both read the same count.
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final Future<T> result = _tail.then((_) => op());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<bool> hasPin() async => (await _storage.read(key: _kHash)) != null;

  Future<int> pinLength() async =>
      int.tryParse(await _storage.read(key: _kLength) ?? '') ?? minLength;

  Future<void> setPin(String pin) => _serial(() async {
        if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
          throw ArgumentError.value('***', 'pin', 'must be 4-6 digits');
        }
        await _storage.write(key: _kHash, value: await _newHash(pin));
        await _storage.write(key: _kLength, value: '${pin.length}');
        await _storage.delete(key: _kSalt);
        await _resetFailures();
      });

  Future<void> clearPin() => _serial(() async {
        await _storage.delete(key: _kHash);
        await _storage.delete(key: _kSalt);
        await _storage.delete(key: _kLength);
        await _resetFailures();
      });

  /// Current lockout end, or null when input is allowed. The returned
  /// [DateTime] is for display only; the check itself uses uptime.
  Future<DateTime?> lockedUntil() async {
    final Duration? left = await _lockoutLeft();
    return left == null ? null : DateTime.now().add(left);
  }

  Future<PinCheck> verify(String pin) => _serial(() async {
        final int failed = int.tryParse(await _storage.read(key: _kFailed) ?? '') ?? 0;
        final DateTime? blocked = await lockedUntil();
        if (blocked != null) return PinCheck.wrong(failed, blocked);

        // Count the attempt *before* checking it, so killing the app during
        // the (slow) check cannot yield a free guess.
        final int now = failed + 1;
        await _storage.write(key: _kFailed, value: '$now');
        DateTime? until;
        if (now >= freeAttempts) {
          final Duration d = lockoutFor(now);
          await _startLockout(d);
          until = DateTime.now().add(d);
        }

        final String? stored = await _storage.read(key: _kHash);
        if (stored != null && await _matches(pin, stored)) {
          await _resetFailures();
          if (_needsUpgrade(stored)) {
            // Single write: the new value carries its own salt.
            await _storage.write(key: _kHash, value: await _newHash(pin));
            await _storage.delete(key: _kSalt);
          }
          return const PinCheck.success();
        }
        return PinCheck.wrong(now, until);
      });

  /// 5th wrong attempt: 30 s, 6th: 60 s, 7th: 120 s ... capped at 1 hour.
  static Duration lockoutFor(int failedAttempts) {
    final int step = (failedAttempts - freeAttempts).clamp(0, 20);
    final int secs = baseLockout.inSeconds * (1 << step);
    return Duration(seconds: min(secs, maxLockout.inSeconds));
  }

  // ---- lockout clock ---------------------------------------------------------

  Future<void> _startLockout(Duration d) async {
    final int? up = await _uptime();
    if (up != null) {
      await _storage.write(key: _kLockStart, value: '$up');
      await _storage.write(key: _kLockMs, value: '${d.inMilliseconds}');
      await _storage.delete(key: _kUntil);
    } else {
      // No monotonic clock (tests / other platforms): wall clock.
      final int until = DateTime.now().add(d).millisecondsSinceEpoch;
      await _storage.write(key: _kUntil, value: '$until');
    }
  }

  Future<Duration?> _lockoutLeft() async {
    final int? start = int.tryParse(await _storage.read(key: _kLockStart) ?? '');
    final int? length = int.tryParse(await _storage.read(key: _kLockMs) ?? '');
    if (start != null && length != null) {
      final int? up = await _uptime();
      // Clock unreadable: fail closed with the full lockout.
      if (up == null) return Duration(milliseconds: length.clamp(0, maxLockout.inMilliseconds));
      // Uptime restarts at 0 after a reboot. Time since boot is then still a
      // lower bound of the real time passed, so the estimate never shortens
      // the lockout.
      final int passed = up >= start ? up - start : up;
      final int left = length - passed;
      return left > 0 ? Duration(milliseconds: left) : null;
    }
    final int? untilMs = int.tryParse(await _storage.read(key: _kUntil) ?? '');
    if (untilMs == null) return null;
    final int left = untilMs - DateTime.now().millisecondsSinceEpoch;
    if (left <= 0) return null;
    // Never more than the longest lockout, even if the clock was set back.
    return Duration(milliseconds: min(left, maxLockout.inMilliseconds));
  }

  Future<void> _resetFailures() async {
    await _storage.delete(key: _kFailed);
    await _storage.delete(key: _kUntil);
    await _storage.delete(key: _kLockStart);
    await _storage.delete(key: _kLockMs);
  }

  // ---- hashing ---------------------------------------------------------------

  Future<String> _newHash(String pin) async {
    final Random rnd = Random.secure();
    final Uint8List salt = Uint8List.fromList(
      List<int>.generate(16, (_) => rnd.nextInt(256)),
    );
    final Uint8List key = await _derive(utf8.encode(pin), salt, _iterations);
    return '$_scheme\$$_iterations\$${base64UrlEncode(salt)}\$${base64UrlEncode(key)}';
  }

  Future<bool> _matches(String pin, String stored) async {
    final List<String> parts = stored.split(r'$');
    if (parts.length == 4 && parts[0] == _scheme) {
      final int? iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 1 || iterations > 10000000) return false;
      try {
        final Uint8List salt = base64Url.decode(parts[2]);
        final Uint8List expected = base64Url.decode(parts[3]);
        final Uint8List actual = await _derive(utf8.encode(pin), salt, iterations);
        return constantTimeEquals(actual, expected);
      } on FormatException {
        return false;
      }
    }
    // Legacy 1.0.0: hex(SHA-256(saltString + pin)), salt in its own key.
    final String? salt = await _storage.read(key: _kSalt);
    if (salt == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(stored)) return false;
    final List<int> actual = sha256.convert(utf8.encode('$salt$pin')).bytes;
    return constantTimeEquals(actual, _hexDecode(stored));
  }

  bool _needsUpgrade(String stored) {
    final List<String> parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _scheme) return true;
    return (int.tryParse(parts[1]) ?? 0) < _iterations;
  }

  static List<int> _hexDecode(String hex) => <int>[
        for (int i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
      ];

  /// Runs PBKDF2 off the UI isolate (it takes a few hundred ms on a phone).
  /// Under `flutter test` it runs inline, because a background isolate never
  /// completes inside the fake-async zone of widget tests.
  static Future<Uint8List> _derive(List<int> pin, List<int> salt, int iterations) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<Uint8List>.value(pbkdf2Sha256(pin, salt, iterations));
    }
    return Isolate.run(() => pbkdf2Sha256(pin, salt, iterations));
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018) with a single 32-byte output block.
  @visibleForTesting
  static Uint8List pbkdf2Sha256(List<int> password, List<int> salt, int iterations) {
    final Hmac mac = Hmac(sha256, password);
    List<int> u = mac.convert(<int>[...salt, 0, 0, 0, 1]).bytes;
    final Uint8List out = Uint8List.fromList(u);
    for (int i = 1; i < iterations; i++) {
      u = mac.convert(u).bytes;
      for (int j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  /// Compares in time independent of where the inputs differ.
  @visibleForTesting
  static bool constantTimeEquals(List<int> a, List<int> b) {
    int diff = a.length ^ b.length;
    final int n = min(a.length, b.length);
    for (int i = 0; i < n; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
