import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:kestrel_app/services/auth_service.dart';
import 'package:kestrel_app/services/api_service.dart';

class MockHttpClient extends Mock implements http.Client {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockHttpClient mockClient;
  late MockFlutterSecureStorage mockStorage;
  late AuthService authService;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    mockStorage = MockFlutterSecureStorage();
    authService = AuthService(storage: mockStorage, httpClient: mockClient);
    ApiService.baseUrl = 'http://test.local';
  });

  group('AuthService.login()', () {
    test('200 response: stores access_token and refresh_token, returns true', () async {
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'access_token': 'acc_tok', 'refresh_token': 'ref_tok'}),
        200,
      ));
      when(() => mockStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      )).thenAnswer((_) async {});

      final result = await authService.login('password');

      expect(result, isTrue);
      verify(() => mockStorage.write(key: 'access_token', value: 'acc_tok')).called(1);
      verify(() => mockStorage.write(key: 'refresh_token', value: 'ref_tok')).called(1);
    });

    test('401 response: returns false, nothing stored', () async {
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response('', 401));

      final result = await authService.login('wrong');

      expect(result, isFalse);
      verifyNever(() => mockStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ));
    });

    test('500 response: throws Exception', () async {
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response('error', 500));

      await expectLater(
        () => authService.login('password'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AuthService.logout()', () {
    test('deletes both access_token and refresh_token from storage', () async {
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await authService.logout();

      verify(() => mockStorage.delete(key: 'access_token')).called(1);
      verify(() => mockStorage.delete(key: 'refresh_token')).called(1);
    });
  });

  group('AuthService.getAccessToken()', () {
    test('returns the stored value from secure storage', () async {
      when(() => mockStorage.read(key: 'access_token'))
          .thenAnswer((_) async => 'my_token');

      final result = await authService.getAccessToken();

      expect(result, equals('my_token'));
    });
  });

  group('AuthService.isLoggedIn()', () {
    test('returns true when token is present', () async {
      when(() => mockStorage.read(key: 'access_token'))
          .thenAnswer((_) async => 'some_token');

      expect(await authService.isLoggedIn(), isTrue);
    });

    test('returns false when no token stored', () async {
      when(() => mockStorage.read(key: 'access_token'))
          .thenAnswer((_) async => null);

      expect(await authService.isLoggedIn(), isFalse);
    });
  });

  group('AuthService.refreshToken()', () {
    test('valid refresh token + 200: stores new access token and returns it', () async {
      when(() => mockStorage.read(key: 'refresh_token'))
          .thenAnswer((_) async => 'ref_tok');
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'access_token': 'new_acc'}),
        200,
      ));
      when(() => mockStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      )).thenAnswer((_) async {});

      final result = await authService.refreshToken();

      expect(result, equals('new_acc'));
      verify(() => mockStorage.write(key: 'access_token', value: 'new_acc')).called(1);
    });

    test('empty refresh token: returns null without HTTP call', () async {
      when(() => mockStorage.read(key: 'refresh_token'))
          .thenAnswer((_) async => '');

      final result = await authService.refreshToken();

      expect(result, isNull);
      verifyNever(() => mockClient.post(any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ));
    });

    test('server returns 401: returns null', () async {
      when(() => mockStorage.read(key: 'refresh_token'))
          .thenAnswer((_) async => 'ref_tok');
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response('', 401));

      final result = await authService.refreshToken();

      expect(result, isNull);
    });
  });
}
