import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/odp_export_service.dart';
import 'package:image/image.dart' as img;

/// B17 (2026-09-02): ODP embeds re-encoded JPEGs for large opaque photo
/// PNGs — before the fix every photo was packed as PNG (3-6× bigger).
void main() {
  test('B17: ODP embeds photo PNG as Pictures/N.jpg, not N.png', () {
    final image = img.Image(width: 600, height: 400);
    for (var y = 0; y < 400; y++) {
      for (var x = 0; x < 600; x++) {
        image.setPixelRgb(x, y, (x * 2) % 256, (y * 3) % 256, 128);
      }
    }
    final tmp = Directory.systemTemp.createTempSync('ghita_b17_odp');
    addTearDown(() => tmp.delete(recursive: true));
    final imgPath = '${tmp.path}/photo.png';
    File(imgPath).writeAsBytesSync(img.encodePng(image));

    final bytes = OdpExportService.buildOdpBytes([
      {
        'title': 'Photo',
        'htmlContent': '<div><img src="$imgPath"></div>',
      },
    ]);
    final decoded = ZipDecoder().decodeBytes(bytes);
    final pictures =
        decoded.files.map((f) => f.name).where((n) => n.startsWith('Pictures/'));
    expect(pictures, isNotEmpty, reason: 'ODP should embed the photo');
    final first = pictures.first;
    expect(first, endsWith('.jpg'),
        reason: 'photo PNG must be re-encoded as JPEG (B17)');
    // JPEG embedded: SOI marker.
    final content = decoded.files.firstWhere((f) => f.name == first).content
        as List<int>;
    expect(content.take(2).toList(), [0xFF, 0xD8]);
  });
}
