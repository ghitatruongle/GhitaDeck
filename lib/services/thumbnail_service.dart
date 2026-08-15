import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/slide.dart';
import 'slide_frame_renderer.dart';

/// Thumbnail service (Track 64, OPT 20).
///
/// Renders slide thumbnails with the pure-Dart [SlideFrameRenderer] (the same
/// pipeline as PPTX/PDF export) so thumbnails work with or without WebView2:
///
/// * [renderThumbnail] → small PNG (default 160×90);
/// * [renderThumbnailB64] → base64 for `.ghita` bundle caching
///   (`media/thumbs/`);
/// * [renderBatch] renders up to [maxConcurrent] frames per pass (RAM guard —
///   a 50-slide deck never holds 50 bitmaps at once);
/// * [extractThumbsFromBundle]/[injectThumbs] read/write the cache.
class ThumbnailService {
  ThumbnailService._();

  static const int defaultMaxConcurrent = 4;

  /// Render one slide to a PNG [Uint8List] (or null when the slide is empty /
  /// render fails — callers fall back to the layoutType placeholder).
  static Uint8List? renderThumbnail(Slide slide, {int width = 160, int height = 90}) {
    try {
      final frame = SlideFrameRenderer.renderSlide(slide.toMap(),
          width: width, height: height);
      if (frame == null) return null;
      return Uint8List.fromList(img.encodePng(frame.image));
    } catch (_) {
      return null;
    }
  }

  /// Base64 PNG for bundle caching.
  static String? renderThumbnailB64(Slide slide,
      {int width = 160, int height = 90}) {
    final bytes = renderThumbnail(slide, width: width, height: height);
    if (bytes == null) return null;
    return base64Encode(bytes);
  }

  /// Render a batch in passes of [maxConcurrent] — bounds peak memory.
  /// Returns a map slideIndex → base64 PNG.
  static Map<int, String> renderBatch(
    List<Slide> slides, {
    int width = 160,
    int height = 90,
    int maxConcurrent = defaultMaxConcurrent,
  }) {
    final result = <int, String>{};
    for (var i = 0; i < slides.length; i += maxConcurrent) {
      final end = (i + maxConcurrent).clamp(0, slides.length);
      for (var j = i; j < end; j++) {
        final b64 = renderThumbnailB64(slides[j], width: width, height: height);
        if (b64 != null) result[j] = b64;
      }
    }
    return result;
  }

  /// Deterministic placeholder for slides that fail to render / when
  /// rendering is unavailable: a colored rect derived from the layout type.
  static String placeholderB64(String layoutType,
      {int width = 160, int height = 90}) {
    final color = switch (layoutType) {
      'title_slide' => 0xFF1F4E79,
      'section_header' => 0xFF7030A0,
      'two_content' => 0xFF2E75B6,
      'comparison' => 0xFFC00000,
      _ => 0xFF4A4A4A,
    };
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8((color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF));
    return base64Encode(img.encodePng(image));
  }

  // -------------------------------------------------------------------------
  // Bundle cache (media/thumbs/ inside the .ghita JSON)
  // -------------------------------------------------------------------------

  /// Extract cached thumbnails from a bundle map (key `media.thumbs`).
  static Map<int, String> thumbsFromBundle(Map<String, dynamic> bundle) {
    final media = bundle['media'];
    if (media is! Map) return const {};
    final thumbs = media['thumbs'];
    if (thumbs is! Map) return const {};
    final result = <int, String>{};
    thumbs.forEach((k, v) {
      final idx = int.tryParse(k.toString());
      if (idx != null && v is String) result[idx] = v;
    });
    return result;
  }

  /// Inject thumbnails into a bundle map (replaces `media.thumbs`).
  static Map<String, dynamic> injectThumbs(
      Map<String, dynamic> bundle, Map<int, String> thumbs) {
    final media = (bundle['media'] is Map)
        ? Map<String, dynamic>.from(bundle['media'] as Map)
        : <String, dynamic>{};
    media['thumbs'] = {
      for (final e in thumbs.entries) '${e.key}': e.value,
    };
    return {...bundle, 'media': media};
  }

  /// Rough byte cost of a thumbnails map (for the ≤10% bundle budget check).
  static int thumbsBytes(Map<int, String> thumbs) {
    var total = 0;
    for (final v in thumbs.values) {
      total += v.length * 3 ~/ 4; // base64 → bytes approx
    }
    return total;
  }
}
