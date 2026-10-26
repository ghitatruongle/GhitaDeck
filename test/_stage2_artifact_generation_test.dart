import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/models/export_options.dart';
import 'package:ghita_deck/services/html_export_service.dart';
import 'package:ghita_deck/services/pdf_export_service.dart';
import 'package:ghita_deck/services/ppt_generator.dart';

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  test('creates Stage 2 internal release fixtures', () async {
    final output = Directory('build/stage2_validation');
    await output.create(recursive: true);
    final slides = <Map<String, dynamic>>[
      {
        'title': 'Skip this slide',
        'bgColor': '#8B0000',
        'notes': 'This slide must not be selected.',
        'htmlContent': '<p>Unselected slide</p>',
      },
      {
        'title': 'Advanced export validation',
        'bgColor': '#123456',
        'notes': 'Presenter-only note.',
        'htmlContent': '<h2>Ratio and quality are effective</h2>'
            '<p><strong>Bold</strong>, <em>italic</em> and <u>underlined</u>.</p>'
            '<ul><li>Selected content remains</li><li>Background can be disabled</li></ul>'
            '<img src="data:image/png;base64,$_onePixelPng">',
      },
      {
        'title': 'Skip this too',
        'bgColor': '#006400',
        'notes': 'This slide must not be selected.',
        'htmlContent': '<p>Second unselected slide</p>',
      },
    ];
    final selected = [slides[1]];
    final pptxPath =
        '${output.path}/stage2-portrait-no-notes-no-background.pptx';
    final htmlPath = '${output.path}/stage2-square-with-notes.html';
    final pdfPath = '${output.path}/stage2-portrait-with-notes.pdf';

    await PPTGenerator.generatePPT(
      selected,
      pptxPath,
      aspectRatio: ExportAspectRatio.portrait9x16,
      includeNotes: false,
      includeBackgrounds: false,
      imageMaxWidth: ExportQuality.low.imageMaxWidth,
    );
    await HtmlExportService().exportToHtmlPath(
      selected,
      htmlPath,
      aspectRatio: ExportAspectRatio.square1x1,
      includeNotes: true,
      includeBackgrounds: true,
      imageMaxWidth: ExportQuality.medium.imageMaxWidth,
    );
    await PdfExportService().exportToPdf(
      selected,
      pdfPath,
      aspectRatio: ExportAspectRatio.portrait9x16,
      includeNotes: true,
      includeBackgrounds: true,
      imageMaxWidth: ExportQuality.high.imageMaxWidth,
    );

    for (final path in [pptxPath, htmlPath, pdfPath]) {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(File(path).lengthSync(), greaterThan(0), reason: path);
    }
  }, testOn: 'windows');
}
