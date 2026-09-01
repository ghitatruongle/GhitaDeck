import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/src/rust/api/zip.dart' as rust_zip;
import 'package:ghita_ppt_converter/src/rust/frb_generated.dart' as frb;
import 'package:image/image.dart' as img;

/// Track 02 (ghita_zip) benchmark — media-heavy deck.
///
/// Measures full-archive ZIP encode time for a deck of 20 slides × 20 unique
/// JPEG media (total input bytes reported honestly, photos-like entropy):
///
///  * Dart `archive` ZipEncoder (level 9 text deflate, media stored) — always
///    measured;
///  * Rust `zip_archive` through the real `ghita_core.dll` — only when
///    GHITA_ZIP_RUST=1 (flutter test runs with CWD = project root, and the
///    FRB non-packaged loader resolves rust/target/release/ from there; the
///    Release DLL is also rebuilt alongside the exe for packaged runs).
///
/// Media pixels are generated once and cached under build/zip_bench_media/
/// so re-runs (and the regular test suite) don't pay the JPEG encode cost.
/// Results are appended to tool/benchmark_results_media.md when
/// GHITA_BENCH_LABEL is set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ZIP media benchmark: Dart baseline + optional Rust engine', () async {
    final images = _loadOrBuildMedia(20);
    final entries = <_Entry>[
      for (var i = 1; i <= 20; i++) ...[
        _Entry('ppt/slides/slide$i.xml',
            Uint8List.fromList(utf8.encode(_slideXml(i))), false),
        _Entry('ppt/slides/_rels/slide$i.xml.rels',
            Uint8List.fromList(utf8.encode(_slideRelsXml(i))), false),
        _Entry('ppt/media/image$i.jpg', images[i - 1], true),
      ],
      _Entry('docProps/core.xml', Uint8List.fromList(utf8.encode(coreXml)), false),
      _Entry('[Content_Types].xml',
          Uint8List.fromList(utf8.encode(contentTypesXml)), false),
    ];
    final inputBytes = entries.fold<int>(0, (a, e) => a + e.bytes.length);

    final dartZip = _encodeDart(entries);
    expect(dartZip.bytes.length, greaterThan(0));
    _assertValid(dartZip.bytes, entries);

    final rows = <String>[
      '| Deck media: ${entries.length} entries, ${_fmtBytes(inputBytes)} input | '
          '${_fmt(dartZip.ms)} ms | ${_fmtBytes(dartZip.bytes.length)} |',
    ];

    if (Platform.environment['GHITA_ZIP_RUST'] == '1') {
      String? rustMs;
      String? rustError;
      try {
        await frb.RustLib.init();
        final rustZip = await _encodeRust(entries);
        rustMs = _fmt(rustZip.ms);
        _assertValid(rustZip.bytes, entries);
        rows.add('| Deck media — **ghita_zip (Rust)** | $rustMs ms | '
            '${_fmtBytes(rustZip.bytes.length)} |');
      } catch (e) {
        rustError = '$e';
        rows.add('| Deck media — **ghita_zip (Rust)** | ERROR: $rustError | — |');
      }
    } else {
      rows.add('| Deck media — ghita_zip (Rust) | (bỏ qua — chưa bật'
          ' GHITA_ZIP_RUST=1) | — |');
    }

    final label = Platform.environment['GHITA_BENCH_LABEL'];
    if (label != null) {
      // Text-only scenario isolates the deflate engine from media copy cost.
      final textEntries = [
        for (var i = 0; i < 42; i++)
          _Entry('text/part$i.xml',
              Uint8List.fromList(utf8.encode(
                  List.filled(70, _slideXml(1 + i % 20)).join())),
              false),
      ];
      final textInput = textEntries.fold<int>(0, (a, e) => a + e.bytes.length);
      final dartText = _encodeDart(textEntries);
      String? rustText;
      if (Platform.environment['GHITA_ZIP_RUST'] == '1') {
        try {
          final r = await _encodeRust(textEntries);
          rustText = _fmt(r.ms);
        } catch (e) {
          rustText = 'ERROR: $e';
        }
      }
      rows.add('| Text-only: ${_fmtBytes(textInput)} input | Dart ${_fmt(dartText.ms)} ms | '
          '${rustText != null ? 'Rust $rustText ms' : '—'} |');

      final file = File('tool/benchmark_results_media.md');
      final out = StringBuffer();
      if (file.existsSync()) out.write(file.readAsStringSync());
      out
        ..writeln()
        ..writeln('## $label — ${DateTime.now().toString().substring(0, 19)}')
        ..writeln()
        ..writeln('| Kịch bản | Nén ZIP | Kích thước |')
        ..writeln('|---|---|---|');
      for (final l in rows) {
        out.writeln(l);
      }
      await file.writeAsString(out.toString(), flush: true);
    }
  });
}

// ---------- helpers ----------

class _Entry {
  final String name;
  final Uint8List bytes;
  final bool stored;
  const _Entry(this.name, this.bytes, this.stored);
}

class _ZipResult {
  final Uint8List bytes;
  final double ms;
  const _ZipResult(this.bytes, this.ms);
}

_ZipResult _encodeDart(List<_Entry> entries) {
  final archive = Archive();
  for (final e in entries) {
    archive.addFile(ArchiveFile(e.name, e.bytes.length, e.bytes)
      ..compress = !e.stored);
  }
  final watch = Stopwatch()..start();
  final bytes = ZipEncoder().encode(archive, level: 9)!;
  watch.stop();
  return _ZipResult(Uint8List.fromList(bytes), watch.elapsedMicroseconds / 1000);
}

Future<_ZipResult> _encodeRust(List<_Entry> entries) async {
  final rustEntries = entries
      .map((e) => rust_zip.ZipEntry(
          name: e.name, data: e.bytes, stored: e.stored))
      .toList();
  final watch = Stopwatch()..start();
  final bytes = await rust_zip.zipArchive(entries: rustEntries, level: 9);
  watch.stop();
  return _ZipResult(bytes, watch.elapsedMicroseconds / 1000);
}

void _assertValid(Uint8List zipBytes, List<_Entry> entries) {
  final decoded = ZipDecoder().decodeBytes(zipBytes);
  final names = decoded.files.map((f) => f.name).toSet();
  for (final e in entries) {
    expect(names, contains(e.name), reason: 'missing ${e.name}');
    final f = decoded.files.firstWhere((x) => x.name == e.name);
    final content = f.content as List<int>;
    expect(content.length, e.bytes.length, reason: 'size mismatch ${e.name}');
    for (var i = 0; i < e.bytes.length; i++) {
      expect(content[i], e.bytes[i], reason: 'byte mismatch ${e.name} @$i');
      if (i >= 64) break;
    }
  }
}

List<Uint8List> _loadOrBuildMedia(int count) {
  final dir = Directory('build/zip_bench_media');
  final files = [
    for (var i = 0; i < count; i++)
      File('${dir.path}/image$i.jpg'),
  ];
  if (files.every((f) => f.existsSync())) {
    return [for (final f in files) f.readAsBytesSync()];
  }
  dir.createSync(recursive: true);
  final result = <Uint8List>[];
  for (var i = 0; i < count; i++) {
    final bytes = _makePhotoLikeJpeg(i);
    files[i].writeAsBytesSync(bytes);
    result.add(bytes);
  }
  return result;
}

/// Pseudo-photo: hue-varying gradient + deterministic noise, 1600×900,
/// JPEG q90 — realistic entropy for a media-heavy deck.
Uint8List _makePhotoLikeJpeg(int seed) {
  const w = 1600, h = 900;
  final image = img.Image(width: w, height: h);
  final rng = Random(seed * 7919 + 17);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final base = (x * 3 + y * 2 + seed * 40) % 256;
      final noise = rng.nextInt(90) - 45;
      image.setPixelRgb(
          x,
          y,
          (base + noise).clamp(0, 255),
          ((base ~/ 2) + noise).clamp(0, 255),
          (255 - (base ~/ 3) + noise).clamp(0, 255));
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

String _slideXml(int n) => buildSlideXml(n);

String _slideRelsXml(int n) => buildSlideRelsXml(n);

// -------- static XML payload (same shape as real exports) --------

const String coreXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/'
    '2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/">'
    '<dc:title>GhitaPPT benchmark deck</dc:title>'
    '<dc:creator>GhitaPPT</dc:creator>'
    '<cp:revision>1</cp:revision></cp:coreProperties>';

const String contentTypesXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-'
    'package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/ppt/presentation.xml" ContentType="application/'
    'vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>'
    '</Types>';

String buildSlideXml(int n) => '<?xml version="1.0" encoding="UTF-8" '
    'standalone="yes"?><p:sld xmlns:a="http://schemas.openxmlformats.org/'
    'drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/'
    'presentationml/2006/main"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1"'
    ' name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/><p:sp>'
    '<p:nvSpPr><p:cNvPr id="2" name="Tiêu đề $n"/><p:cNvSpPr/><p:nvPr/>'
    '</p:nvSpPr><p:spPr><a:xfrm><a:off x="609600" y="228600"/>'
    '<a:ext cx="8737600" cy="822960"/></a:xfrm>'
    '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr><p:txBody>'
    '<a:bodyPr/><a:lstStyle/>'
    '<a:p><a:pPr algn="l"/><a:r><a:rPr lang="vi-VN" sz="3600" b="1"/>'
    '<a:t>Tiêu đề phụ $n — đoạn văn tiếng Việt có dấu để tăng entropy '
    'nén như deck người dùng thật sự sử dụng, bản thân đây là XML dài '
    'đáng kể chứ không phải chuỗi rỗng tuếch</a:t></a:r></a:p></p:txBody>'
    '</p:sp><p:sp><p:nvSpPr><p:cNvPr id="3" name="Nội dung $n"/>'
    '<p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm>'
    '<a:off x="609600" y="1016000"/><a:ext cx="8737600" cy="5486400"/>'
    '</a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
    '<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Mục $n.1 — ghi chú và '
    'dữ liệu mẫu thêm vào lần nữa để khối XML đạt kích thước thực tế của '
    'một slide chứa bảng và danh sách dài.</a:t></a:r></a:p><a:p><a:r><a:t>'
    'Mục $n.2 với tiếng Việt: ảnh, âm thanh, việc trình chiếu và các mẫu '
    'ứng dụng.</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld>'
    '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr><p:transition '
    'spd="med"/></p:sld>';

String buildSlideRelsXml(int n) => '<?xml version="1.0" encoding="UTF-8" '
    'standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/'
    'package/2006/relationships"><Relationship Id="rId1" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/'
    'slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
    '<Relationship Id="rId2" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/'
    'image" Target="../media/image$n.jpg"/></Relationships>';

String _fmt(double v) => v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _fmtBytes(int bytes) =>
    bytes >= 1 << 20
        ? '${(bytes / (1 << 20)).toStringAsFixed(1)} MB'
        : '${(bytes / 1024).toStringAsFixed(1)} KB';
