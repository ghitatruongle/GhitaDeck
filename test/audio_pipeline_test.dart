import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';
import 'package:ghita_ppt_converter/services/project_bundle_service.dart';
import 'package:ghita_ppt_converter/config/build_info.dart';
import 'package:xml/xml.dart' as xml;

/// Track 13 tests — Audio & Narration gắn slide (FEAT 8, 9 + OPT 31).
///
///  * Slide audio fields round-trip + backward compatibility (P3),
///  * PPTX `<p:audio>`: media part + Default m4a + audio rel + speaker icon
///    + timing (autoplay/loop/on-stop) (P4),
///  * HTML deck: ghitaAudios map + <audio> tag + hide-icon + across-slides
///    exception (P5–P6),
///  * bundle save/load carries the narration under media/ (P8),
///  * decks without audio stay unchanged (P10).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fake m4a payload — the exporters package bytes as-is (real audio
  // verification happens against PowerPoint/Chrome, see CHANGELOG P10).
  final fakeAudioBytes = List<int>.generate(64, (i) => i);

  late Directory tmpDir;
  late String fakeAudioPath;
  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('ghita_t13_');
    fakeAudioPath = '${tmpDir.path}/narration.m4a';
    await File(fakeAudioPath).writeAsBytes(fakeAudioBytes);
  });
  tearDown(() async {
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<Archive> exportPptx(Slide slide) async {
    await PPTGenerator.generatePPT(
      [slide.toMap()],
      '${tmpDir.path}/out.pptx',
    );
    return ZipDecoder()
        .decodeBytes(File('${tmpDir.path}/out.pptx').readAsBytesSync());
  }

  String part(Archive archive, String name) => utf8.decode(
      archive.files.firstWhere((e) => e.name == name).content as List<int>);

  Slide slideWithAudio({
    bool autoplay = false,
    bool loop = false,
    bool acrossSlides = false,
    int durationMs = 2000,
  }) =>
      Slide(
        title: 'Narration',
        htmlContent: '<p>Nội dung</p>',
        audioPath: fakeAudioPath,
        audioEmbedded: true,
        audioOptions: {
          'durationMs': durationMs,
          if (autoplay) 'autoplay': true,
          if (loop) 'loop': true,
          if (acrossSlides) 'acrossSlides': true,
        },
      );

  group('Slide model (P3)', () {
    test('audio fields round-trip through toMap/fromMap', () {
      final slide = slideWithAudio(autoplay: true, loop: true);
      final restored = Slide.fromMap(slide.toMap());
      expect(restored.audioPath, fakeAudioPath);
      expect(restored.audioEmbedded, isTrue);
      expect(restored.audioOptions['autoplay'], isTrue);
      expect(restored.audioOptions['loop'], isTrue);
      expect(restored.audioOptions['durationMs'], 2000);
    });

    test('old maps without audio fields stay backward compatible', () {
      final restored = Slide.fromMap({
        'title': 'Cũ',
        'htmlContent': '<p>x</p>',
        'timestamp': 1,
      });
      expect(restored.audioPath, isEmpty);
      expect(restored.audioEmbedded, isFalse);
      expect(restored.audioOptions, isEmpty);
    });

    test('copyWith(clearAudio: true) removes narration', () {
      final cleared = slideWithAudio().copyWith(clearAudio: true);
      expect(cleared.audioPath, isEmpty);
      expect(cleared.audioOptions, isEmpty);
    });
  });

  group('PPTX <p:audio> package (P4)', () {
    test('audio becomes a pic with audio rel + speaker icon + timing',
        () async {
      final archive = await exportPptx(slideWithAudio());
      expect(
        archive.files.any((e) => e.name == 'ppt/media/audio1.m4a'),
        isTrue,
        reason: 'm4a embedded under ppt/media/',
      );
      expect(
        archive.files.any((e) =>
            e.name.startsWith('ppt/media/image') && e.name.endsWith('.png')),
        isTrue,
        reason: 'speaker icon embedded',
      );
      final ct = part(archive, '[Content_Types].xml');
      expect(ct, contains('Extension="m4a" ContentType="audio/mp4"'));
      // Defaults precede every Override.
      expect(ct.indexOf('<Default'), lessThan(ct.indexOf('<Override')));

      final rels = part(archive, 'ppt/slides/_rels/slide1.xml.rels');
      expect(rels, contains('relationships/audio'));
      expect(rels, contains('Target="../media/audio1.m4a"'));

      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect(() => xml.XmlDocument.parse(slide), returnsNormally);
      expect(slide, contains('<a:audioFile'));
      expect(slide, contains('ppaction://media'));
      expect(slide, contains('<p:audio>'));
    });

    test('autoplay + loop + acrossSlides shape the timing', () async {
      final archive = await exportPptx(
          slideWithAudio(autoplay: true, loop: true, acrossSlides: true));
      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect(slide, contains('cmd="playFrom(0.0)"'));
      expect(slide, contains('dur="2000"'));
      expect(slide, contains('repeatCount="indefinite"'));
      // Across slides: no onStopAudio end condition.
      expect(slide, isNot(contains('onStopAudio')));
    });

    test('default audio stops on slide change (onStopAudio end condition)',
        () async {
      final archive = await exportPptx(slideWithAudio());
      final slide = part(archive, 'ppt/slides/slide1.xml');
      expect(slide, contains('evt="onStopAudio"'));
      // On-click audio still uses PowerPoint's playFrom media call (golden).
      expect(slide, contains('playFrom(0.0)'));
      expect(slide, isNot(contains('togglePause')));
    });

    test('deck without audio stays unchanged', () async {
      final archive =
          await exportPptx(Slide(title: 'x', htmlContent: '<p>ok</p>'));
      expect(part(archive, '[Content_Types].xml'), isNot(contains('m4a')));
      expect(
        part(archive, 'ppt/slides/slide1.xml'),
        isNot(contains('audioFile')),
      );
    });
  });

  group('HTML deck audio (P5–P6)', () {
    test('narration becomes an <audio> tag with hoisted payload', () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t13_html_');
      try {
        final slide =
            slideWithAudio(loop: true, acrossSlides: true, autoplay: true);
        final path = await HtmlExportService().exportToHtmlPath(
          [slide.toMap()],
          '${dir.path}/deck.html',
        );
        final html = File(path).readAsStringSync();
        expect(html, contains('const ghitaAudios = {'));
        expect(html, contains('"a0":"data:audio/mp4;base64'));
        // Tag carries a data-src id, options and flags; not the payload.
        final tagStart = html.indexOf('<audio');
        final tag = html.substring(tagStart, tagStart + 400);
        expect(tag, contains('data-src="a0"'));
        expect(tag, contains('data-across="1"'));
        expect(tag, contains('preload="none"'));
        expect(tag, isNot(contains(base64Encode(fakeAudioBytes))));
        // Player JS: injection + options + across-slides pause exception.
        expect(html, contains('function setupAudio'));
        expect(html, contains('ghitaAudios[a.dataset.src]'));
        expect(html, contains('a.dataset.across !== "1"'));
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('hide-icon audio drops controls and gets a toggle button JS',
        () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t13_html2_');
      try {
        final slide =
            slideWithAudio().copyWith(audioOptions: const {'hideIcon': true});
        final path = await HtmlExportService().exportToHtmlPath(
          [slide.toMap()],
          '${dir.path}/deck.html',
        );
        final html = File(path).readAsStringSync();
        final tagStart = html.indexOf('<audio');
        final tag = html.substring(tagStart, tagStart + 300);
        expect(tag, contains('data-hideicon="1"'));
        expect(html, contains('ghita-audio-toggle'));
        expect(html, contains('el.removeAttribute("controls")'));
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('project bundle media/ (P8)', () {
    test('narration travels inside the bundle and is rehydrated on load',
        () async {
      final bundlePath = '${tmpDir.path}/proj.ghita';
      final service = ProjectBundleService();
      final ok = await service.saveProjectBundle(
        targetPath: bundlePath,
        slides: [slideWithAudio()],
        title: 'Audio project',
        mediaFiles: [
          MapEntry('narration.m4a', Uint8List.fromList(fakeAudioBytes))
        ],
      );
      expect(ok, isTrue);

      // The bundle must be self-contained: slides reference media/….
      final bytes = File(bundlePath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.files.any((e) => e.name == 'media/narration.m4a'), isTrue);
      final slidesJson = utf8.decode(archive.files
          .firstWhere((e) => e.name == 'slides.json')
          .content as List<int>);
      expect(slidesJson, contains('"audioPath":"media/narration.m4a"'));
      expect(slidesJson, contains('"audioEmbedded":true'));

      // Load on "another machine": media extracted + path rewritten.
      final loaded = await service.loadProjectBundle(
        bundlePath,
        extractDir: '${tmpDir.path}/extract',
      );
      expect(loaded, isNotNull);
      final slides = (loaded!['slides'] as List).cast<Slide>();
      expect(slides.single.audioPath, isNot(contains('media/')));
      expect(File(slides.single.audioPath).existsSync(), isTrue);
      expect(slides.single.audioEmbedded, isTrue);
      expect(
        File(slides.single.audioPath).readAsBytesSync(),
        fakeAudioBytes,
      );
    });

    test('atomic overwrite leaves a valid latest bundle and no temp files',
        () async {
      final bundlePath = '${tmpDir.path}/atomic.ghita';
      final service = ProjectBundleService();
      expect(
        await service.saveProjectBundle(
          targetPath: bundlePath,
          slides: [Slide(title: 'A', htmlContent: '<h1>A</h1>')],
          title: 'First',
        ),
        isTrue,
      );
      expect(
        await service.saveProjectBundle(
          targetPath: bundlePath,
          slides: [Slide(title: 'B', htmlContent: '<h1>B</h1>')],
          title: 'Second',
        ),
        isTrue,
      );
      final loaded = await service.loadProjectBundle(
        bundlePath,
        extractDir: '${tmpDir.path}/atomic_extract',
      );
      expect(loaded?['manifest']['title'], 'Second');
      final leftovers = tmpDir.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.tmp') || file.path.endsWith('.bak'));
      expect(leftovers, isEmpty);
    });

    test('load sanitizes embedded HTML and protects manifest version',
        () async {
      final path = '${tmpDir.path}/sanitized.ghita';
      final service = ProjectBundleService();
      expect(
        await service.saveProjectBundle(
          targetPath: path,
          slides: [
            Slide(
              title: 'Unsafe',
              htmlContent:
                  '<h1 onclick=alert(1)>Safe</h1><script>alert(2)</script>',
            ),
          ],
          extraManifest: const {'version': 'attacker-controlled'},
        ),
        isTrue,
      );
      final loaded = await service.loadProjectBundle(
        path,
        extractDir: '${tmpDir.path}/sanitize_extract',
      );
      expect(loaded?['manifest']['version'], BuildInfo.appVersion);
      final slide = (loaded?['slides'] as List<Slide>).single;
      expect(slide.htmlContent.toLowerCase(), isNot(contains('<script')));
      expect(slide.htmlContent.toLowerCase(), isNot(contains('onclick')));
    });

    test('save and load reject unsafe embedded media paths', () async {
      final service = ProjectBundleService();
      expect(
        await service.saveProjectBundle(
          targetPath: '${tmpDir.path}/unsafe-save.ghita',
          slides: [Slide(title: 'A', htmlContent: '<p>A</p>')],
          mediaFiles: [
            MapEntry('../escape.mp3', Uint8List.fromList(fakeAudioBytes)),
          ],
        ),
        isFalse,
      );

      final archive = Archive()
        ..addFile(ArchiveFile(
          'slides.json',
          2,
          utf8.encode('[]'),
        ))
        ..addFile(ArchiveFile(
          'media/../escape.mp3',
          fakeAudioBytes.length,
          fakeAudioBytes,
        ));
      final maliciousPath = '${tmpDir.path}/unsafe-load.ghita';
      File(maliciousPath).writeAsBytesSync(ZipEncoder().encode(archive)!);
      expect(
        await service.loadProjectBundle(
          maliciousPath,
          extractDir: '${tmpDir.path}/unsafe_extract',
        ),
        isNull,
      );
      expect(File('${tmpDir.path}/escape.mp3').existsSync(), isFalse);
    });
  });
}
