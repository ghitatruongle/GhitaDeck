import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/services/zip_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZipCodec.decodeWithCaps (Dart fallback)', () {
    test('decodes honest archives and skips directories', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('slides.json', 2, [91, 93]))
        ..addFile(ArchiveFile('media/', 0, Uint8List(0)));
      final bytes = ZipEncoder().encode(archive)!;
      final out = await ZipCodec.decodeWithCaps(bytes);
      expect(ZipCodec.lastBackend, 'dart');
      expect(out.single.name, 'slides.json');
      expect(out.single.bytes, [91, 93]);
    });

    test('rejects traversal entry names', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('../evil.txt', 1, [120]));
      final bytes = ZipEncoder().encode(archive)!;
      await expectLater(
        ZipCodec.decodeWithCaps(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('aborts when an entry inflates past the cap', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('media/bomb.m4a', 2 << 20,
            List<int>.filled(2 << 20, 0))..compress = true);
      final bytes = ZipEncoder().encode(archive)!;
      await expectLater(
        ZipCodec.decodeWithCaps(bytes, maxEntryBytes: 64 << 10),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects archives expanding past the total cap', () async {
      final archive = Archive();
      for (var i = 0; i < 3; i++) {
        archive.addFile(ArchiveFile('m$i.m4a', 1 << 20,
            List<int>.filled(1 << 20, i))..compress = true);
      }
      final bytes = ZipEncoder().encode(archive)!;
      await expectLater(
        ZipCodec.decodeWithCaps(bytes, maxTotalBytes: 1 << 20),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects entries over the count limit', () async {
      final archive = Archive();
      for (var i = 0; i < 5; i++) {
        archive.addFile(ArchiveFile('f$i.txt', 1, [120]));
      }
      final bytes = ZipEncoder().encode(archive)!;
      await expectLater(
        ZipCodec.decodeWithCaps(bytes, maxEntries: 3),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
