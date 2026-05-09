import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kestrel_app/screens/login/login_screen.dart';
import 'package:kestrel_app/services/auth_service.dart';
import 'package:kestrel_app/services/api_service.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.baseUrl = 'http://test.local';
    mockAuth = MockAuthService();
  });

  Widget buildLoginScreen() => MaterialApp(home: LoginScreen(authService: mockAuth));

  // LoginScreen sizes its column to the full screen height and renders an image,
  // so the Anmelden button overflows the default 800×600 test viewport.
  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('LoginScreen', () {
    testWidgets('renders password field and Anmelden button', (tester) async {
      useTallView(tester);
      await tester.pumpWidget(buildLoginScreen());
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Anmelden'), findsOneWidget);
    });

    testWidgets('submit with empty field: no AuthService call, no navigation', (tester) async {
      useTallView(tester);
      await tester.pumpWidget(buildLoginScreen());
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Anmelden'));
      await tester.pump();

      verifyNever(() => mockAuth.login(any()));
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('login returns true: navigates away from LoginScreen', (tester) async {
      useTallView(tester);
      when(() => mockAuth.login(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(buildLoginScreen());
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Anmelden'));
      // Pump 1: processes tap + drains microtasks → pushReplacement → MainScreen built.
      // NotificationService.init() catches Firebase error internally; no crash.
      await tester.pump();
      // Pump 2: advance past the 300 ms FadeTransition so the old route (LoginScreen)
      // is fully dismissed.  Using a fixed duration instead of pumpAndSettle because
      // the sub-screens (DashboardScreen etc.) start real HTTP calls whose IO
      // completions are not driven by the fake clock.
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('login returns false: shows Falsches Passwort', (tester) async {
      useTallView(tester);
      when(() => mockAuth.login(any())).thenAnswer((_) async => false);

      await tester.pumpWidget(buildLoginScreen());
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'wrongpassword');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Anmelden'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Falsches Passwort'), findsOneWidget);
    });

    testWidgets('login throws: shows Verbindungsfehler', (tester) async {
      useTallView(tester);
      when(() => mockAuth.login(any())).thenThrow(Exception('Network error'));

      await tester.pumpWidget(buildLoginScreen());
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Anmelden'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Verbindungsfehler'), findsOneWidget);
    });

    testWidgets('loading state: CircularProgressIndicator while login is pending', (tester) async {
      useTallView(tester);
      final completer = Completer<bool>();
      when(() => mockAuth.login(any())).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildLoginScreen());
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Anmelden'));
      await tester.pump(); // setState({loading:true}) applied; login() still pending

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(false);
      await tester.pump();
    });
  });
}
