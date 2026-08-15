import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/export_options.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider MethodChannel
  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/path_provider');
  final List<MethodCall> log = <MethodCall>[];

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    log.add(call);
    if (call.method == 'getApplicationDocumentsDirectory') {
      // Return a real existing temp directory
      return Directory.systemTemp.path;
    }
    return null;
  });

  group('HtmlExportService', () {
    late HtmlExportService service;

    setUp(() {
      service = HtmlExportService();
    });

    test('throws on empty slides', () async {
      expect(
        () => service.exportToHtml([]),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'message', contains('No slides'))),
      );
    });

    test('generates valid HTML structure', () async {
      final slides = [
        {
          'title': 'Test Slide',
          'htmlContent': '<p>Hello world</p>',
        },
      ];

      final path = await service.exportToHtml(slides, fileName: 'test_export');
      expect(File(path).existsSync(), isTrue);
      final content = File(path).readAsStringSync();

      expect(content, contains('<!DOCTYPE html>'));
      expect(content, contains('<html'));
      expect(content, contains('Test Slide'));
      expect(content, contains('Hello world'));
      expect(content, contains('class="deck"'));
      expect(content, contains('id="slide-0"'));
      expect(content, contains('changeSlide'));
      expect(content, contains('</html>'));
    });

    test('handles background colors from data-bg-color', () async {
      final slides = [
        {
          'title': 'Colored Slide',
          'htmlContent': '<div data-bg-color="#ff0000"><p>Red slide</p></div>',
        },
      ];

      final path = await service.exportToHtml(slides, fileName: 'test_bg');
      final content = File(path).readAsStringSync();

      expect(content, contains('#slide-0'));
      expect(content, contains('background-color: #FF0000'));
    });

    test('includes navigation controls', () async {
      final slides = [
        {'title': 'Slide 1', 'htmlContent': '<p>A</p>'},
        {'title': 'Slide 2', 'htmlContent': '<p>B</p>'},
      ];

      final path = await service.exportToHtml(slides, fileName: 'test_nav');
      final content = File(path).readAsStringSync();

      expect(content, contains('totalSlides = 2'));
      expect(content, contains('changeSlide'));
      expect(content, contains('prevBtn'));
      expect(content, contains('nextBtn'));
      expect(content, contains('toggleFullscreen'));
    });

    test('handles special characters in file name', () async {
      final slides = [
        {'title': 'Test', 'htmlContent': '<p>Content</p>'},
      ];

      final path =
          await service.exportToHtml(slides, fileName: 'my presentation!');
      final name = File(path).uri.pathSegments.last;
      expect(name, contains('my_presentation_'));
      expect(name, endsWith('.html'));
    });

    test('buildPresentationHtml starts at the requested startIndex', () {
      final slides = [
        {'title': 'A', 'htmlContent': '<p>A</p>'},
        {'title': 'B', 'htmlContent': '<p>B</p>'},
        {'title': 'C', 'htmlContent': '<p>C</p>'},
      ];
      final html = service.buildPresentationHtml(slides, startIndex: 1);
      expect(html, contains('let currentSlide = 0;'));
      expect(html, contains('showSlide(1);'));
    });

    test('buildPresentationHtml embeds auto-advance timer when configured', () {
      final slides = [
        {'title': 'A', 'htmlContent': '<p>A</p>'},
        {'title': 'B', 'htmlContent': '<p>B</p>'},
      ];
      final html = service.buildPresentationHtml(
        slides,
        autoAdvance: const Duration(seconds: 5),
      );
      expect(html, contains('let autoMs = 5000;'));
      expect(html, contains('function scheduleAuto'));
      expect(html, contains('onclick="toggleAuto()"'));
    });

    test('buildPresentationHtml omits auto control when not configured', () {
      final slides = [
        {'title': 'A', 'htmlContent': '<p>A</p>'},
      ];
      final html = service.buildPresentationHtml(slides);
      expect(html, contains('let autoMs = 0;'));
      expect(html, isNot(contains('onclick="toggleAuto()"')));
    });

    test('applies aspect ratio, notes and backgrounds advanced options',
        () async {
      final path = '${Directory.systemTemp.path}/advanced_html_options.html';
      final exported = await service.exportToHtmlPath(
        [
          {
            'title': 'Portrait',
            'bgColor': '#123456',
            'notes': 'Private presenter note',
            'htmlContent': '<p>Visible content</p>',
          }
        ],
        path,
        aspectRatio: ExportAspectRatio.portrait9x16,
        includeNotes: true,
        includeBackgrounds: true,
      );
      final content = File(exported).readAsStringSync();

      expect(content, contains('aspect-ratio: 9 / 16'));
      expect(content, contains('#slide-0 { background-color: #123456; }'));
      expect(content, contains('Private presenter note'));
      expect(content, contains('function toggleNotes'));
    });

    test('omits notes and slide background when disabled', () async {
      final path =
          '${Directory.systemTemp.path}/advanced_html_without_options.html';
      final exported = await service.exportToHtmlPath(
        [
          {
            'title': 'Plain',
            'bgColor': '#123456',
            'notes': 'Must not be exported',
            'htmlContent': '<p>Visible content</p>',
          }
        ],
        path,
        includeNotes: false,
        includeBackgrounds: false,
      );
      final content = File(exported).readAsStringSync();

      expect(content, isNot(contains('Must not be exported')));
      expect(content, isNot(contains('#slide-0 { background-color:')));
      expect(content, isNot(contains('id="notesBtn"')));
    });

    test('reuses identical decks from the in-session hash cache', () async {
      HtmlExportService.clearDeckCache();
      const deck = [
        {
          'title': 'Cached deck',
          'htmlContent': '<p>Same content twice</p>',
        }
      ];
      final p1 = '${Directory.systemTemp.path}/cached_a.html';
      final p2 = '${Directory.systemTemp.path}/cached_b.html';
      final first = await service.exportToHtmlPath(deck, p1);
      final second = await service.exportToHtmlPath(deck, p2);

      expect(first, p1);
      expect(second, p2);
      // Identical input → served from the cache, byte-identical output.
      expect(HtmlExportService.deckCacheHits, 1);
      expect(HtmlExportService.deckCacheMisses, 1);
      expect(
        File(p1).readAsStringSync(),
        File(p2).readAsStringSync(),
      );

      // A different deck is a cache miss and builds fresh.
      HtmlExportService.clearDeckCache();
      await service.exportToHtmlPath(
        [
          {
            'title': 'Different',
            'htmlContent': '<p>Changed</p>',
          }
        ],
        '${Directory.systemTemp.path}/cached_c.html',
      );
      expect(HtmlExportService.deckCacheMisses, 1);
      expect(HtmlExportService.deckCacheHits, 0);
    });
  });
}
