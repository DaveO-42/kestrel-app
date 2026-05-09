import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kestrel_app/main_screen.dart';
import 'package:kestrel_app/services/api_service.dart';
import 'package:kestrel_app/services/auth_service.dart';
import 'package:kestrel_app/test/widget_test_helpers.dart';
import 'package:kestrel_app/widgets/sold_sheet.dart';

class MockHttpClient extends Mock implements http.Client {}
class MockAuthService extends Mock implements AuthService {}

// Pushes SoldSheet as a second route so Navigator.pop() returns to base route.
Widget _soldSheetViaRoute({required SoldSheet sheet, VoidCallback? onSettings}) {
  return MaterialApp(
    home: Builder(
      builder: (ctx) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(
            builder: (_) => KestrelNav(
              goToDashboard: () {},
              goToSystem: () {},
              goToHistory: () {},
              goToSettings: onSettings ?? () {},
              refreshDashboard: () {},
              refreshShortlist: () {},
              setConnectionError: (_) {},
              goToTab: (_) {},
              connectionError: false,
              child: Scaffold(body: sheet),
            ),
          )),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

SoldSheet _sheet({VoidCallback? onSuccess}) => SoldSheet(
  ticker: 'NVDA',
  entryPriceEur: 100.0,
  quantity: 3,
  lastKnownPriceEur: 115.0,
  onSuccess: onSuccess ?? () {},
);

void main() {
  late MockHttpClient mockClient;
  late MockAuthService mockAuth;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.baseUrl = 'http://test.local';
    mockClient = MockHttpClient();
    mockAuth = MockAuthService();
    ApiService.testClient = mockClient;
    ApiService.testAuthService = mockAuth;
    when(() => mockAuth.getAccessToken()).thenAnswer((_) async => null);
    when(() => mockAuth.refreshToken()).thenAnswer((_) async => null);
    when(() => mockAuth.logout()).thenAnswer((_) async {});
  });

  tearDown(() {
    ApiService.testClient = null;
    ApiService.testAuthService = null;
  });

  group('SoldSheet', () {
    testWidgets('renders with pre-filled price showing lastKnownPriceEur', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();

      expect(find.text('115.00'), findsOneWidget);
    });

    testWidgets('P&L preview shows +€60.00 when fill is 120.00', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '120.00');
      await tester.pump();

      expect(find.text('+€60.00'), findsOneWidget);
    });

    testWidgets('P&L preview shows €-30.00 when fill is 90.00', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '90.00');
      await tester.pump();

      expect(find.text('€-30.00'), findsOneWidget);
    });

    testWidgets('confirm button disabled when fill field is empty', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Verkauf erfassen'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('confirm button enabled when fill > 0', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();

      // lastKnownPriceEur = 115.0 is pre-filled, so _fill > 0 already
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Verkauf erfassen'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('happy path: fill 115.00, confirm dialog, onSuccess called', (tester) async {
      bool onSuccessCalled = false;
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(jsonEncode({'ok': true}), 200));

      await tester.pumpWidget(_soldSheetViaRoute(
        sheet: _sheet(onSuccess: () => onSuccessCalled = true),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap the sell confirmation button → opens dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verkauf erfassen'));
      await tester.pump();

      // Dialog is open — tap Verkaufen
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verkaufen'));
      await tester.pump(); // microtasks: postSold resolves, pop() called, onSuccess()
      await tester.pump();

      expect(onSuccessCalled, isTrue);
    });

    testWidgets('error path: ActionException shows error message, sheet stays open, onSuccess not called', (tester) async {
      bool onSuccessCalled = false;
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async =>
          http.Response(jsonEncode({'detail': 'Server-Fehler'}), 500));

      await tester.pumpWidget(wrapWithKestrelNav(
        _sheet(onSuccess: () => onSuccessCalled = true),
      ));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Verkauf erfassen'));
      await tester.pump(); // dialog opens

      await tester.tap(find.widgetWithText(ElevatedButton, 'Verkaufen'));
      await tester.pump(); // postSold fails → _error set
      await tester.pump();

      expect(find.text('Server-Fehler'), findsOneWidget);
      expect(onSuccessCalled, isFalse);
      expect(find.byType(SoldSheet), findsOneWidget);
    });

    testWidgets('cancel in confirmation dialog: onSuccess not called, sheet stays open', (tester) async {
      bool onSuccessCalled = false;

      await tester.pumpWidget(wrapWithKestrelNav(
        _sheet(onSuccess: () => onSuccessCalled = true),
      ));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Verkauf erfassen'));
      await tester.pump(); // dialog opens

      // SoldSheet also has a disabled "Abbrechen" TextButton (loading=true) in the
      // sheet itself; target specifically the one inside the AlertDialog.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Abbrechen'),
        ),
      );
      await tester.pump();

      expect(onSuccessCalled, isFalse);
      expect(find.byType(SoldSheet), findsOneWidget);
    });
  });
}
