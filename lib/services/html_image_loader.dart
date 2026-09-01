import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'image_codec.dart';
import 'image_optimizer_service.dart';

/// A decoded image ready to be embedded into an export (PPTX/PDF).
class LoadedImage {
  final Uint8List bytes;
  final String ext; // png, jpg, gif
  final int width;
  final int height;

  LoadedImage({
    required this.bytes,
    required this.ext,
    required this.width,
    required this.height,
  });
}

/// Why an image could not be embedded (dirty bytes, oversized fetch, HTTP
/// error, …). Collected per export job and written to `*.warnings.log`.
class ImageLoadWarning {
  const ImageLoadWarning(this.src, this.reason);

  final String src;
  final String reason;

  @override
  String toString() => '$src: $reason';
}

/// Loads `<img src="...">` sources for export embedding (Track 03).
///
/// Supported sources:
///
///  * base64 data URIs (`data:image/png;base64,…`),
///  * local file paths,
///  * remote http/https URLs — fetched at export time with a 10 s timeout,
///    a 10 MB size cap and `image/*` content-type validation, then served
///    from an in-memory cache plus a disk cache under the app cache folder.
///
/// The pipeline prefetches every remote image ([prefetchSlides]) before
/// generation starts; the synchronous [load] then serves raw bytes from the
/// caches and applies the deterministic processing shared by PPTX/PDF/HTML:
/// EXIF orientation is baked in, oversized images are downscaled, and large
/// opaque PNGs may be re-encoded as JPEG ([allowJpeg]) to shrink the deck.
class HtmlImageLoader {
  static final RegExp _dataUriRegExp =
      RegExp(r'^data:image/(png|jpe?g|gif);base64,(.+)$', dotAll: true);

  static final RegExp _imgSrcRegExp =
      RegExp(r"""<img[^>]+src=["']([^"']+)["']""", caseSensitive: false);

  /// Remote fetch guardrails (Track 03, phase 2).
  static const Duration _remoteTimeout = Duration(seconds: 10);
  static const int _maxRemoteBytes = 10 * 1024 * 1024; // 10 MB

  static const int _memoryCacheCapacity = 64;

  // ---- Caches -----------------------------------------------------------

  static final Map<String, _RawImage> _rawCache = {}; // src → raw bytes
  static final Map<String, LoadedImage> _processedCache = {}; // src|opts → result

  /// Test override for the disk-cache directory (defaults to the app cache).
  static String? debugCacheDir;

  /// Per-job warnings (phase 7): cleared by [clearWarnings], written by
  /// [writeWarningsLog] once an export finishes.
  static final List<ImageLoadWarning> warnings = [];

  /// N2: per-export savings tally is cleared together with the warnings so
  /// every export starts from a clean slate (and the dialog shows the latest
  /// job only).
  static void clearWarnings() {
    warnings.clear();
    ImageOptimizationStats.reset();
  }

  static String _cacheDir() {
    final override = debugCacheDir;
    if (override != null && override.isNotEmpty) return override;
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      return '$localAppData\\GhitaPPT\\image_cache';
    }
    return '${Directory.systemTemp.path}/ghita_image_cache';
  }

  /// Drop the in-memory caches and warnings (session reset, tests).
  static void clearCaches() {
    _rawCache.clear();
    _processedCache.clear();
    warnings.clear();
  }

  static void _warn(String src, String reason) {
    if (warnings.length >= 100) return;
    warnings.add(ImageLoadWarning(src, reason));
  }

  /// Write the job's image warnings to `<outputPath>.warnings.log`.
  static Future<void> writeWarningsLog(String outputPath) async {
    if (warnings.isEmpty) return;
    final file = File('$outputPath.warnings.log');
    try {
      await file.writeAsString(
        warnings.map((w) => w.toString()).join('\n'),
        flush: true,
      );
    } catch (_) {
      // Logging must never fail the export.
    }
  }

  // ---- Remote prefetch (phase 2 + 3) ------------------------------------

  /// Fetch every remote image referenced by [slides] into the caches.
  ///
  /// Best-effort: failed fetches are recorded as warnings and the export
  /// continues without those images. Runs before the (synchronous) generation
  /// so the sync [load] can serve remote sources from the caches.
  static Future<void> prefetchSlides(List<Map<String, dynamic>> slides) async {
    final srcs = <String>{};
    for (final slide in slides) {
      final html = (slide['htmlContent'] ?? '').toString();
      for (final match in _imgSrcRegExp.allMatches(html)) {
        final src = match.group(1)?.trim() ?? '';
        if (src.isEmpty) continue;
        if (src.startsWith('http://') || src.startsWith('https://')) {
          srcs.add(src);
        }
      }
    }
    if (srcs.isEmpty) return;

    // Bound concurrency so slow servers cannot pile up sockets.
    final queue = srcs.toList();
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= queue.length) return;
        await _ensureRaw(queue[index]);
      }
    }

    const parallel = 4;
    await Future.wait([
      for (var i = 0; i < parallel && i < queue.length; i++) worker(),
    ]);
  }

  static Future<void> _ensureRaw(String src) async {
    if (_rawCache.containsKey(src)) return;
    final cached = await _readDiskCache(src);
    if (cached != null) {
      _rawCache[src] = cached;
      return;
    }
    final fetched = await _fetchRemote(src);
    if (fetched == null) return; // warning already recorded
    _rawCache[src] = fetched;
    await _writeDiskCache(src, fetched);
  }

  /// Fetch one remote image with the phase-2 guardrails.
  static Future<_RawImage?> _fetchRemote(String src) async {
    final client = HttpClient()..connectionTimeout = _remoteTimeout;
    try {
      final request = await client
          .getUrl(Uri.parse(src))
          .timeout(_remoteTimeout);
      final response = await request.close().timeout(_remoteTimeout);
      if (response.statusCode != 200) {
        _warn(src, 'HTTP ${response.statusCode}');
        return null;
      }
      if (response.contentLength > _maxRemoteBytes) {
        _warn(src, 'larger than 10 MB');
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > _maxRemoteBytes) {
          _warn(src, 'larger than 10 MB');
          return null;
        }
      }
      final bytes = builder.takeBytes();
      final ext = _extFromResponse(src, response.headers.contentType?.mimeType, bytes);
      if (ext == null) {
        _warn(src, 'not an image (image/* expected)');
        return null;
      }
      return _RawImage(bytes, ext);
    } catch (e) {
      _warn(src, 'fetch failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static String? _extFromResponse(String src, String? mimeType, Uint8List bytes) {
    // An explicit non-image content-type wins over every fallback.
    if (mimeType != null && !mimeType.startsWith('image/')) return null;
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/jpeg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
    }
    // Header missing or unhelpful: sniff the magic bytes.
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'gif';
    }
    // Last resort: trust the URL extension only when nothing says otherwise.
    final lower = src.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    if (lower.endsWith('.gif')) return 'gif';
    return null;
  }

  static String _diskPath(String src) =>
      '${_cacheDir()}\\${_sha256Hex(src)}';

  static Future<_RawImage?> _readDiskCache(String src) async {
    try {
      final file = File(_diskPath(src));
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      final ext = _extFromResponse(src, null, bytes);
      if (ext == null) return null;
      return _RawImage(bytes, ext);
    } catch (_) {
      return null;
    }
  }

  static _RawImage? _readDiskCacheSync(String src) {
    try {
      final file = File(_diskPath(src));
      if (!file.existsSync()) return null;
      final bytes = file.readAsBytesSync();
      final ext = _extFromResponse(src, null, bytes);
      if (ext == null) return null;
      return _RawImage(bytes, ext);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeDiskCache(String src, _RawImage raw) async {
    try {
      final file = File(_diskPath(src));
      await file.create(recursive: true);
      await file.writeAsBytes(raw.bytes, flush: true);
    } catch (_) {
      // Best-effort disk cache.
    }
  }

  // ---- Synchronous load (shared by PPTX/PDF/HTML) -----------------------

  /// Load an exportable image.
  ///
  /// [maxWidth] downscales wider images; [allowJpeg] re-encodes large opaque
  /// PNGs as JPEG at [jpegQuality] (keeps alpha images and GIFs as-is);
  /// EXIF orientation is always baked before embedding.
  static LoadedImage? load(
    String src, {
    int? maxWidth,
    bool allowJpeg = false,
    int jpegQuality = 80,
  }) {
    final trimmed = src.trim();
    if (trimmed.isEmpty) return null;

    // N2 beta: with the flag on the configured quality drives the PNG→JPEG
    // re-encode (and savings are tallied); off runs exactly as before.
    final effectiveQuality =
        ImageOptimizerConfig.betaEnabled ? ImageOptimizerConfig.quality : jpegQuality;

    final optionsKey =
        '$trimmed\u0000$maxWidth\u0000$allowJpeg\u0000$effectiveQuality'
        '\u0000${ImageOptimizerConfig.betaEnabled ? 1 : 0}';
    final cachedResult = _processedCache[optionsKey];
    if (cachedResult != null) return cachedResult;
    // T07 P5: disk cache for processed images — the same image+options must
    // not be re-decoded and re-encoded on every export.
    final onDisk = _readProcessedDisk(optionsKey);
    if (onDisk != null) {
      _cacheProcessed(optionsKey, onDisk);
      return onDisk;
    }

    final raw = _rawFor(trimmed);
    if (raw == null) return null;

    final result = _process(raw,
        maxWidth: maxWidth, allowJpeg: allowJpeg, jpegQuality: effectiveQuality);
    if (result != null) {
      _cacheProcessed(optionsKey, result);
      _writeProcessedDisk(optionsKey, result);
    }
    return result;
  }

  // ---- Processed-image disk cache (T07 P5) --------------------------------

  static String _processedDiskPath(String optionsKey) =>
      '${_cacheDir()}\\proc_${_sha256Hex(optionsKey)}';

  static LoadedImage? _readProcessedDisk(String optionsKey) {
    try {
      final base = _processedDiskPath(optionsKey);
      final file = File(base);
      final meta = File('$base.json');
      if (!file.existsSync() || !meta.existsSync()) return null;
      final map = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
      if (map['opts'] != optionsKey) return null;
      return LoadedImage(
        bytes: file.readAsBytesSync(),
        ext: map['ext'] as String,
        width: map['width'] as int,
        height: map['height'] as int,
      );
    } catch (_) {
      return null; // corrupt/stale cache entry — reprocess next time.
    }
  }

  static void _writeProcessedDisk(String optionsKey, LoadedImage image) {
    try {
      final base = _processedDiskPath(optionsKey);
      File(base).writeAsBytesSync(image.bytes, flush: true);
      File('$base.json').writeAsStringSync(
        jsonEncode({
          'opts': optionsKey,
          'ext': image.ext,
          'width': image.width,
          'height': image.height,
        }),
        flush: true,
      );
    } catch (_) {
      // Best-effort disk cache — never fails an export.
    }
  }

  /// Raw bytes for [src]: caches for remote/data-URI, fresh read for local
  /// files so on-disk edits are picked up.
  static _RawImage? _rawFor(String src) {
    final dataMatch = _dataUriRegExp.firstMatch(src);
    if (dataMatch != null) {
      final cached = _rawCache[src];
      if (cached != null) return cached;
      try {
        final bytes = base64Decode(dataMatch.group(2)!.replaceAll(RegExp(r'\s'), ''));
        final raw = _RawImage(bytes, _normalizeExt(dataMatch.group(1)!));
        if (_rawCache.length >= _memoryCacheCapacity) _rawCache.remove(_rawCache.keys.first);
        _rawCache[src] = raw;
        return raw;
      } catch (_) {
        _warn(src, 'invalid base64 data URI');
        return null;
      }
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      final cached = _rawCache[src];
      if (cached != null) return cached;
      // Fall back to the disk cache (populated by a previous session).
      final onDisk = _readDiskCacheSync(src);
      if (onDisk != null) {
        if (_rawCache.length >= _memoryCacheCapacity) {
          _rawCache.remove(_rawCache.keys.first);
        }
        _rawCache[src] = onDisk;
        return onDisk;
      }
      _warn(src, 'not prefetched (remote images load before export)');
      return null;
    }
    // Local file path (absolute or relative).
    try {
      final file = File(src);
      if (!file.existsSync()) {
        _warn(src, 'file not found');
        return null;
      }
      final bytes = file.readAsBytesSync();
      final dotIndex = src.lastIndexOf('.');
      final ext = dotIndex == -1
          ? null
          : _normalizeExt(src.substring(dotIndex + 1).toLowerCase());
      if (ext == null || !const ['png', 'jpg', 'gif'].contains(ext)) {
        _warn(src, 'unsupported image extension');
        return null;
      }
      return _RawImage(bytes, ext);
    } catch (e) {
      _warn(src, 'unreadable file: $e');
      return null;
    }
  }

  /// Decode, bake EXIF, downscale, optionally convert PNG→JPEG, re-encode —
  /// delegated to [ImageCodec] (Rust `ghita_image` when the engine prefers it
  /// and the DLL is ready in this isolate; the Dart implementation otherwise).
  static LoadedImage? _process(
    _RawImage raw, {
    int? maxWidth,
    bool allowJpeg = false,
    int jpegQuality = 80,
  }) {
    ImageCodecResult processed;
    try {
      processed = ImageCodec.process(
        raw.bytes,
        raw.ext,
        maxWidth: maxWidth,
        allowJpeg: allowJpeg,
        jpegQuality: jpegQuality,
      );
    } on FormatException {
      // Some decoders throw on corrupted payloads instead of returning null.
      _warn('image bytes', 'undecodable/dirty image');
      return null;
    }
    if (processed.bytes.isEmpty) {
      _warn('image bytes', 'undecodable/dirty image');
      return null;
    }
    if (ImageOptimizerConfig.betaEnabled &&
        (processed.ext != raw.ext ||
            (processed.changed && processed.resized))) {
      // Same tally rules as before the backend split: PNG→JPEG conversion
      // always counts; resize re-encodes only count their savings.
      ImageOptimizationStats.record(raw.bytes.length, processed.bytes.length);
    }
    return _makeResult(
      processed.bytes,
      processed.ext,
      processed.width,
      processed.height,
    );
  }

  // ---- EXIF orientation: now in ImageCodec (shared Rust/Dart pipeline) ----

  static LoadedImage _makeResult(
    Uint8List bytes,
    String ext,
    int width,
    int height,
  ) {
    return LoadedImage(bytes: bytes, ext: ext, width: width, height: height);
  }

  static void _cacheProcessed(String key, LoadedImage value) {
    if (_processedCache.length >= _memoryCacheCapacity) {
      _processedCache.remove(_processedCache.keys.first);
    }
    _processedCache[key] = value;
  }

  static String _sha256Hex(String input) {
    // FNV-1a 64 — content-addressing for the disk cache; collision-safe
    // enough for cache keys (the raw bytes are validated on read).
    const offset = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    var hash = offset;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static String _normalizeExt(String raw) => raw == 'jpeg' ? 'jpg' : raw;
}

/// Raw undecoded image bytes plus their normalized extension.
class _RawImage {
  _RawImage(this.bytes, this.ext);

  final Uint8List bytes;
  final String ext;
}