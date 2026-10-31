import 'package:flutter/foundation.dart' show visibleForTesting;

/// Marks the time the app spends behind one of its *own* system dialogs, so
/// the auto-lock does not mistake it for the user leaving the app.
///
/// Android reports a file picker, the share sheet, the camera / gallery of
/// image_picker and the device-credential screen as `paused` (another
/// activity covers ours), exactly like pressing Home. With the "Immediately"
/// auto-lock that would lock the app under the user's hands. While a guard is
/// active, backgrounding is treated as a system dialog: the app never locks
/// sooner than [grace] (the v1.1 default of one minute), or later than the
/// user's own timeout when that is longer. Leaving the app for good through
/// the dialog therefore still locks it.
///
/// **Hook for other features** — wrap every call that opens a system UI:
///
/// ```dart
/// final picked = await SystemDialogGuard.run(() => FilePicker.pickFile(...));
/// await SystemDialogGuard.run(() => SharePlus.instance.share(params));
/// final img = await SystemDialogGuard.run(() => ImagePicker().pickImage(...));
/// ```
///
/// When the dialog cannot be expressed as one future, pair [begin] with
/// [end] in a `try` / `finally`. Biometric and device-credential prompts
/// started through `LockController` are already guarded.
abstract final class SystemDialogGuard {
  /// Never lock sooner than this after leaving through a guarded dialog.
  static const Duration grace = Duration(minutes: 1);

  /// Some plugins complete their future slightly before Android delivers the
  /// matching `paused` (or `resumed`) event. The guard stays active this long
  /// after the last dialog finished, so that late event is still covered.
  static const Duration tail = Duration(seconds: 1);

  static int _depth = 0;
  static DateTime? _endedAt;

  /// Clock used for [tail]; replaced in tests.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// True while a guarded dialog is open (or just closed, see [tail]).
  static bool get isActive {
    if (_depth > 0) return true;
    final DateTime? ended = _endedAt;
    return ended != null && now().difference(ended) < tail;
  }

  /// Runs [dialog] with the guard active. Exceptions propagate unchanged.
  static Future<T> run<T>(Future<T> Function() dialog) async {
    begin();
    try {
      return await dialog();
    } finally {
      end();
    }
  }

  /// Starts a guarded section; every call needs a matching [end].
  static void begin() => _depth++;

  /// Ends a guarded section started with [begin].
  static void end() {
    if (_depth > 0) _depth--;
    if (_depth == 0) _endedAt = now();
  }

  /// Open guarded sections (not counting [tail]).
  @visibleForTesting
  static int get debugDepth => _depth;

  @visibleForTesting
  static void reset() {
    _depth = 0;
    _endedAt = null;
    now = DateTime.now;
  }
}
