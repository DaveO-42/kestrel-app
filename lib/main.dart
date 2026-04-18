import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/kestrel_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const KestrelApp());
}

class KestrelApp extends StatelessWidget {
  const KestrelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kestrel',
      debugShowCheckedModeBanner: false,
      theme: KestrelTheme.theme,
      home: const SplashScreen(),
    );
  }
}