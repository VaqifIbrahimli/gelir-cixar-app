import 'package:flutter/services.dart' show PredictiveBackEvent;
import 'package:flutter/widgets.dart';

import '../../core/platform_window.dart';

/// Swallows the system back action while the lock overlay is shown, so the
/// hidden route stack underneath is never popped. Back sends the app to the
/// background instead (like Home).
///
/// Must be registered in `main()` *before* `runApp`, because
/// [WidgetsBinding] asks observers in registration order and the router's
/// own observer would otherwise pop a route first.
class LockBackInterceptor with WidgetsBindingObserver {
  LockBackInterceptor(this._isLocked);

  final bool Function() _isLocked;
  bool _gestureClaimed = false;

  /// Set by an overlay that handles back itself (onboarding: previous page).
  /// Returns true when it consumed the back action.
  static bool Function()? overlayBack;

  Future<void> _back() async {
    final bool Function()? h = overlayBack;
    if (h != null && h()) return;
    await PlatformWindow.moveToBack();
  }

  @override
  Future<bool> didPopRoute() async {
    if (!_isLocked()) return false;
    await _back();
    return true;
  }

  // Android 14+ predictive back.
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) =>
      _gestureClaimed = _isLocked();

  @override
  void handleCommitBackGesture() {
    if (_gestureClaimed) {
      _gestureClaimed = false;
      _back();
    }
  }

  @override
  void handleCancelBackGesture() => _gestureClaimed = false;
}
