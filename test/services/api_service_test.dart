import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kestrel_app/services/api_service.dart';
import 'package:kestrel_app/services/auth_service.dart';
import 'package:kestrel_app/services/cache_service.dart';

class MockHttpClient extends Mock implements http.Client {}
class MockAuthService extends Mock implements AuthService {}

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

  // ── getMapCached ──────────────────────────────────────────────

  group('ApiService.getMapCached()', () {
    test('200 response: returns CachedResult isOffline=false and writes to cache', () async {
      final responseData = {'key': 'value', 'count': 42};
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(jsonEncode(responseData), 200));

      final result = await ApiService.getMapCached<Map<String, dynamic>>(
        'assets/mock/dashboard.json',
        '/dashboard',
        'cache_dashboard',
      );

      expect(result.isOffline, isFalse);
      expect(result.data, equals(responseData));

      final cached = await CacheService.read<Map<String, dynamic>>('cache_dashboard');
      expect(cached, isNotNull);
      expect(cached!.data, equals(responseData));
    });

    test('network error: falls back to cache if cache exists', () async {
      await CacheService.write('cache_dashboard', {'from_cache': true});

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('Network error'));

      final result = await ApiService.getMapCached<Map<String, dynamic>>(
        'assets/mock/dashboard.json',
        '/dashboard',
        'cache_dashboard',
      );

      expect(result.isOffline, isTrue);
      expect(result.data, equals({'from_cache': true}));
    });

    test('network error with empty cache: rethrows', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('Network error'));

      await expectLater(
        () => ApiService.getMapCached<Map<String, dynamic>>(
          'assets/mock/dashboard.json',
          '/dashboard',
          'cache_dashboard',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('401 + successful refresh + retry 200: returns data', () async {
      when(() => mockAuth.refreshToken()).thenAnswer((_) async => 'new_token');

      var callCount = 0;
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return http.Response('', 401);
        return http.Response(jsonEncode({'refreshed': true}), 200);
      });

      final result = await ApiService.getMapCached<Map<String, dynamic>>(
        'assets/mock/dashboard.json',
        '/dashboard',
        'cache_dashboard',
      );

      expect(result.data, equals({'refreshed': true}));
      expect(callCount, equals(2));
    });

    test('401 + failed refresh: throws ActionException with isAuthError=true', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('', 401));

      await expectLater(
        () => ApiService.getMapCached<Map<String, dynamic>>(
          'assets/mock/dashboard.json',
          '/dashboard',
          'cache_dashboard',
        ),
        throwsA(
          isA<ActionException>()
              .having((e) => e.isAuthError, 'isAuthError', isTrue),
        ),
      );

      verify(() => mockAuth.logout()).called(1);
    });
  });

  // ── postSold ──────────────────────────────────────────────────

  group('ApiService.postSold()', () {
    test('200 response: returns decoded Map, body contains ticker and fill_price_eur', () async {
      when(() => mockAuth.getAccessToken()).thenAnswer((_) async => 'tok');

      late Map<String, dynamic> capturedBody;
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((inv) async {
        capturedBody = jsonDecode(inv.namedArguments[#body] as String)
            as Map<String, dynamic>;
        return http.Response(jsonEncode({'ok': true, 'status': 'sold'}), 200);
      });

      final result = await ApiService.postSold(
        ticker: 'NVDA',
        fillPriceEur: 123.45,
      );

      expect(result, equals({'ok': true, 'status': 'sold'}));
      expect(capturedBody['ticker'], equals('NVDA'));
      expect(capturedBody['fill_price_eur'], equals(123.45));
    });

    test('401 response: throws ActionException', () async {
      when(() => mockAuth.getAccessToken()).thenAnswer((_) async => 'tok');
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response('', 401));

      await expectLater(
        () => ApiService.postSold(ticker: 'NVDA', fillPriceEur: 123.45),
        throwsA(isA<ActionException>()),
      );
    });
  });

  // ── postBought ────────────────────────────────────────────────

  group('ApiService.postBought()', () {
    test('200 response: body contains all required fields', () async {
      when(() => mockAuth.getAccessToken()).thenAnswer((_) async => 'tok');

      late Map<String, dynamic> capturedBody;
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((inv) async {
        capturedBody = jsonDecode(inv.namedArguments[#body] as String)
            as Map<String, dynamic>;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      await ApiService.postBought(
        ticker: 'AAPL',
        quantity: 10,
        fillPriceEur: 150.0,
        stopEur: 145.0,
        atrEur: 2.5,
        notes: 'test note',
      );

      expect(capturedBody['ticker'], equals('AAPL'));
      expect(capturedBody['quantity'], equals(10));
      expect(capturedBody['fill_price_eur'], equals(150.0));
      expect(capturedBody['stop_eur'], equals(145.0));
      expect(capturedBody['atr_eur'], equals(2.5));
      expect(capturedBody['notes'], equals('test note'));
    });
  });
}
