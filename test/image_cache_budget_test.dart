import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/html_image_loader.dart';

Uint8List _pngBytes(int fill, int sizeKb) {
  final out = BytesBuilder();
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final body = List<int>.filled(sizeKb * 1024 - 8, fill);
  out.add(body);
  return out.toBytes();
}

void main() {
  test('processed cache obeys its byte budget', () {
    final dir = Directory.systemTemp.createTempSync('ghita_ram_budget_');
    addTearDown(() => dir.deleteSync(recursive: true));
    HtmlImageLoader.debugCacheDir = dir.path;
    HtmlImageLoader.clearCaches();

    const imageKb = 512;
    final decodedBytes = List<int>.filled(imageKb * 1024, 0);
    for (var i = 0; i < 60; i++) {
      final png = _pngBytes(i & 0xFF, imageKb);
      final path = '${dir.path}\\img_$i.png';
      File(path).writeAsBytesSync(png);
      final src = '<img src="$path">';
      final out = HtmlImageLoader.load(src, maxWidth: 64);
      if (out == null) continue;
      decodedBytes[i] = out.bytes.length;
    }
    expect(HtmlImageLoader.debugCacheBytesTotal,
        lessThanOrEqualTo(64 * 1024 * 1024));
    HtmlImageLoader.clearCaches();
    expect(HtmlImageLoader.debugCacheBytesTotal, 0);
  });
}
