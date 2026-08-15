import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/export_job.dart';
import 'package:ghita_ppt_converter/services/export_primitives.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';

/// Track 01 tests (phase 8): the standardized [ExportJob] contract.
///
///  * progress must be monotonic and cover every slide (plus a 1.0 done),
///  * a mid-run cancellation stops the export and leaves no output file,
///  * the session parse cache tokenizes each unique slide content once and
///    serves identical trees to the PPTX and PDF pipelines,
///  * the optimized ZIP encoder stores already-compressed media and deflates
///    text parts at the highest level.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Map<String, dynamic>> deck(int count, {int unique = 2}) =>
      List<Map<String, dynamic>>.generate(count, (i) {
        final n = i % unique;
        return {
          'title': 'Slide ${i + 1}',
          'htmlContent': '<h2>Phụ đề $n</h2><p>Nội dung $n</p>'
              '<ul><li>Mục $n</li></ul>'
              '<aside class="notes">Ghi chú $n.</aside>',
        };
      });

  Future<Directory> tempDir() =>
      Directory.systemTemp.createTemp('ghita_job_');

  test('ExportJob reports monotonic progress covering every slide', () async {
    final dir = await tempDir();
    final progress = <ExportProgress>[];
    try {
      final job = ExportJob(
        slides: deck(8),
        outputPath: '${dir.path}/out.pptx',
        format: ExportJobFormat.pptx,
        onProgress: progress.add,
      );
      final path = await job.run();
      expect(path, '${dir.path}/out.pptx');
      expect(File(path).existsSync(), isTrue);

      expect(progress, isNotEmpty);
      // Monotonic: never a decrease, last report is 100%.
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i].fraction, greaterThanOrEqualTo(progress[i - 1].fraction));
      }
      expect(progress.last.fraction, 1.0);
      expect(progress.last.stage, 'done');
      // Every slide was reported exactly once during the 'slides' stage.
      final slideStages =
          progress.where((p) => p.stage == 'slides').toList();
      expect(slideStages.length, 8);
      for (var i = 0; i < 8; i++) {
        expect(slideStages[i].slideIndex, i);
        expect(slideStages[i].slideCount, 8);
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('cancel mid-way stops the export and leaves no output file', () async {
    final dir = await tempDir();
    try {
      final token = ExportCancelToken();
      final job = ExportJob(
        slides: deck(12),
        outputPath: '${dir.path}/out.pptx',
        format: ExportJobFormat.pptx,
        cancelToken: token,
        onProgress: (p) {
          if (p.slideIndex == 4) token.cancel();
        },
      );
      await expectLater(job.run(), throwsA(isA<ExportCancelledException>()));
      expect(token.isCancelled, isTrue);
      expect(File('${dir.path}/out.pptx').existsSync(), isFalse);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('cache tokenizes each unique slide content exactly once', () {
    const html = '<h2>Phụ đề</h2><p>Thân bài</p>'
        '<aside class="notes">Ghi chú diễn giả.</aside>';
    final cache = HtmlParseCache();

    final blocks = cache.blocksFor(html);
    expect(cache.misses, 1);
    // All consumers of the same content share the single tokenization:
    // notes, subtitle, canonical blocks and the PPTX drop-first-h2 variant.
    expect(cache.notesFor(html), 'Ghi chú diễn giả.');
    expect(cache.subtitleFor(html), 'Phụ đề');
    expect(cache.blocksFor(html), same(blocks));
    final pptBlocks = cache.blocksFor(html, dropFirstH2: true);
    expect(cache.misses, 1, reason: 'every artifact came from one parse');
    expect(cache.hits, greaterThanOrEqualTo(4));

    // The drop-h2 variant removed the subtitle from the body tree only.
    bool containsText(List<Map<String, dynamic>> b, String t) => b.any((blk) {
          final runs = (blk['type'] == 'list'
              ? blk['items']
              : blk['paragraphs']) as List?;
          return runs != null &&
              runs.any((r) => (r['text'] ?? '').contains(t));
        });
    expect(containsText(blocks, 'Phụ đề'), isTrue);
    expect(containsText(pptBlocks, 'Phụ đề'), isFalse);
    expect(containsText(pptBlocks, 'Thân bài'), isTrue);
  });

  test('cache serves PPTX and PDF pipelines the same shared blocks', () async {
    final dir = await tempDir();
    final cache = HtmlParseCache();
    try {
      final pptx = ExportJob(
        slides: deck(2),
        outputPath: '${dir.path}/a.pptx',
        format: ExportJobFormat.pptx,
        parseCache: cache,
      );
      await pptx.run();
      final pdf = ExportJob(
        slides: deck(2),
        outputPath: '${dir.path}/a.pdf',
        format: ExportJobFormat.pdf,
        parseCache: cache,
      );
      await pdf.run();
      // The PDF run reused the parses the PPTX run performed.
      expect(cache.misses, 2); // exactly the two unique contents
      expect(cache.hits, greaterThan(0));
      expect(File('${dir.path}/a.pdf').lengthSync(), greaterThan(0));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('ZIP: media entries stored, text entries deflated at level 9', () async {
    final dir = await tempDir();
    try {
      // 1x1 PNG — tiny but already-compressed payload for the media entry.
      const pngBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
          'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final slide = {
        'title': 'Ảnh',
        'htmlContent':
            '<p>Văn bản</p><img src="data:image/png;base64,$pngBase64"/>',
      };
      PPTGenerator.debugZipLevel = Deflate.BEST_COMPRESSION;
      PPTGenerator.debugStoreCompressedMedia = true;
      final job = ExportJob(
        slides: [slide],
        outputPath: '${dir.path}/out.pptx',
        format: ExportJobFormat.pptx,
      );
      await job.run();

      final archive = ZipDecoder().decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
      final media = archive.files.firstWhere((e) => e.name.startsWith('ppt/media/'));
      final text = archive.files.firstWhere((e) => e.name == 'ppt/slides/slide1.xml');
      expect(media.compressionType, ArchiveFile.STORE,
          reason: 'already-compressed media must be stored, not re-deflated');
      expect(text.compressionType, ArchiveFile.DEFLATE);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}