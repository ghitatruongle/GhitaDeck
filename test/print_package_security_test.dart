import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/doc_security_service.dart';
import 'package:ghita_ppt_converter/services/odp_export_service.dart';
import 'package:ghita_ppt_converter/services/outline_export_service.dart';
import 'package:ghita_ppt_converter/services/package_format_service.dart';
import 'package:ghita_ppt_converter/services/package_service.dart';
import 'package:ghita_ppt_converter/services/print_service.dart';

Map<String, dynamic> _slide(String title, String body,
    {bool hidden = false}) {
  return {
    'title': title,
    'htmlContent': '<h1>$title</h1><p>$body</p>',
    'hidden': hidden,
  };
}

void main() {
  group('T43 — Outline RTF', () {
    test('builds entries from titles + body text', () {
      final slides = [
        _slide('Giới thiệu', 'Nội dung giới thiệu sản phẩm'),
        _slide('Phần hai', 'Một đoạn văn thứ hai'),
      ];
      final entries = OutlineExportService.buildOutline(slides);
      expect(entries.length, 2);
      expect(entries[0].title, 'Giới thiệu');
      expect(entries[0].body, contains('Nội dung giới thiệu sản phẩm'));
    });

    test('RTF escapes non-ASCII as \\uN? and survives a write+read', () async {
      final dir = Directory.systemTemp.createTempSync('ghita_rtf');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = await OutlineExportService.writeRtf(
          [_slide('Tiếng Việt', 'Đường thẳng {và} ký tự \\ đặc biệt')],
          '${dir.path}/outline.rtf');
      final text = await File(path).readAsString();
      expect(text, startsWith(r'{\rtf1'));
      // ế = U+1EBF (7871), ệ = U+1EC7 (7879) → RTF \uN? escapes.
      expect(text, contains(r'\u7871?'));
      expect(text, contains(r'\u7879?'));
      expect(text, contains(r'\{'));
      expect(text, contains(r'\\'));
    });
  });

  group('T43 — Handout PDF', () {
    test('renders a 6-per-page handout PDF for 8 slides', () async {
      final slides = List.generate(8, (i) => _slide('S${i + 1}', 'body $i'));
      final bytes = await PrintService.buildHandoutPdf(slides,
          options: const PrintJobOptions(perPage: HandoutPerPage.six));
      expect(bytes.length, greaterThan(1000));
      // PDF magic.
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF
    });

    test('grayscale mode still produces a PDF', () async {
      final bytes = await PrintService.buildHandoutPdf(
        [_slide('A', 'b')],
        options: const PrintJobOptions(
            perPage: HandoutPerPage.two, grayscale: true),
      );
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });
  });

  group('T44 — potx / ppsx', () {
    late Uint8List pptx;
    setUpAll(() {
      // A minimal hand-built PPTX-like zip so the tests do not depend on the
      // full generator: content types + presentation part.
      final archive = Archive()
        ..addFile(ArchiveFile(
            '[Content_Types].xml',
            _ctXml.length,
            _ctXml.codeUnits))
        ..addFile(ArchiveFile(
            'ppt/presentation.xml',
            _presXml.length,
            _presXml.codeUnits));
      pptx = Uint8List.fromList(ZipEncoder().encode(archive)!);
    });

    test('ppsx rewrites the presentation content type', () {
      final out = PackageFormatService.rewritePackageType(
          pptx, OoxmlDeckKind.slideshow)!;
      final decoded = ZipDecoder().decodeBytes(out);
      final ct = decoded.files
          .firstWhere((f) => f.name == '[Content_Types].xml');
      final text = String.fromCharCodes(ct.content as List<int>);
      expect(
          text,
          contains(
              'application/vnd.openxmlformats-officedocument.presentationml.slideshow.main+xml'));
    });

    test('potx rewrites the template content type', () {
      final out = PackageFormatService.rewritePackageType(
          pptx, OoxmlDeckKind.template)!;
      final text = String.fromCharCodes(ZipDecoder()
          .decodeBytes(out)
          .files
          .firstWhere((f) => f.name == '[Content_Types].xml')
          .content as List<int>);
      expect(
          text,
          contains(
              'application/vnd.openxmlformats-officedocument.presentationml.template.main+xml'));
    });

    test('.ppt conversion reports a clear error without LibreOffice', () {
      PackageFormatService.binaryProbe = () => null;
      expect(
        () => PackageFormatService.convertToPpt('x.pptx', '.'),
        throwsStateError,
      );
      PackageFormatService.binaryProbe = null;
    });
  });

  group('T44 — ODP', () {
    test('produces an ODF package with the right entries and text', () {
      final slides = [
        {
          'title': 'Slide Một',
          'htmlContent': '<p>Hello thế giới</p>',
        },
      ];
      final bytes = OdpExportService.buildOdpBytes(slides);
      final decoded = ZipDecoder().decodeBytes(bytes);
      final names = decoded.files.map((f) => f.name).toSet();
      expect(names, contains('mimetype'));
      expect(names, contains('content.xml'));
      expect(names, contains('META-INF/manifest.xml'));
      final content = utf8.decode(decoded.files
          .firstWhere((f) => f.name == 'content.xml')
          .content as List<int>);
      expect(content, contains('office:presentation'));
      expect(content, contains('Slide Một'));
      expect(content, contains('Hello thế giới'));
    });
  });

  group('T45 — Package', () {
    test('extracts media and writes README + optional zip', () async {
      const png1x1 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';
      final slides = [
        {
          'title': 'P',
          'htmlContent':
              '<p><img src="data:image/png;base64,$png1x1"/></p>',
        },
      ];
      final dir = Directory.systemTemp.createTempSync('ghita_pkg');
      addTearDown(() => dir.deleteSync(recursive: true));
      final result = await PackageService.packageDeck(slides, dir.path,
          createZip: true);
      expect(result.media.length, 1);
      expect(File(result.media.first.filePath).existsSync(), isTrue);
      expect(File('${dir.path}/deck.pptx').existsSync(), isTrue);
      expect(File('${dir.path}/README.txt').existsSync(), isTrue);
      expect(result.zipPath, isNotNull);
      expect(File(result.zipPath!).existsSync(), isTrue);
    });
  });

  group('T45 — Document Inspector & security', () {
    test('finds author, emails and phones; cleaning redacts them', () {
      final slides = [
        {
          'title': 'x',
          'htmlContent': '<p>Nguyen Van An</p>'
              '<p>lienhe@congty.vn</p><p>0912345678</p>',
        },
      ];
      final findings = DocSecurityService.inspect(slides, authorName: 'Van An');
      expect(findings.where((f) => f.kind == FindingKind.author), isNotEmpty);
      expect(findings.where((f) => f.kind == FindingKind.email), isNotEmpty);
      expect(findings.where((f) => f.kind == FindingKind.phone), isNotEmpty);
      final cleaned = DocSecurityService.clean(
        slides,
        removeAuthor: true,
        removeEmails: true,
        removePhones: true,
        authorName: 'Van An',
      );
      final html = cleaned.first['htmlContent'].toString();
      expect(html, isNot(contains('lienhe@congty.vn')));
      expect(html, isNot(contains('0912345678')));
      expect(html, isNot(contains('Van An')));
    });

    test('flags hidden and empty slides', () {
      final slides = [
        {'title': 'h', 'htmlContent': '<p>text</p>', 'hidden': true},
        {'title': 'e', 'htmlContent': ''},
      ];
      final findings = DocSecurityService.inspect(slides);
      expect(findings.where((f) => f.kind == FindingKind.hiddenSlide),
          hasLength(1));
      expect(
          findings.where((f) => f.kind == FindingKind.emptySlide), hasLength(1));
    });

    test('office hash is deterministic and spin-count sensitive', () {
      final salt = List<int>.generate(16, (i) => i);
      final h1 = DocSecurityService.computeOfficeHash('secret', salt, 100);
      final h2 = DocSecurityService.computeOfficeHash('secret', salt, 100);
      final h3 = DocSecurityService.computeOfficeHash('secret', salt, 101);
      expect(h1, h2);
      expect(h1, isNot(h3));
      expect(h1.length, 64); // SHA-512
    });

    test('markAsFinal adds contentStatus and modifyVerifier', () {
      final archive = Archive()
        ..addFile(ArchiveFile('docProps/core.xml', _coreXml.length, _coreXml.codeUnits))
        ..addFile(ArchiveFile('ppt/presentation.xml', _presXml.length, _presXml.codeUnits));        final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final out = DocSecurityService.markAsFinal(bytes)!;
      final decoded = ZipDecoder().decodeBytes(out);
      final core = String.fromCharCodes(decoded.files
          .firstWhere((f) => f.name == 'docProps/core.xml')
          .content as List<int>);
      final pres = String.fromCharCodes(decoded.files
          .firstWhere((f) => f.name == 'ppt/presentation.xml')
          .content as List<int>);
      expect(core, contains('<cp:contentStatus>Final</cp:contentStatus>'));
      expect(pres, contains('modifyVerifier'));
    });

    test('applyModifyPassword embeds fileSharing with the right hash', () {
      final archive = Archive()
        ..addFile(ArchiveFile('docProps/app.xml', _appXml.length, _appXml.codeUnits));        final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final out = DocSecurityService.applyModifyPassword(bytes, 'pw123')!;
      final text = String.fromCharCodes(ZipDecoder()
          .decodeBytes(out)
          .files
          .firstWhere((f) => f.name == 'docProps/app.xml')
          .content as List<int>);
      expect(text, contains('<fileSharing'));
      expect(text, contains('hashData='));
      expect(text, contains('saltData='));
    });

    test('password rewrite preserves UTF-8 slide text byte-exact', () {
      // Regression: the package rewriter used to Latin-1 decode every XML
      // part then re-encode UTF-8, mojibake-ing non-ASCII text (Vietnamese
      // 'ế' → 'Ã¡') in every part of the deck.
      const vn = '<p>Xin chào thế giới ế ộ</p>';
      final slideXml = utf8.encode(
          '<?xml version="1.0" encoding="UTF-8"?><p:sld>'
          '<p:cSld><p:spTree><p:sp><p:txBody><a:p><a:r><a:t>$vn</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>');
      final archive = Archive()
        ..addFile(ArchiveFile('ppt/slides/slide1.xml', slideXml.length, slideXml))
        ..addFile(ArchiveFile('docProps/app.xml', _appXml.length, _appXml.codeUnits));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final out = DocSecurityService.applyModifyPassword(bytes, 'pw')!;
      final slideOut = ZipDecoder().decodeBytes(out).files
          .firstWhere((f) => f.name == 'ppt/slides/slide1.xml')
          .content as List<int>;
      expect(slideOut, slideXml); // byte-exact round trip
      expect(utf8.decode(slideOut), contains(vn));
    });

    test('handouts PDF throws a clean error for an empty deck', () {
      expect(
        () => PrintService.buildHandoutPdf(const []),
        throwsArgumentError,
      );
    });
  });
}

const _ctXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
</Types>''';

const _presXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:sldIdLst/></p:presentation>''';

const _coreXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>x</dc:title></cp:coreProperties>''';

const _appXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>Ghita</Application></Properties>''';
