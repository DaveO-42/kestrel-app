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
import 'package:kestrel_app/theme/kestrel_theme.dart';
import 'package:kestrel_app/widgets/bought_sheet.dart';

class MockHttpClient extends Mock implements http.Client {}
class MockAuthService extends Mock implements AuthService {}

// Standard fixture used throughout the suite.
final _candidate = <String, dynamic>{
  'ticker': 'NVDA',
  'katalysator': 'Earnings Beat Q2',
  'trade_params': <String, dynamic>{
    'quantity': 3,
    'entry_price_eur': 100.0,
    'stop_level_eur': 90.0,
    'atr_eur': 5.0,
  },
};
const _budget = 500.0;

BoughtSheet _sheet({VoidCallback? onSuccess}) => BoughtSheet(
  candidate: _candidate,
  availableBudgetEur: _budget,
  onSuccess: onSuccess ?? () {},
);

// Pushes BoughtSheet as a second route so Navigator.pop() returns to a base
// route (avoids empty-navigator state when the sheet is dismissed).
Widget _viaRoute({required BoughtSheet sheet}) {
  return MaterialApp(
    home: Builder(
      builder: (ctx) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(
            builder: (_) => KestrelNav(
              goToDashboard: () {},
              goToSystem: () {},
              goToHistory: () {},
              goToSettings: () {},
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

  // ── Rendering & prefill ──────────────────────────────────────

  group('BoughtSheet – Rendering & prefill', () {
    testWidgets('renders KAUF BESTÄTIGEN header and ticker NVDA', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();
      expect(find.text('KAUF BESTÄTIGEN'), findsOneWidget);
      expect(find.text('NVDA'), findsOneWidget);
    });

    testWidgets('all four fields prefilled from trade_params', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();
      // EditableText inside each TextFormField holds the controller value.
      expect(find.text('3'), findsOneWidget);      // qty
      expect(find.text('100.00'), findsOneWidget); // fill (entry_price_eur)
      expect(find.text('90.00'), findsOneWidget);  // stop
      expect(find.text('5.00'), findsOneWidget);   // atr
    });

    testWidgets('empty candidate: all fields empty, confirm button disabled', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(BoughtSheet(
        candidate: const <String, dynamic>{'ticker': 'TEST'},
        availableBudgetEur: _budget,
        onSuccess: () {},
      )));
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Kauf erfassen'),
      );
      expect(button.onPressed, isNull);
    });
  });

  // ── Form validation ──────────────────────────────────────────

  group('BoughtSheet – Form validation', () {
    // TextFormField order in the widget tree:
    // at(0) = STÜCKZAHL (qty), at(1) = FILL-KURS, at(2) = STOP, at(3) = ATR

    testWidgets('all fields valid + within budget: confirm button enabled', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Kauf erfassen'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('qty cleared: confirm button disabled', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Kauf erfassen'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('fill cleared: confirm button disabled', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Kauf erfassen'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('stop cleared: confirm button disabled', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(2), '');
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Kauf erfassen'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('atr cleared: confirm button disabled', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(3), '');
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Kauf erfassen'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('volume exceeds budget: confirm button disabled', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();
      // qty=10, fill=100.00 → volume=1000 > budget=500
      await tester.enterText(find.byType(TextFormField).at(0), '10');
      await tester.pump();
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Kauf erfassen'),
      );
      expect(button.onPressed, isNull);
    });
  });

  // ── Volume summary ───────────────────────────────────────────

  group('BoughtSheet – Volume summary', () {
    testWidgets('qty=3 fill=100.0: volume display shows €300.00', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();
      // _VolumeSummary renders the total as a separate Text widget.
      expect(find.text('€300.00'), findsOneWidget);
    });

    testWidgets('volume within budget: volume Text is green', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();
      final volumeText = tester.widget<Text>(find.text('€300.00'));
      expect(volumeText.style?.color, KestrelColors.green);
    });

    testWidgets('volume exceeds budget: volume Text is red', (tester) async {
      await tester.pumpWidget(wrapWithKestrelNav(_sheet()));
      await tester.pump();
      // qty=10 → 10×100=1000 > 500
      await tester.enterText(find.byType(TextFormField).at(0), '10');
      await tester.pump();
      final volumeText = tester.widget<Text>(find.text('€1000.00'));
      expect(volumeText.style?.color, KestrelColors.red);
    });
  });

  // ── Happy path ───────────────────────────────────────────────

  group('BoughtSheet – Happy path', () {
    testWidgets(
        'Kauf erfassen calls postBought with correct args and fires onSuccess',
        (tester) async {
      bool onSuccessCalled = false;
      late Map<String, dynamic> capturedBody;

      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((inv) async {
        capturedBody =
            jsonDecode(inv.namedArguments[#body] as String) as Map<String, dynamic>;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      // Use a two-route setup so Navigator.pop() returns to the base route.
      await tester.pumpWidget(
        _viaRoute(sheet: _sheet(onSuccess: () => onSuccessCalled = true)),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Kauf erfassen'));
      await tester.pump(); // microtasks: postBought resolves → pop → onSuccess
      await tester.pump();

      expect(onSuccessCalled, isTrue);
      expect(capturedBody['ticker'], 'NVDA');
      expect(capturedBody['quantity'], 3);
      expect(capturedBody['fill_price_eur'], 100.0);
      expect(capturedBody['stop_eur'], 90.0);
      expect(capturedBody['atr_eur'], 5.0);
      expect(capturedBody['notes'], 'Earnings Beat Q2');
    });
  });

  // ── Error handling ───────────────────────────────────────────

  group('BoughtSheet – Error handling', () {
    testWidgets(
        'ActionException: error text visible, sheet stays open, onSuccess not called',
        (tester) async {
      bool onSuccessCalled = false;
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async =>
          http.Response(jsonEncode({'detail': 'Position existiert bereits'}), 500));

      await tester.pumpWidget(
        wrapWithKestrelNav(_sheet(onSuccess: () => onSuccessCalled = true)),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Kauf erfassen'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Position existiert bereits'), findsOneWidget);
      expect(find.byType(BoughtSheet), findsOneWidget);
      expect(onSuccessCalled, isFalse);
    });

    testWidgets(
        'generic Exception: error text visible, sheet stays open, onSuccess not called',
        (tester) async {
      bool onSuccessCalled = false;
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenThrow(Exception('Connection failed'));

      await tester.pumpWidget(
        wrapWithKestrelNav(_sheet(onSuccess: () => onSuccessCalled = true)),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Kauf erfassen'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Verbindungsfehler'), findsOneWidget);
      expect(find.byType(BoughtSheet), findsOneWidget);
      expect(onSuccessCalled, isFalse);
    });
  });

  // ── Cancel ───────────────────────────────────────────────────

  group('BoughtSheet – Cancel', () {
    testWidgets('tap Abbrechen: Navigator.pop called, onSuccess not called',
        (tester) async {
      bool onSuccessCalled = false;

      await tester.pumpWidget(
        _viaRoute(sheet: _sheet(onSuccess: () => onSuccessCalled = true)),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
      // pumpAndSettle drains the MaterialPageRoute exit animation so the
      // BoughtSheet route is fully removed.  No API calls are pending here, so
      // the settle completes quickly.
      await tester.pumpAndSettle();

      expect(onSuccessCalled, isFalse);
      expect(find.byType(BoughtSheet), findsNothing);
    });
  });
}
