import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/models/export_options.dart';
import 'package:ghita_deck/services/html_image_loader.dart';
import 'package:image/image.dart' as image;

void main() {
  group('ExportOptions', () {
    test('keeps all slides in original order when exporting all', () {
      const options = ExportOptions(format: PresentationExportFormat.pptx);
      expect(options.selectSlides(['A', 'B', 'C']), ['A', 'B', 'C']);
    });

    test('deduplicates and sorts explicit slide selection', () {
      const options = ExportOptions(
        format: PresentationExportFormat.pdf,
        allSlides: false,
        selectedSlideIndices: [2, 0, 2],
      );
      expect(options.selectSlides(['A', 'B', 'C']), ['A', 'C']);
    });

    test('rejects an empty or out-of-range explicit selection', () {
      const empty = ExportOptions(
        format: PresentationExportFormat.html,
        allSlides: false,
      );
      const outOfRange = ExportOptions(
        format: PresentationExportFormat.html,
        allSlides: false,
        selectedSlideIndices: [4],
      );

      expect(() => empty.selectSlides(['A']), throwsArgumentError);
      expect(() => outOfRange.selectSlides(['A']), throwsRangeError);
    });
  });

  test('image quality ceiling downscales raster content deterministically', () {
    final source = image.Image(width: 800, height: 400);
    image.fill(source, color: image.ColorRgb8(45, 120, 200));
    final bytes = Uint8List.fromList(image.encodePng(source));
    final uri = 'data:image/png;base64,${base64Encode(bytes)}';

    final low =
        HtmlImageLoader.load(uri, maxWidth: ExportQuality.low.imageMaxWidth);
    final high =
        HtmlImageLoader.load(uri, maxWidth: ExportQuality.high.imageMaxWidth);

    expect(low, isNotNull);
    expect(high, isNotNull);
    expect(low!.width, ExportQuality.low.imageMaxWidth);
    expect(low.height, 75);
    expect(high!.width, ExportQuality.high.imageMaxWidth);
    expect(high.height, 300);
  });
}
