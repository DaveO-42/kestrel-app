import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kestrel_app/main_screen.dart';

Widget _wrap({VoidCallback? onSettings}) {
  return MaterialApp(
    home: KestrelNav(
      goToDashboard: () {},
      goToSystem: () {},
      goToHistory: () {},
      goToSettings: onSettings ?? () {},
      refreshDashboard: () {},
      refreshShortlist: () {},
      setConnectionError: (_) {},
      goToTab: (_) {},
      connectionError: false,
      child: const Scaffold(body: ErrorBanner()),
    ),
  );
}

void main() {
  group('ErrorBanner', () {
    testWidgets('renders Keine Verbindung text', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.text('Keine Verbindung'), findsOneWidget);
    });

    testWidgets('renders Settings tap target', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.text('↑ Settings'), findsOneWidget);
    });

    testWidgets('tapping Settings calls KestrelNav.goToSettings()', (tester) async {
      bool settingsTapped = false;
      await tester.pumpWidget(_wrap(onSettings: () => settingsTapped = true));

      await tester.tap(find.text('↑ Settings'));
      await tester.pump();

      expect(settingsTapped, isTrue);
    });
  });
}
