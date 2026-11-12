import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ghita_deck/models/media_item.dart';
import 'package:ghita_deck/services/addin_service.dart';
import 'package:ghita_deck/services/html_image_loader.dart';
import 'package:ghita_deck/services/image_optimizer_service.dart';
import 'package:ghita_deck/services/local_image_allowlist.dart';
import 'package:ghita_deck/services/video_embed_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List imgEncodePng(int w, int h) {
  final image = img.Image(width: w, height: h);
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/path_provider');
  final List<MethodCall> log = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    log.add(call);
    if (call.method == 'getApplicationSupportDirectory' ||
        call.method == 'getApplicationDocumentsDirectory') {
      return Directory.systemTemp.path;
    }
    if (call.method == 'getTemporaryDirectory') {
      return Directory.systemTemp.path;
    }
    return null;
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('AddinService load/install/uninstall', () {
    late Directory addinsDir;

    setUp(() async {
      addinsDir = await Directory.systemTemp.createTemp('ghita_cov_addins_');
      AddinService.addinsDirOverride = () async => addinsDir;
      SharedPreferences.setMockInitialValues({});
      addTearDown(() async {
        AddinService.addinsDirOverride = null;
        if (await addinsDir.exists()) await addinsDir.delete(recursive: true);
      });
    });

    test('loadAddins returns valid json and addin files and marks enabled',
        () async {
      SharedPreferences.setMockInitialValues({
        'addins_enabled': ['enabled_one']
      });
      await File('${addinsDir.path}/enabled_one.addin')
          .writeAsString(jsonEncode({
        'id': 'enabled_one',
        'name': 'Enabled One',
        'version': '1.2',
        'description': 'On',
        'handler': 'transform',
        'code': 'upper',
      }));
      await File('${addinsDir.path}/other.json').writeAsString(jsonEncode({
        'id': 'other',
        'name': 'Other',
        'handler': 'kpi',
        'code': '',
      }));
      await File('${addinsDir.path}/skip.txt').writeAsString('ignore-me');
      await File('${addinsDir.path}/bad.json').writeAsString('not-json');
      await File('${addinsDir.path}/remote.json').writeAsString(jsonEncode({
        'id': 'remote_one',
        'name': 'Remote',
        'handler': 'transform',
        'code': 'upper',
        'source': 'https://example.com/addin.json',
      }));

      final list = await AddinService.loadAddins();
      expect(list.map((e) => e.id), containsAll(['enabled_one', 'other']));
      expect(list.any((e) => e.id == 'remote_one'), isFalse);
      expect(
        list.firstWhere((e) => e.id == 'enabled_one').enabled,
        isTrue,
      );
      expect(list.firstWhere((e) => e.id == 'other').enabled, isFalse);
    });

    test('loadAddins skips oversized manifest and invalid manifest', () async {
      await File('${addinsDir.path}/big.addin')
          .writeAsString('x' * (256 * 1024 + 1));
      await File('${addinsDir.path}/invalid.json').writeAsString(jsonEncode({
        'id': 'bad id!',
        'name': 'Bad',
        'handler': 'transform',
        'code': '',
      }));
      final list = await AddinService.loadAddins();
      expect(list, isEmpty);
    });

    test('loadAddins tolerates missing directory', () async {
      AddinService.addinsDirOverride = () async {
        throw Exception('no dir');
      };
      final list = await AddinService.loadAddins();
      expect(list, isEmpty);
    });

    test('setEnabled toggles persistence and ignores unsafe ids', () async {
      SharedPreferences.setMockInitialValues({
        'addins_enabled': ['keep']
      });
      await AddinService.setEnabled('keep', false);
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('addins_enabled'), isNot(contains('keep')));

      await AddinService.setEnabled('new_one', true);
      await AddinService.setEnabled('new_one', true);
      prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('addins_enabled')!;
      expect(list.where((e) => e == 'new_one').length, 1);

      await AddinService.setEnabled('../escape', true);
      await AddinService.setEnabled('.', true);
      await AddinService.setEnabled('..', true);
      prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getStringList('addins_enabled'), isNot(contains('../escape')));
    });

    test('installFromJson validates size and handler', () async {
      final ok = await AddinService.installFromJson(jsonEncode({
        'id': 'ok_addin',
        'name': 'OK',
        'handler': 'append_title',
        'code': ' v2',
        'version': '2.0',
        'description': 'd',
      }));
      expect(ok?.id, 'ok_addin');
      expect(ok?.name, 'OK');
      expect(ok?.version, '2.0');

      expect(
          await AddinService.installFromJson(jsonEncode({
            'id': 'bad_id!',
            'name': 'x',
            'handler': 'transform',
            'code': '',
          })),
          isNull);
      expect(
          await AddinService.installFromJson(jsonEncode({
            'id': 'x1',
            'name': 'x',
            'handler': 'unknown_handler',
            'code': '',
          })),
          isNull);
      expect(
          await AddinService.installFromJson(jsonEncode({
            'id': 'x2',
            'name': '',
            'handler': 'transform',
            'code': '',
          })),
          isNull);
      expect(
          await AddinService.installFromJson(jsonEncode({
            'id': 'x3',
            'name': 'x',
            'handler': 'transform',
            'source': 'ftp://example.com/x',
          })),
          isNull);
      expect(await AddinService.installFromJson('not json'), isNull);
      expect(
          await AddinService.installFromJson('a' * (256 * 1024 + 1)), isNull);
      expect(
        await AddinService.installFromJson(jsonEncode({
          'id': 'long',
          'name': 'n' * 129,
          'handler': 'transform',
          'code': '',
        })),
        isNull,
      );
      expect(
        await AddinService.installFromJson(jsonEncode({
          'id': 'longcode',
          'name': 'n',
          'handler': 'transform',
          'code': 'x' * (64 * 1024 + 1),
        })),
        isNull,
      );
    });

    test('uninstall deletes file and disables', () async {
      SharedPreferences.setMockInitialValues({
        'addins_enabled': ['to_remove']
      });
      final file = File('${addinsDir.path}/to_remove.addin');
      await file.writeAsString('x');
      expect(await file.exists(), isTrue);
      await AddinService.uninstall('to_remove');
      expect(await file.exists(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getStringList('addins_enabled'), isNot(contains('to_remove')));

      await AddinService.uninstall('../escape');
      await AddinService.uninstall('missing_id');
    });

    test('AddinInfo defaults and toJson', () {
      final info = AddinInfo.fromJson({'id': 'a1'});
      expect(info.name, 'Add-in');
      expect(info.version, '1.0');
      expect(info.description, '');
      expect(info.handler, 'transform');
      expect(info.code, '');
      final map = info.toJson();
      expect(map['id'], 'a1');
      expect(map.keys, containsAll(['name', 'version', 'handler', 'code']));

      final enabled = AddinInfo.fromJson(
        {
          'id': 'a2',
          'name': 'N',
          'version': '3',
          'description': 'd',
          'handler': 'kpi',
          'code': 'c'
        },
        enabled: true,
      );
      expect(enabled.enabled, isTrue);
      expect(enabled.isNew, isFalse);
      expect(enabled.lastError, isNull);
    });

    test('transform handler lower and invalid mode', () {
      const addin = AddinInfo(
        id: 't',
        name: 'T',
        version: '1',
        description: '',
        handler: 'transform',
        code: 'lower',
      );
      final lower = AddinService.runHandler(addin, [
        {
          'title': 'HELLO',
          'htmlContent': '<h1>Hello World</h1><p>MixedCase Text</p>',
        },
      ]);
      expect(lower.update.single['slide']['title'], 'hello');
      expect(
          lower.update.single['slide']['htmlContent'], contains('hello world'));
      expect(lower.update.single['slide']['htmlContent'],
          contains('mixedcase text'));

      const invalid = AddinInfo(
        id: 't2',
        name: 'T2',
        version: '1',
        description: '',
        handler: 'transform',
        code: 'rot13',
      );
      final r = AddinService.runHandler(invalid, [
        {'title': 'A', 'htmlContent': '<p>a</p>'},
      ]);
      expect(r.add, isEmpty);
      expect(r.update, isEmpty);
    });

    test('kpi handler with no numbers returns empty', () {
      const addin = AddinInfo(
        id: 'k',
        name: 'K',
        version: '1',
        description: '',
        handler: 'kpi',
        code: '',
      );
      final r = AddinService.runHandler(addin, [
        {'title': 'Intro', 'htmlContent': '<h1>Hello</h1><p>No digits</p>'},
      ]);
      expect(r.add, isEmpty);
      expect(r.update, isEmpty);
    });

    test('append_title default suffix when code empty', () {
      const addin = AddinInfo(
        id: 'a',
        name: 'A',
        version: '1',
        description: '',
        handler: 'append_title',
        code: '   ',
      );
      final r = AddinService.runHandler(addin, [
        {'title': 'Slide', 'htmlContent': '<p>x</p>'},
      ]);
      expect(r.update.single['slide']['title'], 'Slide — updated');
    });
  });

  group('VideoEmbedService pure helpers', () {
    test('youtubeWatchUrl and thumbnailDataUri', () {
      expect(
        VideoEmbedService.youtubeWatchUrl('abc123'),
        'https://www.youtube.com/watch?v=abc123',
      );
      expect(
        VideoEmbedService.thumbnailDataUri(Uint8List.fromList([1, 2, 3])),
        'data:image/jpeg;base64,AQID',
      );
    });

    test('escapeAttribute escapes single quotes', () {
      const v = VideoData(src: "it's", poster: '');
      expect(VideoEmbedService.escapeAttribute(v), contains('&#39;'));
      expect(VideoEmbedService.escapeAttribute(v), isNot(contains("'")));
    });

    test('videoMarkup omits empty src and poster', () {
      const v = VideoData(youtubeId: 'abc');
      final markup = VideoEmbedService.videoMarkup(v);
      expect(markup, startsWith('<video'));
      expect(markup, contains('controls'));
      expect(markup, contains('data-video='));
      expect(markup, isNot(contains(' src=')));
      expect(markup, isNot(contains(' poster=')));
      expect(markup, endsWith('></video>'));
    });

    test('videoMarkup includes src and poster escaped', () {
      const v = VideoData(
        src: 'data:video/mp4;base64,AAA"test',
        poster: 'data:image/png;base64,BBB<test>',
      );
      final markup = VideoEmbedService.videoMarkup(v);
      expect(markup, contains('&quot;'));
      expect(markup, contains('&lt;'));
    });

    test('videosIn skips empty payload and handles single quotes', () {
      const empty = VideoData();
      final htmlEmpty = "<video data-video='${empty.toJson()}'></video>";
      expect(VideoEmbedService.videosIn(htmlEmpty), isEmpty);

      const v = VideoData(src: 'data:video/mp4;base64,AAA');
      final htmlSingle = "<video data-video='${v.toJson()}'></video>";
      final found = VideoEmbedService.videosIn(htmlSingle);
      expect(found.length, 1);
      expect(found.single.src, v.src);
    });

    test('videoCount counts data-video occurrences', () {
      expect(VideoEmbedService.videoCount('<p>none</p>'), 0);
      const v = VideoData(src: 'x');
      final html = '<video data-video="${v.toJson()}"></video>'
          '<video data-video="${v.toJson()}"></video>';
      expect(VideoEmbedService.videoCount(html), 2);
    });

    test('replaceVideoAt negative and out of range', () {
      const v = VideoData(src: 'x');
      final html = '<video data-video="${v.toJson()}"></video>';
      expect(VideoEmbedService.replaceVideoAt(html, -1, v), html);
      expect(VideoEmbedService.replaceVideoAt('', 0, v), '');
      final replaced =
          VideoEmbedService.replaceVideoAt(html, 0, v.copyWith(loop: true));
      expect(VideoEmbedService.videosIn(replaced).single.loop, isTrue);
    });

    test('parseYouTubeId trims whitespace and handles watch with extra params',
        () {
      expect(
        VideoEmbedService.parseYouTubeId(
            ' https://www.youtube.com/watch?time_continue=5&v=XYZ123_45 '),
        'XYZ123_45',
      );
      expect(
        VideoEmbedService.parseYouTubeId('https://www.youtube.com/v/ABC-123_'),
        'ABC-123_',
      );
      expect(VideoEmbedService.parseYouTubeId(''), isNull);
      expect(VideoEmbedService.parseYouTubeId(' no url '), isNull);
    });

    test('trimToBytes rejects end <= start', () async {
      expect(await VideoEmbedService.trimToBytes('dummy.mp4', 5, 5), isNull);
      expect(await VideoEmbedService.trimToBytes('dummy.mp4', 10, 2), isNull);
    });

    test('ffmpeg helpers return null when ffmpeg unavailable', () async {
      await VideoEmbedService.ffmpegAvailable();
      await VideoEmbedService.probeDurationMs('nonexistent.mp4');
      await VideoEmbedService.extractFrameJpeg('nonexistent.mp4', at: 1);
    });

    test('fetchYouTubeThumbnail returns null on bad network', () async {
      final r = await VideoEmbedService.fetchYouTubeThumbnail('invalid_id_xxx');
      expect(r, isNull);
    });

    test('fallbackPosterDataUri is a data uri', () {
      expect(
        VideoEmbedService.fallbackPosterDataUri
            .startsWith('data:image/png;base64,'),
        isTrue,
      );
    });
  });

  group('VideoEmbedService PPTX XML builders', () {
    test('videoPicXml without mediaRid', () {
      final xml = VideoEmbedService.videoPicXml(
        shapeId: 2,
        name: 'Video 1',
        videoRid: 'rId10',
        posterRid: 'rId9',
        offX: 100,
        offY: 200,
        extCx: 300,
        extCy: 400,
      );
      expect(xml, contains('<p:pic>'));
      expect(xml, contains('id="2"'));
      expect(xml, contains('r:link="rId10"'));
      expect(xml, contains('r:embed="rId9"'));
      expect(xml, isNot(contains('p14:media')));
      expect(xml, contains('ppaction://media'));
    });

    test('videoPicXml with mediaRid', () {
      final xml = VideoEmbedService.videoPicXml(
        shapeId: 3,
        name: 'V',
        videoRid: 'rId1',
        posterRid: 'rId2',
        offX: 0,
        offY: 0,
        extCx: 1,
        extCy: 1,
        mediaRid: 'rId3',
      );
      expect(xml, contains('p14:media'));
      expect(xml, contains('r:embed="rId3"'));
    });

    test('audioPicXml defaults and with mediaRid', () {
      final xml = VideoEmbedService.audioPicXml(
        shapeId: 5,
        name: 'Audio',
        audioRid: 'rId7',
        posterRid: 'rId8',
      );
      expect(xml, contains('<a:audioFile'));
      expect(xml, contains('r:link="rId7"'));
      expect(xml, contains('x="1269999"'));
      final xml2 = VideoEmbedService.audioPicXml(
        shapeId: 6,
        name: 'A2',
        audioRid: 'rId7',
        posterRid: 'rId8',
        mediaRid: 'rId9',
        offX: 10,
        offY: 20,
        iconSize: 30,
      );
      expect(xml2, contains('p14:media'));
      expect(xml2, contains('cx="30"'));
    });

    test('mediaTimingXml empty returns empty string', () {
      expect(VideoEmbedService.mediaTimingXml([]), '');
      expect(VideoEmbedService.mediaTimingInnerXml([]), '');
    });

    test('mediaTimingXml autoplay video covers branches', () {
      final xml = VideoEmbedService.mediaTimingXml([
        const MediaTimingSpec(
          spid: 10,
          autoplay: true,
          loop: false,
          durationMs: 5000,
        ),
        const MediaTimingSpec(
          spid: 11,
          autoplay: false,
          loop: true,
          durationMs: 3000,
        ),
      ]);
      expect(xml, startsWith('<p:timing><p:tnLst>'));
      expect(xml, contains('cmd="playFrom(0.0)"'));
      expect(xml, contains('cmd="togglePause"'));
      expect(xml, contains('repeatCount="indefinite"'));
      expect(xml, contains('<p:video>'));
      expect(xml, contains('spid="10"'));
      expect(xml, contains('spid="11"'));
    });

    test('mediaTimingXml audio acrossSlides variants', () {
      final xml = VideoEmbedService.mediaTimingXml([
        const MediaTimingSpec(
          spid: 20,
          autoplay: false,
          loop: false,
          durationMs: 1000,
          kind: MediaTimingKind.audio,
          acrossSlides: false,
        ),
        const MediaTimingSpec(
          spid: 21,
          autoplay: false,
          loop: false,
          durationMs: 1000,
          kind: MediaTimingKind.audio,
          acrossSlides: true,
        ),
        const MediaTimingSpec(
          spid: 22,
          autoplay: true,
          loop: true,
          durationMs: 2000,
          kind: MediaTimingKind.audio,
          acrossSlides: true,
        ),
      ]);
      expect(xml, contains('<p:audio>'));
      expect(xml, contains('onStopAudio'));
      expect(xml, contains('presetID="1"'));
      expect(xml, contains('presetID="2"'));
    });

    test('mediaTimingInnerXml shares ids sequentially', () {
      final xml = VideoEmbedService.mediaTimingInnerXml([
        const MediaTimingSpec(spid: 1, autoplay: false, loop: false, durationMs: 100),
        const MediaTimingSpec(spid: 2, autoplay: false, loop: false, durationMs: 100),
      ]);
      expect(xml.contains('id="1"'), isTrue);
      expect(xml.contains('id="7"'), isTrue);
    });
  });

  group('HtmlImageLoader pure and local paths', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ghita_cov_img_');
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = null);
      HtmlImageLoader.clearCaches();
      HtmlImageLoader.debugCacheDir = '${tempDir.path}/cache';
      LocalImageAllowlist.resetForTests();
      LocalImageAllowlist.debugAllowedDirs = [tempDir.path];
      await LocalImageAllowlist.ensureWarm();
      ImageOptimizerConfig.betaEnabled = false;
      ImageOptimizationStats.reset();
      HtmlImageLoader.clearWarnings();
    });

    tearDown(() async {
      HtmlImageLoader.clearCaches();
      HtmlImageLoader.debugCacheDir = null;
      LocalImageAllowlist.resetForTests();
      LocalImageAllowlist.debugAllowedDirs = null;
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Uint8List tinyPngBytes() {
      final imgPkg = imgEncodePng(1, 1);
      return imgPkg;
    }

    test('ImageLoadWarning displayName and toString', () {
      expect(
        const ImageLoadWarning('data:image/png;base64,abc', 'bad').displayName,
        'embedded-image',
      );
      expect(
        const ImageLoadWarning('http://x/pic.png?v=1', 'bad').displayName,
        'pic.png',
      );
      expect(
        const ImageLoadWarning('http://x///', 'bad').displayName,
        'http://x///',
      );
      expect(
        const ImageLoadWarning('', 'bad').displayName,
        '',
      );
      expect(
        const ImageLoadWarning('C:\\Users\\pic.jpg', 'oops').toString(),
        'pic.jpg: oops',
      );
    });

    test('clearWarnings and importWorkerDiagnostics', () {
      HtmlImageLoader.warnings.add(
        const ImageLoadWarning('a.png', 'bad'),
      );
      HtmlImageLoader.clearWarnings();
      expect(HtmlImageLoader.warnings, isEmpty);

      HtmlImageLoader.importWorkerDiagnostics([
        {'src': 'b.png', 'reason': 'bad'},
        'not-a-map',
        {'src': 'c.png', 'reason': 'bad2'},
      ], 3);
      expect(HtmlImageLoader.skippedOutsideAllowlistCount, 3);
      expect(HtmlImageLoader.warnings.length, 2);
      expect(HtmlImageLoader.warnings.first.src, 'b.png');

      HtmlImageLoader.importWorkerDiagnostics(null, 0);
      expect(HtmlImageLoader.warnings.length, 2);
    });

    test('clearCaches and debugCacheBytesTotal', () {
      expect(HtmlImageLoader.debugCacheBytesTotal, 0);
      HtmlImageLoader.clearCaches();
      expect(HtmlImageLoader.debugCacheBytesTotal, 0);
    });

    test('load returns null for empty src', () {
      expect(HtmlImageLoader.load(''), isNull);
      expect(HtmlImageLoader.load('   '), isNull);
    });

    test('load invalid base64 data uri records warning', () {
      expect(
        HtmlImageLoader.load('data:image/png;base64,!!!notbase64!!!'),
        isNull,
      );
      expect(
        HtmlImageLoader.warnings
            .any((w) => w.reason.contains('invalid base64')),
        isTrue,
      );
    });

    test('load unsupported mime data uri', () {
      expect(
        HtmlImageLoader.load('data:image/tiff;base64,AQI='),
        isNull,
      );
      expect(
        HtmlImageLoader.warnings
            .any((w) => w.reason.contains('unsupported image mime')),
        isTrue,
      );
    });

    test('load data uri gif unsupported via public path', () {
      HtmlImageLoader.clearWarnings();
      final gifBytes = Uint8List.fromList([
        0x47,
        0x49,
        0x46,
        0x38,
        0x39,
        0x61,
        1,
        0,
        1,
        0,
        0,
        0,
        0,
        0x3B,
      ]);
      final uri = 'data:image/gif;base64,${base64Encode(gifBytes)}';
      final loaded = HtmlImageLoader.load(uri);
      final rejected = loaded == null ||
          HtmlImageLoader.warnings
              .any((w) => w.reason.contains('unsupported image mime'));
      expect(rejected, isTrue, reason: 'gif data URI must be rejected');
    });

    test('load remote not prefetched records warning', () {
      expect(
        HtmlImageLoader.load('https://127.0.0.1:9/unfetched.png'),
        isNull,
      );
      expect(
        HtmlImageLoader.warnings
            .any((w) => w.reason.contains('not prefetched')),
        isTrue,
      );
    });

    test('load local outside allowlist counts and warns', () {
      final before = HtmlImageLoader.skippedOutsideAllowlistCount;
      final loaded = HtmlImageLoader.load('C:\\Windows\\secret.png');
      expect(loaded, isNull);
      expect(HtmlImageLoader.skippedOutsideAllowlistCount, before + 1);
      expect(
        HtmlImageLoader.warnings
            .any((w) => w.reason.contains('outside allowed')),
        isTrue,
      );
    });

    test('load local missing file warns', () {
      final loaded = HtmlImageLoader.load('${tempDir.path}/missing.png');
      expect(loaded, isNull);
      expect(
        HtmlImageLoader.warnings
            .any((w) => w.reason.contains('file not found')),
        isTrue,
      );
    });

    test('load local unsupported extension warns', () {
      final p = '${tempDir.path}/file.txt';
      File(p).writeAsBytesSync([1, 2, 3]);
      expect(HtmlImageLoader.load(p), isNull);
      expect(
        HtmlImageLoader.warnings
            .any((w) => w.reason.contains('unsupported image extension')),
        isTrue,
      );
    });

    test('writeWarningsLog no-op when empty', () async {
      HtmlImageLoader.clearWarnings();
      await HtmlImageLoader.writeWarningsLog('${tempDir.path}/out.pptx');
      expect(
          File('${tempDir.path}/out.pptx.warnings.log').existsSync(), isFalse);
    });

    test('writeWarningsLog writes skipped count alone', () async {
      HtmlImageLoader.clearWarnings();
      HtmlImageLoader.skippedOutsideAllowlistCount = 2;
      final out = '${tempDir.path}/out2.pptx';
      await HtmlImageLoader.writeWarningsLog(out);
      final content = File('$out.warnings.log').readAsStringSync();
      expect(content, contains('images skipped outside allowed folders: 2'));
    });

    test('writeWarningsLog writes warnings plus skipped count', () async {
      HtmlImageLoader.clearWarnings();
      HtmlImageLoader.warnings.add(
        const ImageLoadWarning('x.png', 'bad'),
      );
      HtmlImageLoader.skippedOutsideAllowlistCount = 1;
      final out = '${tempDir.path}/out3.pptx';
      await HtmlImageLoader.writeWarningsLog(out);
      final content = File('$out.warnings.log').readAsStringSync();
      expect(content, contains('x.png: bad'));
      expect(content, contains('images skipped outside allowed folders: 1'));
    });

    test('prefetchSlides with no remote images returns quickly', () async {
      await HtmlImageLoader.prefetchSlides([
        {'title': 'A', 'htmlContent': '<p>No images</p>'},
        {'title': 'B', 'htmlContent': '<img src="data:image/png;base64,AQI=">'},
      ]);
      expect(HtmlImageLoader.warnings, isEmpty);
    });

    test('load valid data uri png decodes', () {
      final uri = 'data:image/png;base64,${base64Encode(tinyPngBytes())}';
      final loaded = HtmlImageLoader.load(uri, dartOnly: true);
      expect(loaded, isNotNull);
      expect(loaded!.ext, 'png');
      expect(loaded.width, 1);
      expect(loaded.height, 1);
      expect(loaded.bytes, isNotEmpty);

      final again = HtmlImageLoader.load(uri, dartOnly: true);
      expect(again!.bytes, orderedEquals(loaded.bytes));
    });

    test('load with maxWidth downscales via dartOnly', () {
      final uri = 'data:image/png;base64,${base64Encode(tinyPngBytes())}';
      final loaded = HtmlImageLoader.load(uri, maxWidth: 10, dartOnly: true);
      expect(loaded, isNotNull);
    });

    test('corrupt processed disk entry is reprocessed', () async {
      final uri = 'data:image/png;base64,${base64Encode(tinyPngBytes())}';
      HtmlImageLoader.load(uri, dartOnly: true);
      final cacheDir = Directory('${tempDir.path}/cache');
      if (cacheDir.existsSync()) {
        for (final f in cacheDir.listSync().whereType<File>()) {
          if (f.path.endsWith('.json')) {
            f.writeAsStringSync('corrupt{{{');
          }
        }
      }
      HtmlImageLoader.clearCaches();
      final loaded = HtmlImageLoader.load(uri, dartOnly: true);
      expect(loaded, isNotNull);
    });

    test('gif decompression bomb header rejected', () {
      final bomb = Uint8List.fromList([
        0x47,
        0x49,
        0x46,
        0x38,
        0x39,
        0x61,
        0x00,
        0x9C,
        0x00,
        0x9C,
        0,
        0,
        0,
        0x3B,
      ]);
      final uri = 'data:image/gif;base64,${base64Encode(bomb)}';
      HtmlImageLoader.load(uri, dartOnly: true);
      expect(HtmlImageLoader.warnings.any((w) => w.reason.contains('pixel')),
          isTrue);
    });

    test('jpeg bomb header rejected', () {
      final j = <int>[0xFF, 0xD8];
      j.addAll([0xFF, 0xC0, 0, 17, 8, 0x7F, 0xFF, 0x7F, 0xFF]);
      j.addAll(List.filled(10, 0));
      j.addAll([0xFF, 0xD9]);
      final uri = 'data:image/jpeg;base64,${base64Encode(j)}';
      HtmlImageLoader.load(uri, dartOnly: true);
      expect(HtmlImageLoader.warnings.any((w) => w.reason.contains('pixel')),
          isTrue);
    });

    test('beta config tallies hit savings on cache hit', () {
      final uri = 'data:image/png;base64,${base64Encode(tinyPngBytes())}';
      HtmlImageLoader.load(uri, dartOnly: true);
      HtmlImageLoader.load(uri, dartOnly: true);
      expect(HtmlImageLoader.debugCacheBytesTotal, greaterThan(0));
    });

    test('ImageOptimizationStats record and summary', () {
      ImageOptimizationStats.reset();
      ImageOptimizationStats.record(100, 50);
      expect(ImageOptimizationStats.processedCount, 1);
      expect(ImageOptimizationStats.savedBytes, 50);
      ImageOptimizationStats.record(10, 20);
      expect(ImageOptimizationStats.processedCount, 1);
      expect(ImageOptimizationStats.summary(), contains('50'));
      expect(ImageOptimizationStats.hasData, isTrue);
      expect(ImageOptimizationStats.displaySummary(), isNotNull);
      expect(ImageOptimizationStats.displayCount, 1);

      ImageOptimizationStats.importWorkerSummary('worker saved', 7);
      expect(ImageOptimizationStats.displaySummary(), 'worker saved');
      expect(ImageOptimizationStats.displayCount, 7);
      expect(ImageOptimizationStats.hasData, isTrue);
      ImageOptimizationStats.reset();
      expect(ImageOptimizationStats.summary(), isNull);
      expect(ImageOptimizationStats.hasData, isFalse);
      expect(ImageOptimizationStats.displaySummary(), isNull);
    });
  });
}
