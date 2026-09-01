import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/zip_codec.dart';

/// Track 02 — ghita_zip backend selection + output correctness.
///
/// Unit level: routing (Rust/Dart/fallback) is tested with injected hooks;
/// the real DLL round-trip lives in integration_test/rust_engine_probe_test.dart
/// and the benchmark tool measures real Rust speed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ZipEngineConfig.rustReadyProbe = null;
    ZipEngineConfig.setPreferredRust(true);
    ZipCodec.rustOverride = null;
  });

  test('Dart backend: deflate text + store media, byte-perfect round trip',
      () async {
    final entries = [
      ZipCodecEntry(
          name: 'text.xml',
          bytes: Uint8List.fromList([65, 66, 67, 68]),
          stored: false),
      ZipCodecEntry(
          name: 'media/img.jpg',
          bytes: Uint8List.fromList([0xAB, 0xCD, 0xEF, 0x11]),
          stored: true),
    ];
    final zip = await ZipCodec.encode(entries);
    final decoded = ZipDecoder().decodeBytes(zip);

    expect(decoded.files.map((f) => f.name), containsAll(['text.xml', 'media/img.jpg']));
    for (final e in entries) {
      final f = decoded.files.firstWhere((x) => x.name == e.name);
      final content = f.content as List<int>;
      expect(content.length, e.bytes.length);
      for (var i = 0; i < content.length; i++) {
        expect(content[i], e.bytes[i]);
      }
    }
  });

  test('Rust routing: override returns marker and receives entries', () async {
    ZipEngineConfig.rustReadyProbe = () async => true;
    List<ZipCodecEntry>? seen;
    ZipCodec.rustOverride = (entries, level) async {
      seen = entries;
      return Uint8List.fromList(utf8.encode('rust-marker'));
    };

    final out = await ZipCodec.encode([
      ZipCodecEntry(name: 'a', bytes: Uint8List.fromList([1]), stored: false),
    ]);
    expect(utf8.decode(out), 'rust-marker');
    expect(seen, hasLength(1));
    expect(seen!.single.name, 'a');
  });

  test('Rust failure falls back to Dart (never breaks the export)', () async {
    ZipEngineConfig.rustReadyProbe = () async => true;
    ZipCodec.rustOverride =
        (entries, level) async => throw StateError('rust exploded');

    final out = await ZipCodec.encode([
      ZipCodecEntry(name: 'a.txt', bytes: Uint8List.fromList([1, 2, 3]), stored: false),
    ]);
    final decoded = ZipDecoder().decodeBytes(out);
    expect(decoded.files.single.name, 'a.txt');
  });

  test('preferred Dart skips Rust entirely', () async {
    ZipEngineConfig.setPreferredRust(false);
    var rustCalled = false;
    ZipEngineConfig.rustReadyProbe = () async => true;
    ZipCodec.rustOverride = (entries, level) async {
      rustCalled = true;
      return Uint8List(0);
    };

    final out = await ZipCodec.encode([
      ZipCodecEntry(name: 'a.txt', bytes: Uint8List.fromList([1, 2]), stored: false),
    ]);
    expect(rustCalled, isFalse);
    expect(ZipDecoder().decodeBytes(out).files.single.name, 'a.txt');
  });

  test('fromArchive maps compress=false members to stored', () async {
    final archive = Archive();
    archive.addFile(ArchiveFile('ppt/slides/slide1.xml', 4, [65, 66, 67, 68]));
    archive.addFile(
        ArchiveFile('ppt/media/img.jpg', 4, [1, 2, 3, 4])..compress = false);

    final entries = ZipCodec.fromArchive(archive);
    expect(entries, hasLength(2));
    expect(entries[0].stored, isFalse); // text → deflate
    expect(entries[1].stored, isTrue); // media → stored
    expect(entries[1].bytes, [1, 2, 3, 4]);
  });

  test('fromArchive handles InputStream-backed members', () {
    final archive = Archive();
    archive.addFile(ArchiveFile(
        'stream.bin', 4, InputStream(Uint8List.fromList([9, 8, 7, 6]))));

    final entries = ZipCodec.fromArchive(archive);
    expect(entries, hasLength(1));
    expect(entries.single.name, 'stream.bin');
    expect(entries.single.bytes, [9, 8, 7, 6]);
    expect(entries.single.stored, isFalse);
  });

  test('corrupt bytes surface as FormatException (no silent empty file)',
      () {
    expect(
      () => ZipDecoder().decodeBytes(Uint8List.fromList(List.filled(64, 7))),
      throwsA(isA<FormatException>()),
    );
  });
}
