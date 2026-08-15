import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/media_item.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:ghita_ppt_converter/services/video_embed_service.dart';
import 'package:xml/xml.dart' as xml;

/// Track 11 tests — Video nhúng & chỉnh (FEAT 5, 6, 76).
///
///  * model round-trip + YouTube id parsing (P7),
///  * PPTX `<p:pic>` media shape: mp4 under ppt/media/, `video`+`media`+
///    image rels, autoplay/loop p:timing, poster, dedupe, online rel (P1–P3),
///  * HTML deck: `ghitaVideos` map, slim data-video JSON, player JS with
///    trim/bookmarks/options (P4, P6, P8),
///  * PDF draws the poster (P5),
///  * empty videos are skipped + decks without video stay unchanged (P10).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A tiny fake mp4 payload — the exporters package bytes as-is (real mp4
  // verification happens against PowerPoint itself, see CHANGELOG P8).
  // Valid base64 of 12 zero/sequence bytes (16 chars → no padding issues).
  const kFakeMp4Base64 = 'AAAAAAECAwQFBgcI';
  String videoSrcDataUri() => 'data:video/mp4;base64,$kFakeMp4Base64';

  String videoTag(VideoData video) =>
      '<video src="${video.src}"${video.poster.isNotEmpty ? ' poster="${video.poster}"' : ''} '
      'controls data-video=\'${video.toJson().replaceAll("'", '&#39;')}\'></video>';

  Future<Archive> exportPptx(String htmlContent) async {
    final dir = await Directory.systemTemp.createTemp('ghita_t11_');
    try {
      await PPTGenerator.generatePPT(
        [
          {'title': 'Video', 'htmlContent': htmlContent},
        ],
        '${dir.path}/out.pptx',
      );
      return ZipDecoder()
          .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
    } finally {
      await dir.delete(recursive: true);
    }
  }

  String part(Archive archive, String name) => utf8.decode(
      archive.files.firstWhere((e) => e.name == name).content as List<int>);

  group('model + service (P1, P7)', () {
    test('VideoData round-trips through JSON', () {
      final video = VideoData(
        src: videoSrcDataUri(),
        poster: 'data:image/jpeg;base64,abc',
        trimStart: 1.5,
        trimEnd: 8,
        autoplay: true,
        loop: true,
        durationMs: 12000,
        bookmarks: const [
          VideoBookmark(time: 2, label: 'Mở đầu'),
          VideoBookmark(time: 6.5, label: 'Kết'),
        ],
      );
      final restored = VideoData.fromJson(video.toJson());
      expect(restored.src, video.src);
      expect(restored.poster, video.poster);
      expect(restored.trimStart, 1.5);
      expect(restored.trimEnd, 8);
      expect(restored.autoplay, isTrue);
      expect(restored.loop, isTrue);
      expect(restored.durationMs, 12000);
      expect(restored.bookmarks.length, 2);
      expect(restored.bookmarks.last.label, 'Kết');
    });

    test('parseYouTubeId handles the common URL shapes', () {
      expect(
        VideoEmbedService.parseYouTubeId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        VideoEmbedService.parseYouTubeId(
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=3'),
        'dQw4w9WgXcQ',
      );
      expect(
        VideoEmbedService.parseYouTubeId(
            'https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        VideoEmbedService.parseYouTubeId(
            'https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(VideoEmbedService.parseYouTubeId('https://example.com/x'),
          isNull);
    });

    test('videosIn / videoMarkup / replaceVideoAt', () {
      final a = VideoData(src: videoSrcDataUri());
      const b = VideoData(
          youtubeId: 'dQw4w9WgXcQ', poster: 'data:image/jpeg;base64,xyz');
      final html = '${videoTag(a)}<p>x</p>${videoTag(b)}';
      final found = VideoEmbedService.videosIn(html);
      expect(found.length, 2);
      expect(found[0].src, videoSrcDataUri());
      expect(found[1].isOnline, isTrue);

      final replaced = VideoEmbedService.replaceVideoAt(
          html, 0, a.copyWith(loop: true));
      expect(VideoEmbedService.videosIn(replaced).length, 2);
      expect(VideoEmbedService.videosIn(replaced)[0].loop, isTrue);
      // Out of range is a no-op.
      expect(VideoEmbedService.replaceVideoAt(html, 5, a), html);
    });
  });

  group('PPTX <p:pic> media package (P1–P3, P7)', () {
    test('video becomes a media pic with rels + content types', () async {
      final archive = await exportPptx(
          '<h2>Phụ đề</h2>${videoTag(VideoData(src: videoSrcDataUri()))}');
      expect(
        archive.files.any((e) => e.name == 'ppt/media/video1.mp4'),
        isTrue,
        reason: 'mp4 embedded under ppt/media/',
      );
      final ct = part(archive, '[Content_Types].xml');
      expect(
        ct,
        contains('Extension="mp4" ContentType="video/mp4"'),
        reason: 'Default mp4 present',
      );
      // Defaults must precede every Override (PowerPoint rejects otherwise).
      expect(ct.indexOf('<Default'), lessThan(ct.indexOf('<Override')));

      final rels = part(archive, 'ppt/slides/_rels/slide1.xml.rels');
      expect(rels, contains('relationships/video'));
      expect(rels, contains('Target="../media/video1.mp4"'));
      expect(rels, contains('relationships/media'));
      expect(rels, contains('relationships/image'));

      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect(() => xml.XmlDocument.parse(slide), returnsNormally);
      expect(slide, contains('<a:videoFile'));
      expect(slide, contains('ppaction://media'));
      expect(slide, contains('<p:blipFill>'));
    });

    test('autoplay + loop emit the media timeline', () async {
      final archive = await exportPptx(
          '<h2>Phụ đề</h2>${videoTag(VideoData(src: videoSrcDataUri(), autoplay: true, loop: true, durationMs: 3000))}');
      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect(slide, contains('<p:timing>'));
      expect(slide, contains('cmd="playFrom(0.0)"'));
      expect(slide, contains('dur="3000"'));
      expect(slide, contains('repeatCount="indefinite"'));
      expect(slide, contains('nodeType="mainSeq"'));
    });

    test('on-click video gets the interactive sequence', () async {
      final archive = await exportPptx(
          '<h2>Phụ đề</h2>${videoTag(VideoData(src: videoSrcDataUri()))}');
      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect(slide, contains('nodeType="interactiveSeq"'));
      expect(slide, contains('cmd="togglePause"'));
      expect(slide, isNot(contains('playFrom(0.0)')));
    });

    test('identical videos share one media part (dedupe)', () async {
      final archive = await exportPptx(
          '${videoTag(VideoData(src: videoSrcDataUri()))}'
          '<p>x</p>${videoTag(VideoData(src: videoSrcDataUri()))}');
      final mediaParts = archive.files
          .where((e) => e.name.startsWith('ppt/media/video'))
          .toList();
      expect(mediaParts.length, 1, reason: 'one mp4 part for two tags');
      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect('<p:pic>'.allMatches(slide).length, 2);
    });

    test('YouTube video becomes an external video rel', () async {
      final archive = await exportPptx(
          '<h2>Phụ đề</h2>${videoTag(const VideoData(youtubeId: 'dQw4w9WgXcQ'))}');
      final rels = part(archive, 'ppt/slides/_rels/slide1.xml.rels');
      expect(rels, contains('relationships/video'));
      expect(rels, contains('Target="https://www.youtube.com/watch?v=dQw4w9WgXcQ"'));
      expect(rels, contains('TargetMode="External"'));
    });

    test('videos without payload are skipped; no-video decks unchanged',
        () async {
      final archive = await exportPptx(
          '<p>ok</p>${videoTag(const VideoData())}');
      expect(
        archive.files.any((e) => e.name.startsWith('ppt/media/video')),
        isFalse,
      );
      final plain = await exportPptx('<p>không có video</p>');
      expect(part(plain, '[Content_Types].xml'), isNot(contains('mp4')));
      expect(part(plain, 'ppt/slides/slide1.xml'), isNot(contains('videoFile')));
    });
  });

  group('HTML deck playback (P4, P6, P8)', () {
    test('payload hoisted to ghitaVideos with slim inline JSON', () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t11_html_');
      try {
        final path = await HtmlExportService().exportToHtmlPath(
          [
            {
              'title': 'Video',
              'htmlContent':
                  '<h2>Phụ đề</h2>${videoTag(VideoData(src: videoSrcDataUri(), trimStart: 1, trimEnd: 4, loop: true, bookmarks: const [VideoBookmark(time: 2, label: 'Giữa')]))}',
            },
          ],
          '${dir.path}/deck.html',
        );
        final html = File(path).readAsStringSync();
        expect(html, contains('const ghitaVideos = {'));
        expect(html, contains('"v0":"data:video/mp4;base64,$kFakeMp4Base64"'));
        // The tag carries a data-src id and preload="none", not the payload.
        expect(html, contains('data-src="v0"'));
        expect(html, contains('preload="none"'));
        // The inline data-video JSON keeps playback metadata (trim/bookmarks)
        // but not the megabyte payload (attribute is HTML-escaped).
        final tagStart = html.indexOf('<video');
        final tag = html.substring(tagStart, tagStart + 600);
        expect(tag, contains('&quot;trimStart&quot;:1.0'));
        expect(tag, contains('&quot;bookmarks&quot;'));
        expect(tag, isNot(contains(kFakeMp4Base64)));
        // Player JS: setupVideo + trim + bookmarks + YouTube transform —
        // asserted AFTER minification so the deck's script stays intact.
        expect(html, contains('function setupVideo'));
        expect(html, contains('opts.trimStart'));
        expect(html, contains('ghita-video-bookmarks'));
        expect(html, contains('opts.youtubeId'));
        expect(html, contains('vd.pause()'));
        expect(html, contains('fmtTime'));
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('PDF poster (P4–P5)', () {
    test('PDF export renders a slide with a video poster', () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t11_pdf_');
      try {
        final out = '${dir.path}/out.pdf';
        await PdfExportService().exportToPdf(
          [
            {
              'title': 'Video',
              'htmlContent':
                  '<h2>Phụ đề</h2>${videoTag(VideoData(src: videoSrcDataUri(), poster: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAACXBIWXMAAAABAAAAAQBPJcTWAAAADElEQVR4nGNkYGAAAAAIAAI76MGHAAAAAElFTkSuQmCC'))}',
            },
          ],
          out,
        );
        final bytes = File(out).readAsBytesSync();
        expect(bytes.length, greaterThan(500), reason: 'a PDF was produced');
        expect(String.fromCharCodes(bytes.take(5).toList()), '%PDF-');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('editor sanitizer (P7)', () {
    test('video tags pass through the HTML sanitizer', () {
      // The sanitizer strips script/iframe/object/embed; <video> survives so
      // the editor preview can play the embedded payload.
      final raw = '<p>x</p>${videoTag(VideoData(src: videoSrcDataUri()))}';
      final sanitized = raw
          .replaceAll(RegExp(r'<script[\s\S]*?<\/script>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<iframe[\s\S]*?<\/iframe>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<object[\s\S]*?<\/object>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<embed[\s\S]*?\/>', caseSensitive: false), '');
      expect(sanitized, contains('<video'));
    });
  });
}
