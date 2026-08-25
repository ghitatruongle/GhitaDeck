import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as img;

/// Track 07 tests — optimized HTML deck.
///
///  * effect CSS: only the used effects, one short class each, deduplicated
///    keyframes (P2),
///  * images: lazy via data-src + the JS image map, identical sources share
///    one entry (P3),
///  * player JS: injection + lazy/async attributes (P4),
///  * in-session deck cache (P5, kept from Track 01),
///  * whole-document minify — no newlines/comments left in the output (P6),
///  * player still carries every key handler, notes, auto-play, progress
///    bar (P8),
///  * player strings localized en/vi (P9),
///  * a deck using all 33 effects still carries every class + parses (P10).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dir = Directory.systemTemp.createTempSync('ghita_t07_');

  tearDownAll(() => dir.deleteSync(recursive: true));

  String deckHtml(
    List<Map<String, dynamic>> slides, {
    String locale = 'en',
    Duration? autoAdvance,
  }) {
    return HtmlExportService().buildPresentationHtml(
      slides,
      autoAdvance: autoAdvance,
      playerLocale: locale,
    );
  }

  test('only used effects are emitted, keyframes deduplicated (P2)', () {
    const effects = ['fade', 'pushLeft', 'wipe', 'fade'];
    final html = deckHtml([
      for (final e in effects)
        {'title': e, 'effect': e, 'htmlContent': '<p>x</p>'}
    ]);
    // Used classes present, unused ones absent.
    for (final e in ['slide-transition-fade', 'slide-transition-pushLeft', 'slide-transition-wipe']) {
      expect(html, contains(e));
    }
    for (final absent in ['slide-transition-zoom', 'slide-transition-blinds']) {
      expect(html, isNot(contains(absent)));
    }
    // Duplicated effect does not duplicate its keyframes (the base CSS
    // fadeIn animation matches 'fade' as a prefix, so anchor on '{').
    final keyframes =
        RegExp(r'@keyframes (fade|pushLeft|wipe)\{').allMatches(html).length;
    expect(keyframes, 3);
  });

  test('images are lazy: data-src + JS map, dedupe by source (P3/P4)', () {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    const uri = 'data:image/png;base64,$png';
    // Two slides reference the SAME image → one map entry.
    final html = deckHtml([
      {'title': 'A', 'htmlContent': '<img src="$uri"><img src="$uri"><p>1</p>'},
      {'title': 'B', 'htmlContent': '<img src="$uri"><p>2</p>'},
    ]);
    // No inline base64 <img src>; placeholder + lazy attributes instead.
    expect(html, isNot(contains('<img src="data:')));
    expect(html, contains('<img data-src="i0" loading="lazy" decoding="async"'));
    // The JS map holds the payload ONCE (the loader re-encodes the PNG, so
    // only the structure — one entry, correct prefix — is asserted).
    final mapMatch = RegExp(r'const ghitaImages = (\{.*?\});')
        .firstMatch(html)!
        .group(1)!;
    expect(mapMatch, contains('"i0":"data:image/png;base64,'));
    expect(mapMatch, isNot(contains('"i1"')));
    expect(RegExp('"i\\d+"').allMatches(mapMatch).length, 1,
        reason: 'one entry only');
    // The player injects src when the slide activates.
    expect(html, contains('querySelectorAll("img[data-src]")'));
    expect(html, contains('im.loading = "lazy"'));
    expect(html, contains('im.decoding = "async"'));
  });

  test('two distinct images get two map entries (P3)', () {
    // Two PNGs with genuinely different pixels, so the content differs.
    final bytesA = Uint8List.fromList(img.encodePng(
        img.Image(width: 2, height: 2, numChannels: 3)));
    final bytesB = Uint8List.fromList(img.encodePng(
        img.Image(width: 4, height: 3, numChannels: 3)));
    final html = deckHtml([
      {
        'title': 'A',
        'htmlContent':
            '<img src="data:image/png;base64,${base64Encode(bytesA)}">'
                '<img src="data:image/png;base64,${base64Encode(bytesB)}">'
      }
    ]);
    final map = RegExp(r'const ghitaImages = (\{.*?\});')
        .firstMatch(html)!
        .group(1)!;
    expect(map, contains('"i0"'));
    expect(map, contains('"i1"'));
    expect(RegExp('"i\\d+"').allMatches(map).length, 2);
  });

  test('output is minified — no newlines or comments remain (P6)', () {
    final html = deckHtml([
      {'title': 'T', 'effect': 'fade', 'htmlContent': '<p>Hello</p>'}
    ]);
    expect(html, isNot(contains('\n')));
    expect(html, isNot(contains('// Remove and re-add')));
    expect(html, isNot(contains('/* Slide transition')));
    // The document still parses and is complete.
    expect(html.endsWith('</html>'), isTrue);
    final doc = html_parser.parse(html);
    expect(doc.querySelectorAll('.slide').length, 1);
  });

  test('player still carries every control handler (P8)', () {
    final html = deckHtml([
      {'title': 'N', 'notes': 'Đây là ghi chú', 'effect': 'clock', 'htmlContent': '<p>Nội dung</p>'}
    ], autoAdvance: const Duration(seconds: 3));
    for (final needle in [
      'e.key === "ArrowRight"',
      'e.key === " "',
      'e.key === "PageDown"',
      'e.key === "ArrowLeft"',
      'e.key === "PageUp"',
      'e.key === "Home"',
      'e.key === "End"',
      'e.key === "f"',
      'toggleFullscreen',
      'scheduleAuto()',
      'toggleNotes',
      'progressBar.style.width',
      'setTimeout(() => changeSlide(1), autoMs)',
      'notesBtn',
    ]) {
      expect(html, contains(needle), reason: needle);
    }
  });

  test('player strings follow the deck locale en/vi (P9)', () {
    final en = deckHtml([{'title': 'T', 'htmlContent': '<p>x</p>'}]);
    // P1b: the prev/next buttons are gone — locale parity is asserted on
    // the strings that remain (fullscreen toggle + slide counter).
    expect(en, contains('title="Fullscreen"'));
    expect(en, contains('1 / 1'));
    final vi = deckHtml([{'title': 'T', 'htmlContent': '<p>x</p>'}],
        locale: 'vi');
    expect(vi, contains('title="Toàn màn hình"'));
    expect(vi, contains('1 / 1'));
  });

  test('a deck using all 33 effects keeps every class and parses (P10)', () {
    final slides = [
      for (final effect in SlideEffect.values)
        {
          'title': effect.name,
          'effect': effect.name,
          'htmlContent': '<p>${effect.name}</p>',
        }
    ];
    final html = deckHtml(slides);
    for (final effect in SlideEffect.values) {
      if (effect == SlideEffect.none) continue;
      expect(html, contains('slide-transition-${effect.name}'),
          reason: effect.name);
    }
    expect(() => html_parser.parse(html), returnsNormally);
    expect(html_parser.parse(html).querySelectorAll('.slide').length,
        SlideEffect.values.length);
  });

  test('in-session cache still avoids rebuilds (P5)', () {
    HtmlExportService.clearDeckCache();
    const slides = [
      {'title': 'C', 'htmlContent': '<p>Same deck</p>'}
    ];
    final a = deckHtml(slides);
    final b = deckHtml(slides);
    expect(a, b); // identical object — served from the cache
    expect(HtmlExportService.deckCacheHits, 1);
    expect(HtmlExportService.deckCacheMisses, 1);
  });

  test('text-only decks carry no media player weight (v2.0.1 P3b)', () {
    HtmlExportService.clearDeckCache();
    final plain = deckHtml([
      {'title': 'A', 'htmlContent': '<p>text only</p>'},
      {'title': 'B', 'htmlContent': '<p>more text</p>'},
    ]);
    for (final absent in [
      'function setupVideo',
      'function setupAudio',
      'const ghitaVideos',
      'const ghitaAudios',
      '.ghita-video-bookmarks',
      '.ghita-video-youtube',
      '.ghita-audio-toggle',
      '.ghita-model3d',
      'video[data-src]',
      'audio[data-src]',
    ]) {
      expect(plain, isNot(contains(absent)), reason: absent);
    }
    // The core player must remain fully intact.
    for (final present in [
      'function ghitaShowSlide',
      'addEventListener("keydown"',
      '@keyframes fadeIn',
      'function toggleFullscreen',
      'function scheduleAuto',
    ]) {
      expect(plain, contains(present));
    }
  });

  test('decks using media keep their full player (v2.0.1 P3b)', () {
    HtmlExportService.clearDeckCache();
    final html = deckHtml([
      {
        'title': 'Media',
        'htmlContent': '<video data-video=\'{"youtubeId":"abc"}\'></video>'
            '<audio controls></audio>'
            '<div data-model3d="{}"></div>',
      },
    ]);
    for (final present in [
      'function setupVideo',
      'function setupAudio',
      'const ghitaVideos',
      'const ghitaAudios',
      '.ghita-video-youtube',
      '.ghita-audio-toggle',
      '.ghita-model3d',
      'video[data-video]',
    ]) {
      expect(html, contains(present), reason: present);
    }
  });
}