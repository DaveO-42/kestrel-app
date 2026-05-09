import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kestrel_app/services/cache_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CacheService', () {
    test('write + read: returns CachedResult with isOffline=true and non-null cachedAt', () async {
      await CacheService.write('key1', {'foo': 'bar'});
      final result = await CacheService.read<Map<String, dynamic>>('key1');

      expect(result, isNotNull);
      expect(result!.isOffline, isTrue);
      expect(result.cachedAt, isNotNull);
      expect(result.data, equals({'foo': 'bar'}));
    });

    test('read on missing key returns null', () async {
      final result = await CacheService.read<Map<String, dynamic>>('nonexistent');
      expect(result, isNull);
    });

    test('write Map survives JSON round-trip', () async {
      final data = {'ticker': 'NVDA', 'price': 123.45, 'active': true};
      await CacheService.write('map_key', data);
      final result = await CacheService.read<Map<String, dynamic>>('map_key');
      expect(result!.data, equals(data));
    });

    test('write List survives JSON round-trip', () async {
      final data = ['AAPL', 'MSFT', 'GOOG'];
      await CacheService.write('list_key', data);
      final result = await CacheService.read<List<dynamic>>('list_key');
      expect(result!.data, equals(data));
    });

    test('delete: key is gone after deletion, read returns null', () async {
      await CacheService.write('del_key', {'x': 1});
      await CacheService.delete('del_key');
      final result = await CacheService.read<Map<String, dynamic>>('del_key');
      expect(result, isNull);
    });

    test('clearAll: all keys removed', () async {
      await CacheService.write('k1', {'a': 1});
      await CacheService.write('k2', {'b': 2});
      await CacheService.clearAll();
      expect(await CacheService.read<Map<String, dynamic>>('k1'), isNull);
      expect(await CacheService.read<Map<String, dynamic>>('k2'), isNull);
    });
  });
}
