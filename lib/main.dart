import 'package:flutter/material.dart';
import 'main_screen.dart';
import 'theme/kestrel_theme.dart';

void main() {
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
      home: const MainScreen(),
    );
  }
}