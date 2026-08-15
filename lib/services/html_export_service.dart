import 'dart:convert';
import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';
import '../models/chart_data.dart';
import '../models/export_options.dart';
import '../models/free_shape.dart';
import '../models/icon_item.dart';
import '../models/media_item.dart';
import '../models/model3d_item.dart';
import '../models/smartart.dart';
import '../models/drawn_shape.dart';
import '../models/object_animation.dart';
import '../models/slide.dart';
import 'animation_engine.dart';
import 'morph_service.dart';
import 'chart_service.dart';
import 'model3d_service.dart';
import 'smartart_service.dart';
import 'action_button_service.dart';
import 'equation_service.dart';
import 'ole_service.dart';
import 'header_footer_service.dart';
import 'zoom_feature_service.dart';
import 'cameo_service.dart';
import 'effect_preview_service.dart';
import 'export_primitives.dart';
import 'html_image_loader.dart';
import 'ppt_generator.dart';

class HtmlExportService {
  static const String _defaultFileName = 'presentation';

  /// Note shown under a 3D model poster in the HTML deck (Track 14, P7).
  static const String _model3dNote =
      '3D model — mở trong PowerPoint để xem & xoay';

  /// In-session deck cache (Track 01, phase 6): building a standalone deck is
  /// pure string work keyed by (slides, options); re-exporting identical
  /// content (same deck, same options, twice in a session) skips the rebuild.
  /// Content-addressed by FNV-1a 64 over the canonical JSON of the inputs,
  /// with a full-source equality check so a hash collision never serves the
  /// wrong deck.
  static const int _deckCacheCapacity = 4;
  static final Map<String, _DeckCacheEntry> _deckCache = {};
  static int deckCacheHits = 0;
  static int deckCacheMisses = 0;

  static String _fnv1a64(String input) {
    const offset = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    var hash = offset;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Reset the in-session deck cache (session reset, tests).
  static void clearDeckCache() {
    _deckCache.clear();
    deckCacheHits = 0;
    deckCacheMisses = 0;
  }

  Future<String> exportToHtml(
    List<Map<String, dynamic>> slides, {
    String? fileName,
    ExportAspectRatio aspectRatio = ExportAspectRatio.widescreen16x9,
    bool includeNotes = false,
    bool includeBackgrounds = true,
    int? imageMaxWidth,
    String playerLocale = 'en',
    ExportCancelToken? cancelToken,
  }) async {
    if (slides.isEmpty) {
      throw Exception('No slides to export.');
    }

    final safeName = (fileName ?? _defaultFileName).replaceAll(
      RegExp(r'[^\w.\-]'),
      '_',
    );
    final htmlContent = _deckHtml(
      slides,
      aspectRatio: aspectRatio,
      includeNotes: includeNotes,
      includeBackgrounds: includeBackgrounds,
      imageMaxWidth: imageMaxWidth,
      playerLocale: playerLocale,
      cancelToken: cancelToken,
    );

    final Directory targetDir = await getApplicationDocumentsDirectory();
    final String fullPath = '${targetDir.path}/$safeName.html';
    final File htmlFile = File(fullPath);
    await htmlFile.create(recursive: true);
    await htmlFile.writeAsString(htmlContent, flush: true);
    return htmlFile.path;
  }

  /// Export the HTML deck to an explicit file path (save-as dialog).
  Future<String> exportToHtmlPath(
    List<Map<String, dynamic>> slides,
    String filePath, {
    ExportAspectRatio aspectRatio = ExportAspectRatio.widescreen16x9,
    bool includeNotes = false,
    bool includeBackgrounds = true,
    int? imageMaxWidth,
    String playerLocale = 'en',
    ExportCancelToken? cancelToken,
  }) async {
    if (slides.isEmpty) {
      throw Exception('No slides to export.');
    }
    final htmlContent = _deckHtml(
      slides,
      aspectRatio: aspectRatio,
      includeNotes: includeNotes,
      includeBackgrounds: includeBackgrounds,
      imageMaxWidth: imageMaxWidth,
      playerLocale: playerLocale,
      cancelToken: cancelToken,
    );
    final File htmlFile = File(filePath);
    await htmlFile.create(recursive: true);
    await htmlFile.writeAsString(htmlContent, flush: true);
    return htmlFile.path;
  }

  /// Build the standalone presentation HTML (used by in-app present mode).
  ///
  /// [startIndex] selects the first visible slide (for "Present From Current");
  /// [autoAdvance] enables automatic slide advancement in the embedded player.
  /// [imageMaxWidth] limits the width of embedded images to reduce memory usage.
  String buildPresentationHtml(
    List<Map<String, dynamic>> slides, {
    int startIndex = 0,
    Duration? autoAdvance,
    int? imageMaxWidth,
    String playerLocale = 'en',
    ExportCancelToken? cancelToken,
    DeckMeta? deckMeta,
  }) {
    return _deckHtml(
      slides,
      startIndex: startIndex,
      autoAdvance: autoAdvance,
      imageMaxWidth: imageMaxWidth,
      playerLocale: playerLocale,
      cancelToken: cancelToken,
      deckMeta: deckMeta,
    );
  }

  /// Standalone deck builder with an in-session hash cache: identical inputs
  /// return the previously built HTML instead of rebuilding it from scratch.
  String _deckHtml(
    List<Map<String, dynamic>> slides, {
    int startIndex = 0,
    Duration? autoAdvance,
    ExportAspectRatio aspectRatio = ExportAspectRatio.widescreen16x9,
    bool includeNotes = false,
    bool includeBackgrounds = true,
    int? imageMaxWidth,
    String playerLocale = 'en',
    ExportCancelToken? cancelToken,
    DeckMeta? deckMeta,
  }) {
    final keySource = jsonEncode([
      slides,
      aspectRatio.name,
      includeNotes,
      includeBackgrounds,
      imageMaxWidth,
      startIndex,
      autoAdvance?.inMilliseconds ?? 0,
      playerLocale,
      deckMeta?.toJson() ?? '',
    ]);
    final key = _fnv1a64(keySource);
    final hit = _deckCache[key];
    if (hit != null && hit.source == keySource) {
      deckCacheHits++;
      _deckCache.remove(key);
      _deckCache[key] = hit; // refresh LRU position
      return hit.html;
    }
    cancelToken?.throwIfCancelled();
    deckCacheMisses++;
    final html = _buildHtmlPresentation(
      slides,
      startIndex: startIndex,
      autoAdvance: autoAdvance,
      aspectRatio: aspectRatio,
      includeNotes: includeNotes,
      includeBackgrounds: includeBackgrounds,
      imageMaxWidth: imageMaxWidth,
      playerLocale: playerLocale,
      cancelToken: cancelToken,
      deckMeta: deckMeta,
    );
    _deckCache[key] = _DeckCacheEntry(keySource, html);
    if (_deckCache.length > _deckCacheCapacity) {
      _deckCache.remove(_deckCache.keys.first);
    }
    return html;
  }

  String _buildHtmlPresentation(
    List<Map<String, dynamic>> slides, {
    int startIndex = 0,
    Duration? autoAdvance,
    ExportAspectRatio aspectRatio = ExportAspectRatio.widescreen16x9,
    bool includeNotes = false,
    bool includeBackgrounds = true,
    int? imageMaxWidth,
    String playerLocale = 'en',
    ExportCancelToken? cancelToken,
    DeckMeta? deckMeta,
  }) {
    final buffer = StringBuffer();
    cancelToken?.throwIfCancelled();
    // Clamp safely — the caller guards against empty decks, but keep this
    // robust in case a deck becomes empty between build and render.
    final int initIndex =
        slides.isEmpty ? 0 : startIndex.clamp(0, slides.length - 1).toInt();
    final int autoMs = autoAdvance?.inMilliseconds ?? 0;
    final t = _playerTitles(playerLocale);

    // Collect per-slide background colors and transition effects
    final slideBgStyles = <String>[];
    final slideTransitions = <String>[];
    final usedEffects = <SlideEffect>{};
    for (int i = 0; i < slides.length; i++) {
      final slide = slides[i];
      final color = includeBackgrounds ? _extractSlideBgColor(slide) : null;
      if (color != null) {
        slideBgStyles.add('#slide-$i { background-color: #$color; }');
      }
      // Parse per-slide transition effect
      final effectName = slides[i]['effect'] as String?;
      if (effectName != null && effectName.isNotEmpty && effectName != 'none') {
        try {
          final effect = SlideEffect.values.byName(effectName);
          slideTransitions.add('"slide-$i": "${effect.name}"');
          usedEffects.add(effect);
        } catch (_) {}
      }
    }

    final bgStylesBlock = slideBgStyles.join('\n  ');
    final transitionBlock = slideTransitions.join(',');

    // Generate CSS for the effects this deck actually uses (Track 07, P2):
    // one short class per effect, duplicated keyframes emitted only once.
    final effectsCss = EffectPreviewService.generateEffectsCss(
      usedEffects,
      duration: 0.6,
    );

    // Track 29, P3: per-object animations from visualElements. Collected by
    // slide index so the CSS block and the player JS can reference them.
    final slideAnimations = <int, List<ObjectAnimation>>{};
    final allAnimations = <ObjectAnimation>[];
    for (var i = 0; i < slides.length; i++) {
      final rawVisual = slides[i]['visualElements'];
      final raw = rawVisual is Map ? rawVisual['animations'] : null;
      if (raw is List && raw.isNotEmpty) {
        final anims = raw
            .map((e) => e is Map<String, dynamic>
                ? ObjectAnimation.fromMap(e)
                : (e is Map
                    ? ObjectAnimation.fromMap(Map<String, dynamic>.from(e))
                    : null))
            .whereType<ObjectAnimation>()
            .toList();
        slideAnimations[i] = anims;
        allAnimations.addAll(anims);
      }
    }
    final animationsCss = allAnimations.isEmpty
        ? ''
        : '\n  /* Object animations (Track 29) */\n  ${AnimationEngine.cssFor(allAnimations)}';

    // Track 34, P3: morph CSS — each slide with morphFromPrevious gets
    // FLIP keyframes matching its shapes against the previous slide.
    final morphCss = StringBuffer();
    for (var i = 1; i < slides.length; i++) {
      final cur = slides[i];
      if (cur['morphFromPrevious'] != true) continue;
      final prevVisual = slides[i - 1]['visualElements'];
      final curVisual = cur['visualElements'];
      if (prevVisual is! Map || curVisual is! Map) continue;
      final pairs = MorphService.match(
        Map<String, dynamic>.from(prevVisual).drawnShapes(),
        Map<String, dynamic>.from(curVisual).drawnShapes(),
      );
      if (pairs.isEmpty) continue;
      morphCss.write(MorphService.cssFor(pairs, slideWidthPx: 1280, slideHeightPx: 720));
    }
    final morphCssBlock = morphCss.isEmpty
        ? ''
        : '\n  /* Morph transitions (Track 34) */\n  $morphCss';

    buffer.write('<!DOCTYPE html>');
    buffer.write('<html lang="en">');
    buffer.write('<head>');
    buffer.write('<meta charset="UTF-8">');
    buffer.write(
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.write('<title>Presentation</title>');
    buffer.write('<style>');
    buffer.write('  * { margin: 0; padding: 0; box-sizing: border-box; }');
    buffer.write('  body {');
    buffer.write(
        "    font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;");
    buffer.write('    background: #1a1a2e;');
    buffer.write('    overflow: hidden;');
    buffer.write('    height: 100vh;');
    buffer.write('    width: 100vw;');
    buffer.write('    display: grid;');
    buffer.write('    place-items: center;');
    buffer.write('  }');
    buffer.write('  .deck {');
    buffer.write('    position: relative;');
    buffer.write('    aspect-ratio: ${aspectRatio.cssAspectRatio};');
    buffer.write('    width: min(100vw, calc(100vh * ${aspectRatio.ratio}));');
    buffer.write('    height: auto;');
    buffer.write('    overflow: hidden;');
    buffer.write('  }');
    buffer.write('  .slide {');
    buffer.write('    position: absolute;');
    buffer.write('    top: 0; left: 0;');
    buffer.write('    width: 100%;');
    buffer.write('    height: 100%;');
    buffer.write('    display: none;');
    buffer.write('    padding: 5vh 8vw;');
    buffer.write('    overflow-y: auto;');
    buffer.write('    color: #e0e0e0;');
    buffer.write('    animation: fadeIn 0.5s ease;');
    buffer.write('  }');
    buffer.write(
        '  .slide.active { display: flex; flex-direction: column; justify-content: center; }');
    buffer.write('  @keyframes fadeIn {');
    buffer.write('    from { opacity: 0; transform: translateY(10px); }');
    buffer.write('    to { opacity: 1; transform: translateY(0); }');
    buffer.write('  }');
    buffer.write('  .slide h1 {');
    buffer.write('    font-size: clamp(1.8rem, 4vw, 3.5rem);');
    buffer.write('    font-weight: 700;');
    buffer.write('    margin-bottom: 0.3em;');
    buffer.write('    line-height: 1.2;');
    buffer.write('    color: #ffffff;');
    buffer.write('  }');
    buffer.write('  .slide h2 {');
    buffer.write('    font-size: clamp(1.2rem, 2.5vw, 2rem);');
    buffer.write('    font-weight: 500;');
    buffer.write('    margin-bottom: 1em;');
    buffer.write('    color: #cccccc;');
    buffer.write('    font-style: italic;');
    buffer.write('  }');
    buffer.write('  .slide p {');
    buffer.write('    font-size: clamp(0.95rem, 1.8vw, 1.4rem);');
    buffer.write('    line-height: 1.7;');
    buffer.write('    margin-bottom: 0.8em;');
    buffer.write('    color: #d0d0d0;');
    buffer.write('  }');
    buffer.write('  .slide b, .slide strong { color: #ffffff; }');
    buffer.write('  .slide i, .slide em { color: #bbbbbb; }');
    buffer.write('  .slide video {');
    buffer.write('    width: min(100%, 960px);');
    buffer.write('    max-height: 62vh;');
    buffer.write('    display: block;');
    buffer.write('    margin: 0 auto 0.4em auto;');
    buffer.write('    border-radius: 8px;');
    buffer.write('    background: #000;');
    buffer.write('  }');
    buffer.write('  .ghita-video-bookmarks {');
    buffer.write('    display: flex;');
    buffer.write('    flex-wrap: wrap;');
    buffer.write('    gap: 0.5em;');
    buffer.write('    justify-content: center;');
    buffer.write('    margin-bottom: 0.8em;');
    buffer.write('  }');
    buffer.write('  .ghita-video-bookmarks button {');
    buffer.write('    background: rgba(255,255,255,0.12);');
    buffer.write('    color: #e0e0e0;');
    buffer.write('    border: 1px solid rgba(255,255,255,0.25);');
    buffer.write('    border-radius: 999px;');
    buffer.write('    padding: 0.25em 0.8em;');
    buffer.write('    font-size: 0.85rem;');
    buffer.write('    cursor: pointer;');
    buffer.write('  }');
    buffer.write('  .ghita-video-bookmarks button:hover { background: rgba(255,255,255,0.25); }');
    buffer.write('  .ghita-video-youtube {');
    buffer.write('    position: relative;');
    buffer.write('    display: block;');
    buffer.write('    width: min(100%, 960px);');
    buffer.write('    margin: 0 auto;');
    buffer.write('    border-radius: 8px;');
    buffer.write('    overflow: hidden;');
    buffer.write('    text-decoration: none;');
    buffer.write('  }');
    buffer.write('  .ghita-video-youtube img { width: 100%; display: block; }');
    buffer.write('  .ghita-video-play {');
    buffer.write('    position: absolute;');
    buffer.write('    top: 50%; left: 50%;');
    buffer.write('    transform: translate(-50%, -50%);');
    buffer.write('    width: 3.2em; height: 3.2em;');
    buffer.write('    border-radius: 50%;');
    buffer.write('    background: rgba(0,0,0,0.65);');
    buffer.write('    color: #fff;');
    buffer.write('    display: grid; place-items: center;');
    buffer.write('    font-size: 1.1rem;');
    buffer.write('    border: 2px solid rgba(255,255,255,0.9);');
    buffer.write('  }');
    buffer.write('  .slide audio {');
    buffer.write('    width: min(100%, 420px);');
    buffer.write('    display: block;');
    buffer.write('    margin: 0.4em auto 0.2em auto;');
    buffer.write('  }');
    buffer.write('  .ghita-audio-toggle {');
    buffer.write('    background: rgba(255,255,255,0.14);');
    buffer.write('    border: 1px solid rgba(255,255,255,0.3);');
    buffer.write('    color: #fff;');
    buffer.write('    border-radius: 50%;');
    buffer.write('    width: 2.6em; height: 2.6em;');
    buffer.write('    font-size: 1.05rem;');
    buffer.write('    cursor: pointer;');
    buffer.write('    display: block;');
    buffer.write('    margin: 0 auto;');
    buffer.write('  }');
    buffer.write('  .ghita-audio-toggle:hover { background: rgba(255,255,255,0.3); }');
    buffer.write('  .ghita-model3d {');
    buffer.write('    margin: 0 auto 0.6em auto;');
    buffer.write('    max-width: min(100%, 720px);');
    buffer.write('  }');
    buffer.write('  .ghita-model3d svg {');
    buffer.write('    width: 100%;');
    buffer.write('    display: block;');
    buffer.write('    border-radius: 8px;');
    buffer.write('  }');
    buffer.write('  .ghita-model3d-note {');
    buffer.write('    text-align: center;');
    buffer.write('    font-size: 0.8rem;');
    buffer.write('    color: #9aa5c0;');
    buffer.write('    margin-top: 0.3em;');
    buffer.write('  }');
    buffer.write('  .slide ul, .slide ol {');
    buffer.write('    margin: 0.5em 0 0.5em 1.5em;');
    buffer.write('    font-size: clamp(0.95rem, 1.8vw, 1.4rem);');
    buffer.write('    line-height: 1.8;');
    buffer.write('  }');
    buffer.write('  .slide li { margin-bottom: 0.4em; }');
    buffer.write('  .slide ul li { list-style-type: disc; }');
    buffer.write('  .slide ol li { list-style-type: decimal; }');
    buffer.write('  .slide table {');
    buffer.write('    width: 80%;');
    buffer.write('    border-collapse: collapse;');
    buffer.write('    margin: 1em 0;');
    buffer.write('    font-size: clamp(0.85rem, 1.5vw, 1.2rem);');
    buffer.write('  }');
    buffer.write('  .slide th, .slide td {');
    buffer.write('    padding: 10px 14px;');
    buffer.write('    border: 1px solid rgba(255,255,255,0.2);');
    buffer.write('    text-align: left;');
    buffer.write('  }');
    buffer.write('  .slide th {');
    buffer.write('    background: rgba(255,255,255,0.1);');
    buffer.write('    font-weight: 600;');
    buffer.write('    color: #ffffff;');
    buffer.write('  }');
    buffer.write('  .controls {');
    buffer.write('    position: fixed;');
    buffer.write('    bottom: 20px;');
    buffer.write('    left: 50%;');
    buffer.write('    transform: translateX(-50%);');
    buffer.write('    display: flex;');
    buffer.write('    align-items: center;');
    buffer.write('    gap: 12px;');
    buffer.write('    background: rgba(0,0,0,0.6);');
    buffer.write('    backdrop-filter: blur(12px);');
    buffer.write('    padding: 10px 20px;');
    buffer.write('    border-radius: 50px;');
    buffer.write('    z-index: 100;');
    buffer.write('    border: 1px solid rgba(255,255,255,0.1);');
    buffer.write('  }');
    buffer.write('  .controls button {');
    buffer.write('    background: rgba(255,255,255,0.15);');
    buffer.write('    border: none;');
    buffer.write('    color: white;');
    buffer.write('    width: 40px; height: 40px;');
    buffer.write('    border-radius: 50%;');
    buffer.write('    cursor: pointer;');
    buffer.write('    font-size: 18px;');
    buffer.write('    display: flex;');
    buffer.write('    align-items: center;');
    buffer.write('    justify-content: center;');
    buffer.write('    transition: all 0.2s;');
    buffer.write('  }');
    buffer.write(
        '  .controls button:hover { background: rgba(255,255,255,0.3); }');
    buffer.write(
        '  .controls button:disabled { opacity: 0.3; cursor: not-allowed; }');
    buffer.write(
        '  .controls button.auto-armed { background: rgba(102,126,234,0.5); }');
    buffer.write('  .slide-counter {');
    buffer.write('    color: #ccc;');
    buffer.write('    font-size: 14px;');
    buffer.write('    min-width: 60px;');
    buffer.write('    text-align: center;');
    buffer.write('    font-variant-numeric: tabular-nums;');
    buffer.write('  }');
    buffer.write('  .progress-bar {');
    buffer.write('    position: fixed;');
    buffer.write('    top: 0; left: 0;');
    buffer.write('    height: 3px;');
    buffer.write('    background: linear-gradient(90deg, #667eea, #764ba2);');
    buffer.write('    transition: width 0.3s ease;');
    buffer.write('    z-index: 100;');
    buffer.write('  }');
    buffer.write('  .ghita-hf {');
    buffer.write('    position: fixed;');
    buffer.write('    top: 0; left: 0; right: 0;');
    buffer.write('    display: flex; justify-content: space-between;');
    buffer.write('    padding: 4px 16px;');
    buffer.write('    background: rgba(0,0,0,0.5);');
    buffer.write('    color: #ccc; font-size: 0.78rem;');
    buffer.write('    z-index: 200;');
    buffer.write('  }');
    buffer.write('  .fullscreen-btn {');
    buffer.write('    position: fixed;');
    buffer.write('    top: 16px;');
    buffer.write('    right: 16px;');
    buffer.write('    background: rgba(0,0,0,0.5);');
    buffer.write('    border: 1px solid rgba(255,255,255,0.2);');
    buffer.write('    color: white;');
    buffer.write('    padding: 8px 14px;');
    buffer.write('    border-radius: 8px;');
    buffer.write('    cursor: pointer;');
    buffer.write('    font-size: 13px;');
    buffer.write('    z-index: 100;');
    buffer.write('    backdrop-filter: blur(8px);');
    buffer.write('  }');
    buffer.write('  .fullscreen-btn:hover { background: rgba(0,0,0,0.7); }');
    buffer.write(
        '  .speaker-notes { display: none; margin-top: 1rem; padding: 0.8rem; border-left: 3px solid #667eea; background: rgba(0,0,0,0.24); color: #f1f1f1; font-size: 0.9rem; white-space: pre-wrap; }');
    buffer.write('  .slide.notes-visible .speaker-notes { display: block; }');
    if (bgStylesBlock.isNotEmpty) {
      buffer.write('  $bgStylesBlock');
    }
    // Add effects CSS
    buffer.write('\n  /* Slide transition effects */');
    buffer.write('\n  $effectsCss');
    buffer.write(animationsCss);
    buffer.write(morphCssBlock);
    buffer.write('</style>');
    buffer.write('</head>');
    buffer.write('<body>');
    // Track 19, P5: header/footer bars (fixed at the top/bottom of the deck).
    // When excludeFirst is true, the bar is hidden on slide 0 via JS.
    final meta = deckMeta;
    final hfExcludeFirst = meta?.excludeFirst ?? false;
    if (meta != null &&
        (meta.header.isNotEmpty ||
            meta.footer.isNotEmpty ||
            meta.slideNumber ||
            meta.dateTime)) {
      buffer.write('<div class="ghita-hf"${hfExcludeFirst ? ' id="ghitaHf"' : ''}>');
      if (meta.header.isNotEmpty) {
        buffer.write('<div class="ghita-hf-header">${_htmlEscape(meta.header)}</div>');
      }
      if (meta.footer.isNotEmpty) {
        buffer.write('<div class="ghita-hf-footer">${_htmlEscape(meta.footer)}</div>');
      }
      buffer.write('</div>');
    }
    buffer.write('<div class="progress-bar" id="progressBar"></div>');
    buffer.write(
        '<button class="fullscreen-btn" onclick="toggleFullscreen()" title="${t['fullscreen']}">&#x26F6; ${t['fullscreen']}</button>');
    buffer.write('<div class="deck" id="deck">');

    final hasNotes =
        includeNotes && slides.any((slide) => _speakerNotes(slide).isNotEmpty);
    // Track 07, P3: base64 images are kept in a JS map and injected only
    // when their slide becomes active (lazy load); identical sources share
    // one entry.
    final lazyImages = <String, String>{};
    final imageIds = <String, String>{};
    // Track 11, P8: video payloads (mp4 + poster) are hoisted into their own
    // JS map exactly like images — the <video> tag keeps a slim data-video
    // JSON (trim/bookmarks/options) and gets data-src/data-poster ids.
    final lazyVideos = <String, String>{};
    final videoIds = <String, String>{};
    // Track 13, P5: per-slide narration audio hoisted the same way.
    final lazyAudios = <String, String>{};
    for (int i = 0; i < slides.length; i++) {
      // Cooperative cancellation between slides (Track 01).
      cancelToken?.throwIfCancelled();
      final slide = slides[i];
      final title = slide['title'] ?? 'Slide ${i + 1}';
      final rawHtml = slide['htmlContent'] ?? '';
      final cleanTitle = _xmlEscape(title.toString());
      final processedContent = _processSlideHtml(
        rawHtml.toString(),
        imageMaxWidth: imageMaxWidth,
        lazyImages: lazyImages,
        imageIds: imageIds,
        lazyVideos: lazyVideos,
        videoIds: videoIds,
      );
      final notes = includeNotes ? _speakerNotes(slide) : '';
      // Track 13, P5: narration audio (slide-level field) becomes a small
      // <audio> player; the payload joins the JS map and the tag only keeps
      // playback options.
      String audioTag = '';
      final audioPath = (slide['audioPath'] ?? '').toString();
      if (audioPath.isNotEmpty && File(audioPath).existsSync()) {
        final audioOptions = slide['audioOptions'] is Map
            ? Map<String, dynamic>.from(slide['audioOptions'] as Map)
            : <String, dynamic>{};
        try {
          final bytes = File(audioPath).readAsBytesSync();
          final isWav = audioPath.toLowerCase().endsWith('.wav');
          // audio/mp4 is the canonical MIME for m4a — Chrome's media stack
          // rejects data:audio/m4a (MEDIA_ERR_SRC_NOT_SUPPORTED).
          final mime = isWav ? 'wav' : 'mp4';
          final id = 'a${lazyAudios.length}';
          lazyAudios[id] = 'data:audio/$mime;base64,${base64Encode(bytes)}';
          final hideIcon = audioOptions['hideIcon'] == true;
          final across = audioOptions['acrossSlides'] == true;
          final slim = jsonEncode(audioOptions);
          audioTag = '<audio controls data-src="$id"'
              '${hideIcon ? ' data-hideicon="1"' : ''}'
              '${across ? ' data-across="1"' : ''}'
              " data-audio='${slim.replaceAll("'", '&#39;')}'"
              ' preload="none"></audio>';
        } catch (_) {}
      }

      // Get transition class for this slide
      String transitionClass = '';
      final effectName = slide['effect'] as String?;
      if (effectName != null && effectName.isNotEmpty && effectName != 'none') {
        transitionClass = ' slide-transition-$effectName';
      }

      buffer.write('  <div class="slide$transitionClass" id="slide-$i">');
      buffer.write('    <h1>$cleanTitle</h1>');
      buffer.write('    $processedContent');
      // Track 17, P6: free-form text/shape elements from the visualElements
      // map — appended as absolutely-positioned divs so their % coordinates
      // survive the HTML deck.
      final rawVisual = slide['visualElements'];
      if (rawVisual is Map && rawVisual['freeTexts'] is List) {
        final freeTexts = (rawVisual['freeTexts'] as List)
            .map((e) => e is Map<String, dynamic>
                ? FreeTextShape.fromMap(e)
                : (e is Map
                    ? FreeTextShape.fromMap(Map<String, dynamic>.from(e))
                    : null))
            .whereType<FreeTextShape>()
            .toList()
          ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
        for (final ft in freeTexts) {
          buffer.write('    ${ft.htmlMarkup}');
        }
      }
      // Track 21: drawn shapes from the visualElements map — appended as
      // absolutely-positioned SVG divs so their % coordinates survive.
      if (rawVisual is Map && rawVisual['shapes'] is List) {
        final shapes = (rawVisual['shapes'] as List)
            .map((e) => e is Map<String, dynamic>
                ? DrawnShape.fromMap(e)
                : (e is Map
                    ? DrawnShape.fromMap(Map<String, dynamic>.from(e))
                    : null))
            .whereType<DrawnShape>()
            .toList()
          ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
        for (final shape in shapes) {
          buffer.write('    ${shape.htmlMarkup}');
        }
      }
      if (audioTag.isNotEmpty) {
        buffer.write('    $audioTag');
      }
      if (notes.isNotEmpty) {
        buffer.write(
            '    <aside class="speaker-notes">${_htmlEscape(notes)}</aside>');
      }
      buffer.write('  </div>');
    }

    buffer.write('</div>');
    buffer.write('<div class="controls">');
    buffer.write(
        '  <button id="prevBtn" onclick="changeSlide(-1)" title="${t['prev']}">&#x25C0;</button>');
    buffer.write(
        '  <span class="slide-counter" id="counter">1 / ${slides.length}</span>');
    // Auto-advance toggle (only shown when the deck is configured with timing).
    if (autoMs > 0) {
      buffer.write(
          '  <button id="autoBtn" class="auto-armed" onclick="toggleAuto()" title="Pause auto-play">&#10074;&#10074; Auto</button>');
    }
    if (hasNotes) {
      buffer.write(
          '  <button id="notesBtn" onclick="toggleNotes()" title="${t['notes']}">Notes</button>');
    }
    buffer.write(
        '  <button id="nextBtn" onclick="changeSlide(1)" title="${t['next']}">&#x25B6;</button>');
    buffer.write('</div>');
    buffer.write('<script>');
    buffer.write('  let currentSlide = 0;');
    buffer.write('  const totalSlides = ${slides.length};');
    buffer.write('  const deck = document.getElementById("deck");');
    buffer.write('  const counter = document.getElementById("counter");');
    buffer
        .write('  const progressBar = document.getElementById("progressBar");');
    buffer.write('  const prevBtn = document.getElementById("prevBtn");');
    buffer.write('  const nextBtn = document.getElementById("nextBtn");');
    buffer.write('  const autoBtn = document.getElementById("autoBtn");');
    buffer.write('  const notesBtn = document.getElementById("notesBtn");');
    buffer.write('  let autoMs = $autoMs;');
    buffer.write('  let autoTimer = null;');
    buffer.write('  let autoPaused = false;');
    buffer.write('  const hfExcludeFirst = ${hfExcludeFirst ? 'true' : 'false'};');
    buffer.write('  const transitionMap = { $transitionBlock };');
    buffer.write('  const ghitaImages = ${jsonEncode(lazyImages)};');
    buffer.write('  const ghitaVideos = ${jsonEncode(lazyVideos)};');
    buffer.write('  const ghitaAudios = ${jsonEncode(lazyAudios)};');
    buffer.write('  function setupAudio(el) {');
    buffer.write('    let opts = {};');
    buffer.write('    try { opts = JSON.parse(el.dataset.audio || "{}"); } catch (e) {}');
    buffer.write('    // Track 13, P3/P6/P7: loop, trim window, hide icon.\n');
    buffer.write('    if (opts.loop) el.loop = true;');
    buffer.write('    const ts = parseFloat(opts.trimStart) || 0;');
    buffer.write('    const te = parseFloat(opts.trimEnd) || 0;');
    buffer.write('    if (ts > 0) el.addEventListener("loadedmetadata", () => { el.currentTime = ts; });');
    buffer.write('    if (te > ts && te > 0) {');
    buffer.write('      el.addEventListener("timeupdate", () => {');
    buffer.write('        if (el.currentTime >= te) { el.currentTime = Math.max(ts, 0); if (!el.loop) el.pause(); }');
    buffer.write('      });');
    buffer.write('    }');
    buffer.write('    if (el.dataset.hideicon) {');
    buffer.write('      el.removeAttribute("controls");');
    buffer.write('      const b = document.createElement("button");');
    buffer.write('      b.type = "button"; b.className = "ghita-audio-toggle";');
    buffer.write('      b.innerHTML = "&#128266;";');
    buffer.write('      b.title = opts.autoplay ? "" : "Play narration";');
    buffer.write('      b.onclick = () => { if (el.paused) { el.play().catch(() => {}); } else { el.pause(); } };');
    buffer.write('      el.parentNode.insertBefore(b, el.nextSibling);');
    buffer.write('    }');
    buffer.write('    if (opts.autoplay) el.play().catch(() => {});');
    buffer.write('  }');
    buffer.write('  function fmtTime(s) {');
    buffer.write('    const m = Math.floor(s / 60); const sec = Math.floor(s % 60);');
    buffer.write('    return m + ":" + (sec < 10 ? "0" : "") + sec;');
    buffer.write('  }');
    buffer.write('  function setupVideo(vd) {');
    buffer.write('    let opts = {};');
    buffer.write('    try { opts = JSON.parse(vd.dataset.video || "{}"); } catch (e) {}');
    buffer.write('    // Track 11, P7: online videos become a thumbnail that\n');
    buffer.write('    // opens YouTube (the deck stays iframe-free).\n');
    buffer.write('    if (opts.youtubeId) {');
    buffer.write('      const a = document.createElement("a");');
    buffer.write('      a.href = "https://www.youtube.com/watch?v=" + opts.youtubeId;');
    buffer.write('      a.target = "_blank"; a.rel = "noopener";');
    buffer.write('      a.className = "ghita-video-youtube";');
    buffer.write('      const img = document.createElement("img");');
    buffer.write('      if (vd.dataset.poster) { const pv = ghitaVideos[vd.dataset.poster]; if (pv) img.src = pv; }');
    buffer.write('      img.alt = "YouTube";');
    buffer.write('      const play = document.createElement("span");');
    buffer.write('      play.className = "ghita-video-play"; play.innerHTML = "&#9654;";');
    buffer.write('      a.append(img, play);');
    buffer.write('      vd.parentNode.replaceChild(a, vd);');
    buffer.write('      return;');
    buffer.write('    }');
    buffer.write('    // Track 11, P4/P6/P3: trim window, bookmarks, loop, autoplay.\n');
    buffer.write('    const ts = parseFloat(opts.trimStart) || 0;');
    buffer.write('    const te = parseFloat(opts.trimEnd) || 0;');
    buffer.write('    if (ts > 0) {');
    buffer.write('      vd.addEventListener("loadedmetadata", () => { if (vd.duration > ts) vd.currentTime = ts; });');
    buffer.write('    }');
    buffer.write('    if (te > ts && te > 0) {');
    buffer.write('      vd.addEventListener("timeupdate", () => {');
    buffer.write('        if (vd.currentTime >= te) { vd.currentTime = Math.max(ts, 0); if (!vd.loop) vd.pause(); }');
    buffer.write('      });');
    buffer.write('    }');
    buffer.write('    if (opts.loop) vd.loop = true;');
    buffer.write('    if (opts.autoplay) {');
    buffer.write('      vd.muted = true;');
    buffer.write('      vd.play().catch(() => {});');
    buffer.write('    }');
    buffer.write('    const marks = opts.bookmarks || [];');
    buffer.write('    if (marks.length) {');
    buffer.write('      const bar = document.createElement("div");');
    buffer.write('      bar.className = "ghita-video-bookmarks";');
    buffer.write('      marks.forEach(m => {');
    buffer.write('        const b = document.createElement("button");');
    buffer.write('        b.type = "button";');
    buffer.write('        b.textContent = (m.label || "") + " " + fmtTime(m.time);');
    buffer.write('        b.onclick = () => { vd.currentTime = m.time; vd.play().catch(() => {}); };');
    buffer.write('        bar.appendChild(b);');
    buffer.write('      });');
    buffer.write('      vd.parentNode.insertBefore(bar, vd.nextSibling);');
    buffer.write('    }');
    buffer.write('  }');
    buffer.write('  function scheduleAuto() {');
    buffer.write(
        '    if (autoTimer) { clearTimeout(autoTimer); autoTimer = null; }');
    buffer.write(
        '    if (autoMs > 0 && !autoPaused && currentSlide < totalSlides - 1) {');
    buffer.write('      autoTimer = setTimeout(() => changeSlide(1), autoMs);');
    buffer.write('    }');
    buffer.write('  }');
    buffer.write('  function toggleAuto() {');
    buffer.write('    if (autoMs <= 0 || !autoBtn) return;');
    buffer.write('    autoPaused = !autoPaused;');
    buffer.write(
        '    if (autoTimer) { clearTimeout(autoTimer); autoTimer = null; }');
    buffer.write('    if (!autoPaused) scheduleAuto();');
    buffer.write('    autoBtn.classList.toggle("auto-armed", !autoPaused);');
    buffer.write(
        '    autoBtn.title = autoPaused ? "${t['resumeAuto']}" : "${t['pauseAuto']}";');
    buffer.write(
        '    autoBtn.innerHTML = (autoPaused ? "&#9654;" : "&#10074;&#10074;") + " Auto";');
    buffer.write('  }');
    buffer.write('  function ghitaShowSlide(index) {');
    buffer.write('    if (index < 0 || index >= totalSlides) return;');
    buffer.write('    // Track 11, P8: pause every video before switching slides.\n');
    buffer.write('    deck.querySelectorAll("video").forEach(v => v.pause());');
    buffer.write('    // Track 13, P6: pause narration audio unless it plays across slides.\n');
    buffer.write('    deck.querySelectorAll("audio[data-src]").forEach(a => { if (a.dataset.across !== "1") a.pause(); });');
    buffer.write('    deck.querySelectorAll(".slide").forEach(s => {');
    buffer.write('      s.classList.remove("active");');
    buffer.write(
        '      // Remove and re-add transition class to re-trigger animation\n');
    buffer.write(
        '      const cls = s.className.split(" ").filter(c => !c.startsWith("slide-transition-"));');
    buffer.write('      s.className = cls.join(" ");');
    buffer.write('    });');
    buffer
        .write('    const slide = document.getElementById("slide-" + index);');
    buffer.write('    if (slide) {');
    buffer.write('      // Track 07, P3: lazy-load this slide\'s images now.\n');
    buffer.write(
        '      slide.querySelectorAll("img[data-src]").forEach(im => { const v = ghitaImages[im.dataset.src]; if (v) { im.src = v; im.decoding = "async"; im.loading = "lazy"; im.removeAttribute("data-src"); } });');
    buffer.write(
        '      // Track 11, P8: inject this slide\'s video + poster payloads.\n');
    buffer.write(
        '      slide.querySelectorAll("video[data-src]").forEach(vd => { const v = ghitaVideos[vd.dataset.src]; if (v) { vd.src = v; vd.removeAttribute("data-src"); } });');
    buffer.write(
        '      slide.querySelectorAll("video[data-poster]").forEach(vd => { const v = ghitaVideos[vd.dataset.poster]; if (v) { vd.poster = v; vd.removeAttribute("data-poster"); } });');
    buffer.write(
        '      slide.querySelectorAll("video[data-video]").forEach(vd => setupVideo(vd));');
    buffer.write(
        '      // Track 13, P5: inject narration audio + apply its options.\n');
    buffer.write(
        '      slide.querySelectorAll("audio[data-src]").forEach(a => { const v = ghitaAudios[a.dataset.src]; if (v) { a.src = v; a.removeAttribute("data-src"); setupAudio(a); } });');
    buffer.write('      // Force reflow to restart animation\n');
    buffer.write('      void slide.offsetWidth;');
    buffer.write('      // Re-apply transition class\n');
    buffer.write('      const eff = transitionMap["slide-" + index];');
    buffer.write(
        '      if (eff) slide.classList.add("slide-transition-" + eff);');
    buffer.write('      slide.classList.add("active");');
    buffer.write('      slide.scrollTop = 0;');
    buffer.write('    }');
    buffer.write('    currentSlide = index;');
    // Track 19, P7: hide the header/footer bar on the title slide when
    // excludeFirst is enabled.
    buffer.write('    const hfEl = document.getElementById("ghitaHf");');
    buffer.write('    if (hfEl) { hfEl.style.display = (hfExcludeFirst && index === 0) ? "none" : ""; }');
    buffer
        .write('    counter.textContent = (index + 1) + " / " + totalSlides;');
    buffer.write(
        '    progressBar.style.width = ((index + 1) / totalSlides * 100) + "%";');
    buffer.write('    prevBtn.disabled = index === 0;');
    buffer.write('    nextBtn.disabled = index === totalSlides - 1;');
    buffer.write('    scheduleAuto();');
    buffer.write('  }');
    buffer.write('  function changeSlide(delta) {');
    buffer.write('    showSlide(currentSlide + delta);');
    buffer.write('  }');
    // Track 20, P5: slide zoom thumbnails call goToSlide(index) directly.
    buffer.write('  function goToSlide(index) { showSlide(index); }');
    buffer.write('  function toggleNotes() {');
    buffer.write(
        '    const slide = document.getElementById("slide-" + currentSlide);');
    buffer.write('    if (slide) slide.classList.toggle("notes-visible");');
    buffer.write('  }');
    buffer.write('  function toggleFullscreen() {');
    buffer.write('    if (!document.fullscreenElement) {');
    buffer.write(
        '      document.documentElement.requestFullscreen().catch(() => {});');
    buffer.write('    } else {');
    buffer.write('      document.exitFullscreen();');
    buffer.write('    }');
    buffer.write('  }');
    buffer.write('  document.addEventListener("keydown", (e) => {');
    buffer.write(
        '    if (e.key === "ArrowRight" || e.key === " " || e.key === "PageDown") {');
    buffer.write('      e.preventDefault(); changeSlide(1);');
    buffer
        .write('    } else if (e.key === "ArrowLeft" || e.key === "PageUp") {');
    buffer.write('      e.preventDefault(); changeSlide(-1);');
    buffer.write('    } else if (e.key === "Home") {');
    buffer.write('      e.preventDefault(); showSlide(0);');
    buffer.write('    } else if (e.key === "End") {');
    buffer.write('      e.preventDefault(); showSlide(totalSlides - 1);');
    buffer.write('    } else if (e.key === "f" || e.key === "F") {');
    buffer.write('      toggleFullscreen();');
    buffer.write('    }');
    buffer.write('  });');
    buffer.write('  let touchStartX = 0;');
    buffer.write(
        '  deck.addEventListener("touchstart", (e) => { touchStartX = e.touches[0].clientX; });');
    buffer.write('  deck.addEventListener("touchend", (e) => {');
    buffer.write('    const diff = touchStartX - e.changedTouches[0].clientX;');
    buffer
        .write('    if (Math.abs(diff) > 50) changeSlide(diff > 0 ? 1 : -1);');
    buffer.write('  });');
    if (allAnimations.isNotEmpty) {
      // Track 29/30/31, P7/P3: animation player — runs entrance/motion
      // animations when the slide activates, honouring start order, delay,
      // repeat/autoReverse and click triggers.
      final animData = <Map<String, dynamic>>[
        for (final entry in slideAnimations.entries)
          {
            'slide': entry.key,
            'list': [for (final a in entry.value) a.toMap()],
          },
      ];
      buffer.write('  const ghitaAnimations = ${jsonEncode(animData)};');
      buffer.write('  const animGroups = {};');
      buffer.write('  ghitaAnimations.forEach(spec => {');
      buffer.write('    animGroups[spec.slide] = spec.list;');
      buffer.write('  });');
      buffer.write('  function playSlideAnimations(index) {');
      buffer.write('    const slide = document.getElementById("slide-" + index);');
      buffer.write('    if (!slide) return;');
      buffer.write('    const list = animGroups[index] || [];');
      buffer.write('    let withPrevElapsed = 0;');
      buffer.write('    list.sort((a, b) => {"click":2,"withPrevious":1,"afterPrevious":0}[a.start] - {"click":2,"withPrevious":1,"afterPrevious":0}[b.start]);');
      buffer.write('    list.forEach((a) => {');
      buffer.write('      const el = slide.querySelector("[data-ghita-id="" + a.shapeId + ""]");');
      buffer.write('      if (!el) return;');
      buffer.write('      const baseDelay = a.start === "afterPrevious" ? withPrevElapsed : (a.start === "withPrevious" ? 0 : a.delay || 0);');
      buffer.write('      if (a.start === "withPrevious" || a.start === "afterPrevious") withPrevElapsed += (a.delay || 0) + (a.duration || 0.5);');
      buffer.write('      const cls = "ghita-anim-" + a.shapeId.replace(/[^a-zA-Z0-9]/g, "_") + "-" + a.effect;');
      buffer.write('      const startFn = () => {');
      buffer.write('        el.classList.remove(cls);');
      buffer.write('        void el.offsetWidth;');
      buffer.write('        el.classList.add(cls);');
      buffer.write('        el.style.animationDelay = baseDelay + "s";');
      buffer.write('        el.style.animationDuration = a.duration + "s";');
      buffer.write('        el.style.animationIterationCount = a.repeat === -1 ? "infinite" : String(a.repeat + 1);');
      buffer.write('        el.style.animationDirection = a.autoReverse ? "alternate" : "normal";');
      buffer.write('        el.style.animationFillMode = a.group === "entrance" ? "both" : "forwards";');
      buffer.write('      };');
      buffer.write('      if (a.triggerShapeId) {');
      buffer.write('        const trig = slide.querySelector("[data-ghita-id="" + a.triggerShapeId + ""]");');
      buffer.write('        if (trig) trig.addEventListener("click", startFn, { once: true });');
      buffer.write('      } else if (a.start === "onClick") {');
      buffer.write('        setTimeout(startFn, (a.delay || 0) * 1000);');
      buffer.write('      } else {');
      buffer.write('        setTimeout(startFn, baseDelay * 1000);');
      buffer.write('      }');
      buffer.write('    });');
      buffer.write('  }');
      // (the showSlide wrapper is defined unconditionally below so decks
      // without animations still navigate normally)
    }
    // showSlide wrapper — always defined. ghitaShowSlide does the real work;
    // the wrapper fires object animations when the deck has any. Patching the
    // local binding (not just window.showSlide) so changeSlide/goToSlide/
    // keyboard/touch all trigger animations.
    buffer.write('  function showSlide(index) {');
    buffer.write('    ghitaShowSlide(index);');
    buffer.write(
        '    if (typeof playSlideAnimations === "function") setTimeout(() => playSlideAnimations(index), 60);');
    buffer.write('  }');
    buffer.write('  showSlide($initIndex);');
    buffer.write('</script>');
    buffer.write('</body>');
    buffer.write('</html>');

    // Track 07, P6: minify the whole document (string-literal aware) before
    // caching/writing — HTML/CSS/JS whitespace and comments are the deck's
    // cheapest win.
    return _minify(buffer.toString());
  }

  /// Player control strings per deck locale (Track 07, P9).
  static Map<String, String> _playerTitles(String locale) {
    final vi = locale == 'vi';
    return {
      'prev': vi ? 'Trước' : 'Previous',
      'next': vi ? 'Sau' : 'Next',
      'fullscreen': vi ? 'Toàn màn hình' : 'Fullscreen',
      'notes': vi ? 'Hiện/ẩn ghi chú' : 'Show or hide speaker notes',
      'pauseAuto': vi ? 'Tạm dừng tự chạy' : 'Pause auto-play',
      'resumeAuto': vi ? 'Tiếp tục tự chạy' : 'Resume auto-play',
    };
  }

  /// Deterministic, string-literal-aware minifier for the generated deck:
  /// strips comments and collapses whitespace outside quotes while keeping
  /// every string (JS literals, attribute values, data URIs) byte-for-byte.
  static String _minify(String input) {
    final out = StringBuffer();
    var inString = false;
    var quote = '';
    var lastWasSpace = false;
    var i = 0;
    while (i < input.length) {
      final c = input[i];
      if (inString) {
        out.write(c);
        if (c == '\\' && i + 1 < input.length) {
          out.write(input[i + 1]);
          i += 2;
          continue;
        }
        if (c == quote) {
          inString = false;
          quote = '';
        }
        i++;
        continue;
      }
      if (c == '"' || c == "'") {
        inString = true;
        quote = c;
        out.write(c);
        i++;
        continue;
      }
      if (c == '/' && i + 1 < input.length && input[i + 1] == '/') {
        while (i < input.length && input[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '/' && i + 1 < input.length && input[i + 1] == '*') {
        i += 2;
        while (i + 1 < input.length &&
            !(input[i] == '*' && input[i + 1] == '/')) {
          i++;
        }
        i += 2;
        continue;
      }
      if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
        lastWasSpace = out.isNotEmpty && !_isSpace(out.toString().codeUnitAt(out.length - 1));
        if (lastWasSpace) {
          out.write(' ');
        }
        i++;
        continue;
      }
      out.write(c);
      i++;
    }
    return out.toString();
  }

  static bool _isSpace(int codeUnit) =>
      codeUnit == 0x20 || codeUnit == 0x09 || codeUnit == 0x0A || codeUnit == 0x0D;

  // Compiled once — these run per slide on every deck build.
  static final RegExp _bgColorAttrRe =
      RegExp(r"""data-bg-color=["']([^"']+)["']""", caseSensitive: false);
  static final RegExp _bgColorDqRe =
      RegExp(r'data-bg-color="[^"]*"', caseSensitive: false);
  static final RegExp _bgColorSqRe =
      RegExp(r"data-bg-color='[^']*'", caseSensitive: false);
  static final RegExp _emptyDivRe =
      RegExp(r'<div[^>]*>\s*</div>', caseSensitive: false);
  static final RegExp _excessBrRe =
      RegExp(r'(<br\s*/?>\s*){3,}', caseSensitive: false);

  String? _extractSlideBgColor(Map<String, dynamic> slide) {
    final typed =
        PPTGenerator.cssColorToHex((slide['bgColor'] ?? '').toString());
    if (typed != null) return typed;
    final html = (slide['htmlContent'] ?? '').toString();
    final match = _bgColorAttrRe.firstMatch(html);
    return match == null ? null : PPTGenerator.cssColorToHex(match.group(1)!);
  }

  String _speakerNotes(Map<String, dynamic> slide) {
    final explicit = (slide['notes'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;
    return PPTGenerator.extractNotes((slide['htmlContent'] ?? '').toString());
  }

  String _processSlideHtml(
    String rawHtml, {
    int? imageMaxWidth,
    required Map<String, String> lazyImages,
    required Map<String, String> imageIds,
    required Map<String, String> lazyVideos,
    required Map<String, String> videoIds,
  }) {
    final document = html_parser.parse(rawHtml);
    final body = document.body;
    if (body == null) return '';

    for (final aside in body.querySelectorAll('aside.notes')) {
      aside.remove();
    }
    for (final diagramDiv in body.querySelectorAll('div[data-smartart]')) {
      // Track 10, P4: replace the placeholder with self-generated inline SVG.
      final graph =
          SmartArtGraph.fromJson(diagramDiv.attributes['data-smartart'] ?? '');
      if (graph != null) {
        diagramDiv.innerHtml = SmartArtService.renderSvg(graph);
      }
    }
    for (final chartDiv in body.querySelectorAll('div[data-chart]')) {
      // Track 08, P6: replace the chart placeholder with self-generated
      // inline SVG (no runtime dependency); the data-chart attribute stays
      // for re-editing.
      final chart = ChartData.fromJson(chartDiv.attributes['data-chart'] ?? '');
      if (chart != null) {
        chartDiv.innerHtml = ChartService.renderSvg(chart);
      }
    }
    for (final modelDiv in body.querySelectorAll('div[data-model3d]')) {
      // Track 14, P7: the HTML deck never embeds the GLB — the poster SVG
      // (with a note) stands in, and the inline JSON is slimmed to metadata
      // (name/rotate) so the megabyte payload does not bloat the deck.
      final model = Model3DData.fromJson(
          modelDiv.attributes['data-model3d'] ?? '');
      if (model.src.isNotEmpty) {
        modelDiv.innerHtml = Model3DService.renderHtmlPoster(
          model,
          note: _model3dNote,
        );
        modelDiv.attributes['data-model3d'] =
            model.copyWith(src: '').toJson().replaceAll("'", '&#39;');
      }
    }
    for (final iconSpan in body.querySelectorAll('span[data-icon]')) {
      // Track 15, P4: replace the icon span with inline SVG markup, keeping
      // the data-icon attribute for re-editing.
      final icon = IconItem.fromJson(
          iconSpan.attributes['data-icon'] ?? '');
      if (icon.svgPath.isNotEmpty) {
        iconSpan.innerHtml = icon.svgMarkup;
      }
    }
    for (final actionDiv in body.querySelectorAll('div[data-action]')) {
      // Track 18, P1–P2: replace the action button placeholder with the
      // styled HTML button (the data-action attribute stays for re-editing).
      final button = ActionButton.fromJson(
          actionDiv.attributes['data-action'] ?? '');
      actionDiv.innerHtml = button.htmlMarkup;
    }
    for (final eqDiv in body.querySelectorAll('div[data-equation]')) {
      // Track 18, P3–P4: replace the equation placeholder with the
      // plain-text fallback (real rendering would need KaTeX).
      final eq = EquationData.fromJson(
          eqDiv.attributes['data-equation'] ?? '');
      eqDiv.innerHtml = eq.htmlMarkup;
    }
    for (final oleDiv in body.querySelectorAll('div[data-ole]')) {
      // Track 18, P6: replace the OLE placeholder with the styled HTML
      // document icon (the data-ole attribute stays for re-editing).
      final ole = OleData.fromJson(
          oleDiv.attributes['data-ole'] ?? '');
      oleDiv.innerHtml = ole.htmlMarkup;
    }
    for (final zoomDiv in body.querySelectorAll('div[data-zoom]')) {
      // Track 20, P5: replace the zoom placeholder with the clickable
      // thumbnail markup (the data-zoom attribute stays for re-editing).
      final zoom = ZoomItem.fromJson(zoomDiv.attributes['data-zoom'] ?? '');
      zoomDiv.innerHtml = zoom.htmlMarkup;
    }
    for (final szDiv in body.querySelectorAll('div[data-sectionzoom]')) {
      // Track 20, P6: replace the Section/Summary Zoom placeholder with the
      // clickable tile grid (the data-sectionzoom attribute stays for
      // re-editing).
      final sz = SectionZoomData.fromJson(
          szDiv.attributes['data-sectionzoom'] ?? '');
      szDiv.innerHtml = sz.htmlMarkup;
    }
    for (final cameoDiv in body.querySelectorAll('div[data-cameo]')) {
      // Track 20, P8: replace the cameo placeholder with the styled camera
      // markup (the data-cameo attribute stays for re-editing).
      final cameo = CameoData.fromJson(cameoDiv.attributes['data-cameo'] ?? '');
      cameoDiv.innerHtml = cameo.htmlMarkup;
    }
    for (final image in body.querySelectorAll('img')) {
      final src = (image.attributes['src'] ?? '').trim();
      final loaded = HtmlImageLoader.load(
        src,
        maxWidth: imageMaxWidth,
      );
      if (loaded != null) {
        // Track 07, P3: the payload moves into the JS image map; the <img>
        // gets data-src and the player injects src when the slide becomes
        // active (identical sources share one entry).
        final id = imageIds.putIfAbsent(src, () => 'i${imageIds.length}');
        lazyImages[id] =
            'data:image/${loaded.ext};base64,${base64Encode(loaded.bytes)}';
        image.attributes
          ..remove('src')
          ..['data-src'] = id
          ..['loading'] = 'lazy'
          ..['decoding'] = 'async';
      }
    }
    for (final video in body.querySelectorAll('video[data-video]')) {
      // Track 11, P8: hoist the mp4 + poster payloads into the JS video map
      // (slimming the data-video JSON to playback metadata only — the raw
      // attribute would otherwise duplicate megabytes of base64), keep
      // `controls`, and let the player inject sources lazily per slide.
      var data = VideoData.fromJson(video.attributes['data-video'] ?? '');
      final srcAttr = (video.attributes['src'] ?? '').trim();
      if (data.src.isEmpty && srcAttr.isNotEmpty) {
        data = data.copyWith(src: srcAttr);
      }
      final posterAttr = (video.attributes['poster'] ?? '').trim();
      if (data.poster.isEmpty && posterAttr.isNotEmpty) {
        data = data.copyWith(poster: posterAttr);
      }
      if (data.src.isNotEmpty && data.src.startsWith('data:')) {
        final id = videoIds.putIfAbsent(
            data.src, () => 'v${videoIds.length}');
        lazyVideos[id] = data.src;
        video.attributes
          ..remove('src')
          ..['data-src'] = id
          ..['preload'] = 'none';
      }
      if (data.poster.isNotEmpty && data.poster.startsWith('data:')) {
        final id =
            videoIds.putIfAbsent(data.poster, () => 'p${videoIds.length}');
        lazyVideos[id] = data.poster;
        video.attributes
          ..remove('poster')
          ..['data-poster'] = id;
      }
      // Slim JSON: payloads live in the map; playback metadata stays inline.
      final slim = data.copyWith(src: '', poster: '').toJson();
      video.attributes['data-video'] = slim.replaceAll("'", '&#39;');
    }

    var processed = body.innerHtml;

    // Remove data-bg-color attributes (both single and double quotes)
    processed = processed.replaceAll(_bgColorDqRe, '');
    processed = processed.replaceAll(_bgColorSqRe, '');

    // Remove empty divs
    processed = processed.replaceAll(_emptyDivRe, '');

    // Clean up excessive breaks
    processed = processed.replaceAll(_excessBrRe, '<br><br>');

    return processed.trim();
  }

  static String _htmlEscape(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;')
      .replaceAll('\n', '<br>');

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

/// One cached standalone deck: the canonical input serialization used as the
/// cache key together with the built HTML output.
class _DeckCacheEntry {
  _DeckCacheEntry(this.source, this.html);

  final String source;
  final String html;
}
