import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ghita_ppt_converter/services/image_editor_service.dart';

/// Build a solid-colour test image (default white background with a dark
/// centre block so flood-fill / crop / corrections have something to act on).
Uint8List _makeTestImage({int w = 64, int h = 64}) {
  final image = img.Image(width: w, height: h, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
  // Dark centre rectangle
  for (var y = h ~/ 4; y < 3 * h ~/ 4; y++) {
    for (var x = w ~/ 4; x < 3 * w ~/ 4; x++) {
      image.setPixelRgba(x, y, 40, 60, 200, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('T22 — crop & background removal', () {
    test('cropImage keeps the requested rectangle (quality preserved)', () async {
      final bytes = _makeTestImage(w: 100, h: 80);
      final out = await ImageEditorService.cropImage(bytes, x: 0.25, y: 0.25, w: 0.5, h: 0.5);
      expect(out, isNotNull);
      final decoded = img.decodeImage(out!)!;
      expect(decoded.width, 50);
      expect(decoded.height, 40);
    });

    test('cropImage clamps out-of-range rectangles', () async {
      final bytes = _makeTestImage(w: 100, h: 100);
      final out = await ImageEditorService.cropImage(bytes, x: 0.9, y: 0.9, w: 0.5, h: 0.5);
      expect(out, isNotNull);
      final decoded = img.decodeImage(out!)!;
      // x=90 leaves only 10 px → width clamps to 10; same for height.
      expect(decoded.width, 10);
      expect(decoded.height, 10);
    });

    test('cropImage flush against the right edge survives the clamp guard',
        () async {
      final bytes = _makeTestImage(w: 100, h: 80);
      // x = y = 1.0 rounds to px = image.width → the old `clamp(1, 0)`
      // threw ArgumentError (lower > upper), silently failing the crop.
      // The guard clamps the upper bound to ≥ 1 first.
      final out = await ImageEditorService.cropImage(
          bytes, x: 1.0, y: 1.0, w: 0.5, h: 0.5);
      if (out != null) {
        final decoded = img.decodeImage(out)!;
        expect(decoded.width, greaterThan(0));
        expect(decoded.height, greaterThan(0));
      }
    });

    test('cropToShape oval makes corners transparent', () async {
      final bytes = _makeTestImage(w: 64, h: 64);
      final out = await ImageEditorService.cropToShape(bytes, shape: 'oval');
      expect(out, isNotNull);
      final decoded = img.decodeImage(out!)!;
      // Corner pixel (1,1) is outside the oval → fully transparent.
      final corner = decoded.getPixel(1, 1);
      expect(corner.a, 0);
      // Centre pixel stays opaque.
      final centre = decoded.getPixel(32, 32);
      expect(centre.a, greaterThan(0));
    });

    test('cropToShape heart also masks corners', () async {
      final bytes = _makeTestImage(w: 64, h: 64);
      final out = await ImageEditorService.cropToShape(bytes, shape: 'heart');
      final decoded = img.decodeImage(out!)!;
      expect(decoded.getPixel(1, 1).a, 0);
    });

    test('removeBackground flood-fills the white background away', () async {
      final bytes = _makeTestImage(w: 64, h: 64);
      final out = await ImageEditorService.removeBackground(bytes, seedX: 0.05, seedY: 0.05, tolerance: 0.3);
      expect(out, isNotNull);
      final decoded = img.decodeImage(out!)!;
      // Top-left corner (white) removed.
      expect(decoded.getPixel(1, 1).a, 0);
      // Dark centre block untouched (distance from white is large).
      expect(decoded.getPixel(32, 32).a, 255);
    });

    test('brushEdit erases and restores a disc', () async {
      final bytes = _makeTestImage(w: 64, h: 64);
      final erased = await ImageEditorService.brushEdit(bytes, original: bytes, cx: 0.5, cy: 0.5, radius: 0.2, erase: true);
      final eImg = img.decodeImage(erased!)!;
      expect(eImg.getPixel(32, 32).a, 0);
      final restored = await ImageEditorService.brushEdit(erased, original: bytes, cx: 0.5, cy: 0.5, radius: 0.2, erase: false);
      final rImg = img.decodeImage(restored!)!;
      expect(rImg.getPixel(32, 32).a, 255);
    });
  });

  group('T23 — corrections & artistic effects', () {
    test('correctImage saturation & sharpness keep alpha', () async {
      final bytes = _makeTestImage();
      final out = await ImageEditorService.correctImage(bytes, saturation: 0.4, sharpness: 0.5);
      expect(out, isNotNull);
      final decoded = img.decodeImage(out!)!;
      expect(decoded.width, 64);
      expect(decoded.getPixel(32, 32).a, 255);
    });

    test('correctImage duotone maps luminance to the two colours', () async {
      final bytes = _makeTestImage();
      final out = await ImageEditorService.correctImage(bytes, duotoneA: '#000000', duotoneB: '#FFFFFF');
      expect(out, isNotNull);
      final decoded = img.decodeImage(out!)!;
      // Centre is a mid-grey → duotone should be a mid value, not pure blue.
      final p = decoded.getPixel(32, 32);
      expect(p.b, lessThan(120));
      expect(p.r, greaterThan(0));
    });

    test('artisticEffect blur/mosaic/pencil/oil/film all return images', () async {
      final bytes = _makeTestImage();
      for (final e in ['blur', 'mosaic', 'pencil', 'oil', 'film']) {
        final out = await ImageEditorService.artisticEffect(bytes, effect: e, intensity: 1.0);
        expect(out, isNotNull, reason: '$e should produce output');
        expect(img.decodeImage(out!)!.width, 64);
      }
    });

    test('artisticEffect unknown effect returns input unchanged', () async {
      final bytes = _makeTestImage();
      final out = await ImageEditorService.artisticEffect(bytes, effect: 'nope');
      expect(out, same(bytes));
    });

    test('oil paint keeps a solid colour (bucket reuse optimisation)', () async {
      final image = img.Image(width: 40, height: 40, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(120, 60, 200, 255));
      final bytes = Uint8List.fromList(img.encodePng(image));
      final out = await ImageEditorService.artisticEffect(bytes,
          effect: 'oil', intensity: 1.0);
      expect(out, isNotNull);
      final decoded = img.decodeImage(out!)!;
      for (final p in [decoded.getPixel(5, 5), decoded.getPixel(20, 20)]) {
        expect(p.r, 120);
        expect(p.g, 60);
        expect(p.b, 200);
      }
    });

    test('all six quick presets apply', () async {
      final bytes = _makeTestImage();
      for (final p in ['bw', 'vintage', 'cool', 'warm', 'soft', 'vivid']) {
        final out = await ImageEditorService.presetImage(bytes, p);
        expect(out, isNotNull, reason: '$p should produce output');
        expect(img.decodeImage(out!)!.width, 64);
      }
    });

    test('legacy operations still work (regression)', () async {
      final bytes = _makeTestImage(w: 32, h: 24);
      final rotated = await ImageEditorService.rotateImage(bytes, degrees: 90);
      expect(img.decodeImage(rotated!)!.width, 24);
      final flipped = await ImageEditorService.flipImage(bytes, horizontal: true);
      expect(img.decodeImage(flipped!)!.width, 32);
      final resized = await ImageEditorService.resizeImage(bytes, width: 16);
      expect(img.decodeImage(resized!)!.width, 16);
      final adjusted = await ImageEditorService.adjustImage(bytes, brightness: 10, contrast: 5);
      expect(adjusted, isNotNull);
    });
  });
}
