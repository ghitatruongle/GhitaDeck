// T06 (v2.0.1-beta.2) — PDF depth: bookmarks outline, dedicated notes pages,
// and a 50-slide benchmark smoke (phases 1–2, 7).
//
// The exporter's contract: scale-to-fit means one page per slide, so
// `notesPages` interleaves EXTRA pages after every slide that has notes, and
// `bookmarks` appends a /Outlines tree with one entry per slide.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';

void main() {
  final tmpDir = Directory.systemTemp.path;
  final service = PdfExportService();

  int countPages(String path) => RegExp(r'/Type\s*/Page[^s]')
      .allMatches(String.fromCharCodes(File(path).readAsBytesSync()))
      .length;

  group('bookmarks outline', () {
    test('adds an /Outlines tree with one titled entry per slide', () async {
      final path = await service.exportToPdf(
        [
          {'title': 'Intro', 'htmlContent': '<p>intro</p>'},
          {'title': 'Method', 'htmlContent': '<p>method</p>'},
          {'title': 'Results', 'htmlContent': '<p>results</p>'},
        ],
        '$tmpDir/t06_bookmarks.pdf',
        bookmarks: true,
      );

      final content = String.fromCharCodes(File(path).readAsBytesSync());
      expect(content, contains('/Outlines'));
      expect(RegExp(r'/Outlines \d+ 0 R').hasMatch(content), isTrue,
          reason: 'the catalog must reference the outline root object');
      expect(content, contains('/First'));
      expect(content, contains('/Last'));
      expect(content, contains('1. Intro'));
      expect(content, contains('2. Method'));
      expect(content, contains('3. Results'));
      // Bookmarks must not add pages.
      expect(countPages(path), 3);
    });

    test('without the option no outline is written', () async {
      final path = await service.exportToPdf(
        [
          {'title': 'Plain', 'htmlContent': '<p>plain</p>'},
        ],
        '$tmpDir/t06_no_bookmarks.pdf',
      );
      final content = String.fromCharCodes(File(path).readAsBytesSync());
      expect(content, isNot(contains('/Outlines')));
    });

    test('Vietnamese titles survive in the outline without crashing',
        () async {
      final path = await service.exportToPdf(
        [
          {'title': 'Kết luận', 'htmlContent': '<p>kết</p>'},
        ],
        '$tmpDir/t06_bookmarks_vi.pdf',
        bookmarks: true,
      );
      expect(countPages(path), 1);
      expect(String.fromCharCodes(File(path).readAsBytesSync()),
          contains('/Outlines'));
    });
  });

  group('dedicated notes pages', () {
    test('interleaves one extra page after every slide that has notes',
        () async {
      final path = await service.exportToPdf(
        [
          {
            'title': 'One',
            'htmlContent': '<p>a</p>',
            'notes': 'Nhắc nhở cho slide một.',
          },
          {'title': 'Two', 'htmlContent': '<p>b</p>'},
          {
            'title': 'Three',
            'htmlContent': '<p>c</p>',
            'notes': 'Nhắc nhở cho slide ba.',
          },
        ],
        '$tmpDir/t06_notes_pages.pdf',
        notesPages: true,
      );
      expect(countPages(path), 5,
          reason: 'S1, N1, S2, S3, N3 — every slide keeps its own page');
    });

    test('slides without notes gain nothing', () async {
      final path = await service.exportToPdf(
        [
          {'title': 'Only', 'htmlContent': '<p>solo</p>'},
        ],
        '$tmpDir/t06_notes_pages_empty.pdf',
        notesPages: true,
      );
      expect(countPages(path), 1);
    });

    test('works together with bookmarks (page indices stay aligned)',
        () async {
      final path = await service.exportToPdf(
        [
          {
            'title': 'With notes',
            'htmlContent': '<p>x</p>',
            'notes': 'note line',
          },
          {'title': 'Without', 'htmlContent': '<p>y</p>'},
        ],
        '$tmpDir/t06_both.pdf',
        notesPages: true,
        bookmarks: true,
      );
      expect(countPages(path), 3);
      final content = String.fromCharCodes(File(path).readAsBytesSync());
      expect(content, contains('1. With notes'));
      expect(content, contains('2. Without'),
          reason: 'bookmark #2 must point at the second SLIDE page, '
              'not the interleaved notes page');
    });

    test('inline speaker notes behaviour is untouched', () async {
      final path = await service.exportToPdf(
        [
          {
            'title': 'Inline',
            'htmlContent': '<p>body</p>',
            'notes': 'inline note',
          },
        ],
        '$tmpDir/t06_inline_unchanged.pdf',
        includeNotes: true,
      );
      expect(countPages(path), 1);
    });
  });

  group('50-slide benchmark smoke', () {
    test('exports fifty simple slides well under a minute', () async {
      final slides = [
        for (var i = 1; i <= 50; i++)
          {
            'title': 'Slide $i',
            'htmlContent': '<h1>Mục $i</h1><p>Nội dung ngắn gọn cho slide $i.</p>',
          },
      ];
      final watch = Stopwatch()..start();
      final path = await service.exportToPdf(slides, '$tmpDir/t06_bench.pdf');
      watch.stop();

      expect(countPages(path), 50);
      expect(watch.elapsed, lessThan(const Duration(seconds: 60)),
          reason: 'benchmark drifted: 50 slides took ${watch.elapsed}');
      File(path).deleteSync();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
