import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      final initialized = await _notificationsPlugin
          .initialize(
            initSettings,
            onDidReceiveNotificationResponse: (NotificationResponse response) {},
          )
          .timeout(const Duration(milliseconds: 600), onTimeout: () => false);

      if (initialized == true) {
        _initialized = true;
        // Request notification permission safely on Android 13+ in background
        final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          await androidImplementation
              .requestNotificationsPermission()
              .timeout(const Duration(milliseconds: 500), onTimeout: () => null);
        }
      }
    } catch (_) {
      // Ignore notification initialization errors to prevent app freeze
    }
  }

  Future<void> showBudgetExceededNotification({
    required String title,
    required String body,
  }) async {
    try {
      if (!_initialized) {
        await init().timeout(const Duration(milliseconds: 600), onTimeout: () {});
      }
      if (!_initialized) return;

      const androidDetails = AndroidNotificationDetails(
        'budget_alerts',
        'Budget Target Alerts',
        channelDescription: 'Notifications sent when expense exceeds daily or monthly targets',
        importance: Importance.high,
        priority: Priority.high,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin
          .show(
            0,
            title,
            body,
            notificationDetails,
          )
          .timeout(const Duration(milliseconds: 600), onTimeout: () {});
    } catch (_) {}
  }
}
