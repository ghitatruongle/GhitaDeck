import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/export_options.dart';
import 'package:ghita_ppt_converter/services/html_export_service.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';

// Regression tests for the T17 template refresh.
// Contract: every text element carries an inline `color` because the
// slide preview stylesheet forces light text on tags like h1/p/li/th.
void main() {
  final templateDir = Directory('assets/templates');

  final cases = <String, List<String>>{
    'business.html': ['Department Performance', 'Revenue growth', '96%'],
    'creative.html': [
      'Three Pillars of the Concept',
      'Localized content',
      'Two-week experiment loop',
    ],
    'academic.html': ['Class Highlights', 'Survey theory', 'analysis report'],
    'marketing.html': [
      'Primary Marketing Channels',
      'Social Media',
      'In-store',
    ],
    'minimal.html': [
      'What Was Done This Week',
      'landing page flow',
      'archive question set',
    ],
  };

  group('T17 refreshed templates', () {
    for (final entry in cases.entries) {
      final file = entry.key;
      test('$file parses with expected content and inline colors', () {
        final html = File('${templateDir.path}/$file').readAsStringSync();

        // Parser must accept the full template HTML and yield blocks.
        final blocks = PPTGenerator.parseHtmlContentFull(html);
        expect(blocks, isNotEmpty,
            reason: '$file should produce at least one content block');

        final text = blocks
            .map((b) => '${b['type']} ${b.toString()}')
            .join('\n');
        for (final keyword in entry.value) {
          expect(text, contains(keyword),
              reason: '$file should keep content "$keyword"');
        }

        // Every visible text element needs an inline color so preview and
        // PPTX runs stay readable regardless of the stylesheet defaults.
        final colorLess = <String>[];
        final tags = RegExp(r'<(h1|h2|h3|p|li|td|th|span|b|strong|em|i)\b[^>]*>',
            caseSensitive: false).allMatches(html);
        for (final tag in tags) {
          final tagStr = tag.group(0)!;
          if (!tagStr.endsWith('>')) {
            continue;
          }
          if (tagStr.contains('/>')) {
            continue;
          }
          if (tagStr.contains('aside')) {
            continue;
          }
          if (!RegExp(r'color\s*:', caseSensitive: true).hasMatch(tagStr)) {
            // Accent glyph spans carry explicit color in these templates.
            colorLess.add(tagStr);
          }
        }
        expect(colorLess, isEmpty,
            reason: '$file must set inline color on every text tag, got: '
                '${colorLess.take(5).toList()}');
      });
    }
  });

  group('T17 templates export cleanly (PPTX/PDF/HTML)', () {
    test('a slide made from each refreshed template exports to all formats',
        () async {
      final tmp = Directory.systemTemp.createTempSync('t17_export_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      for (final file in cases.keys) {
        final html = File('${templateDir.path}/$file').readAsStringSync();
        final slides = <Map<String, dynamic>>[
          {
            'title': file.replaceFirst('.html', ''),
            'htmlContent': html,
            'notes': '',
            'bgColor': null,
          },
        ];
        final pptxPath = '${tmp.path}/${file.replaceFirst('.html', '')}.pptx';
        final htmlPath = '${tmp.path}/${file.replaceFirst('.html', '')}.html';
        final pdfPath = '${tmp.path}/${file.replaceFirst('.html', '')}.pdf';
        await PPTGenerator.generatePPT(slides, pptxPath);
        await HtmlExportService().exportToHtmlPath(
          slides,
          htmlPath,
          aspectRatio: ExportAspectRatio.widescreen16x9,
        );
        await PdfExportService().exportToPdf(
          slides,
          pdfPath,
          aspectRatio: ExportAspectRatio.widescreen16x9,
        );
        for (final path in [pptxPath, htmlPath, pdfPath]) {
          expect(File(path).existsSync(), isTrue, reason: '$file -> $path');
          expect(File(path).lengthSync(), greaterThan(0),
              reason: '$file -> $path must not be empty');
        }
      }
    }, testOn: 'windows');
  });

  group('T17 keeps old templates usable (no regression)', () {
    test('every shipped template file parses and carries a background',
        () {
      final files = templateDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.html'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      expect(files.length, greaterThanOrEqualTo(20),
          reason: 'all templates must still ship');
      for (final f in files) {
        final html = f.readAsStringSync();
        expect(html, contains('data-bg-color'),
            reason: '${f.path} needs data-bg-color for preview background');
        final blocks = PPTGenerator.parseHtmlContentFull(html);
        expect(blocks, isNotEmpty,
            reason: '${f.path} must remain parseable after the refresh');
      }
    });
  });
}
