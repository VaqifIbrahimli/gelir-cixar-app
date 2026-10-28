import 'package:flutter/services.dart';

/// Window-level and system calls into MainActivity (android/.../MainActivity.kt).
abstract final class PlatformWindow {
  static const MethodChannel _channel = MethodChannel('az.vaqif.gelir_cixar/window');

  /// Sets or clears `FLAG_SECURE` (blocks screenshots and hides the app in
  /// the recents preview).
  static Future<void> setSecure(bool secure) => _call('setSecure', secure);

  /// Sends the task to the background, like the Home button.
  static Future<void> moveToBack() => _call('moveToBack');

  /// Milliseconds since boot, including deep sleep (`SystemClock
  /// .elapsedRealtime()`). Unlike the wall clock it cannot be changed by the
  /// user, so lockouts and re-lock timers use it. Null when unavailable
  /// (tests, other platforms).
  static Future<int?> elapsedRealtime() async {
    try {
      return await _channel.invokeMethod<int>('elapsedRealtime');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> _call(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Not on Android (tests, other platforms).
    } on PlatformException {
      // Best effort: a window flag failing must not break the app.
    }
  }
}
