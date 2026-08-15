/// Printing & handouts (Track 43, FEAT 69/70).
///
/// Two layers:
///
///  * **Layout** — [HandoutLayout] turns slides into a multi-slide-per-page
///    PDF via the `printing` widgets API ([pw.Document], no platform
///    channel needed → fully unit-testable). Thumbnails come from
///    [SlideFrameRenderer]; speaker notes are printed under each thumbnail
///    when [PrintJobOptions.includeNotes] is set.
///  * **Send to printer** — [PrintService.printPdf] hands the document to
///    the Windows print dialog via `Printing.layoutPdf` (app layer only).
library;

import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pwpdf;
import 'package:pdf/widgets.dart' as pw;

import 'slide_frame_renderer.dart';

/// How many slides per printed page (standard PowerPoint handout patterns).
enum HandoutPerPage { two, three, four, six, nine }

/// Options for a print job.
class PrintJobOptions {
  const PrintJobOptions({
    this.perPage = HandoutPerPage.six,
    this.includeNotes = false,
    this.printHiddenSlides = false,
    this.grayscale = false,
    this.border = true,
    this.startSlide = 0,
    this.endSlide,
    this.thumbScale = 1,
  });

  final HandoutPerPage perPage;
  final bool includeNotes;
  final bool printHiddenSlides;

  /// Render thumbnails in grayscale (black & white printing).
  final bool grayscale;
  final bool border;

  /// 0-based inclusive range (null end = last slide).
  final int startSlide;
  final int? endSlide;
  final int thumbScale;
}

/// One handout page layout (rows × cols).
class HandoutGrid {
  final int rows;
  final int cols;
  const HandoutGrid(this.rows, this.cols);
}

class PrintService {
  PrintService._();

  /// Grid for each handout density (rows × columns).
  static HandoutGrid gridFor(HandoutPerPage perPage) => switch (perPage) {
        HandoutPerPage.two => const HandoutGrid(1, 2),
        HandoutPerPage.three => const HandoutGrid(1, 3),
        HandoutPerPage.four => const HandoutGrid(2, 2),
        HandoutPerPage.six => const HandoutGrid(2, 3),
        HandoutPerPage.nine => const HandoutGrid(3, 3),
      };

  /// Render the handout document as PDF bytes (pure layout, testable).
  ///
  /// Layout: a [pw.MultiPage] with one [pw.Row] per handout row; cells are
  /// [pw.Expanded] columns (thumbnail + optional notes + slide number).
  /// MultiPage flows the rows onto fresh pages, so any slide count works.
  static Future<Uint8List> buildHandoutPdf(
    List<Map<String, dynamic>> slides, {
    PrintJobOptions options = const PrintJobOptions(),
  }) async {
    if (slides.isEmpty) throw ArgumentError('Nothing to print');
    final doc = pw.Document();
    final grid = gridFor(options.perPage);
    final thumbW = (320 * options.thumbScale).round();
    final thumbH = (180 * options.thumbScale).round();
    final thumbAspect = thumbH / thumbW;

    final start = options.startSlide.clamp(0, slides.length - 1);
    final end = (options.endSlide ?? slides.length - 1)
        .clamp(start, slides.length - 1);
    final visible = <Map<String, dynamic>>[];
    for (var i = start; i <= end; i++) {
      if (!options.printHiddenSlides && slides[i]['hidden'] == true) continue;
      visible.add(slides[i]);
    }
    if (visible.isEmpty) throw ArgumentError('Nothing to print');

    // A4 portrait; cell height derived from the column width.
    const page = pwpdf.PdfPageFormat.a4;
    const margin = 24.0;
    final usableW = page.width - 2 * margin;
    final cellW = usableW / grid.cols;
    final cellH = cellW * thumbAspect + (options.includeNotes ? 34 : 14);

    doc.addPage(
      pw.MultiPage(
        pageFormat: page,
        margin: const pw.EdgeInsets.all(margin),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 9)),
        ),
        build: (ctx) {
          final rows = <pw.Widget>[];
          for (var k = 0; k < visible.length; k += grid.cols) {
            final endK = (k + grid.cols).clamp(0, visible.length);
            final cells = <pw.Widget>[];
            for (var j = k; j < endK; j++) {
              cells.add(pw.Expanded(
                child: _handoutCell(visible[j], j, options,
                    thumbW: thumbW, thumbH: thumbH, cellH: cellH),
              ));
            }
            // Pad the last row to keep the grid aligned.
            while (cells.length < grid.cols) {
              cells.add(pw.Expanded(child: pw.Container(height: cellH)));
            }
            rows.add(pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: cells,
            ));
          }
          return rows;
        },
      ),
    );
    return doc.save();
  }

  /// One handout cell: thumbnail + optional first notes line + slide number.
  static pw.Widget _handoutCell(
    Map<String, dynamic> slide,
    int index,
    PrintJobOptions options, {
    required int thumbW,
    required int thumbH,
    required double cellH,
  }) {
    final children = <pw.Widget>[];
    final thumb = SlideFrameRenderer.renderSlide(
      slide,
      width: thumbW,
      height: thumbH,
    );
    if (thumb != null) {
      var bytes = thumb.pngBytes;
      if (options.grayscale) bytes = _grayscale(bytes);
      children.add(pw.Image(
        pw.MemoryImage(bytes),
        fit: pw.BoxFit.contain,
        width: double.infinity,
      ));
    }
    if (options.includeNotes) {
      final notes = (slide['notes'] ?? '').toString().trim();
      if (notes.isNotEmpty) {
        children.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            notes.split('\n').first,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: const pw.TextStyle(fontSize: 7),
          ),
        ));
      }
    }
    children.add(pw.Text('${index + 1}',
        style: const pw.TextStyle(fontSize: 7)));
    return pw.Container(
      height: cellH,
      padding: const pw.EdgeInsets.only(right: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// Desaturate PNG bytes to grayscale (black & white printing).
  static Uint8List _grayscale(Uint8List pngBytes) {
    final image = img.decodeImage(pngBytes);
    if (image == null) return pngBytes;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final g = (p.r * 0.299 + p.g * 0.587 + p.b * 0.114).round();
        image.setPixelRgba(x, y, g, g, g, p.a);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }
}
