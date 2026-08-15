import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ghita_ppt_converter/services/export_primitives.dart';
import 'package:ghita_ppt_converter/services/slide_frame_renderer.dart';
import 'package:ghita_ppt_converter/services/slide_image_export_service.dart';
import 'package:ghita_ppt_converter/services/video_export_service.dart';

Map<String, dynamic> _slide({
  String title = 'Test Slide',
  String? bg,
  String body = 'Hello world',
}) {
  final bgAttr = bg != null ? ' data-bg-color="$bg"' : '';
  return {
    'title': title,
    'htmlContent':
        '<h1>$title</h1><p$bgAttr>$body</p>',
  };
}

void main() {
  group('T42 — SlideFrameRenderer', () {
    test('renders a slide at the requested size with the background colour',
        () {
      final frame = SlideFrameRenderer.renderSlide(
        _slide(bg: '#123456'),
        width: 1280,
        height: 720,
      );
      expect(frame, isNotNull);
      expect(frame!.image.width, 1280);
      expect(frame.image.height, 720);
      // Corner pixel = background (content only fills the middle).
      final corner = frame.image.getPixel(2, 2);
      expect(corner.r, 0x12);
      expect(corner.g, 0x34);
      expect(corner.b, 0x56);
    });

    test('transparent background keeps alpha 0', () {
      final frame = SlideFrameRenderer.renderSlide(
        _slide(bg: '#123456'),
        width: 640,
        height: 360,
        transparentBackground: true,
      );
      final corner = frame!.image.getPixel(2, 2);
      expect(corner.a, 0);
    });

    test('drawn shapes are rasterized (rect + oval)', () {
      final slide = {
        'title': 'Shapes',
        'htmlContent': '<p>x</p>',
        'visualElements': {
          'shapes': [
            {
              'id': 's1',
              'type': 'rect',
              'x': 10, 'y': 10, 'w': 40, 'h': 30,
              'zOrder': 0,
              'fillColor': '#FF0000',
              'strokeColor': '#000000',
              'strokeWidth': 1,
              'rotation': 0,
              'fillTransparency': 0,
              'freeformPath': '',
            },
            {
              'id': 's2',
              'type': 'oval',
              'x': 60, 'y': 40, 'w': 20, 'h': 20,
              'zOrder': 1,
              'fillColor': '#00FF00',
              'strokeColor': '#000000',
              'strokeWidth': 0,
              'rotation': 0,
              'fillTransparency': 0,
              'freeformPath': '',
            },
          ],
          'freeTexts': [],
        },
      };
      final frame = SlideFrameRenderer.renderSlide(slide, width: 640, height: 360);
      // Centre of the rect (10%..50% width, 10%..40% height → px 64..320,
      // 36..144) is red.
      final rectC = frame!.image.getPixel(160, 90);
      expect(rectC.r, 255);
      expect(rectC.g, 0);
      expect(rectC.b, 0);
      // Centre of the oval (60%..80% × 40%..60% → px 384..512, 144..216).
      final ovalC = frame.image.getPixel(448, 180);
      expect(ovalC.g, 255);
    });

    test('image blocks are embedded', () {
      final base = img.Image(width: 40, height: 40, numChannels: 4);
      img.fill(base, color: img.ColorRgba8(9, 9, 200, 255));
      final imgBytes = Uint8List.fromList(img.encodePng(base));
      final slide = {
        'title': 'Img',
        'htmlContent':
            '<p><img src="data:image/png;base64,'
            '${base64Encode(imgBytes)}"/></p>',
      };
      final frame =
          SlideFrameRenderer.renderSlide(slide, width: 640, height: 360);
      // Some pixel in the middle should be the image blue.
      var found = false;
      for (var y = 60; y < 300; y += 4) {
        for (var x = 40; x < 600; x += 4) {
          final p = frame!.image.getPixel(x, y);
          if (p.b > 150 && p.r < 60) {
            found = true;
            break;
          }
        }
        if (found) break;
      }
      expect(found, isTrue);
    });
  });

  group('T42 — SlideImageExportService', () {
    test('exports PNGs of the right size with a prefix', () async {
      final dir = Directory.systemTemp.createTempSync('ghita_slides');
      addTearDown(() => dir.deleteSync(recursive: true));
      final slides = [_slide(bg: '#112233'), _slide(bg: '#445566')];
      final result = await SlideImageExportService.exportSlides(
        slides,
        dir.path,
        options: const SlideImageExportOptions(scale: 1),
      );
      expect(result.count, 2);
      for (final f in result.files) {
        expect(f.path, contains('slide_'));
        final bytes = await File(f.path).readAsBytes();
        final decoded = img.decodeImage(bytes)!;
        expect(decoded.width, 1280);
        expect(decoded.height, 720);
      }
    });

    test('respects a start/end range and makes a contact sheet', () async {
      final dir = Directory.systemTemp.createTempSync('ghita_slides');
      addTearDown(() => dir.deleteSync(recursive: true));
      final slides = List.generate(5, (i) => _slide(title: 'S${i + 1}'));
      final result = await SlideImageExportService.exportSlides(
        slides,
        dir.path,
        options: const SlideImageExportOptions(
            startSlide: 1, endSlide: 3, contactSheet: true),
      );
      expect(result.count, 3); // slides 2..4
      expect(result.contactSheetPath, isNotNull);
      final sheet = img.decodeImage(await File(result.contactSheetPath!).readAsBytes())!;
      expect(sheet.width, greaterThan(300));
    });

    test('reports monotonic progress and honours cancel', () async {
      final dir = Directory.systemTemp.createTempSync('ghita_slides');
      addTearDown(() => dir.deleteSync(recursive: true));
      final slides = List.generate(5, (i) => _slide(title: 'S${i + 1}'));
      final fractions = <double>[];
      final token = ExportCancelToken();
      var cancelled = false;
      try {
        await SlideImageExportService.exportSlides(
          slides,
          dir.path,
          options: const SlideImageExportOptions(),
          cancelToken: token,
          onProgress: (f, i) {
            fractions.add(f);
            if (i >= 2) token.cancel();
          },
        );
      } on ExportCancelledException {
        cancelled = true;
      }
      expect(cancelled, isTrue);
      // Monotonic until cancelled.
      for (var i = 1; i < fractions.length; i++) {
        expect(fractions[i], greaterThanOrEqualTo(fractions[i - 1]));
      }
    });
  });

  group('T41 — VideoExportService', () {
    test('builds a schedule from rehearse timings then the default', () {
      final slides = [
        {'title': 'A', 'htmlContent': '<p>a</p>', 'rehearseMs': 2500},
        {'title': 'B', 'htmlContent': '<p>b</p>'},
      ];
      final shots = VideoExportService.buildSchedule(slides);
      expect(shots.length, 2);
      expect(shots[0].duration.inMilliseconds, 2500);
      expect(shots[1].duration.inMilliseconds, 3000);
    });

    test('estimates duration/frames and warns on long renders', () {
      const shots = [
        SlideShot(slideIndex: 0, duration: Duration(seconds: 3)),
        SlideShot(slideIndex: 1, duration: Duration(seconds: 2)),
      ];
      final est = VideoExportService.estimate(shots);
      expect(est.duration.inMilliseconds, 5000);
      expect(est.frameCount, 150); // 5s × 30fps
      expect(est.estimatedSeconds, greaterThan(0));
    });

    test('renders a GIF with per-slide durations (pure Dart)', () async {
      final dir = Directory.systemTemp.createTempSync('ghita_gif');
      addTearDown(() => dir.deleteSync(recursive: true));
      final slides = [
        _slide(title: 'A', bg: '#101010'),
        _slide(title: 'B', bg: '#202020'),
      ];
      final out = '${dir.path}/clip.gif';
      final result = await VideoExportService.exportVideo(
        slides,
        out,
        options: const VideoExportOptions(
            format: SlideMovieFormat.gif, gifFps: 10, defaultSlideDuration: Duration(seconds: 1)),
      );
      expect(result.frameCount, 2); // one frame per shot
      final bytes = await File(out).readAsBytes();
      // GIF magic.
      expect(bytes.sublist(0, 3), [0x47, 0x49, 0x46]);
      final decoded = img.decodeGif(bytes);
      expect(decoded, isNotNull);
    });

    test('WAV narration duration probe reads the fmt chunk', () async {
      final dir = Directory.systemTemp.createTempSync('ghita_wav');
      addTearDown(() => dir.deleteSync(recursive: true));
      // Minimal valid WAV header: 1 s of 8 kHz mono 8-bit.
      final wav = ByteData(44);
      // FourCC tags must read "RIFF WAVE fmt data" on disk → write them
      // big-endian (little-endian would produce "FFIR EVAW ...").
      wav.setUint32(0, 0x52494646, Endian.big); // 'RIFF'
      wav.setUint32(4, 36 + 8000, Endian.little);
      wav.setUint32(8, 0x57415645, Endian.big); // 'WAVE'
      wav.setUint32(12, 0x666d7420, Endian.big); // 'fmt '
      wav.setUint32(16, 16, Endian.little);
      wav.setUint16(20, 1, Endian.little); // PCM
      wav.setUint16(22, 1, Endian.little); // mono
      wav.setUint32(24, 8000, Endian.little); // sample rate
      wav.setUint32(28, 8000, Endian.little); // byte rate
      wav.setUint16(32, 1, Endian.little); // block align
      wav.setUint16(34, 8, Endian.little); // bits
      wav.setUint32(36, 0x64617461, Endian.big); // 'data'
      wav.setUint32(40, 8000, Endian.little); // data size
      final path = '${dir.path}/n.wav';
      File(path).writeAsBytesSync(wav.buffer.asUint8List());
      final dur = VideoExportService.slideDuration({
        'title': 't',
        'htmlContent': '<p>x</p>',
        'audioPath': path,
      });
      expect(dur.inMilliseconds, closeTo(1000, 20));
    });

    test('M4A narration probe reads mdhd inside moov/trak/mdia', () {
      final dir = Directory.systemTemp.createTempSync('ghita_m4a');
      addTearDown(() => dir.deleteSync(recursive: true));
      // Synthetic MP4: ftyp + moov > trak > mdia > mdhd (version 0),
      // timescale 44100, duration 111274 → 2.523 s. The mdhd box lives
      // nested inside containers — a flat top-level scan would miss it.
      final mdhd = ByteData(32)
        ..setUint32(0, 32, Endian.big) // size
        ..setUint32(4, 0x6D646864, Endian.big) // 'mdhd'
        ..setUint8(8, 0) // version
        ..setUint32(12, 0, Endian.big) // creation_time
        ..setUint32(16, 0, Endian.big) // modification_time
        ..setUint32(20, 44100, Endian.big) // timescale
        ..setUint32(24, 111274, Endian.big) // duration
        ..setUint16(28, 0x55C4) // language
        ..setUint16(30, 0);
      final mdia = ByteData(8 + 32)
        ..setUint32(0, 40, Endian.big)
        ..setUint32(4, 0x6D646961, Endian.big) // 'mdia'
        ..buffer.asUint8List().setAll(8, mdhd.buffer.asUint8List());
      final trak = ByteData(8 + 40)
        ..setUint32(0, 48, Endian.big)
        ..setUint32(4, 0x7472616B, Endian.big) // 'trak'
        ..buffer.asUint8List().setAll(8, mdia.buffer.asUint8List());
      final moov = ByteData(8 + 48)
        ..setUint32(0, 56, Endian.big)
        ..setUint32(4, 0x6D6F6F76, Endian.big) // 'moov'
        ..buffer.asUint8List().setAll(8, trak.buffer.asUint8List());
      final ftyp = ByteData(16)
        ..setUint32(0, 16, Endian.big)
        ..setUint32(4, 0x66747970, Endian.big) // 'ftyp'
        ..setUint32(8, 0x4D344120, Endian.big) // 'M4A '
        ..setUint32(12, 0);
      final file = BytesBuilder()
        ..add(ftyp.buffer.asUint8List())
        ..add(moov.buffer.asUint8List());
      final path = '${dir.path}/n.m4a';
      File(path).writeAsBytesSync(file.toBytes());
      final dur = VideoExportService.slideDuration({
        'title': 't',
        'htmlContent': '<p>x</p>',
        'audioPath': path,
      });
      expect(dur.inMilliseconds, closeTo(2523, 30));
    });

    test('GIF estimate counts one frame per shot, not fps × seconds', () {
      final shots = [
        const SlideShot(slideIndex: 0, duration: Duration(seconds: 1)),
        const SlideShot(slideIndex: 1, duration: Duration(seconds: 1)),
      ];
      final gif = VideoExportService.estimate(shots,
          options: const VideoExportOptions(
              format: SlideMovieFormat.gif, gifFps: 10));
      expect(gif.frameCount, 2); // per-shot frames
      final mp4 = VideoExportService.estimate(shots,
          options: const VideoExportOptions(format: SlideMovieFormat.mp4));
      expect(mp4.frameCount, 60); // 2 s × 30 fps
    });
  });
}
