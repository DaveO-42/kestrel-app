import 'package:flutter/material.dart';
import '../main_screen.dart';

Widget wrapWithKestrelNav(Widget child) {
  return MaterialApp(
    home: KestrelNav(
      goToDashboard: () {},
      goToSystem: () {},
      goToHistory: () {},
      goToSettings: () {},
      refreshDashboard: () {},
      refreshShortlist: () {},
      setConnectionError: (_) {},
      goToTab: (_) {},
      connectionError: false,
      child: Scaffold(body: child),
    ),
  );
}
