import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

class NotificationService extends GetxService {
  final plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await plugin.initialize(settings: settings);
  }

  Future<void> showWarning({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'zenverse_warnings',
      'Warnings',
      channelDescription: 'Session warnings and protection alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
