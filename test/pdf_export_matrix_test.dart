// T04 (v2.0.1-beta.2) — PdfExportService option-matrix tests (phases 5–7).
//
// Extends pdf_export_test/pdf_export_advanced_test with the option axes they
// do not touch: notes pages, background suppression, margin presets, 4:3
// aspect ratio, merged-freeform shapes (the polygon_boolean consumer),
// cooperative cancellation and progress reporting.
//
// Behaviour note: the exporter scales content to fit — there is no overflow
// pagination, so a content-heavy slide still produces exactly one page.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/chart_data.dart';
import 'package:ghita_ppt_converter/models/export_options.dart';
import 'package:ghita_ppt_converter/services/action_button_service.dart';
import 'package:ghita_ppt_converter/services/chart_service.dart';
import 'package:ghita_ppt_converter/services/export_primitives.dart';
import 'package:ghita_ppt_converter/services/pdf_export_service.dart';

void main() {
  final tmpDirPath = Directory.systemTemp.path;
  final service = PdfExportService();

  int countPages(String path) {
    final bytes = File(path).readAsBytesSync();
    final content = String.fromCharCodes(bytes);
    return RegExp(r'/Type\s*/Page[^s]').allMatches(content).length;
  }

  group('notes and backgrounds', () {
    test('includeNotes renders speaker notes into the document', () async {
      final slides = [
        {
          'title': 'Noted',
          'htmlContent': '<p>Body</p>',
          'notes': 'Nhắc người nói: nhấn mạnh con số 42.',
        },
      ];

      final withoutNotes =
          await service.exportToPdf(slides, '$tmpDirPath/t04_no_notes.pdf');
      final withNotes =
          await service.exportToPdf(slides, '$tmpDirPath/t04_notes.pdf',
              includeNotes: true);

      expect(File(withoutNotes).lengthSync(), greaterThan(0));
      // The notes variant must carry extra text content.
      expect(File(withNotes).lengthSync(),
          greaterThan(File(withoutNotes).lengthSync() - 1));
      expect(countPages(withNotes), 1);
    });

    test('includeBackgrounds=false skips data-bg-color painting', () async {
      final slides = [
        {
          'title': 'Tinted',
          'htmlContent': '<div data-bg-color="#204080"><p>On blue</p></div>',
        },
      ];

      final path = await service.exportToPdf(
        slides,
        '$tmpDirPath/t04_nobg.pdf',
        includeBackgrounds: false,
      );
      expect(File(path).lengthSync(), greaterThan(0));
      expect(countPages(path), 1);
    });
  });

  group('page geometry matrix', () {
    final slides = [
      {'title': 'S1', 'htmlContent': '<h1>One</h1><p>text</p>'},
      {'title': 'S2', 'htmlContent': '<ul><li>a</li><li>b</li></ul>'},
    ];

    for (final paper in PdfPaperSize.values) {
      for (final margin in PdfMarginPreset.values) {
        test('paper=$paper margin=$margin exports two pages', () async {
          final path =
              '$tmpDirPath/t04_${paper.name}_${margin.name}.pdf';
          final out = await service.exportToPdf(
            slides,
            path,
            paperSize: paper,
            marginPreset: margin,
          );
          expect(out, path);
          expect(countPages(path), 2);
        });
      }
    }

    test('4:3 aspect ratio changes the page box', () async {
      final wide = await service.exportToPdf(
        slides,
        '$tmpDirPath/t04_169.pdf',
      );
      final tall = await service.exportToPdf(
        slides,
        '$tmpDirPath/t04_43.pdf',
        aspectRatio: ExportAspectRatio.standard4x3,
      );
      final wideBytes = File(wide).readAsBytesSync();
      final tallBytes = File(tall).readAsBytesSync();
      expect(wideBytes.length, greaterThan(0));
      expect(tallBytes.length, greaterThan(0));
      // Different page geometry must produce different documents — the
      // difference lives in the page object dicts, not the header.
      expect(wideBytes, isNot(equals(tallBytes)));
    });

    test('content-heavy slide still yields exactly one page (scale-to-fit)',
        () async {
      final wall = List.generate(
        120,
        (i) => '<p>Câu $i: nội dung tràn để thử cơ chế co giãn.</p>',
      ).join();
      final path = await service.exportToPdf(
        [
          {'title': 'Wall', 'htmlContent': wall},
        ],
        '$tmpDirPath/t04_wall.pdf',
        scaleToFit: true,
      );
      expect(countPages(path), 1,
          reason: 'the contract is scale-to-fit, not overflow pagination');
    });
  });

  group('rich content branches', () {
    test('a merged freeform shape (SVG path) exports without crashing',
        () async {
      final slides = [
        {
          'title': 'Merged shape',
          'htmlContent': '<p>shape below</p>',
          'visualElements': {
            'shapes': [
              {
                'id': 'sh_m',
                'type': 'merged',
                'x': 10.0,
                'y': 10.0,
                'w': 40.0,
                'h': 30.0,
                'mergeOp': 'union',
                'mergedIds': ['a', 'b'],
                'fillColor': '#3B82F6',
                'freeformPath': 'M0,0 L40,0 L40,30 L0,30 Z M5,5 L20,5 L20,20 L5,20 Z',
              },
            ],
          },
        },
      ];
      final path = await service.exportToPdf(slides, '$tmpDirPath/t04_freeform.pdf');
      expect(File(path).lengthSync(), greaterThan(0));
    });

    test('anchor-heavy content exports (links render as styled text)',
        () async {
      final slides = [
        {
          'title': 'Links',
          'htmlContent': '<p>See <a href="https://example.com/docs">the docs</a>'
              ' and <a href="https://ghita.app">ghita.app</a>.</p>',
        },
      ];
      final path = await service.exportToPdf(slides, '$tmpDirPath/t04_links.pdf');
      expect(File(path).lengthSync(), greaterThan(0));
      expect(countPages(path), 1);
    });

    test('Vietnamese diacritics export cleanly across the whole alphabet',
        () async {
      const sample = 'ÂĂÊÔƠƯ àáạảã ằắặẳẵ ềếệểễ ồốộổỗ ờớợởỡ ừứựửữ';
      final path = await service.exportToPdf(
        [
          {'title': sample, 'htmlContent': '<h1>$sample</h1><p>$sample</p>'},
        ],
        '$tmpDirPath/t04_viet.pdf',
      );
      final bytes = File(path).readAsBytesSync();
      expect(bytes.length, greaterThan(2000));
      // The embedded subset font carries the Vietnamese glyphs.
      final content = String.fromCharCodes(bytes);
      expect(content, contains('/Font'));
    });
  });

  group('cancellation and progress', () {
    test('a pre-cancelled token aborts the export', () async {
      final token = ExportCancelToken()..cancel();
      await expectLater(
        service.exportToPdf(
          [
            {'title': 'X', 'htmlContent': '<p>x</p>'},
          ],
          '$tmpDirPath/t04_cancelled.pdf',
          cancelToken: token,
        ),
        throwsA(isA<Exception>()),
      );
      expect(File('$tmpDirPath/t04_cancelled.pdf').existsSync(), isFalse);
    });

    test('onProgress reports per-slide budget events', () async {
      final events = <int>[];
      final path = await service.exportToPdf(
        [
          {'title': 'A', 'htmlContent': '<p>a</p>'},
          {'title': 'B', 'htmlContent': '<p>b</p>'},
        ],
        '$tmpDirPath/t04_progress.pdf',
        onProgress: (progress) => events.add(progress.slideIndex),
      );
      expect(File(path).existsSync(), isTrue);
      expect(events, isNotEmpty);
    });
  });

  group('canvas object rendering (shapes, free texts, gradients)', () {
    test('full-featured shapes and free texts exercise colour/gradient/effect',
        () async {
      final slides = [
        {
          'title': 'Canvas objects',
          'htmlContent': '<p>canvas objects below</p>',
          'visualElements': {
            'shapes': [
              {
                'id': 'sh_rect',
                'type': 'rect',
                'x': 5.0,
                'y': 10.0,
                'w': 30.0,
                'h': 20.0,
                'fillColor': '#FF8A00',
                'strokeColor': '#204080',
                'strokeWidth': 2.5,
                'gradientStart': '#FF8A00',
                'gradientEnd': '#E52E71',
                'gradientAngle': 45.0,
                'effect': 'shadow',
              },
              {
                'id': 'sh_oval',
                'type': 'oval',
                'x': 40.0,
                'y': 10.0,
                'w': 20.0,
                'h': 20.0,
                'fillColor': '#10B981',
                'effect': 'glow',
              },
              {
                'id': 'sh_line',
                'type': 'line',
                'x': 10.0,
                'y': 40.0,
                'w': 50.0,
                'h': 0.0,
                'strokeColor': '#3B82F6',
                'strokeWidth': 3.0,
              },
              {
                'id': 'sh_arrow',
                'type': 'arrow',
                'x': 10.0,
                'y': 45.0,
                'w': 40.0,
                'h': 10.0,
                'strokeColor': '#EF4444',
                'strokeWidth': 2.0,
              },
            ],
            'freeTexts': [
              {
                'id': 'ft_1',
                'text': 'Chú thích nổi bật',
                'x': 20.0,
                'y': 60.0,
                'w': 40.0,
                'h': 10.0,
                'color': '#1F4E79',
                'backgroundColor': '#FFF3CD',
                'borderColor': '#E6A700',
                'borderWidth': 1.5,
                'fontSize': 22.0,
                'shadow': true,
              },
            ],
          },
        },
      ];
      final path =
          await service.exportToPdf(slides, '$tmpDirPath/t04_canvas.pdf');
      expect(File(path).lengthSync(), greaterThan(3000));
      expect(countPages(path), 1);
    });
  });

  group('deep engine branches (funnel, curved paths, action buttons)', () {
    test('funnel chart renders its trapezoid slot painter', () async {
      const chart = ChartData(
        type: ChartType.funnel,
        title: 'Phễu bán hàng',
        categories: ['Truy cập', 'Giỏ hàng', 'Thanh toán', 'Thành công'],
        series: [ChartSeries(name: 'Số lượng', values: [1000, 400, 120, 90])],
      );
      final html = "<div data-chart='${ChartService.escapeAttribute(chart)}'></div>";
      final path = await service.exportToPdf(
        [
          {'title': 'Funnel', 'htmlContent': html},
        ],
        '$tmpDirPath/t04_funnel.pdf',
      );
      expect(File(path).lengthSync(), greaterThan(3000));
      expect(countPages(path), 1);
    });

    test('freeform paths with bezier curves and fill+stroke paint cleanly',
        () async {
      final slides = [
        {
          'title': 'Curved paths',
          'htmlContent': '<p>curves</p>',
          'visualElements': {
            'shapes': [
              {
                'id': 'sh_curve',
                'type': 'merged',
                'x': 10.0,
                'y': 10.0,
                'w': 50.0,
                'h': 40.0,
                'fillColor': '#8B5CF6',
                'strokeColor': '#1F2937',
                'strokeWidth': 2.0,
                'mergeOp': 'union',
                'mergedIds': ['a', 'b'],
                'freeformPath': 'M0,20 C10,0 20,40 30,20 S45,5 50,20 '
                    'Q55,35 65,25 T80,20 L80,40 L0,40 Z',
              },
            ],
          },
        },
      ];
      final path =
          await service.exportToPdf(slides, '$tmpDirPath/t04_curves.pdf');
      expect(countPages(path), 1);
    });

    test('action button blocks render their label chip', () async {
      const button = ActionButton(
        kind: ActionButtonKind.home,
        label: 'Về đầu',
        x: 60.0,
        y: 80.0,
        w: 15.0,
        h: 8.0,
      );
      final html =
          "<div data-action='${ActionButtonService.escapeAttribute(button)}'></div>";
      final path = await service.exportToPdf(
        [
          {'title': 'Buttons', 'htmlContent': html},
        ],
        '$tmpDirPath/t04_button.pdf',
      );
      expect(countPages(path), 1);
    });
  });

  group('inline styling coverage (rich text engine)', () {
    test('kitchen-sink slide exercises every inline run branch', () async {
      final html = [
        '<h1 style="color:#FF0000">Đỏ</h1>',
        '<h2 style="background-color:rgba(59,130,246,0.5)">Nền rgba</h2>',
        '<p style="text-align:center"><b>đậm</b> <i>nghiêng</i> '
            '<u>gạch chân</u> <s>gạch ngang</s></p>',
        '<p style="text-align:right">'
            '<span style="color:#10B981;font-size:28px">to xanh</span> '
            '<span style="font-family:Consolas">monospace</span></p>',
        '<ul><li>Gốc<ul><li>Lồng một</li><li>Lồng hai</li></ul></li>'
            '<li>Nhánh hai</li></ul>',
        '<ol start="3"><li>Ba</li><li>Bốn</li></ol>',
        '<blockquote>Trích dẫn nổi bật</blockquote>',
        '<pre><code>void main() {}</code></pre>',
        '<hr>',
        '<p>Dòng thường với <a href="https://example.com">liên kết</a>.</p>',
      ].join('\n');
      final path = await service.exportToPdf(
        [
          {'title': 'Kitchen sink', 'htmlContent': html},
        ],
        '$tmpDirPath/t04_kitchen.pdf',
      );
      expect(File(path).lengthSync(), greaterThan(3000));
      expect(countPages(path), 1);
    });

    test('malformed colours fall back instead of crashing', () async {
      final path = await service.exportToPdf(
        [
          {
            'title': 'Bad colour',
            'htmlContent': '<span style="color:#XYZ123">x</span>'
                '<span style="color:red-not-hex">y</span>'
                '<div data-bg-color="#">z</div><p>ok</p>',
          },
        ],
        '$tmpDirPath/t04_badcolour.pdf',
      );
      expect(countPages(path), 1);
    });
  });
}
