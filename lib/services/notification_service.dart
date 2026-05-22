import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  static Future<void> showRefundNotification({
    required String exitStationName,
    required double refundAmount,
  }) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'marmaray_refund',
      'Marmaray İade',
      channelDescription: 'Mesafe bazlı otomatik iade bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '₺${refundAmount.toStringAsFixed(2)} iade kartınıza yüklendi',
      '$exitStationName istasyonunda inişiniz onaylandı.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
