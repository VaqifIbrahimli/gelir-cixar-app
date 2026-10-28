import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local notifications (budget alerts). Lazily initialised on first use.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _init;

  static const String _channelId = 'budget_alerts';

  Future<bool> _ensureInit() => _init ??= () async {
        try {
          final bool? ok = await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
            ),
          );
          return ok ?? false;
        } on Exception {
          return false;
        }
      }();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Asks for POST_NOTIFICATIONS on Android 13+ (no-op below). Returns
  /// whether notifications may be shown.
  Future<bool> requestPermission() async {
    if (!await _ensureInit()) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } on Exception {
      return false;
    }
  }

  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!await _ensureInit()) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } on Exception {
      // Permission denied or channel blocked: the in-app SnackBar still shows.
    }
  }
}

final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((Ref ref) => NotificationService());
