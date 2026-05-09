import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kestrel_app/widgets/offline_banner.dart';

Widget _build(DateTime? cachedAt) => MaterialApp(
      home: Scaffold(body: OfflineBanner(cachedAt: cachedAt)),
    );

void main() {
  group('OfflineBanner – Rendering', () {
    testWidgets('renders Keine Verbindung text', (tester) async {
      await tester.pumpWidget(_build(null));
      expect(find.textContaining('Keine Verbindung'), findsOneWidget);
    });

    testWidgets('renders a red circular dot (BoxShape.circle Container)', (tester) async {
      await tester.pumpWidget(_build(null));
      // The dot is a Container whose decoration parameter is a BoxDecoration
      // with shape: BoxShape.circle.  The outer banner Container uses the
      // color property (no decoration), so it does not match.
      final circleDot = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final dec = w.decoration;
        return dec is BoxDecoration && dec.shape == BoxShape.circle;
      });
      expect(circleDot, findsOneWidget);
    });
  });

  group('OfflineBanner – _formatAge (cachedAt = null)', () {
    testWidgets('shows unbekannt when cachedAt is null', (tester) async {
      await tester.pumpWidget(_build(null));
      expect(find.textContaining('unbekannt'), findsOneWidget);
    });
  });

  group('OfflineBanner – _formatAge (time intervals)', () {
    testWidgets('30 seconds ago: text contains wenigen Sekunden', (tester) async {
      final cachedAt = DateTime.now().subtract(const Duration(seconds: 30));
      await tester.pumpWidget(_build(cachedAt));
      expect(find.textContaining('wenigen Sekunden'), findsOneWidget);
    });

    testWidgets('5 minutes ago: text contains 5 Min', (tester) async {
      final cachedAt = DateTime.now().subtract(const Duration(minutes: 5));
      await tester.pumpWidget(_build(cachedAt));
      expect(find.textContaining('5 Min'), findsOneWidget);
    });

    testWidgets('3 hours ago: text contains 3 Std', (tester) async {
      final cachedAt = DateTime.now().subtract(const Duration(hours: 3));
      await tester.pumpWidget(_build(cachedAt));
      expect(find.textContaining('3 Std'), findsOneWidget);
    });

    testWidgets('1 day ago: text contains 1 Tag (singular, no en)', (tester) async {
      final cachedAt = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(_build(cachedAt));
      expect(find.textContaining('1 Tag'), findsOneWidget);
      // Must not be plural form '1 Tagen'
      expect(find.textContaining('1 Tagen'), findsNothing);
    });

    testWidgets('3 days ago: text contains 3 Tagen (plural)', (tester) async {
      final cachedAt = DateTime.now().subtract(const Duration(days: 3));
      await tester.pumpWidget(_build(cachedAt));
      expect(find.textContaining('3 Tagen'), findsOneWidget);
    });
  });
}
