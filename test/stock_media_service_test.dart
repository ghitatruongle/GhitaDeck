// T03 (v2.0.1-beta.2) — StockMediaService tests (phase 5).
//
// The library is fully offline (bundled inline SVGs), so the "offline
// fallback" contract is simply: search works with no network, the category
// index stays consistent, and the data-URI form round-trips the exact SVG.
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/stock_media_service.dart';

void main() {
  group('library index', () {
    test('ships the six presentation categories', () {
      expect(
        StockMediaService.byCategory.keys,
        containsAll([
          'Nature',
          'Business',
          'Technology',
          'Education',
          'Abstract',
          'People',
        ]),
      );
    });

    test('every item lands in a bucket matching its own category', () {
      StockMediaService.byCategory.forEach((category, items) {
        for (final item in items) {
          expect(item.category, category);
        }
      });
    });

    test('the bundled library reaches the ~100-item target', () {
      final total = StockMediaService.byCategory.values
          .fold<int>(0, (sum, items) => sum + items.length);
      expect(total, greaterThanOrEqualTo(90),
          reason: 'variants were added to reach ~100 illustrations');
    });

    test('every illustration is a complete SVG document with an aria label',
        () {
      for (final items in StockMediaService.byCategory.values) {
        for (final item in items) {
          expect(item.svg, startsWith('<svg'));
          expect(item.svg, endsWith('</svg>'));
          expect(item.svg, contains('aria-label="${item.name}"'));
        }
      }
    });

    test('the index is cached — repeated access returns the same instance',
        () {
      expect(identical(StockMediaService.byCategory, StockMediaService.byCategory),
          isTrue, reason: 'rebuilding the index per access would waste work');
    });
  });

  group('search (no network involved)', () {
    test('an empty or blank query returns the whole library', () {
      final all = StockMediaService.search('');
      final blank = StockMediaService.search('   ');
      expect(all.length, blank.length);
      final total = StockMediaService.byCategory.values
          .fold<int>(0, (sum, items) => sum + items.length);
      expect(all, hasLength(total));
    });

    test('matches by name, case-insensitively', () {
      final hits = StockMediaService.search('mountain');
      expect(hits.map((m) => m.name), contains('Mountain sunset'));
    });

    test('matches by category name too', () {
      final hits = StockMediaService.search('technology');
      expect(hits, isNotEmpty);
      for (final item in hits) {
        expect(item.category, 'Technology');
      }
    });

    test('a query matching nothing returns an empty list', () {
      expect(StockMediaService.search('zzz-no-such-illustration'), isEmpty);
    });
  });

  group('data URI form', () {
    test('round-trips back to the exact SVG document', () {
      final item = StockMediaService.byCategory['Nature']!.first;
      expect(item.dataUri, startsWith('data:image/svg+xml;base64,'));

      final encoded = item.dataUri.substring('data:image/svg+xml;base64,'.length);
      expect(Uri.decodeComponent(encoded), item.svg);
    });
  });
}
