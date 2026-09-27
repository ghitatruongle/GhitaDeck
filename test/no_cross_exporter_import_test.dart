import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;
  final exporterFiles = [
    'lib/services/pdf_export_service.dart',
    'lib/services/html_export_service.dart',
    'lib/services/odp_export_service.dart',
    'lib/services/outline_export_service.dart',
    'lib/services/slide_frame_renderer.dart',
    'lib/services/docx_report_service.dart',
  ];

  test('exporters never import the PPTX builder', () {
    for (final rel in exporterFiles) {
      final file = File('$root/$rel');
      expect(file.existsSync(), isTrue, reason: '$rel missing');
      final source = file.readAsStringSync();
      expect(source.contains("import 'ppt_generator.dart'"), isFalse,
          reason: '$rel still imports ppt_generator.dart');
      expect(source.contains("import '../services/ppt_generator.dart'"), isFalse,
          reason: '$rel still imports ppt_generator.dart');
    }
  });

  test('shared HTML parse core exists and exposes the extracted API', () {
    final core = File('$root/lib/core/html/html_parser.dart');
    expect(core.existsSync(), isTrue);
    final source = core.readAsStringSync();
    for (final symbol in [
      'class HtmlParseCore',
      'class HtmlParseCache',
      'class HtmlAttrScan',
      'parseHtmlContentFullFromDoc',
      'extractNotes',
      'cssColorToHex',
      'cssFontSizeToSz',
      'jpegQualityForMaxWidth',
      'bgColorAttrRe',
    ]) {
      expect(source.contains(symbol), isTrue, reason: 'core missing $symbol');
    }
  });

  test('codec shim keeps the services facade alive', () {
    final shim = File('$root/lib/services/html_parse_codec.dart');
    final source = shim.readAsStringSync();
    expect(source, contains("export '../core/html/html_parse_codec.dart';"));
  });
}
