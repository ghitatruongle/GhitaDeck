import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/services/ai_html_guard.dart';
import 'package:ghita_deck/services/html_image_loader.dart';
import 'package:ghita_deck/services/local_image_allowlist.dart';
import 'package:ghita_deck/services/network_content_policy.dart';
import 'package:ghita_deck/services/project_bundle_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T2.6 deck security corpus', () {
    test('deck CSP locks media to data: by default and relaxes on opt-in',
        () {
      final previous = NetworkContentPolicy.remoteAllowed;
      addTearDown(() => NetworkContentPolicy.remoteAllowed = previous);
      NetworkContentPolicy.remoteAllowed = false;
      final locked = NetworkContentPolicy.deckContentSecurityPolicy();
      expect(locked, contains('img-src data:'));
      expect(locked, isNot(contains('https:')));
      NetworkContentPolicy.remoteAllowed = true;
      final relaxed = NetworkContentPolicy.deckContentSecurityPolicy();
      expect(relaxed, contains('img-src data: https:'));
    });

    test('present mode strips link targets but keeps link text', () {
      const html = '<p><a href="https://evil.example/x">read more</a></p>';
      final stripped = AIHtmlGuard.guard(html, stripLinks: true).html;
      expect(stripped.contains('href'), isFalse);
      expect(stripped.contains('read more'), isTrue);
      final kept = AIHtmlGuard.guard(html).html;
      expect(kept.contains('href'), isTrue);
    });

    test('local images outside allowed folders are skipped and counted',
        () async {
      final outside = await Directory.systemTemp.createTemp('decksec_out');
      final inside = await Directory.systemTemp.createTemp('decksec_in');
      addTearDown(() async {
        await outside.delete(recursive: true);
        await inside.delete(recursive: true);
      });
      final png = File(p.join(outside.path, 'secret.png'));
      await png.writeAsBytes(base64Decode(_png1x1));
      HtmlImageLoader.clearCaches();
      HtmlImageLoader.clearWarnings();
      LocalImageAllowlist.resetForTests();
      LocalImageAllowlist.debugAllowedDirs = [inside.path];
      await LocalImageAllowlist.ensureWarm();
      addTearDown(() {
        LocalImageAllowlist.resetForTests();
        LocalImageAllowlist.debugAllowedDirs = null;
      });
      final blocked = HtmlImageLoader.load(png.path, dartOnly: true);
      expect(blocked, isNull);
      expect(HtmlImageLoader.skippedOutsideAllowlistCount, 1);
      LocalImageAllowlist.registerPickedFile(png.path);
      final allowed = HtmlImageLoader.load(png.path, dartOnly: true);
      expect(allowed, isNotNull);
      expect(HtmlImageLoader.skippedOutsideAllowlistCount, 1);
    });

    test('zip bomb with lying declared size aborts without OOM', () async {
      final payload =
          List<int>.filled(160 * 1024 * 1024, 0);
      final compressed =
          ZLibCodec(raw: true).encoder.convert(payload);
      final dir = await Directory.systemTemp.createTemp('decksec_bomb');
      addTearDown(() => dir.deleteSync(recursive: true));
      final bundle = File(p.join(dir.path, 'bomb.ghita'));
      await bundle.writeAsBytes(
          _lyingZip('media/bomb.m4a', compressed, 1000));
      final service = ProjectBundleService();
      final result =
          await service.loadProjectBundle(bundle.path, extractDir: dir.path);
      expect(result, isNull);
      expect(
        dir.listSync().any((e) => !e.path.endsWith('.ghita')),
        isFalse,
      );
    });

    test('capped inflate aborts bomb entry and inflates honest data', () {
      final compressed =
          ZLibCodec(raw: true).encoder.convert(List<int>.filled(
        5 * 1024 * 1024,
        0,
      ));
      final entry =
          ArchiveFile('bomb', 1000, compressed, ArchiveFile.DEFLATE);
      expect(
        () => ProjectBundleService.debugInflateCapped(
            entry.rawContent!, 64 * 1024, 'bomb'),
        throwsA(isA<FormatException>()),
      );
      final ok = ProjectBundleService.debugInflateCapped(
          entry.rawContent!, 10 * 1024 * 1024, 'ok');
      expect(ok.length, 5 * 1024 * 1024);
    });

    test('traversal media entry names are rejected', () async {
      final dir = await Directory.systemTemp.createTemp('decksec_trav');
      addTearDown(() => dir.deleteSync(recursive: true));
      final archive = Archive();
      archive.addFile(ArchiveFile('media/../../evil.txt', 4, [1, 2, 3, 4]));
      final bundle = File(p.join(dir.path, 'trav.ghita'));
      await bundle.writeAsBytes(ZipEncoder().encode(archive)!);
      final service = ProjectBundleService();
      final result =
          await service.loadProjectBundle(bundle.path, extractDir: dir.path);
      expect(result, isNull);
      expect(
        dir.listSync().any((e) => !e.path.endsWith('.ghita')),
        isFalse,
      );
    });
  });
}

const String _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Uint8List _lyingZip(String name, List<int> compressed, int declaredSize) {
  final nameBytes = utf8.encode(name);
  final crc = _crc32(compressed);
  final local = BytesBuilder();
  final h = ByteData(30);
  h.setUint32(0, 0x04034b50, Endian.little);
  h.setUint16(4, 20, Endian.little);
  h.setUint16(6, 0, Endian.little);
  h.setUint16(8, 8, Endian.little);
  h.setUint32(14, crc, Endian.little);
  h.setUint32(18, compressed.length, Endian.little);
  h.setUint32(22, declaredSize, Endian.little);
  h.setUint16(26, nameBytes.length, Endian.little);
  h.setUint16(28, 0, Endian.little);
  local.add(h.buffer.asUint8List());
  local.add(nameBytes);
  local.add(compressed);

  final central = BytesBuilder();
  final c = ByteData(46);
  c.setUint32(0, 0x02014b50, Endian.little);
  c.setUint16(4, 20, Endian.little);
  c.setUint16(6, 20, Endian.little);
  c.setUint16(8, 0, Endian.little);
  c.setUint16(10, 8, Endian.little);
  c.setUint32(16, crc, Endian.little);
  c.setUint32(20, compressed.length, Endian.little);
  c.setUint32(24, declaredSize, Endian.little);
  c.setUint16(28, nameBytes.length, Endian.little);
  c.setUint32(42, 0, Endian.little);
  central.add(c.buffer.asUint8List());
  central.add(nameBytes);

  final cdBytes = central.toBytes();
  final e = ByteData(22);
  e.setUint32(0, 0x06054b50, Endian.little);
  e.setUint16(8, 1, Endian.little);
  e.setUint16(10, 1, Endian.little);
  e.setUint32(12, cdBytes.length, Endian.little);
  e.setUint32(16, 30 + nameBytes.length + compressed.length, Endian.little);
  e.setUint16(20, 0, Endian.little);

  final out = BytesBuilder();
  out.add(local.toBytes());
  out.add(cdBytes);
  out.add(e.buffer.asUint8List());
  return out.toBytes();
}

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = ((crc & 1) == 1) ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (~crc) & 0xFFFFFFFF;
}
