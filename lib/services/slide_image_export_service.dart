/// Batch slide→image export (Track 42, FEAT 68).
///
/// Renders every slide (or a selected range) to PNG / JPEG / WebP files via
/// [SlideFrameRenderer], with an optional transparent PNG mode and an
/// optional single contact-sheet image. Progress is reported through
/// [onProgress] (fraction 0..1 + slide index) and the job is cooperatively
/// cancellable via [cancelToken] — same contract as the Track 01 pipeline.
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'export_primitives.dart';
import 'slide_frame_renderer.dart';

/// Output raster format for slide images.
///
/// WebP is intentionally not offered: the bundled `image` codec only
/// decodes WebP (no encoder), and PNG covers the transparency use-case.
enum SlideImageFormat { png, jpeg }

/// Options for a batch slide→image export job.
class SlideImageExportOptions {
  const SlideImageExportOptions({
    this.format = SlideImageFormat.png,
    this.startSlide = 0,
    this.endSlide,
    this.scale = 2,
    this.transparentBackground = false,
    this.jpegQuality = 90,
    this.prefix = 'slide',
    this.contactSheet = false,
    this.contactSheetColumns = 3,
  });

  final SlideImageFormat format;

  /// 0-based inclusive range. [endSlide] null = last slide.
  final int startSlide;
  final int? endSlide;

  /// Pixel scale vs the 16:9 EMU slide (2 = 2× the 1280×720 default, i.e.
  /// 2560×1440). 1 → 1280×720, 2 → 2560×1440, 3 → 3840×2160.
  final int scale;

  /// PNG only: skip the background fill (transparent alpha).
  final bool transparentBackground;

  final int jpegQuality;
  final String prefix;
  final bool contactSheet;
  final int contactSheetColumns;
}

/// One exported image file.
class ExportedSlideImage {
  final String path;
  final int slideIndex;

  const ExportedSlideImage({required this.path, required this.slideIndex});
}

/// Result of a batch run.
class SlideImageExportResult {
  final List<ExportedSlideImage> files;
  final String? contactSheetPath;

  const SlideImageExportResult({required this.files, this.contactSheetPath});

  int get count => files.length;
}

/// Deterministic per-slide size: 1280×720 at scale 1 (16:9 EMU slide).
class SlideImageExportService {
  SlideImageExportService._();

  /// Pixel size for [scale] (16:9).
  static (int, int) sizeForScale(int scale) {
    final s = scale.clamp(1, 4);
    return (1280 * s, 720 * s);
  }

  static String _extFor(SlideImageFormat f) => switch (f) {
        SlideImageFormat.png => 'png',
        SlideImageFormat.jpeg => 'jpg',
      };

  static Uint8List? _encode(
      img.Image image, SlideImageFormat format, int jpegQuality) {
    switch (format) {
      case SlideImageFormat.png:
        return Uint8List.fromList(img.encodePng(image));
      case SlideImageFormat.jpeg:
        return Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
    }
  }

  /// Render one slide to encoded bytes (no file I/O — testable).
  static Uint8List? renderSlideBytes(
    Map<String, dynamic> slide, {
    required SlideImageExportOptions options,
  }) {
    final (w, h) = sizeForScale(options.scale);
    final frame = SlideFrameRenderer.renderSlide(
      slide,
      width: w,
      height: h,
      transparentBackground: options.transparentBackground,
    );
    if (frame == null) return null;
    return _encode(frame.image, options.format, options.jpegQuality);
  }

  /// Batch-export slides into [outputDir]. Returns the written files.
  ///
  /// When [onProgress] is provided it receives a monotonic 0..1 fraction;
  /// [cancelToken] stops the job cooperatively between slides.
  static Future<SlideImageExportResult> exportSlides(
    List<Map<String, dynamic>> slides,
    String outputDir, {
    SlideImageExportOptions options = const SlideImageExportOptions(),
    ExportCancelToken? cancelToken,
    void Function(double fraction, int slideIndex)? onProgress,
  }) async {
    if (slides.isEmpty) {
      throw ArgumentError('No slides to export.');
    }
    final dir = Directory(outputDir);
    await dir.create(recursive: true);

    final end = options.endSlide ?? slides.length - 1;
    final start = options.startSlide.clamp(0, slides.length - 1);
    final last = end.clamp(start, slides.length - 1);
    final total = last - start + 1;
    final files = <ExportedSlideImage>[];

    for (var i = start; i <= last; i++) {
      cancelToken?.throwIfCancelled();
      onProgress?.call((i - start + 1) / total, i);
      final bytes = renderSlideBytes(slides[i], options: options);
      if (bytes == null) continue;
      final ext = _extFor(options.format);
      final path = '${dir.path}${Platform.pathSeparator}'
          '${options.prefix}_${i + 1}.$ext';
      await File(path).writeAsBytes(bytes, flush: true);
      files.add(ExportedSlideImage(path: path, slideIndex: i));
    }

    String? contactPath;
    if (options.contactSheet && files.isNotEmpty) {
      contactPath = await _writeContactSheet(
        slides,
        files,
        dir.path,
        options: options,
        startSlide: start,
      );
    }
    onProgress?.call(1.0, last);
    return SlideImageExportResult(
        files: files, contactSheetPath: contactPath);
  }

  /// Contact sheet: all exported slides arranged in a grid on one image.
  static Future<String?> _writeContactSheet(
    List<Map<String, dynamic>> slides,
    List<ExportedSlideImage> files,
    String dirPath, {
    required SlideImageExportOptions options,
    required int startSlide,
  }) async {
    final int cols = options.contactSheetColumns.clamp(1, 6);
    const int thumbW = 320;
    const int thumbH = 180;
    const int pad = 12;
    final int rows = (files.length / cols).ceil();
    final int sheetW = cols * thumbW + (cols + 1) * pad;
    final int sheetH = rows * thumbH + (rows + 1) * pad;
    final sheet = img.Image(width: sheetW, height: sheetH, numChannels: 4);
    img.fill(sheet, color: img.ColorRgba8(245, 247, 250, 255));

    for (var k = 0; k < files.length; k++) {
      final bytes = await File(files[k].path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;
      final thumb = img.copyResize(decoded, width: thumbW, height: thumbH);
      final col = k % cols;
      final row = k ~/ cols;
      final dx = pad + col * (thumbW + pad);
      final dy = pad + row * (thumbH + pad);
      img.compositeImage(sheet, thumb, dstX: dx, dstY: dy);
      // Slide number label.
      img.drawString(sheet, '${startSlide + k + 1}',
          font: img.arial24,
          x: dx + 4,
          y: dy + thumbH - 28);
    }
    final ext = _extFor(options.format);
    final path =
        '$dirPath${Platform.pathSeparator}${options.prefix}_contact_sheet.$ext';
    final bytes = _encode(sheet, options.format, options.jpegQuality);
    if (bytes == null) return null;
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
