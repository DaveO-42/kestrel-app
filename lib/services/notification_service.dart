import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import '../main_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> init(BuildContext context) async {
    await FirebaseMessaging.instance.requestPermission();

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await ApiService.postFcmToken(token);

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      ApiService.postFcmToken(t);
    });

    // Capture context-dependent objects before async gaps
    final nav = KestrelNav.of(context);
    final messenger = ScaffoldMessenger.of(context);

    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? message.data['event'] ?? 'Kestrel';
      messenger.showSnackBar(SnackBar(content: Text(title)));
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigateFromMessage(message, nav);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _navigateFromMessage(initial, nav);
  }

  void _navigateFromMessage(RemoteMessage message, KestrelNav? nav) {
    final event = message.data['event'] as String?;
    if (event == 'CANDIDATES') {
      nav?.goToTab(1);
    } else {
      nav?.goToTab(0);
    }
  }
}
