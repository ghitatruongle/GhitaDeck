import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/export_options.dart';
import '../models/custom_show.dart';
import '../models/chart_data.dart';
import '../models/free_shape.dart';
import '../models/icon_item.dart';
import '../models/media_item.dart';
import '../models/model3d_item.dart';
import '../models/smartart.dart';
import '../models/drawn_shape.dart';
import '../models/ppt_theme_setting.dart';
import '../models/slide.dart';
import 'action_button_service.dart';
import 'equation_service.dart';
import 'export_primitives.dart';
import 'header_footer_service.dart';
import 'html_image_loader.dart';
import 'icon_library_service.dart';
import 'model3d_service.dart';
import 'ole_service.dart';
import 'ppt_chart_writer.dart';
import 'ppt_layout_registry.dart';
import 'ppt_smartart_writer.dart';
import 'speaker_icon_data.dart';
import 'text_metrics_service.dart';
import 'video_embed_service.dart';
import 'wordart_service.dart';
import 'zoom_feature_service.dart';
import 'cameo_service.dart';
import 'group_service.dart';
import 'animation_ooxml.dart';
import '../models/object_animation.dart';
import 'morph_service.dart';
import 'shape_engine.dart';

/// Relationship registrar for a single slide part.
class _SlideRels {
  final List<String> _entries = [];
  int _next = 2; // rId1 is reserved for the slideLayout

  /// The layout part this slide binds to (Track 05); the default keeps the
  /// v1.6.3 single-blank behavior for slides without a layout.
  String layoutTarget = '../slideLayouts/slideLayout1.xml';

  String _add(String type, String target, {bool external = false}) {
    final id = 'rId$_next';
    _next++;
    final mode = external ? ' TargetMode="External"' : '';
    _entries
        .add('  <Relationship Id="$id" Type="$type" Target="$target"$mode/>');
    return id;
  }

  String addImage(String target) => _add(
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
      target);

  /// Track 18, P6: the `oleObject` relationship carrying the embedded file.
  String addOleObject(String target) => _add(
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/oleObject',
      target);

  /// Track 11, P2: the `video` relationship carrying the mp4 (embedded part
  /// or an external URL for online videos).
  String addVideoFile(String target, {bool external = false}) => _add(
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/video',
      target,
      external: external);

  /// Track 11, P2: the legacy `media` relationship PowerPoint writes
  /// alongside `video` (referenced by the p14:media extension in the shape).
  String addMedia(String target) => _add(
      'http://schemas.microsoft.com/office/2007/relationships/media',
      target);

  /// Track 13, P4: the `audio` relationship carrying the narration mp3/m4a.
  String addAudioFile(String target) => _add(
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/audio',
      target);

  /// Track 14, P3: the 2017 model3d relationship carrying the GLB.
  String addModel3d(String target) => _add(
      'http://schemas.microsoft.com/office/2017/06/relationships/model3d',
      target);

  String addHyperlink(String url) => _add(
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink',
      url,
      external: true);

  String addNotesSlide(String target) => _add(
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide',
      target);

  String addChart(String target) => _add(
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart',
      target);

  String addDiagramData(String target) => _add(
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramData',
      target);

  String addDiagramLayout(String target) => _add(
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramLayout',
      target);

  String addDiagramQuickStyle(String target) => _add(
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramQuickStyle',
      target);

  String addDiagramColors(String target) => _add(
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramColors',
      target);

  String toXml() {
    final b = StringBuffer();
    b.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    b.write(
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n');
    b.write(
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="$layoutTarget"/>\n');
    for (final e in _entries) {
      b.write('$e\n');
    }
    b.write('</Relationships>');
    return b.toString();
  }
}

/// A media file to be embedded under ppt/media/.
class _MediaFile {
  final String name;
  final Uint8List bytes;
  _MediaFile(this.name, this.bytes);
}

/// Chart parts registry (Track 08, P4): one `<c:chart>` part per unique
/// chart definition — identical charts across slides share a part and each
/// slide references it through its own rels.
class _ChartRegistry {
  final Map<String, _ChartEntry> _byJson = {};
  int _next = 1;

  int get count => _byJson.length;

  /// Register [chart], returning its part name (`chartN.xml`).
  String partFor(ChartData chart) {
    final json = chart.toJson();
    final existing = _byJson[json];
    if (existing != null) return existing.name;
    final index = _next++;
    final entry = _ChartEntry(index, 'chart$index.xml', chart);
    _byJson[json] = entry;
    return entry.name;
  }

  List<_ChartEntry> get entries => _byJson.values.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
}

class _ChartEntry {
  _ChartEntry(this.index, this.name, this.chart);

  final int index;
  final String name;
  final ChartData chart;

  String get sheetName => 'Microsoft_Excel_Sheet$index.xlsx';
}

/// SmartArt registry (Track 10, P3): one `data{n}.xml` per unique diagram;
/// the layout / quick-style / colors parts are shared single parts.
class _SmartArtRegistry {
  final Map<String, int> _byJson = {};
  int _next = 1;

  int get count => _byJson.length;

  int partIndexFor(SmartArtGraph graph) {
    final json = graph.toJson();
    return _byJson.putIfAbsent(json, () => _next++);
  }

  List<SmartArtGraph> get graphs => _byJson.entries
      .map((e) => SmartArtGraph.fromJson(e.key)!)
      .toList();
}

/// Per-export slide geometry derived from the selected aspect ratio.
/// Keeping it explicit prevents 1:1 and portrait exports from being written
/// with a 4:3 canvas and then merely labelled as another ratio.
class _PptGeometry {
  const _PptGeometry(this.aspectRatio);

  final ExportAspectRatio aspectRatio;

  int get width => aspectRatio.widthEmu;
  int get height => aspectRatio.heightEmu;
  int get contentX => (width * 0.05).round().clamp(228600, 457200).toInt();
  int get contentWidth => width - contentX * 2;
  int get contentBottom => (height * 0.96).round();
  int get titleY => (height * 0.04).round();
  int get titleHeight => (height / 6).round();
  int get subtitleY => (height * 0.20).round();
  int get subtitleHeight => (height / 15).round();
  int get contentTopWithoutSubtitle => (height * 0.2333333333).round();
  int get contentTopWithSubtitle => (height * 0.2833333333).round();
}

/// Session-lifetime cache for parsed slide HTML (Track 01, phase 3).
///
/// Tokenizing HTML is the single most expensive step of the export pipeline.
/// Within one session the same slide content is often parsed repeatedly:
/// duplicated slides inside a deck, speaker-notes extraction re-parsing the
/// content, or the same deck exported as both PPTX and PDF. This cache keeps
/// one tokenization per unique content and derives every consumer artifact
/// from it:
///
///  * [notesFor] — speaker notes (aside.notes text),
///  * [subtitleFor] — first h2 text (the dedicated subtitle),
///  * [blocksFor] — the shared block tree, with or without the first h2
///    dropped (PPTX wants it dropped so the subtitle is not emitted again as
///    a body paragraph; PDF/HTML keep it).
///
/// Entries are dropped oldest-first once [capacity] is exceeded. Lookups are
/// content-addressed (FNV-1a 64) with a full-string equality check, so a hash
/// collision can never serve the wrong payload.
class HtmlParseCache {
  HtmlParseCache({int capacity = 128}) : _capacity = capacity;

  /// Long-lived cache shared by every export in the worker isolate.
  static final HtmlParseCache shared = HtmlParseCache();

  final int _capacity;

  /// Insertion-ordered so the oldest entry can be evicted easily.
  final Map<String, _ParsedHtmlEntry> _entries = {};

  /// Cache metrics — useful for tests and benchmarks.
  int hits = 0;
  int misses = 0;

  /// Accumulated tokenizer time (ms) for every independent parse performed.
  double parseMs = 0;

  static String _fnv1a64(String input) {
    // FNV-1a 64-bit — good avalanche, no external dependency.
    const offset = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    var hash = offset;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  String _keyFor(String html) => _fnv1a64(html);

  void _touch(String key) {
    final entry = _entries.remove(key);
    if (entry != null) _entries[key] = entry;
  }

  /// Parse (or reuse) [html] once and return the derived artifacts.
  _ParsedHtmlEntry _entryFor(String html) {
    final key = _keyFor(html);
    final cached = _entries[key];
    if (cached != null && cached.html == html) {
      hits++;
      _touch(key);
      return cached;
    }

    misses++;
    final watch = Stopwatch()..start();
    final doc = html_parser.parse(html);
    parseMs += watch.elapsedMicroseconds / 1000;
    final notes = doc.querySelector('aside.notes')?.text.trim() ?? '';
    final h2 = doc.querySelector('h2');
    final subtitle =
        (h2 != null && h2.text.trim().isNotEmpty) ? h2.text.trim() : null;
    final blocks = PPTGenerator.parseHtmlContentFullFromDoc(doc, fallbackText: html);
    // First h2 is the dedicated subtitle and must not be emitted again as a
    // body paragraph (mirrors _buildSlideXml's historical behavior).
    final h2Again = doc.querySelector('h2');
    if (h2Again != null) h2Again.remove();
    final blocksNoFirstH2 = PPTGenerator.parseHtmlContentFullFromDoc(doc, fallbackText: html);

    final entry = _ParsedHtmlEntry(
      html,
      notes: notes,
      subtitle: subtitle,
      blocks: blocks,
      blocksNoFirstH2: blocksNoFirstH2,
    );
    _entries[key] = entry;
    if (_entries.length > _capacity) {
      _entries.remove(_entries.keys.first);
    }
    return entry;
  }

  /// Speaker notes of [html] (empty when absent) — no re-tokenization.
  String notesFor(String html) => _entryFor(html).notes;

  /// First h2 text of [html], or null when there is no non-empty h2.
  String? subtitleFor(String html) => _entryFor(html).subtitle;

  /// The shared block tree of [html].
  ///
  /// Use [dropFirstH2] for PPTX: the first h2 (subtitle) is removed from the
  /// tree so it is only emitted as the subtitle shape, exactly as
  /// [_buildSlideXml] did with a per-slide DOM parse.
  List<Map<String, dynamic>> blocksFor(String html,
      {bool dropFirstH2 = false}) {
    final entry = _entryFor(html);
    return dropFirstH2 ? entry.blocksNoFirstH2 : entry.blocks;
  }

  /// Drop every cached entry (session reset, tests).
  void clear() {
    _entries.clear();
    hits = 0;
    misses = 0;
    parseMs = 0;
  }
}

/// One cache entry: every consumer artifact of a single tokenization.
class _ParsedHtmlEntry {
  _ParsedHtmlEntry(
    this.html, {
    required this.notes,
    required this.subtitle,
    required this.blocks,
    required this.blocksNoFirstH2,
  });

  final String html;
  final String notes;
  final String? subtitle;
  final List<Map<String, dynamic>> blocks;
  final List<Map<String, dynamic>> blocksNoFirstH2;
}

class PPTGenerator {
  /// Track 32: warnings collected while exporting animations (effects that
  /// could not be mapped to OOXML were skipped). Read after generatePPT.
  static final List<String> animationWarnings = [];

  // EMU geometry constants.
  static const int _emuPerPx = 9525;

  /// Benchmark/test-only knobs emulating the v1.6.3 ZIP encoder behavior
  /// (deflate at the fastest level, every entry compressed) so before/after
  /// timings can be measured side by side in the same process. Production
  /// code never modifies these.
  static int debugZipLevel = Deflate.BEST_COMPRESSION;
  static bool debugStoreCompressedMedia = true;

  /// Test-only knob: disable content dedupe so a deck with repeated images
  /// embeds one media part per occurrence (the v1.6.3 behavior).
  static bool debugDisableMediaDedupe = false;

  /// Map an image-max-width ceiling (ExportQuality 150/300/600 px) to the
  /// JPEG quality used when re-encoding large opaque PNGs (Track 03, P5).
  static int jpegQualityForMaxWidth(int? imageMaxWidth) {
    switch (imageMaxWidth) {
      case 150:
        return 70;
      case 600:
        return 90;
      default:
        return 80;
    }
  }

  /// Add an XML/text part using the actual UTF-8 byte length.
  ///
  /// `String.length` counts UTF-16 code units; for non-ASCII content (bullet
  /// glyphs, Vietnamese titles, notes) it understates the byte count, and the
  /// archive package writes that value into the ZIP headers verbatim — which
  /// makes PowerPoint flag the package as corrupt.
  static void _addTextFile(Archive archive, String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  static Future<File> generatePPT(
    List<Map<String, dynamic>> slides,
    String outputPath, {
    SlideEffect effect = SlideEffect.none,
    bool widescreen = true,
    ExportAspectRatio? aspectRatio,
    bool includeNotes = true,
    bool includeBackgrounds = true,
    int? imageMaxWidth,
    Duration? autoAdvance,
    HtmlParseCache? parseCache,
    ExportCancelToken? cancelToken,
    ExportProgressCallback? onProgress,
    ExportTimings? timings,
    bool fitContent = true,
    PptThemeSetting? theme,
    DeckMeta? deckMeta,
    // Track 36, P7: an optional named custom show written into the PPTX
    // (p:custShowLst in presentation.xml) with a sldIdLst referencing the
    // deck's slides.
    CustomShow? customShow,
  }) async {
    try {
      if (slides.isEmpty) {
        throw ArgumentError.value(
          slides,
          'slides',
          'Cannot export an empty presentation',
        );
      }
      final pptxBytes = _createPPTXArchive(slides,
          effect: effect,
          widescreen: widescreen,
          aspectRatio: aspectRatio,
          includeNotes: includeNotes,
          includeBackgrounds: includeBackgrounds,
          imageMaxWidth: imageMaxWidth,
          autoAdvance: autoAdvance,
          parseCache: parseCache,
          cancelToken: cancelToken,
          onProgress: onProgress,
          timings: timings,
          fitContent: fitContent,
          theme: theme,
          deckMeta: deckMeta,
          customShow: customShow);
      final outputFile = File(outputPath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsBytes(pptxBytes);
      return outputFile;
    } catch (e) {
      // Cancellation is not an export failure — let it propagate untouched.
      if (e is ExportCancelledException) rethrow;
      throw Exception('Failed to generate PPT: $e');
    }
  }

  static Uint8List _createPPTXArchive(
    List<Map<String, dynamic>> slides, {
    SlideEffect effect = SlideEffect.none,
    bool widescreen = true,
    ExportAspectRatio? aspectRatio,
    bool includeNotes = true,
    bool includeBackgrounds = true,
    int? imageMaxWidth,
    Duration? autoAdvance,
    HtmlParseCache? parseCache,
    ExportCancelToken? cancelToken,
    ExportProgressCallback? onProgress,
    ExportTimings? timings,
    bool fitContent = true,
    PptThemeSetting? theme,
    DeckMeta? deckMeta,
    CustomShow? customShow,
  }) {
    final geometry = _PptGeometry(
      aspectRatio ??
          (widescreen
              ? ExportAspectRatio.widescreen16x9
              : ExportAspectRatio.standard4x3),
    );
    final archive = Archive();
    final mediaFiles = <_MediaFile>[];
    final mediaExts = <String>{};
    // Track 19: footer shapes drawn on the slide master (header/footer/sldNum/dt).
    final footerShapesXml = deckMeta != null
        ? HeaderFooterService.masterFooterShapesXml(deckMeta)
        : '';
    final notesSlideNums = <int>[];
    var mediaCounter = 0;
    // Track 03, P4: identical image bytes are embedded once — later slides
    // reference the same media part through their own rels.
    final mediaByContentKey = <String, String>{};
    // Track 08, P4: one <c:chart> part per unique chart definition.
    final chartRegistry = _ChartRegistry();
    // Track 10, P3: one <dgm:> data part per unique SmartArt diagram.
    final smartArtRegistry = _SmartArtRegistry();
    // Unified auto-advance timing for every slide (0 = no timing).
    final autoAdvanceMs = autoAdvance?.inMilliseconds ?? 0;

    // 1. Individual slides XML, slide rels, notes slides and media.
    final slideXmls = <String>[];
    final slideRelsXmls = <String>[];
    final timingsWatch = Stopwatch()..start();
    final parseMsBefore = parseCache?.parseMs ?? 0;
    for (int i = 0; i < slides.length; i++) {
      // Cooperative cancellation + per-slide progress (Track 01).
      cancelToken?.throwIfCancelled();
      onProgress?.call(ExportProgressBudget.forSlide(i, slides.length));
      final slideNum = i + 1;
      final slide = slides[i];
      final rels = _SlideRels()
        // Track 05: bind the slide to its registered layout part (blank by
        // default — the v1.6.3 behavior for slides without a layoutType).
        ..layoutTarget =
            '../slideLayouts/slideLayout${layoutPartNumber(layoutTypeOf(slide))}.xml';
      final slideMedia = <_MediaFile>[];

      // Per-slide transition override (falls back to the deck-wide effect).
      var slideEffect = effect;
      final effectOverride = slide['effect'];
      if (effectOverride is String && effectOverride.isNotEmpty) {
        try {
          slideEffect = SlideEffect.values.byName(effectOverride);
        } catch (_) {}
      }

      // Track 33, P5: per-slide auto-advance wins over the deck-wide value.
      final slideAuto = (slide['autoAdvanceMs'] as num?)?.toInt() ?? 0;
      final slideAdvanceMs = slideAuto > 0 ? slideAuto : autoAdvanceMs;

      final slideXml = _buildSlideXml(
        slide,
        slideNum,
        slideEffect,
        geometry: geometry,
        includeBackgrounds: includeBackgrounds,
        imageMaxWidth: imageMaxWidth,
        autoAdvanceMs: slideAdvanceMs > 0 ? slideAdvanceMs : null,
        rels: rels,
        media: slideMedia,
        nextMediaIndex: () => ++mediaCounter,
        parseCache: parseCache,
        fitContent: fitContent,
        mediaByContentKey: mediaByContentKey,
        chartRegistry: chartRegistry,
        smartArtRegistry: smartArtRegistry,
        deckMeta: deckMeta,
      );

      for (final m in slideMedia) {
        mediaFiles.add(m);
        mediaExts.add(m.name.substring(m.name.lastIndexOf('.') + 1));
      }

      // Speaker notes: explicit 'notes' field wins, then <aside class="notes">.
      var notes = (slide['notes'] ?? '').toString().trim();
      if (notes.isEmpty) {
        notes = extractNotes((slide['htmlContent'] ?? '').toString(),
            parseCache: parseCache);
      }
      if (includeNotes && notes.isNotEmpty) {
        notesSlideNums.add(slideNum);
        rels.addNotesSlide('../notesSlides/notesSlide$slideNum.xml');
        final notesXml = _buildNotesSlideXml(notes);
        _addTextFile(
            archive, 'ppt/notesSlides/notesSlide$slideNum.xml', notesXml);
        final notesRelsXml =
            '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="../slides/slide$slideNum.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster" Target="../notesMasters/notesMaster1.xml"/>
</Relationships>''';
        _addTextFile(archive,
            'ppt/notesSlides/_rels/notesSlide$slideNum.xml.rels', notesRelsXml);
      }

      slideXmls.add(slideXml);
      slideRelsXmls.add(rels.toXml());
    }

    // 2. [Content_Types].xml
    final contentTypesXml = _buildContentTypesXml(
      slides.length,
      mediaExtensions: mediaExts,
      notesSlideNums: notesSlideNums,
      hasNotesMaster: notesSlideNums.isNotEmpty,
      chartCount: chartRegistry.count,
      diagramCount: smartArtRegistry.count,
    );
    _addTextFile(archive, '[Content_Types].xml', contentTypesXml);

    // 3. _rels/.rels
    const dotRelsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';
    _addTextFile(archive, '_rels/.rels', dotRelsXml);

    // 4. docProps (title from first slide, app name).
    final docTitle = slides.isNotEmpty
        ? _xmlEscape((slides.first['title'] ?? 'Presentation').toString())
        : 'Presentation';
    final coreXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>$docTitle</dc:title>
  <dc:creator>Ghita PPT Converter</dc:creator>
  <cp:lastModifiedBy>Ghita PPT Converter</cp:lastModifiedBy>
</cp:coreProperties>''';
    _addTextFile(archive, 'docProps/core.xml', coreXml);
    final appXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Ghita PPT Converter</Application>
  <Slides>${slides.length}</Slides>
</Properties>''';
    _addTextFile(archive, 'docProps/app.xml', appXml);

    // 5. ppt/presentation.xml + rels
    final presentationXml = _buildPresentationXml(
      slides.length,
      geometry: geometry,
      hasNotesMaster: notesSlideNums.isNotEmpty,
      customShow: customShow,
    );
    _addTextFile(archive, 'ppt/presentation.xml', presentationXml);
    final presentationRelsXml = _buildPresentationRelsXml(
      slides.length,
      hasNotesMaster: notesSlideNums.isNotEmpty,
    );
    _addTextFile(
        archive, 'ppt/_rels/presentation.xml.rels', presentationRelsXml);

    // 6. ppt/slideMasters/slideMaster1.xml + rels — one master carrying all
    // nine registered layouts (Track 05): PowerPoint allows a single master
    // with several layouts, so the Slide Layout gallery shows the full set.
    final layoutIdLst = [
      for (var i = 0; i < pptLayouts.length; i++)
        '<p:sldLayoutId id="${2147483649 + i}" r:id="rId${i + 1}"/>',
    ].join();
    final slideMasterXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>$footerShapesXml</p:spTree></p:cSld>
  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  <p:sldLayoutIdLst>$layoutIdLst</p:sldLayoutIdLst>
</p:sldMaster>''';
    _addTextFile(archive, 'ppt/slideMasters/slideMaster1.xml', slideMasterXml);
    final slideMasterRels = StringBuffer(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n');
    for (var i = 0; i < pptLayouts.length; i++) {
      slideMasterRels.write(
          '  <Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout${i + 1}.xml"/>\n');
    }
    slideMasterRels.write(
        '  <Relationship Id="rId${pptLayouts.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>\n');
    slideMasterRels.write('</Relationships>');
    _addTextFile(archive, 'ppt/slideMasters/_rels/slideMaster1.xml.rels',
        slideMasterRels.toString());

    // 7. ppt/slideLayouts/slideLayoutN.xml + rels (master). Nine layouts
    // with real PowerPoint placeholders (title/body/pic/…); blank is the
    // v1.6.3 default. Layouts carry no hardcoded palette — colors and fonts
    // flow through the master's clrMap + theme1.xml (Track 04, P6).
    for (var i = 0; i < pptLayouts.length; i++) {
      final layoutNum = i + 1;
      _addTextFile(archive, 'ppt/slideLayouts/slideLayout$layoutNum.xml',
          _buildSlideLayoutXml(pptLayouts[i]));
      const slideLayoutRelsXml =
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''';
      _addTextFile(archive,
          'ppt/slideLayouts/_rels/slideLayout$layoutNum.xml.rels',
          slideLayoutRelsXml);
    }

    // 8. ppt/notesMasters/notesMaster1.xml + rels (theme)
    if (notesSlideNums.isNotEmpty) {
      const notesMasterXml =
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:notesMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld><p:spTree>
    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
    <p:grpSpPr/>
    <p:sp>
      <p:nvSpPr><p:cNvPr id="2" name="Notes Placeholder"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr>
      <p:spPr><a:xfrm><a:off x="685800" y="4400550"/><a:ext cx="5486400" cy="3600450"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>
      <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:endParaRPr lang="en-US"/></a:p></p:txBody>
    </p:sp>
  </p:spTree></p:cSld>
  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  <p:notesStyle><a:lvl1pPr marL="0" algn="l"><a:defRPr sz="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/></a:defRPr></a:lvl1pPr></p:notesStyle>
</p:notesMaster>''';
      _addTextFile(
          archive, 'ppt/notesMasters/notesMaster1.xml', notesMasterXml);
      const notesMasterRelsXml =
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme2.xml"/>
</Relationships>''';
      _addTextFile(archive, 'ppt/notesMasters/_rels/notesMaster1.xml.rels',
          notesMasterRelsXml);
    }

    // 9. ppt/theme/theme1.xml (+ theme2.xml for the notes master) — user
    // theme when provided, otherwise the exact v1.6.3 Office defaults.
    final themeXml = _buildThemeXml(theme ?? PptThemeSetting.office);
    _addTextFile(archive, 'ppt/theme/theme1.xml', themeXml);
    if (notesSlideNums.isNotEmpty) {
      _addTextFile(archive, 'ppt/theme/theme2.xml', themeXml);
    }

    // 10. Slides + rels + media
    for (int i = 0; i < slideXmls.length; i++) {
      final slideNum = i + 1;
      _addTextFile(archive, 'ppt/slides/slide$slideNum.xml', slideXmls[i]);
      _addTextFile(archive, 'ppt/slides/_rels/slide$slideNum.xml.rels',
          slideRelsXmls[i]);
    }
    for (final m in mediaFiles) {
      // Media (JPEG/PNG/GIF) arrives already compressed — storing it as-is
      // avoids a wasteful second deflate pass and shrinks export time while
      // keeping the byte-identical payload PowerPoint expects.
      final mediaFile =
          ArchiveFile('ppt/media/${m.name}', m.bytes.length, m.bytes)
            ..compress = !debugStoreCompressedMedia;
      archive.addFile(mediaFile);
    }

    // 11b. SmartArt (Track 10, P3): data parts per unique diagram + shared
    // layout / quick-style / colors parts.
    if (smartArtRegistry.count > 0) {
      for (final graph in smartArtRegistry.graphs) {
        final index = smartArtRegistry.partIndexFor(graph);
        final pkg = PptSmartArtWriter.build(graph);
        _addTextFile(archive, 'ppt/diagrams/data$index.xml', pkg.dataXml);
      }
      final sample = smartArtRegistry.graphs.first;
      final pkg = PptSmartArtWriter.build(sample);
      _addTextFile(archive, 'ppt/diagrams/layout1.xml', pkg.layoutXml);
      _addTextFile(archive, 'ppt/diagrams/quickStyle1.xml', pkg.quickStyleXml);
      _addTextFile(archive, 'ppt/diagrams/colors1.xml', pkg.colorsXml);
    }

    // 11. Charts (Track 08, P4): one chartN.xml + rels + embedded workbook
    // per unique chart definition, referenced from the slide shapes above.
    for (final entry in chartRegistry.entries) {
      final pkg = PptChartWriter.build(entry.chart, index: entry.index);
      _addTextFile(archive, 'ppt/charts/${pkg.chartName}', pkg.chartXml);
      _addTextFile(archive, 'ppt/charts/_rels/${pkg.chartName}.rels',
          pkg.relsXml);
      archive.addFile(ArchiveFile(
        'ppt/embeddings/${entry.sheetName}',
        pkg.xlsxBytes.length,
        pkg.xlsxBytes,
      ));
    }

    cancelToken?.throwIfCancelled();
    // Text/XML parts are highly compressible: deflate them at the strongest
    // level (the UTF-8 byte-length fix in _addTextFile stays untouched).
    final encoder = ZipEncoder();
    final encodeWatch = Stopwatch()..start();
    final bytes = encoder.encode(archive, level: debugZipLevel);
    encodeWatch.stop();
    timingsWatch.stop();
    if (timings != null) {
      final parseAccumulatedMs = parseCache == null
          ? 0.0
          : parseCache.parseMs - parseMsBefore;
      final zipMs = encodeWatch.elapsedMicroseconds / 1000;
      timings
        ..zipMs = zipMs
        ..parseMs = parseAccumulatedMs
        ..buildMs = timingsWatch.elapsedMicroseconds / 1000 -
            zipMs -
            (parseCache == null ? 0.0 : parseAccumulatedMs)
        ..bytes = bytes?.length ?? 0;
    }
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Failed to encode the PPTX package');
    }
    return Uint8List.fromList(bytes);
  }

  static String _buildContentTypesXml(
    int count, {
    Set<String> mediaExtensions = const {},
    List<int> notesSlideNums = const [],
    bool hasNotesMaster = false,
    int chartCount = 0,
    int diagramCount = 0,
  }) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write(
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n');
    buffer.write(
        '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n');
    buffer
        .write('  <Default Extension="xml" ContentType="application/xml"/>\n');
    if (mediaExtensions.contains('png')) {
      buffer.write('  <Default Extension="png" ContentType="image/png"/>\n');
    }
    if (mediaExtensions.contains('jpg')) {
      buffer.write('  <Default Extension="jpg" ContentType="image/jpeg"/>\n');
    }
    if (mediaExtensions.contains('gif')) {
      buffer.write('  <Default Extension="gif" ContentType="image/gif"/>\n');
    }
    if (mediaExtensions.contains('mp4')) {
      // Track 11, P1: embedded mp4 — kept with the other Defaults so every
      // <Default> still precedes the first <Override> (PowerPoint rejects
      // Defaults that come after Overrides).
      buffer.write(
          '  <Default Extension="mp4" ContentType="video/mp4"/>\n');
    }
    if (mediaExtensions.contains('m4a')) {
      // Track 13, P4: narration audio (AAC in the m4a container).
      buffer.write(
          '  <Default Extension="m4a" ContentType="audio/mp4"/>\n');
    }
    if (mediaExtensions.contains('wav')) {
      // Track 13, P4: narration fallback when FFmpeg is unavailable.
      buffer.write(
          '  <Default Extension="wav" ContentType="audio/x-wav"/>\n');
    }
    if (mediaExtensions.contains('glb')) {
      // Track 14, P3: binary glTF 3D models (Office 2017 model3d parts).
      buffer.write(
          '  <Default Extension="glb" ContentType="model/gltf-binary"/>\n');
    }
    // Track 09: embedded workbooks — OOXML requires every Default BEFORE
    // the first Override (PowerPoint rejects Defaults written after
    // Overrides, which is what the reverse-bisection against real
    // PowerPoint confirmed).
    if (chartCount > 0) {
      buffer.write(
          '  <Default Extension="xlsx" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"/>\n');
    }
    buffer.write(
        '  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>\n');
    buffer.write(
        '  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>\n');
    for (var i = 1; i <= pptLayouts.length; i++) {
      buffer.write(
          '  <Override PartName="/ppt/slideLayouts/slideLayout$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>\n');
    }
    if (chartCount > 0) {
      for (var i = 1; i <= chartCount; i++) {
        buffer.write(
            '  <Override PartName="/ppt/charts/chart$i.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>\n');
      }
    }
    if (diagramCount > 0) {
      for (var i = 1; i <= diagramCount; i++) {
        buffer.write(
            '  <Override PartName="/ppt/diagrams/data$i.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.diagramData+xml"/>\n');
      }
      buffer.write(
          '  <Override PartName="/ppt/diagrams/layout1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.diagramLayout+xml"/>\n');
      buffer.write(
          '  <Override PartName="/ppt/diagrams/quickStyle1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.diagramQuickStyle+xml"/>\n');
      buffer.write(
          '  <Override PartName="/ppt/diagrams/colors1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.diagramColors+xml"/>\n');
    }
    if (hasNotesMaster) {
      buffer.write(
          '  <Override PartName="/ppt/notesMasters/notesMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesMaster+xml"/>\n');
    }
    buffer.write(
        '  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>\n');
    if (hasNotesMaster) {
      buffer.write(
          '  <Override PartName="/ppt/theme/theme2.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>\n');
    }
    buffer.write(
        '  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>\n');
    buffer.write(
        '  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>\n');

    for (int i = 1; i <= count; i++) {
      buffer.write(
          '  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>\n');
    }
    for (final n in notesSlideNums) {
      buffer.write(
          '  <Override PartName="/ppt/notesSlides/notesSlide$n.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml"/>\n');
    }
    buffer.write('</Types>');
    return buffer.toString();
  }

  static String _buildPresentationXml(
    int count, {
    required _PptGeometry geometry,
    bool hasNotesMaster = false,
    // Track 36, P7: named custom show written into the PPTX file.
    CustomShow? customShow,
  }) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write(
        '<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n');
    buffer.write('  <p:sldMasterIdLst>\n');
    buffer.write('    <p:sldMasterId id="2147483648" r:id="rId1"/>\n');
    buffer.write('  </p:sldMasterIdLst>\n');
    if (hasNotesMaster) {
      // Notes master relationship follows all slide relationships.
      buffer.write('  <p:notesMasterIdLst>\n');
      buffer.write('    <p:notesMasterId r:id="rId${count + 2}"/>\n');
      buffer.write('  </p:notesMasterIdLst>\n');
    }
    buffer.write('  <p:sldIdLst>\n');
    for (int i = 1; i <= count; i++) {
      final rId = i + 1; // rId1 is slideMaster, rId2+ are slides
      final sldId = 255 + i;
      buffer.write('    <p:sldId id="$sldId" r:id="rId$rId"/>\n');
    }
    buffer.write('  </p:sldIdLst>\n');
    final preset = geometry.aspectRatio.pptxPreset;
    final type = preset == null ? '' : ' type="$preset"';
    buffer.write(
        '  <p:sldSz cx="${geometry.width}" cy="${geometry.height}"$type/>\n');
    buffer.write('  <p:notesSz cx="6858000" cy="9144000"/>\n');
    if (customShow != null && customShow.slideIndices.isNotEmpty) {
      // Track 36, P7: p:custShowLst — PowerPoint shows this named set in the
      // custom shows list of Set Up Show.
      buffer.write('  <p:custShowLst>\n');
      const showId = 1;
      final safeName = customShow.name
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;');
      buffer.write('    <p:custShow id="$showId" name="$safeName">\n');
      buffer.write('      <p:sldLst>\n');
      for (final i in customShow.validIndices(count)) {
        // sldIdLst ids follow the same scheme as above (255 + index+1).
        buffer.write('        <p:sld id="${256 + i}"/>\n');
      }
      buffer.write('      </p:sldLst>\n');
      buffer.write('    </p:custShow>\n');
      buffer.write('  </p:custShowLst>\n');
    }
    buffer.write('</p:presentation>');
    return buffer.toString();
  }

  static String _buildPresentationRelsXml(
    int count, {
    bool hasNotesMaster = false,
  }) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write(
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n');
    buffer.write(
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>\n');
    for (int i = 1; i <= count; i++) {
      final rId = i + 1;
      buffer.write(
          '  <Relationship Id="rId$rId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>\n');
    }
    if (hasNotesMaster) {
      buffer.write(
          '  <Relationship Id="rId${count + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster" Target="notesMasters/notesMaster1.xml"/>\n');
    }
    buffer.write('</Relationships>');
    return buffer.toString();
  }

  static String _buildNotesSlideXml(String notes) {
    final b = StringBuffer();
    b.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    b.write(
        '<p:notes xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n');
    b.write('  <p:cSld>\n');
    b.write('    <p:spTree>\n');
    b.write(
        '      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\n');
    b.write('      <p:grpSpPr/>\n');
    b.write('      <p:sp>\n');
    b.write(
        '        <p:nvSpPr><p:cNvPr id="2" name="Notes Placeholder"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr>\n');
    b.write('        <p:spPr/>\n');
    b.write('        <p:txBody><a:bodyPr/><a:lstStyle/>\n');
    for (final line in notes.split('\n')) {
      b.write(
          '          <a:p><a:r><a:rPr/><a:t>${_xmlEscape(line)}</a:t></a:r></a:p>\n');
    }
    b.write('        </p:txBody>\n');
    b.write('      </p:sp>\n');
    b.write('    </p:spTree>\n');
    b.write('  </p:cSld>\n');
    b.write('  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>\n');
    b.write('</p:notes>');
    return b.toString();
  }

  /// Minimal but complete Office theme so PowerPoint/LibreOffice open the
  /// package without a repair prompt.
  /// Build the OOXML theme part (Track 04).
  ///
  /// The colour scheme and font scheme are generated from [theme]; the
  /// default ([PptThemeSetting.office]) reproduces the v1.6.3 hardcoded
  /// Office theme byte-for-byte. Values are sanitized so a weird font name
  /// can never corrupt the XML: PowerPoint substitutes unknown families
  /// itself, which is the intended fallback instead of a repair prompt.
  static String _buildThemeXml(PptThemeSetting theme) {
    const fill = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>';
    const ln =
        '<a:ln w="9525" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>';

    String srgb(String value) =>
        '<a:srgbClr val="${_safeThemeHex(value)}"/>';
    String font(String name) {
      final trimmed = name.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
      final safe = trimmed.isEmpty ? 'Calibri' : trimmed;
      return _xmlEscape(safe.substring(0, safe.length > 64 ? 64 : safe.length));
    }

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Ghita Theme">'
        '<a:themeElements>'
        '<a:clrScheme name="Ghita">'
        '<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>'
        '<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
        '<a:dk2>${srgb(theme.dk2)}</a:dk2>'
        '<a:lt2>${srgb(theme.lt2)}</a:lt2>'
        '<a:accent1>${srgb(theme.accent1)}</a:accent1>'
        '<a:accent2>${srgb(theme.accent2)}</a:accent2>'
        '<a:accent3>${srgb(theme.accent3)}</a:accent3>'
        '<a:accent4>${srgb(theme.accent4)}</a:accent4>'
        '<a:accent5>${srgb(theme.accent5)}</a:accent5>'
        '<a:accent6>${srgb(theme.accent6)}</a:accent6>'
        '<a:hlink>${srgb(theme.hlink)}</a:hlink>'
        '<a:folHlink>${srgb(theme.folHlink)}</a:folHlink>'
        '</a:clrScheme>'
        '<a:fontScheme name="Ghita">'
        '<a:majorFont><a:latin typeface="${font(theme.fontMajor)}"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
        '<a:minorFont><a:latin typeface="${font(theme.fontMinor)}"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>'
        '</a:fontScheme>'
        '<a:fmtScheme name="Ghita">'
        '<a:fillStyleLst>$fill$fill$fill</a:fillStyleLst>'
        '<a:lnStyleLst>$ln$ln$ln</a:lnStyleLst>'
        '<a:effectStyleLst>'
        '<a:effectStyle><a:effectLst/></a:effectStyle>'
        '<a:effectStyle><a:effectLst/></a:effectStyle>'
        '<a:effectStyle><a:effectLst/></a:effectStyle>'
        '</a:effectStyleLst>'
        '<a:bgFillStyleLst>$fill$fill$fill</a:bgFillStyleLst>'
        '</a:fmtScheme>'
        '</a:themeElements>'
        '</a:theme>';
  }

  /// Only six hex digits reach the XML; anything else falls back to the
  /// Office accent so a bad value can never trigger a repair prompt.
  static String _safeThemeHex(String value) =>
      RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(value) ? value : '4472C4';

  static String _buildSlideXml(
    Map<String, dynamic> slide,
    int slideNum,
    SlideEffect effect, {
    required _PptGeometry geometry,
    bool includeBackgrounds = true,
    int? imageMaxWidth,
    int? autoAdvanceMs,
    _SlideRels? rels,
    List<_MediaFile>? media,
    int Function()? nextMediaIndex,
    HtmlParseCache? parseCache,
    bool fitContent = true,
    Map<String, String>? mediaByContentKey,
    _ChartRegistry? chartRegistry,
    _SmartArtRegistry? smartArtRegistry,
    DeckMeta? deckMeta,
  }) {
    final rawTitle = slide['title'] ?? 'Slide $slideNum';
    // toString() keeps the whole generator type-safe even when an
    // imported/hand-edited deck carries a non-string htmlContent.
    final rawHtml = (slide['htmlContent'] ?? '').toString();

    final cleanTitle = _xmlEscape(rawTitle.toString());
    // Single-pass HTML parse — served from the session cache when available.
    // The first h2 is the dedicated subtitle and must not be emitted again as
    // a body paragraph.
    String? subtitleText;
    final List<Map<String, dynamic>> parsed;
    if (parseCache != null) {
      subtitleText = parseCache.subtitleFor(rawHtml);
      parsed = parseCache.blocksFor(rawHtml, dropFirstH2: true);
    } else {
      final parsedDoc = html_parser.parse(rawHtml);
      final h2 = parsedDoc.querySelector('h2');
      if (h2 != null && h2.text.trim().isNotEmpty) {
        subtitleText = h2.text.trim();
        h2.remove();
      }
      parsed =
          parseHtmlContentFullFromDoc(parsedDoc, fallbackText: rawHtml);
    }
    final contentW = geometry.contentWidth;

    // Typed Slide.bgColor wins over the legacy HTML data attribute. Normalize
    // values so srgbClr only ever receives six hexadecimal digits.
    String? bgColor = cssColorToHex((slide['bgColor'] ?? '').toString());
    if (bgColor == null) {
      final bgMatch = _bgColorAttrRe.firstMatch(rawHtml);
      if (bgMatch != null) {
        bgColor = cssColorToHex(bgMatch.group(1)!);
      }
    }

    final b = StringBuffer();
    b.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    // Track 14: slides carrying a 3D model declare the Office 2017/2018
    // namespaces on the ROOT — exactly what PowerPoint itself writes
    // (verified against a Microsoft-generated golden deck; inline
    // declarations alone make PowerPoint reject the file).
    final hasModel3d = rawHtml.contains('data-model3d');
    final hasEquation = rawHtml.contains('data-equation');
    b.write(
        '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"'
        '${hasEquation ? ' xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"' : ''}'
        '${hasModel3d ? ' xmlns:am3d="http://schemas.microsoft.com/office/drawing/2017/model3d" xmlns:a16="http://schemas.microsoft.com/office/drawing/2014/main" xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" xmlns:a3danim="http://schemas.microsoft.com/office/drawing/2018/animation/model3d"' : ''}'
        '>\n');

    // CT_Slide requires cSld before transition, so the element is written
    // after the common slide data below.
    // Track 34, P4: morph takes over the transition when enabled.
    final String transitionXml;
    if (slide['morphFromPrevious'] == true) {
      transitionXml = MorphService.pptxTransition(
        enabled: true,
        durationMs: (slide['transitionDurationMs'] as num?)?.toInt(),
      );
    } else {
      transitionXml = _buildTransitionXml(
        effect,
        autoAdvanceMs: autoAdvanceMs,
        durationMs: (slide['transitionDurationMs'] as num?)?.toInt(),
        soundRid: slide['transitionSoundRid']?.toString(),
      );
    }

    b.write('  <p:cSld${(deckMeta?.excludeFirst ?? false) && slideNum == 1 ? ' showMasterSp="0"' : ''}>\n');

    // Background fill (if bgColor is specified)
    if (includeBackgrounds && bgColor != null) {
      b.write('    <p:bg>\n');
      b.write('      <p:bgPr>\n');
      b.write('        <a:solidFill>\n');
      b.write('          <a:srgbClr val="$bgColor"/>\n');
      b.write('        </a:solidFill>\n');
      b.write('        <a:effectLst/>\n');
      b.write('      </p:bgPr>\n');
      b.write('    </p:bg>\n');
    }

    b.write('    <p:spTree>\n');
    b.write(
        '      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\n');
    b.write('      <p:grpSpPr/>\n');

    // --- Title shape ---
    b.write('      <p:sp>\n');
    b.write(
        '        <p:nvSpPr><p:cNvPr id="2" name="Title 1"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>\n');
    b.write(
        '        <p:spPr><a:xfrm><a:off x="${geometry.contentX}" y="${geometry.titleY}"/><a:ext cx="$contentW" cy="${geometry.titleHeight}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
    b.write('        <p:txBody><a:bodyPr/><a:lstStyle/>\n');
    b.write(
        '          <a:p><a:r><a:rPr lang="en-US" sz="3600" b="1"/><a:t>$cleanTitle</a:t></a:r></a:p>\n');
    b.write('        </p:txBody>\n');
    b.write('      </p:sp>\n');

    // --- Subtitle shape (if h2 present) ---
    if (subtitleText != null && subtitleText.isNotEmpty) {
      final cleanSubtitle = _xmlEscape(subtitleText);
      b.write('      <p:sp>\n');
      b.write(
          '        <p:nvSpPr><p:cNvPr id="7" name="Subtitle 1"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>\n');
      b.write(
          '        <p:spPr><a:xfrm><a:off x="${geometry.contentX}" y="${geometry.subtitleY}"/><a:ext cx="$contentW" cy="${geometry.subtitleHeight}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
      b.write('        <p:txBody><a:bodyPr/><a:lstStyle/>\n');
      b.write(
          '          <a:p><a:pPr><a:buNone/></a:pPr><a:r><a:rPr lang="en-US" sz="2400" i="1"/><a:t>$cleanSubtitle</a:t></a:r></a:p>\n');
      b.write('        </p:txBody>\n');
      b.write('      </p:sp>\n');
    }

    // --- Content shapes (simple vertical flow layout) ---
    int y = subtitleText != null
        ? geometry.contentTopWithSubtitle
        : geometry.contentTopWithoutSubtitle;
    int shapeId = 10;

    // Track 32: map app shape ids ('sh_x' / 'ft_x') to the numeric spids
    // assigned below so the p:timing tree can target them.
    final spidMap = <String, int>{};

    int estimatedHeight(Map<String, dynamic> block, {double scale = 1.0}) {
      return estimateBlockHeight(block,
          contentWidthEmu: contentW, scale: scale, imageMaxWidth: imageMaxWidth);
    }

    final layoutBlocks = parsed.where((block) {
      final type = block['type'];
      return type == 'text' ||
          type == 'list' ||
          type == 'table' ||
          (type == 'image' &&
              rels != null &&
              media != null &&
              nextMediaIndex != null) ||
          (type == 'icon' &&
              rels != null &&
              media != null &&
              nextMediaIndex != null);
    }).toList();
    const desiredGap = 91440;
    final contentStart = y;
    final availableHeight = (geometry.contentBottom - contentStart)
        .clamp(1, geometry.contentBottom)
        .toInt();
    final gapCount = layoutBlocks.isEmpty ? 0 : layoutBlocks.length - 1;
    final gapLimit =
        layoutBlocks.isEmpty ? 0 : availableHeight ~/ (layoutBlocks.length * 2);
    final gap = desiredGap < gapLimit ? desiredGap : gapLimit;
    final usableHeight = availableHeight - gap * gapCount;

    int desiredHeightFor(double scale) => layoutBlocks
        .map((block) => estimatedHeight(block, scale: scale))
        .fold<int>(0, (sum, value) => sum + value);

    // "Fit content": when the deck overflows the slide, shrink the text
    // recursively 90% per pass (PowerPoint "Shrink text on overflow" style)
    // down to 60% of the original size — only with fitContent enabled.
    double sizeScale = 1.0;
    if (fitContent) {
      while (sizeScale > 0.6 && desiredHeightFor(sizeScale) > usableHeight) {
        sizeScale *= 0.9;
      }
    }

    final estimates =
        layoutBlocks.map((block) => estimatedHeight(block, scale: sizeScale)).toList();
    final desiredHeight =
        estimates.fold<int>(0, (sum, value) => sum + value);
    final targetHeight =
        desiredHeight < usableHeight ? desiredHeight : usableHeight;
    var allocatedHeight = 0;

    for (int blockIndex = 0; blockIndex < layoutBlocks.length; blockIndex++) {
      final block = layoutBlocks[blockIndex];
      final type = block['type'] as String;
      final blockY = contentStart + allocatedHeight + gap * blockIndex;
      final isLast = blockIndex == layoutBlocks.length - 1;
      final blockHeight = isLast
          ? targetHeight - allocatedHeight
          : (estimates[blockIndex] * targetHeight / desiredHeight)
              .floor()
              .clamp(1, targetHeight - allocatedHeight)
              .toInt();
      allocatedHeight += blockHeight;

      if (type == 'text') {
        _buildTextContentShape(b, block,
            shapeId: shapeId++,
            x: geometry.contentX,
            y: blockY,
            h: blockHeight,
            w: contentW,
            rels: rels,
            sizeScale: sizeScale);
      } else if (type == 'list') {
        _buildListContentShape(b, block,
            shapeId: shapeId++,
            x: geometry.contentX,
            y: blockY,
            h: blockHeight,
            w: contentW,
            rels: rels,
            sizeScale: sizeScale);
      } else if (type == 'table') {
        _buildTableShape(b, block,
            shapeId: shapeId++,
            x: geometry.contentX,
            y: blockY,
            h: blockHeight,
            w: contentW,
            sizeScale: sizeScale);
      } else if (type == 'image' &&
          rels != null &&
          media != null &&
          nextMediaIndex != null) {
        _buildImageShape(b, block,
            shapeId: shapeId++,
            x: geometry.contentX,
            y: blockY,
            h: blockHeight,
            w: contentW,
            imageMaxWidth: imageMaxWidth,
            rels: rels,
            media: media,
            nextMediaIndex: nextMediaIndex,
            mediaByContentKey: mediaByContentKey,
            jpegQuality: jpegQualityForMaxWidth(imageMaxWidth));
      } else if (type == 'icon' &&
          rels != null &&
          media != null &&
          nextMediaIndex != null) {
        _buildIconShape(b, block,
            shapeId: shapeId++,
            x: geometry.contentX,
            y: blockY,
            h: blockHeight,
            w: contentW,
            rels: rels,
            media: media,
            nextMediaIndex: nextMediaIndex,
            mediaByContentKey: mediaByContentKey);
      }
    }

    // 13. SmartArt shapes (Track 10, P3): `<div data-smartart='…'>` blocks
    // become <dgm:diagram> graphicFrames; the layout/quickStyle/colors
    // parts are shared, the data part is unique per diagram definition.
    if (smartArtRegistry != null && rawHtml.contains('data-smartart')) {
      final diagramY = geometry.contentTopWithoutSubtitle;
      const diagramHeight = 2743200; // ~40% of a 7.5" slide
      var offset = 0;
      for (final match in _diagramPatternRe.allMatches(rawHtml)) {
        final graph = SmartArtGraph.fromJson(match.group(2)!);
        // Track 10, P10: empty diagrams are skipped (no repair-prone part).
        if (graph == null || graph.nodes.isEmpty) continue;
        final index = smartArtRegistry.partIndexFor(graph);
        final dataRid = rels?.addDiagramData('../diagrams/data$index.xml');
        final layoutRid = rels?.addDiagramLayout('../diagrams/layout1.xml');
        final styleRid =
            rels?.addDiagramQuickStyle('../diagrams/quickStyle1.xml');
        final colorRid = rels?.addDiagramColors('../diagrams/colors1.xml');
        b.write('      <p:graphicFrame>\n');
        b.write(
            '        <p:nvGraphicFramePr><p:cNvPr id="${shapeId++}" name="SmartArt ${graph.layout.name}"/><p:cNvGraphicFramePr><a:graphicFrameLocks noGrp="1"/></p:cNvGraphicFramePr><p:nvPr/></p:nvGraphicFramePr>\n');
        b.write(
            '        <p:xfrm><a:off x="${geometry.contentX}" y="${diagramY + offset}"/><a:ext cx="$contentW" cy="$diagramHeight"/></p:xfrm>\n');
        b.write(
            '        <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/diagram">\n');
        // Track 10, P8 (verified against real PowerPoint): the modern
        // <dgm:relIds r:dm/r:lo/r:qs/r:cs> binding form is required — the
        // legacy <dgm:diagram dgm:dataId=…/> attribute form makes PowerPoint
        // reject the whole deck (0x80070570) when the diagram is referenced.
        b.write(
            '          <dgm:relIds xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:dm="$dataRid" r:lo="$layoutRid" r:qs="$styleRid" r:cs="$colorRid"/>\n');
        b.write('        </a:graphicData></a:graphic>\n');
        b.write('      </p:graphicFrame>\n');
        offset += diagramHeight + 91440;
      }
    }

    // 12. Chart shapes (Track 08, P4): every `<div data-chart='…'>` in the
    // slide HTML becomes a graphicFrame bound to its (deduplicated) chart
    // part; the embedded workbook keeps the data editable in PowerPoint.
    if (chartRegistry != null && rawHtml.contains('data-chart')) {
      final chartY = geometry.contentTopWithoutSubtitle;
      const chartHeight = 2286000; // ~1/3 of a 7.5" slide
      var offset = 0;
      for (final match in _chartPatternRe.allMatches(rawHtml)) {
        final chart = ChartData.fromJson(match.group(1)!);
        // Track 09, P10: charts without data are skipped instead of emitting
        // an empty (repair-prone) <c:chart> part.
        if (chart == null ||
            chart.series.isEmpty ||
            chart.series.every((s) => s.values.isEmpty)) {
          continue;
        }
        final partName = chartRegistry.partFor(chart);
        b.write('      <p:graphicFrame>\n');
        b.write(
            '        <p:nvGraphicFramePr><p:cNvPr id="${shapeId++}" name="Chart ${chart.type.name}"/><p:cNvGraphicFramePr><a:graphicFrameLocks noGrp="1"/></p:cNvGraphicFramePr><p:nvPr/></p:nvGraphicFramePr>\n');
        b.write(
            '        <p:xfrm><a:off x="${geometry.contentX}" y="${chartY + offset}"/><a:ext cx="$contentW" cy="$chartHeight"/></p:xfrm>\n');
        b.write(
            '        <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">\n');
        b.write(
            '          <c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="${rels?.addChart('../charts/$partName')}"/>\n');
        b.write('        </a:graphicData></a:graphic>\n');
        b.write('      </p:graphicFrame>\n');
        offset += chartHeight + 91440;
      }
    }

    // 14. Video blocks (Track 11, P2): `<video data-video='…'>` tags become
    // a single `<p:pic>` that carries the poster image AND the mp4 link —
    // the shape structure PowerPoint itself writes (verified against an
    // `AddMediaObject2` COM golden). The payload travels as a data: URI in
    // the tag and is embedded under ppt/media/ with the same content-based
    // dedupe as images; autoplay/loop are expressed through p:timing.
    final mediaSpecs = <MediaTimingSpec>[];
    var audioCounter = 0;
    if (rawHtml.contains('data-video')) {
      final videoY = geometry.contentTopWithoutSubtitle;
      var offset = 0;
      var localVideoCounter = 0;
      for (final match in _videoPatternRe.allMatches(rawHtml)) {
        final tagText = match.group(0)!;
        var video = VideoData.fromJson(match.group(2)!);
        // Tolerate tags where the payload lives only in the attributes:
        // merge the src/poster attributes into the JSON payload when the
        // JSON itself does not carry them.
        if (video.src.isEmpty) {
          video = video.copyWith(src: _tagAttr(tagText, 'src') ?? '');
        }
        if (video.poster.isEmpty) {
          video = video.copyWith(poster: _tagAttr(tagText, 'poster') ?? '');
        }
        // Track 11, P10: videos without a payload (no src, not online) are
        // skipped instead of emitting a broken <p:pic>.
        if (video.src.isEmpty && !video.isOnline) continue;
        final videoHeight = (contentW * 9 / 16).round();
        final offX = geometry.contentX;
        final offY = videoY + offset;
        final spid = shapeId++;
        String videoRid;
        String? mediaRid;
        if (video.isOnline) {
          // Online video: an external `video` relationship to the watch URL
          // (no p14:media extension — the legacy media rel is for embedded
          // files only).
          videoRid = rels?.addVideoFile(
                VideoEmbedService.youtubeWatchUrl(video.youtubeId!),
                external: true,
              ) ??
              '';
        } else {
          final bytes = _dataUriBytes(video.src);
          if (bytes == null) continue;
          final contentKey = crypto.sha256.convert(bytes).toString();
          final existingName = mediaByContentKey?[contentKey];
          final name = existingName ??
              'video${nextMediaIndex?.call() ?? ++localVideoCounter}.mp4';
          if (existingName == null) {
            mediaByContentKey?[contentKey] = name;
            media?.add(_MediaFile(name, bytes));
          }
          videoRid = rels?.addVideoFile('../media/$name') ?? '';
          mediaRid = rels?.addMedia('../media/$name');
        }
        // Poster: the tag's poster attribute, else a black fallback so the
        // required <p:blipFill> stays valid.
        final posterSrc = video.poster.isNotEmpty
            ? video.poster
            : VideoEmbedService.fallbackPosterDataUri;
        final posterBytes = _dataUriBytes(posterSrc);
        if (posterBytes == null) continue;
        final posterKey = crypto.sha256.convert(posterBytes).toString();
        final existingPoster = mediaByContentKey?[posterKey];
        final posterName = existingPoster ??
            'image${nextMediaIndex?.call() ?? ++localVideoCounter}.${_dataUriExt(posterSrc)}';
        if (existingPoster == null) {
          mediaByContentKey?[posterKey] = posterName;
          media?.add(_MediaFile(posterName, posterBytes));
        }
        final posterRid = rels?.addImage('../media/$posterName') ?? '';
        b.write('      ${VideoEmbedService.videoPicXml(
          shapeId: spid,
          name: video.isOnline ? 'Video online' : 'Video',
          videoRid: videoRid,
          mediaRid: mediaRid,
          posterRid: posterRid,
          offX: offX,
          offY: offY,
          extCx: contentW,
          extCy: videoHeight,
        )}\n');
        mediaSpecs.add(MediaTimingSpec(
          spid: spid,
          autoplay: video.autoplay,
          loop: video.loop,
          durationMs: video.durationMs > 0 ? video.durationMs : 60000,
        ));
        offset += videoHeight + 91440;
      }
    }

    // 15. Narration audio (Track 13, P4): a slide with an audioPath gets a
    // <p:pic> carrying a:audioFile + the speaker icon + a merged timing
    // entry — the shape PowerPoint writes for its own sound objects
    // (verified against an AddMediaObject2 golden). Playback options come
    // from slide['audioOptions'].
    final audioPath = (slide['audioPath'] ?? '').toString();
    if (audioPath.isNotEmpty && File(audioPath).existsSync()) {
      final audioOptions = slide['audioOptions'] is Map
          ? Map<String, dynamic>.from(slide['audioOptions'] as Map)
          : <String, dynamic>{};
      final audioAutoplay = audioOptions['autoplay'] == true;
      final audioLoop = audioOptions['loop'] == true;
      final acrossSlides = audioOptions['acrossSlides'] == true;
      final durationMs = (audioOptions['durationMs'] as num?)?.toInt() ?? 0;

      File? audioFile = File(audioPath);
      Uint8List? audioBytes;
      try {
        audioBytes = audioFile.readAsBytesSync();
      } catch (_) {}
      if (audioBytes != null) {
        final ext = audioPath.toLowerCase().endsWith('.wav') ? 'wav' : 'm4a';
        final contentKey = crypto.sha256.convert(audioBytes).toString();
        final existing = mediaByContentKey?[contentKey];
        final name =
            existing ?? 'audio${nextMediaIndex?.call() ?? ++audioCounter}.$ext';
        if (existing == null) {
          mediaByContentKey?[contentKey] = name;
          media?.add(_MediaFile(name, audioBytes));
        }
        final audioRid = rels?.addAudioFile('../media/$name') ?? '';
        final mediaRid = rels?.addMedia('../media/$name');
        // The speaker icon travels as a normal image part (deduped).
        final iconBytes =
            base64Decode(kSpeakerIconPngBase64);
        final iconKey = crypto.sha256.convert(iconBytes).toString();
        final existingIcon = mediaByContentKey?[iconKey];
        final iconName = existingIcon ??
            'image${nextMediaIndex?.call() ?? ++audioCounter}.png';
        if (existingIcon == null) {
          mediaByContentKey?[iconKey] = iconName;
          media?.add(_MediaFile(iconName, iconBytes));
        }
        final iconRid = rels?.addImage('../media/$iconName') ?? '';
        final spid = shapeId++;
        b.write('      ${VideoEmbedService.audioPicXml(
          shapeId: spid,
          name: 'Narration',
          audioRid: audioRid,
          mediaRid: mediaRid,
          posterRid: iconRid,
        )}\n');
        mediaSpecs.add(MediaTimingSpec(
          spid: spid,
          autoplay: audioAutoplay,
          loop: audioLoop,
          durationMs: durationMs > 0 ? durationMs : 60000,
          kind: MediaTimingKind.audio,
          acrossSlides: acrossSlides,
        ));
      }
    }

    // 16. 3D models (Track 14, P3–P5): `<div data-model3d='…'>` blocks become
    // the Office 2017 `am3d:model3d` graphicFrame inside mc:AlternateContent
    // (structure validated against a Microsoft-generated golden deck and real
    // PowerPoint). The GLB joins ppt/media/ with content dedupe; the poster
    // is rasterized PNG (package:image). rotate=true adds the a3danim
    // extension + a timeline fragment that plays the model's first embedded
    // animation indefinitely.
    final extraTimingPars = <String>[];
    if (rawHtml.contains('data-model3d')) {
      final modelY = geometry.contentTopWithoutSubtitle;
      var offset = 0;
      var modelCounter = 0;
      for (final match in _model3dPatternRe.allMatches(rawHtml)) {
        final model = Model3DData.fromJson(match.group(2)!);
        // Track 14, P10: models without a payload are skipped.
        if (model.src.isEmpty) continue;
        final glbBytes = _dataUriBytes(model.src);
        if (glbBytes == null) continue;
        final glbKey = crypto.sha256.convert(glbBytes).toString();
        final existingGlb = mediaByContentKey?[glbKey];
        final glbName = existingGlb ??
            'model3d${nextMediaIndex?.call() ?? ++modelCounter}.glb';
        if (existingGlb == null) {
          mediaByContentKey?[glbKey] = glbName;
          media?.add(_MediaFile(glbName, glbBytes));
        }
        final glbRid = rels?.addModel3d('../media/$glbName') ?? '';

        final posterBytes = Model3DService.renderPosterPng(model);
        final posterKey = crypto.sha256.convert(posterBytes).toString();
        final existingPoster = mediaByContentKey?[posterKey];
        final posterName = existingPoster ??
            'image${nextMediaIndex?.call() ?? ++modelCounter}.png';
        if (existingPoster == null) {
          mediaByContentKey?[posterKey] = posterName;
          media?.add(_MediaFile(posterName, posterBytes));
        }
        final posterRid = rels?.addImage('../media/$posterName') ?? '';

        final modelHeight = (contentW * 9 / 16).round();
        final spid = shapeId++;
        final fallbackId = shapeId++;
        b.write('      ${Model3DService.renderPptxModel3dXml(
          shapeId: spid,
          fallbackShapeId: fallbackId,
          name: model.name.isEmpty ? '3D Model' : model.name,
          glbRid: glbRid,
          posterRid: posterRid,
          offX: geometry.contentX,
          offY: modelY + offset,
          extCx: contentW,
          extCy: modelHeight,
          rotate: model.rotate,
          // RFC-4122 v4 GUID — PowerPoint's a16:creationId parser rejects
          // counter-style id strings (bisected against COM).
          creationId: _randomGuidV4(),
        )}\n');
        if (model.rotate) {
          extraTimingPars
              .add(Model3DService.model3dTimingParXml(spid, rotate: true));
        }
        offset += modelHeight + 91440;
      }
    }

    // 17. Free-form text/shape elements (Track 17, P3–P5): the
    // `visualElements` map from the typed Slide model carries a `freeTexts`
    // list — each element becomes a standalone `p:sp` with an explicit
    // `a:xfrm` (absolute EMU position, NOT the vertical flow used by the
    // HTML-derived shapes). WordArt styles map to gradient fills and
    // effects. The default content box is 10×7.5in = 9144000×6858000 EMU.
    final rawVisual = slide['visualElements'];
    if (rawVisual is Map && rawVisual['freeTexts'] is List) {
      final freeTexts = (rawVisual['freeTexts'] as List)
          .map((e) => e is Map<String, dynamic>
              ? FreeTextShape.fromMap(e)
              : (e is Map ? FreeTextShape.fromMap(Map<String, dynamic>.from(e)) : null))
          .whereType<FreeTextShape>()
          .toList()
        ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
      const slideW = 9144000;
      const slideH = 6858000;
      for (final ft in freeTexts) {
        final offX = (ft.x / 100 * slideW).round();
        final offY = (ft.y / 100 * slideH).round();
        final extW = (ft.w / 100 * slideW).round();
        final extH = (ft.h / 100 * slideH).round();
        final rot = ft.rotation != 0
            ? ' rot="${(ft.rotation * 60000).round()}"'
            : '';
        // Background fill
        String fillXml;
        final wa = ft.wordArtStyle;
        if (wa > 0 && WordArtService.pptxGradFill(wa).isNotEmpty) {
          // WordArt gradient style — fill the shape with the gradient.
          fillXml = WordArtService.pptxGradFill(wa);
        } else if (ft.backgroundColor != 'transparent') {
          final bg = _safeThemeHex(ft.backgroundColor.replaceAll('#', ''));
          fillXml = '<a:solidFill><a:srgbClr val="$bg"/></a:solidFill>';
        } else {
          fillXml = '<a:noFill/>';
        }
        // Border
        final lnXml = ft.borderColor.isNotEmpty && ft.borderWidth > 0
            ? '<a:ln w="${(ft.borderWidth * 12700).round()}"><a:solidFill><a:srgbClr val="${_safeThemeHex(ft.borderColor.replaceAll('#', ''))}"/></a:solidFill></a:ln>'
            : '';
        // WordArt effects
        final effectXml = wa > 0 ? WordArtService.pptxEffectLst(wa) : '';
        final textColor = ft.color.isEmpty ? '000000' : _safeThemeHex(ft.color.replaceAll('#', ''));
        final sz = (ft.fontSize * 100).round();
        final bold = ft.fontWeight == 'bold' ? ' b="1"' : '';
        final italic = ft.fontStyle == 'italic' ? ' i="1"' : '';
        final spid = shapeId++;
        spidMap['ft_${ft.id}'] = spid;
        b.write('      <p:sp>\n');
        b.write(
            '        <p:nvSpPr><p:cNvPr id="$spid" name="FreeText ${ft.id}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
        b.write(
            '        <p:spPr><a:xfrm$rot><a:off x="$offX" y="$offY"/><a:ext cx="$extW" cy="$extH"/></a:xfrm>'
            '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>$fillXml$lnXml</p:spPr>\n');
        b.write(
            '        <p:txBody><a:bodyPr wrap="none"><a:normAutofit/></a:bodyPr><a:lstStyle/><a:p>'
            '<a:pPr algn="ctr"/><a:r><a:rPr lang="en-US" sz="$sz"$bold$italic '
            '${ft.fontFamily.isEmpty ? '' : 'typeface="${_xmlEscape(ft.fontFamily)}"'}>'
            '<a:solidFill><a:srgbClr val="$textColor"/></a:solidFill>'
            '${effectXml.replaceAll('<a:effectLst>', '').replaceAll('</a:effectLst>', '')}'
            '</a:rPr><a:t>${_xmlEscape(ft.text)}</a:t></a:r></a:p></p:txBody>\n');
        b.write('      </p:sp>\n');
      }
    }

    // 18. Action buttons (Track 18, P1–P2): `<div data-action='...'>` blocks
    // become `p:sp` shapes with an `a:hlinkClick` carrying the slide-jump or
    // URL action (PowerPoint's Action Button behaviour).
    const slideWEmu = 9144000;
    const slideHEmu = 6858000;
    if (rawHtml.contains('data-action')) {
      for (final match in _actionPatternRe.allMatches(rawHtml)) {
        final button = ActionButton.fromJson(match.group(2)!);
        final offX = (button.x / 100 * slideWEmu).round();
        final offY = (button.y / 100 * slideHEmu).round();
        final extW = (button.w / 100 * slideWEmu).round();
        final extH = (button.h / 100 * slideHEmu).round();
        // Slide-jump actions use the ppaction://hlinksldjump hlink; URL/file
        // actions use a relationship-based hlink.
        String actionXml;
        switch (button.action) {
          case ActionType.url:
          case ActionType.file:
          case ActionType.program:
            final target = button.url.isNotEmpty
                ? button.url
                : (button.action == ActionType.file ? 'file:///' : '');
            if (target.isNotEmpty) {
              final rid = rels?.addHyperlink(target) ?? '';
              actionXml =
                  'r:id="$rid" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
            } else {
              actionXml = '';
            }
          case ActionType.slideNext:
          case ActionType.slidePrev:
          case ActionType.slideFirst:
          case ActionType.slideLast:
            actionXml =
                'action="ppaction://hlinksldjump" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
        }
        final spid = shapeId++;
        b.write(
            '      ${ActionButtonService.renderPptxActionShape(
          shapeId: spid,
          button: button,
          actionXml: actionXml,
          offX: offX,
          offY: offY,
          extCx: extW,
          extCy: extH,
        )}');
      }
    }

    // 19. Equations (Track 18, P3–P4): `<div data-equation='...'>` blocks
    // become `<p:sp>` text shapes whose body carries the OOXML `<a:math>`
    // markup (converted from the stored MathML).
    if (rawHtml.contains('data-equation')) {
      var eqOffset = 0;
      for (final match in _equationPatternRe.allMatches(rawHtml)) {
        final equation = EquationData.fromJson(match.group(2)!);
        final mathInner = EquationService.mathmlToOoxml(equation.mathml);
        final spid = shapeId++;
        const eqH = 685800; // ~0.75in
        b.write('      <p:sp>\n');
        b.write(
            '        <p:nvSpPr><p:cNvPr id="$spid" name="Equation $spid"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\n');
        b.write(
            '        <p:spPr><a:xfrm><a:off x="${geometry.contentX}" y="${geometry.contentTopWithoutSubtitle + eqOffset}"/><a:ext cx="$contentW" cy="$eqH"/></a:xfrm>'
            '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>\n');
        b.write('        <p:txBody><a:bodyPr/><a:lstStyle/>');
        if (mathInner != null) {
          b.write(
              '<a:p><a:pPr algn="ctr"/><a:mathPr><a:mathFont val="Cambria Math"/></a:mathPr>'
              '<m:oMath xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math">'
              '$mathInner</m:oMath></a:p>');
        } else {
          b.write(
              '<a:p><a:pPr algn="ctr"/><a:r><a:rPr lang="en-US" sz="1800" i="1"/>'
              '<a:t>${_xmlEscape(equation.latex.isEmpty ? equation.mathml : equation.latex)}</a:t></a:r></a:p>');
        }
        b.write('</p:txBody>\n');
        b.write('      </p:sp>\n');
        eqOffset += eqH + 91440;
      }
    }

    // 20. OLE objects (Track 18, P6): `<div data-ole='...'>` blocks embed the
    // file as `ppt/embeddings/oleObject{n}.bin` + an icon PNG, and render a
    // `<p:oleObj>` shape with a double-click hlink (opens the embedded file).
    if (rawHtml.contains('data-ole')) {
      var oleCounter = 0;
      var oleOffset = 0;
      for (final match in _olePatternRe.allMatches(rawHtml)) {
        final ole = OleData.fromJson(match.group(2)!);
        if (ole.fileName.isEmpty || ole.fileBytes.isEmpty) continue;
        // Embed the file bytes as oleObject{n}.bin
        final oleName =
            'oleObject${nextMediaIndex?.call() ?? ++oleCounter}.bin';
        media?.add(_MediaFile(oleName, Uint8List.fromList(ole.fileBytes)));
        final oleRid = rels?.addOleObject('../embeddings/$oleName') ?? '';

        // Icon PNG (the document glyph).
        final iconBytes = OleService.renderIconPng(ole);
        final iconKey = crypto.sha256.convert(iconBytes).toString();
        final existingIcon = mediaByContentKey?[iconKey];
        final iconName = existingIcon ??
            'image${nextMediaIndex?.call() ?? ++oleCounter}.png';
        if (existingIcon == null) {
          mediaByContentKey?[iconKey] = iconName;
          media?.add(_MediaFile(iconName, iconBytes));
        }
        final iconRid = rels?.addImage('../media/$iconName') ?? '';

        final oleW = (ole.w / 100 * slideWEmu).round();
        final oleH = (ole.h / 100 * slideHEmu).round();
        final offX = geometry.contentX;
        final offY = geometry.contentTopWithoutSubtitle + oleOffset;
        final spid = shapeId++;
        b.write(
            '      ${OleService.renderPptxOleShape(
          shapeId: spid,
          ole: ole,
          oleRid: oleRid,
          iconRid: iconRid,
          offX: offX,
          offY: offY,
          extCx: oleW,
          extCy: oleH,
        )}');
        oleOffset += oleH + 91440;
      }
    }

    // 21. Slide Zoom (Track 20, P5): `<div data-zoom='...'>` blocks become
    // clickable shapes that jump to the target slide.
    if (rawHtml.contains('data-zoom')) {
      var zoomOffset = 0;
      for (final match in _zoomPatternRe.allMatches(rawHtml)) {
        final zoom = ZoomItem.fromJson(match.group(2)!);
        final offX = (zoom.x / 100 * slideWEmu).round();
        final offY = (zoom.y / 100 * slideHEmu).round() + zoomOffset;
        final extW = (zoom.w / 100 * slideWEmu).round();
        final extH = (zoom.h / 100 * slideHEmu).round();
        b.write('      ${ZoomFeatureService.renderPptxZoomXml(
          shapeId: shapeId++,
          zoom: zoom,
          description: 'Slide Zoom',
          offX: offX,
          offY: offY,
          extCx: extW,
          extCy: extH,
        )}');
        zoomOffset += extH + 91440;
      }
    }

    // 21b. Section/Summary Zoom (Track 20, P6): `<div data-sectionzoom='...'>`
    // becomes a grid of slide-jump shapes.
    if (rawHtml.contains('data-sectionzoom')) {
      var szOffset = 0;
      for (final match in _sectionZoomPatternRe.allMatches(rawHtml)) {
        final sz = SectionZoomData.fromJson(match.group(2)!);
        final offX = (sz.x / 100 * slideWEmu).round();
        final offY = (sz.y / 100 * slideHEmu).round() + szOffset;
        final extW = (sz.w / 100 * slideWEmu).round();
        final extH = (sz.h / 100 * slideHEmu).round();
        b.write(SectionZoomService.renderPptxSectionZoomXml(
          shapeId: shapeId,
          zoom: sz,
          offX: offX,
          offY: offY,
          extCx: extW,
          extCy: extH,
        ));
        shapeId += (sz.entries.isEmpty ? 1 : sz.entries.length);
        szOffset += extH + 91440;
      }
    }

    // 22. Cameo (Track 20, P8): `<div data-cameo='...'>` blocks become
    // camera placeholder shapes.
    if (rawHtml.contains('data-cameo')) {
      var cameoOffset = 0;
      for (final match in _cameoPatternRe.allMatches(rawHtml)) {
        final cameo = CameoData.fromJson(match.group(2)!);
        final offX = (cameo.x / 100 * slideWEmu).round();
        final offY = (cameo.y / 100 * slideHEmu).round() + cameoOffset;
        final extW = (cameo.w / 100 * slideWEmu).round();
        final extH = (cameo.h / 100 * slideHEmu).round();
        b.write('      ${CameoService.renderPptxCameoXml(
          shapeId: shapeId++,
          cameo: cameo,
          offX: offX,
          offY: offY,
          extCx: extW,
          extCy: extH,
        )}');
        cameoOffset += extH + 91440;
      }
    }    // 23. Drawn shapes (Track 21, P2/P3): shapes stored in
    // `visualElements['shapes']` as a list of maps.
    // Track 26, P5: shapes belonging to a group are emitted inside a
    // `<p:grpSp>`; the group box comes from `visualElements['groups']`.
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
      const slideWEmu = 9144000;
      const slideHEmu = 6858000;

      final groups = <ShapeGroup>[];
      final rawGroups = rawVisual['groups'];
      if (rawGroups is List) {
        for (final e in rawGroups) {
          final m = e is Map<String, dynamic>
              ? e
              : (e is Map ? Map<String, dynamic>.from(e) : null);
          if (m == null) continue;
          groups.add(ShapeGroup.fromMap(m));
        }
      }
      final groupedIds = {
        for (final g in groups) ...g.memberIds,
      };
      for (final group in groups) {
        final members =
            shapes.where((s) => group.memberIds.contains(s.id)).toList();
        if (members.length >= 2) {
          b.write(GroupService.renderPptxGroupXml(
            groupShapeId: shapeId++,
            group: group,
            members: members,
          ));
        }
      }
      for (final shape in shapes) {
        if (groupedIds.contains(shape.id)) continue;
        final spid = shapeId++;
        spidMap['sh_${shape.id}'] = spid;
        final offX = (shape.x / 100 * slideWEmu).round();
        final offY = (shape.y / 100 * slideHEmu).round();
        final extW = (shape.w / 100 * slideWEmu).round();
        final extH = (shape.h / 100 * slideHEmu).round();
        b.write('      ${ShapeEngine.renderPptxShape(
            shapeId: spid,
            shape: shape,
            offX: offX,
            offY: offY,
            extCx: extW,
            extCy: extH,
          )}');
      }
    }

    b.write('    </p:spTree>\n');
    b.write('  </p:cSld>\n');
    final mediaInner = VideoEmbedService.mediaTimingInnerXml(mediaSpecs);
    // Track 32: per-object animation timing tree (merged with media timing).
    final rawVisualTiming = rawVisual is Map ? rawVisual['animations'] : null;
    String animTimingInner = '';
    if (rawVisualTiming is List && rawVisualTiming.isNotEmpty) {
      final anims = rawVisualTiming
          .map((e) => e is Map<String, dynamic>
              ? ObjectAnimation.fromMap(e)
              : (e is Map
                  ? ObjectAnimation.fromMap(Map<String, dynamic>.from(e))
                  : null))
          .whereType<ObjectAnimation>()
          .toList();
      final result = AnimationOoxml.buildTimingXml(anims, spidMap: spidMap);
      if (result.warnings.isNotEmpty) {
        // Unmappable effects are skipped; surface in the export dialog.
        animationWarnings.addAll(result.warnings);
      }
      final full = result.xml;
      if (full.isNotEmpty) {
        // Strip the outer <p:timing> wrapper; re-emit merged below.
        final inner =
            _timingInnerRe.firstMatch(full)?.group(1);
        if (inner != null && inner.trim().isNotEmpty) {
          animTimingInner = '\n$inner';
        }
      }
    }
    if (mediaInner.isNotEmpty || extraTimingPars.isNotEmpty || animTimingInner.isNotEmpty) {
      b.write('  <p:timing><p:tnLst>$mediaInner'
          '${extraTimingPars.join()}$animTimingInner</p:tnLst></p:timing>\n');
    }
    if (transitionXml.isNotEmpty) {
      b.write('  $transitionXml\n');
    }
    b.write('</p:sld>');
    return b.toString();
  }

  /// Random RFC-4122 version-4 GUID string (Track 14): the a16:creationId
  /// PowerPoint writes for 3D models must be a well-formed GUID.
  static String _randomGuidV4() {
    final rnd = math.Random();
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant RFC 4122
    return '{${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}'
        '${hex(bytes[14])}${hex(bytes[15])}}';
  }

  /// Decode a data: URI payload (Track 11): `data:<mime>;base64,<bytes>`.
  /// Returns null when the string is not a base64 data URI.
  static Uint8List? _dataUriBytes(String uri) {
    const prefix = ';base64,';
    final idx = uri.indexOf(prefix);
    if (idx < 0 || !uri.startsWith('data:')) return null;
    try {
      return base64Decode(uri.substring(idx + prefix.length));
    } catch (_) {
      return null;
    }
  }

  /// Extension of a data: URI's mime type (`image/jpeg` → `jpg`), or a
  /// conservative default when unknown.
  static String _dataUriExt(String uri) {
    final semi = uri.indexOf(';');
    final colon = uri.indexOf(':');
    if (semi > colon) {
      final mime = uri.substring(colon + 1, semi);
      if (mime == 'image/jpeg') return 'jpg';
      if (mime == 'image/png') return 'png';
      if (mime == 'image/gif') return 'gif';
    }
    return 'png';
  }

  /// Value of an attribute inside a tag string, or null when absent.
  /// (Built by concatenation — `$name` is not interpolated inside Dart raw
  /// strings, so the pattern cannot use r"""…$name…""" form.)
  static String? _tagAttr(String tag, String name) {
    final match = RegExp(
      '\\b$name' r"""\s*=\s*(['"])(.*?)\1""",
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(tag);
    return match?.group(2);
  }

  /// Estimate the height (EMU) a content block needs inside a box
/// [contentWidthEmu] wide — the single estimation point for the vertical
/// flow layout (Track 02).
///
/// Text and lists use real font metrics: runs are summed by advance width,
/// wrapped to the box, and multiplied by the true line height. Tables use
/// per-cell wrapped text heights plus PowerPoint's default vertical cell
/// insets. Images keep their aspect-scaled height.
static int estimateBlockHeight(
  Map<String, dynamic> block, {
  required int contentWidthEmu,
  double scale = 1.0,
  int? imageMaxWidth,
}) {
  final type = block['type'] as String;
  if (type == 'text') {
    // Real-font metrics (Track 02): wrapped lines × true line height,
    // plus the trailing gap that mirrors the 91440 block spacing.
    final runs = (block['paragraphs'] as List).cast<Map<String, String>>();
    var height = 0;
    for (final group in _groupRuns(runs, 'paragraphStart')) {
      height += TextMetricsService.paragraphHeightEmu(group,
          widthEmu: contentWidthEmu, scale: scale);
    }
    return height + 91440;
  }
  if (type == 'list') {
    final runs = (block['items'] as List).cast<Map<String, String>>();
    var height = 0;
    for (final group in _groupRuns(runs, 'itemStart')) {
      height += TextMetricsService.paragraphHeightEmu(group,
          widthEmu: contentWidthEmu, scale: scale);
    }
    return height + 91440;
  }
  if (type == 'table') {
    // Real per-cell text heights + the default vertical cell insets
    // (replaces the flat 400000 EMU per row).
    final rowsDynamic = block['rows'] as List? ?? [];
    if (rowsDynamic.isEmpty) return 0;
    final cols = rowsDynamic.fold<int>(
        0, (m, row) => (row as List).length > m ? row.length : m);
    if (cols == 0) return 0;
    final cellWidth = ((contentWidthEmu / cols) - 2 * 91440)
        .clamp(45720, contentWidthEmu)
        .toInt();
    var height = 0;
    for (int r = 0; r < rowsDynamic.length; r++) {
      final cells = (rowsDynamic[r] as List)
          .map((c) => Map<String, String>.from(c as Map))
          .toList();
      height += TextMetricsService.tableRowHeightEmu(
        cells,
        cellWidthEmu: cellWidth,
        scale: scale,
        header: block['headerRow'] == true && r == 0,
      );
    }
    return height;
  }
  if (type == 'image') {
    // Same load options as _buildImageShape so the processed-image cache
    // serves both the estimate and the embed in one decode.
    final loaded = HtmlImageLoader.load(
      (block['src'] ?? '').toString(),
      maxWidth: imageMaxWidth,
      allowJpeg: true,
      jpegQuality: jpegQualityForMaxWidth(imageMaxWidth),
    );
    if (loaded != null && loaded.width > 0) {
      final scaledHeight = loaded.height * contentWidthEmu / loaded.width;
      return scaledHeight.round().clamp(360000, 3657600).toInt();
    }
  }
  if (type == 'video') {
    // Track 11, P1: fixed 16:9 box scaled to the content width — the same
    // geometry the <p:pic> video shape gets in the PPTX pass.
    return (contentWidthEmu * 9 / 16).round();
  }
  if (type == 'model3d') {
    // Track 14: 16:9 box matching the am3d graphicFrame geometry.
    return (contentWidthEmu * 9 / 16).round();
  }
  if (type == 'icon') {
    // Track 15: square box sized from the icon's pixel size, scaled to the
    // content width (icons are 24-unit SVGs, so use a 1:1 box).
    final icon = IconItem.fromJson((block['data-icon'] ?? '').toString());
    final size = icon.svgPath.isEmpty ? 360000 : (360000 * 3 / 2).round();
    return size.clamp(360000, contentWidthEmu).toInt();
  }
  return 360000;
}

/// Build one OOXML `<p:sldLayout>` part with real placeholders (Track 05).
  ///
  /// Shapes use the standard `p:sp` + `p:ph` structure (type/index) with EMU
  /// geometry from the registry; `clrMapOvr` pins the layout to the master's
  /// colour map so the user theme applies everywhere.
  static String _buildSlideLayoutXml(PptLayoutDef def) {
    final typeAttr = def.schemaType == null ? '' : ' type="${def.schemaType}"';
    final b = StringBuffer(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"$typeAttr preserve="1">\n'
        '  <p:cSld><p:spTree>'
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr/>');
    var shapeId = 2;
    for (final ph in def.placeholders) {
      final idxAttr = ph.idx == null ? '' : ' idx="${ph.idx}"';
      b.write('<p:sp>');
      b.write(
          '<p:nvSpPr><p:cNvPr id="$shapeId" name="${_xmlEscape(ph.name)}"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="${ph.phType}"$idxAttr/></p:nvPr></p:nvSpPr>');
      b.write(
          '<p:spPr><a:xfrm><a:off x="${ph.x}" y="${ph.y}"/><a:ext cx="${ph.cx}" cy="${ph.cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>');
      b.write(
          '<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:endParaRPr lang="en-US"/></a:p></p:txBody>');
      b.write('</p:sp>');
      shapeId++;
    }
    b.write('</p:spTree></p:cSld>\n');
    b.write('  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>\n');
    b.write('</p:sldLayout>');
    return b.toString();
  }

  /// Build a picture shape from an image block; embeds media + relationship.
  static void _buildImageShape(
    StringBuffer b,
    Map<String, dynamic> block, {
    required int shapeId,
    required int x,
    required int y,
    required int h,
    required int w,
    int? imageMaxWidth,
    required _SlideRels rels,
    required List<_MediaFile> media,
    required int Function() nextMediaIndex,
    Map<String, String>? mediaByContentKey,
    int jpegQuality = 80,
  }) {
    final src = (block['src'] ?? '').toString();
    final loaded = HtmlImageLoader.load(
      src,
      maxWidth: imageMaxWidth,
      allowJpeg: true,
      jpegQuality: jpegQuality,
    );
    if (loaded == null) return;

    // Track 03, P4: dedupe by content (SHA-256 of the final bytes) — the
    // same image on several slides embeds one media part; every slide still
    // declares its own relationship to it.
    final contentKey =
        crypto.sha256.convert(loaded.bytes).toString();
    final existingName = debugDisableMediaDedupe ? null : mediaByContentKey?[contentKey];
    final name = existingName ?? 'image${nextMediaIndex()}.${loaded.ext}';
    if (existingName == null) {
      mediaByContentKey?[contentKey] = name;
      media.add(_MediaFile(name, loaded.bytes));
    }
    final rId = rels.addImage('../media/$name');

    // Scale to fit the content width and remaining vertical space.
    int imgW = loaded.width * _emuPerPx;
    int imgH = loaded.height * _emuPerPx;
    final scale = [
      1.0,
      w / imgW,
      h / imgH,
    ].reduce((a, c) => a < c ? a : c);
    imgW = (imgW * scale).round();
    imgH = (imgH * scale).round();
    final xOff = x + ((w - imgW) ~/ 2);

    b.write('      <p:pic>\n');
    b.write(
        '        <p:nvPicPr><p:cNvPr id="$shapeId" name="Picture $shapeId"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>\n');
    b.write(
        '        <p:blipFill><a:blip r:embed="$rId"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>\n');
    b.write(
        '        <p:spPr><a:xfrm><a:off x="$xOff" y="$y"/><a:ext cx="$imgW" cy="$imgH"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
    b.write('      </p:pic>\n');
  }

  /// Build a picture shape from an icon block (Track 15, P3): renders the
  /// SVG path to a PNG via [IconLibraryService.renderPng] and embeds it as
  /// a `<p:pic>` with dedupe, exactly like the image pipeline.
  static void _buildIconShape(
    StringBuffer b,
    Map<String, dynamic> block, {
    required int shapeId,
    required int x,
    required int y,
    required int h,
    required int w,
    required _SlideRels rels,
    required List<_MediaFile> media,
    required int Function() nextMediaIndex,
    Map<String, String>? mediaByContentKey,
  }) {
    final iconJson = (block['data-icon'] ?? '').toString();
    if (iconJson.isEmpty) return;
    final icon = IconItem.fromJson(iconJson);
    if (icon.svgPath.isEmpty) return;

    final bytes = IconLibraryService.renderPng(icon, size: 48);
    final contentKey = crypto.sha256.convert(bytes).toString();
    final existingName = mediaByContentKey?[contentKey];
    final name = existingName ?? 'image${nextMediaIndex()}.png';
    if (existingName == null) {
      mediaByContentKey?[contentKey] = name;
      media.add(_MediaFile(name, bytes));
    }
    final rId = rels.addImage('../media/$name');

    // Square icon, centred in the allocated block.
    final iconSize = h < w ? h : w;
    final xOff = x + ((w - iconSize) ~/ 2);

    b.write('      <p:pic>\n');
    b.write(
        '        <p:nvPicPr><p:cNvPr id="$shapeId" name="Icon ${icon.name}"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>\n');
    b.write(
        '        <p:blipFill><a:blip r:embed="$rId"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>\n');
    b.write(
        '        <p:spPr><a:xfrm><a:off x="$xOff" y="$y"/><a:ext cx="$iconSize" cy="$iconSize"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
    b.write('      </p:pic>\n');
  }

  /// Group consecutive inline runs into semantic paragraphs/list items.
  ///
  /// The public parser keeps returning flat run maps for backward
  /// compatibility. Internal marker keys preserve the HTML block boundaries
  /// so rich inline markup is not incorrectly emitted as separate paragraphs.
  static List<List<Map<String, String>>> _groupRuns(
    List<Map<String, String>> runs,
    String startMarker,
  ) {
    final groups = <List<Map<String, String>>>[];
    for (final run in runs) {
      if (groups.isEmpty || run[startMarker] == 'true') {
        groups.add(<Map<String, String>>[]);
      }
      groups.last.add(run);
    }
    return groups;
  }

  static List<Map<String, String>> _prepareRunGroup(
    List<Map<String, String>> runs,
    String startMarker,
  ) {
    final prepared = runs.map(Map<String, String>.from).toList();
    if (prepared.isEmpty) return prepared;

    // HTML collapses normal whitespace. Preserve a single boundary space
    // between differently styled runs, but not at paragraph edges.
    for (final run in prepared) {
      if (run['isBreak'] != 'true') {
        run['text'] = (run['text'] ?? '').replaceAll(RegExp(r'\s+'), ' ');
      }
    }
    final textRuns = prepared.where((run) => run['isBreak'] != 'true').toList();
    if (textRuns.isNotEmpty) {
      textRuns.first['text'] = (textRuns.first['text'] ?? '').trimLeft();
      textRuns.last['text'] = (textRuns.last['text'] ?? '').trimRight();
    }
    prepared.removeWhere(
      (run) => run['isBreak'] != 'true' && (run['text'] ?? '').isEmpty,
    );
    if (prepared.isNotEmpty) prepared.first[startMarker] = 'true';
    return prepared;
  }

  static String _textElement(String text) {
    final preserve = text != text.trim() ? ' xml:space="preserve"' : '';
    return '<a:t$preserve>${_xmlEscape(text)}</a:t>';
  }

  /// Build a simple text content shape
  static void _buildTextContentShape(
    StringBuffer b,
    Map<String, dynamic> block, {
    int shapeId = 4,
    int x = 457200,
    int y = 1600200,
    int h = 4525963,
    int w = 8229600,
    _SlideRels? rels,
    double sizeScale = 1.0,
  }) {
    final paragraphs =
        (block['paragraphs'] as List).cast<Map<String, String>>();
    if (paragraphs.isEmpty) return;

    b.write('      <p:sp>\n');
    b.write(
        '        <p:nvSpPr><p:cNvPr id="$shapeId" name="Content Text"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>\n');
    b.write(
        '        <p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$w" cy="$h"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
    b.write('        <p:txBody><a:bodyPr/><a:lstStyle/>\n');

    for (final paraRuns in _groupRuns(paragraphs, 'paragraphStart')) {
      _writeParagraphRuns(b, paraRuns,
          indentLevel: 0, rels: rels, sizeScale: sizeScale);
    }

    b.write('        </p:txBody>\n');
    b.write('      </p:sp>\n');
  }

  /// Build a list content shape with bullet or numbered formatting
  static void _buildListContentShape(
    StringBuffer b,
    Map<String, dynamic> block, {
    int shapeId = 5,
    int x = 457200,
    int y = 1600200,
    int h = 4525963,
    int w = 8229600,
    _SlideRels? rels,
    double sizeScale = 1.0,
  }) {
    final items = (block['items'] as List).cast<Map<String, String>>();
    final ordered = block['ordered'] as bool;
    if (items.isEmpty) return;

    b.write('      <p:sp>\n');
    b.write(
        '        <p:nvSpPr><p:cNvPr id="$shapeId" name="List Content"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>\n');
    b.write(
        '        <p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$w" cy="$h"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
    b.write('        <p:txBody><a:bodyPr/><a:lstStyle/>\n');

    final itemGroups = _groupRuns(items, 'itemStart');
    for (int i = 0; i < itemGroups.length; i++) {
      final itemRuns = itemGroups[i];

      b.write('          <a:p>\n');
      b.write('            <a:pPr marL="457200" indent="-228600"');
      final align = itemRuns
          .map((run) => run['align'])
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .firstOrNull;
      if (align != null && align.isNotEmpty) b.write(' algn="$align"');
      if (ordered) {
        // Numbered list
        b.write(
            '><a:buAutoNum type="arabicPeriod" startAt="${i + 1}"/></a:pPr>\n');
      } else {
        // Bullet list — actual bullet glyph (fixed literal \u2022 bug)
        b.write('><a:buChar char="\u2022"/></a:pPr>\n');
      }
      for (final run in itemRuns) {
        _writeTextRun(b, run,
            rels: rels, indent: '            ', sizeScale: sizeScale);
      }
      b.write('          </a:p>\n');
    }

    b.write('        </p:txBody>\n');
    b.write('      </p:sp>\n');
  }

  /// Build a table content shape
  static void _buildTableShape(
    StringBuffer b,
    Map<String, dynamic> block, {
    int shapeId = 6,
    int x = 457200,
    int y = 1600200,
    int? h,
    int w = 8229600,
    double sizeScale = 1.0,
  }) {
    final rowsDynamic = block['rows'] as List?;
    if (rowsDynamic == null || rowsDynamic.isEmpty) return;

    // Convert dynamic rows to properly typed data
    final rows = <List<Map<String, String>>>[];
    for (final rowDynamic in rowsDynamic) {
      final rowList = rowDynamic as List;
      final typedRow = <Map<String, String>>[];
      for (final cellDynamic in rowList) {
        typedRow.add(Map<String, String>.from(cellDynamic as Map));
      }
      rows.add(typedRow);
    }

    final cols =
        rows.fold<int>(0, (max, row) => row.length > max ? row.length : max);
    if (cols == 0) return;
    final rowHeight = ((h ?? rows.length * 400000) / rows.length).floor();
    final tableHeight = rowHeight * rows.length;

    b.write('      <p:graphicFrame>\n');
    b.write(
        '        <p:nvGraphicFramePr><p:cNvPr id="$shapeId" name="Table"/><p:cNvGraphicFramePr><a:graphicFrameLocks noGrp="1"/></p:cNvGraphicFramePr><p:nvPr/></p:nvGraphicFramePr>\n');
    b.write(
        '        <p:xfrm><a:off x="$x" y="$y"/><a:ext cx="$w" cy="$tableHeight"/></p:xfrm>\n');
    b.write(
        '        <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">\n');
    b.write('          <a:tbl><a:tblPr/><a:tblGrid>\n');

    for (int c = 0; c < cols; c++) {
      b.write('            <a:gridCol w="${(w / cols).round()}"/>\n');
    }

    b.write('          </a:tblGrid>\n');

    for (int r = 0; r < rows.length; r++) {
      final isHeader = block['headerRow'] == true && r == 0;
      b.write('          <a:tr h="$rowHeight">\n');
      for (int c = 0; c < cols; c++) {
        final cell = c < rows[r].length
            ? rows[r][c]
            : <String, String>{'text': '', 'bold': 'false', 'italic': 'false'};
        final effectiveCell = Map<String, String>.from(cell);
        if (isHeader) effectiveCell['bold'] = 'true';

        b.write('            <a:tc>\n');
        b.write('              <a:txBody><a:bodyPr/><a:lstStyle/>\n');
        b.write('                <a:p>\n');
        b.write('                  <a:pPr marL="0" indent="0"/>\n');
        b.write('                  <a:r>\n');
        b.write(
            '                    ${_runProps(effectiveCell, defaultSize: '1600', sizeScale: sizeScale)}\n');
        b.write(
            '                    <a:t>${_xmlEscape(cell['text'] ?? '')}</a:t>\n');
        b.write('                  </a:r>\n');
        b.write('                </a:p>\n');
        // Fixed: single closing tag (was duplicated, producing invalid OOXML)
        b.write('              </a:txBody>\n');
        b.write('              <a:tcPr/>\n');
        b.write('            </a:tc>\n');
      }
      b.write('          </a:tr>\n');
    }

    b.write('          </a:tbl>\n');
    b.write('        </a:graphicData></a:graphic>\n');
    b.write('      </p:graphicFrame>\n');
  }

  /// Build run properties (<a:rPr>) from a paragraph/run map.
  ///
  /// Supported keys: bold, italic, underline, strike, size (hundredths of a
  /// point), color / highlight (RRGGBB), font, href.
  static String _runProps(
    Map<String, String> run, {
    required String defaultSize,
    _SlideRels? rels,
    double sizeScale = 1.0,
  }) {
    final size = run['size']?.isNotEmpty == true ? run['size']! : defaultSize;
    // sizeScale (fit-content shrink) scales the hundredths-of-a-point size —
    // never below 1 pt so the XML stays valid for any run.
    final scaledSize =
        ((int.tryParse(size) ?? int.parse(defaultSize)) * sizeScale)
            .round()
            .clamp(100, 4000);
    final b = StringBuffer('<a:rPr lang="en-US" sz="$scaledSize"');
    if (run['bold'] == 'true') b.write(' b="1"');
    if (run['italic'] == 'true') b.write(' i="1"');
    if (run['underline'] == 'true') b.write(' u="sng"');
    if (run['strike'] == 'true') b.write(' strike="sngStrike"');

    final color = run['color'];
    final highlight = run['highlight'];
    final font = run['font'];
    final href = run['href'];
    final hasChildren = (color != null && color.isNotEmpty) ||
        (highlight != null && highlight.isNotEmpty) ||
        (font != null && font.isNotEmpty) ||
        (href != null && href.isNotEmpty && rels != null);

    if (!hasChildren) {
      b.write('/>');
      return b.toString();
    }
    b.write('>');
    if (color != null && color.isNotEmpty) {
      b.write('<a:solidFill><a:srgbClr val="$color"/></a:solidFill>');
    }
    if (highlight != null && highlight.isNotEmpty) {
      b.write('<a:highlight><a:srgbClr val="$highlight"/></a:highlight>');
    }
    if (font != null && font.isNotEmpty) {
      b.write('<a:latin typeface="${_xmlEscape(font)}"/>');
    }
    if (href != null && href.isNotEmpty && rels != null) {
      final rId = rels.addHyperlink(_xmlEscape(href));
      b.write(
          '<a:hlinkClick xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="$rId"/>');
    }
    b.write('</a:rPr>');
    return b.toString();
  }

  static void _writeParagraphRuns(
    StringBuffer b,
    List<Map<String, String>> runs, {
    int indentLevel = 0,
    _SlideRels? rels,
    double sizeScale = 1.0,
  }) {
    final visibleRuns = runs
        .where(
            (run) => run['isBreak'] == 'true' || (run['text'] ?? '').isNotEmpty)
        .toList();
    if (visibleRuns.isEmpty) return;

    b.write('          <a:p>\n');
    final align = visibleRuns
        .map((run) => run['align'])
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    b.write('            <a:pPr');
    if (indentLevel > 0) {
      b.write(' marL="${indentLevel * 457200}" indent="-228600"');
    }
    if (align != null && align.isNotEmpty) b.write(' algn="$align"');
    b.write('><a:buNone/></a:pPr>\n');
    for (final run in visibleRuns) {
      _writeTextRun(b, run,
          rels: rels, indent: '            ', sizeScale: sizeScale);
    }
    b.write('          </a:p>\n');
  }

  static void _writeTextRun(
    StringBuffer b,
    Map<String, String> run, {
    _SlideRels? rels,
    required String indent,
    double sizeScale = 1.0,
  }) {
    if (run['isBreak'] == 'true') {
      // a:br is a direct child of a:p. Placing it inside a:r violates
      // CT_RegularTextRun and causes PowerPoint/OpenXmlValidator to reject it.
      b.write('$indent<a:br>\n');
      b.write('$indent  ${_runProps(run, defaultSize: '1800', rels: rels, sizeScale: sizeScale)}\n');
      b.write('$indent</a:br>\n');
      return;
    }

    final text = run['text'] ?? '';
    if (text.isEmpty) return;
    b.write('$indent<a:r>\n');
    b.write('$indent  ${_runProps(run, defaultSize: '1800', rels: rels, sizeScale: sizeScale)}\n');
    b.write('$indent  ${_textElement(text)}\n');
    b.write('$indent</a:r>\n');
  }

  // ---- HTML parsing ----

  /// Extract speaker notes from an `<aside class="notes">` element.
  static String extractNotes(String html, {HtmlParseCache? parseCache}) {
    if (html.trim().isEmpty) return '';
    if (parseCache != null) {
      // Reuses the session tokenization instead of re-parsing the content
      // that _buildSlideXml has just parsed (Track 01, phase 3).
      return parseCache.notesFor(html);
    }
    try {
      final doc = html_parser.parse(html);
      final aside = doc.querySelector('aside.notes');
      return aside?.text.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Parse HTML content and return structured blocks (text, list, table, image)
  static List<Map<String, dynamic>> parseHtmlContentFull(String html,
      {HtmlParseCache? parseCache}) {
    if (html.trim().isEmpty) {
      return [
        {
          'type': 'text',
          'paragraphs': [
            {'text': '', 'bold': 'false', 'italic': 'false'}
          ]
        }
      ];
    }
    if (parseCache != null) {
      // One tokenization per unique content, shared by PPTX and PDF.
      return parseCache.blocksFor(html);
    }
    final document = html_parser.parse(html);
    return parseHtmlContentFullFromDoc(document, fallbackText: html);
  }

  /// Parse from an already-parsed DOM document (avoids double-parsing).
  static List<Map<String, dynamic>> parseHtmlContentFullFromDoc(
      dom.Document document,
      {String fallbackText = ''}) {
    final body = document.body;
    if (body == null) {
      return [
        {
          'type': 'text',
          'paragraphs': [
            {'text': fallbackText, 'bold': 'false', 'italic': 'false'}
          ]
        }
      ];
    }
    // Speaker notes are not part of the visible slide content.
    for (final aside in body.querySelectorAll('aside.notes')) {
      aside.remove();
    }
    final blocks = _extractBlocks(body);
    if (blocks.isEmpty) {
      return [
        {
          'type': 'text',
          'paragraphs': [
            {'text': body.text, 'bold': 'false', 'italic': 'false'}
          ]
        }
      ];
    }
    return blocks;
  }

  /// Legacy single-paragraph extraction (kept for backward compatibility)
  static List<Map<String, String>> parseHtmlContent(String html) {
    final blocks = parseHtmlContentFull(html);
    final paragraphs = <Map<String, String>>[];
    for (final block in blocks) {
      if (block['type'] == 'text') {
        for (final run
            in (block['paragraphs'] as List).cast<Map<String, String>>()) {
          final legacyRun = Map<String, String>.from(run)
            ..remove('paragraphStart')
            ..remove('itemStart');
          paragraphs.add(legacyRun);
        }
      } else if (block['type'] == 'list') {
        for (final item
            in (block['items'] as List).cast<Map<String, String>>()) {
          final legacyItem = Map<String, String>.from(item)
            ..remove('paragraphStart')
            ..remove('itemStart');
          paragraphs.add(legacyItem);
        }
      }
    }
    return paragraphs;
  }

  // ---- Inline style parsing ----

  static final RegExp _styleDeclRegExp = RegExp(r'([\w-]+)\s*:\s*([^;]+)');

  // ---- Slide-pass content regexes -------------------------------------
  // `_buildSlideXml` walks every slide and, per content type it contains,
  // previously recompiled the same pattern per slide. Hoisted once: they
  // are pure patterns (no captured locals) and deck export builds one
  // slide XML per slide.
  static final RegExp _bgColorAttrRe = RegExp(
    r"""data-bg-color=["']([^"']+)["']""",
    caseSensitive: false,
  );
  static final RegExp _diagramPatternRe = RegExp(
    r"""data-smartart=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _chartPatternRe = RegExp(
    r"""data-chart='([^']*)'""",
    caseSensitive: false,
  );
  static final RegExp _videoPatternRe = RegExp(
    r"""<video\b[^>]*data-video=(['"])(.*?)\1[^>]*>""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _model3dPatternRe = RegExp(
    r"""data-model3d=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _actionPatternRe = RegExp(
    r"""data-action=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _equationPatternRe = RegExp(
    r"""data-equation=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _olePatternRe = RegExp(
    r"""data-ole=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _zoomPatternRe = RegExp(
    r"""data-zoom=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _sectionZoomPatternRe = RegExp(
    r"""data-sectionzoom=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _cameoPatternRe = RegExp(
    r"""data-cameo=(['"])(.*?)\1""",
    caseSensitive: false,
    dotAll: true,
  );
  /// Strip the outer `<p:timing>` wrapper when merging per-animation timing
  /// into the slide timing block (line 2080 area).
  static final RegExp _timingInnerRe =
      RegExp(r'<p:timing>(.*)</p:timing>', dotAll: true);

  static const Map<String, String> _cssColorNames = {
    'black': '000000',
    'white': 'FFFFFF',
    'red': 'FF0000',
    'green': '008000',
    'blue': '0000FF',
    'yellow': 'FFFF00',
    'orange': 'FFA500',
    'purple': '800080',
    'gray': '808080',
    'grey': '808080',
    'silver': 'C0C0C0',
    'navy': '000080',
    'teal': '008080',
    'maroon': '800000',
    'olive': '808000',
    'lime': '00FF00',
    'aqua': '00FFFF',
    'cyan': '00FFFF',
    'magenta': 'FF00FF',
    'fuchsia': 'FF00FF',
    'pink': 'FFC0CB',
    'brown': 'A52A2A',
    'gold': 'FFD700',
  };

  /// Normalize a CSS color (#rgb, #rrggbb, rgb(), named) to RRGGBB, or null.
  static String? cssColorToHex(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v.startsWith('#')) {
      final hex = v.substring(1);
      if (RegExp(r'^[0-9a-f]{6}$').hasMatch(hex)) return hex.toUpperCase();
      if (RegExp(r'^[0-9a-f]{3}$').hasMatch(hex)) {
        return hex.split('').map((c) => '$c$c').join().toUpperCase();
      }
      return null;
    }
    final rgbMatch =
        RegExp(r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)').firstMatch(v);
    if (rgbMatch != null) {
      String toHex(String s) =>
          int.parse(s).clamp(0, 255).toRadixString(16).padLeft(2, '0');
      return (toHex(rgbMatch.group(1)!) +
              toHex(rgbMatch.group(2)!) +
              toHex(rgbMatch.group(3)!))
          .toUpperCase();
    }
    return _cssColorNames[v]?.toUpperCase();
  }

  /// Convert a CSS font-size (px/pt/em/rem) to OOXML hundredths of a point.
  static String? cssFontSizeToSz(String raw) {
    final v = raw.trim().toLowerCase();
    final match = RegExp(r'^([\d.]+)\s*(px|pt|em|rem)?$').firstMatch(v);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null || value <= 0) return null;
    final unit = match.group(2) ?? 'px';
    double pt;
    switch (unit) {
      case 'pt':
        pt = value;
        break;
      case 'em':
      case 'rem':
        pt = value * 12; // 1em ~ 16px = 12pt
        break;
      default: // px
        pt = value * 0.75;
    }
    final sz = (pt * 100).round();
    if (sz < 100 || sz > 40000) return null;
    return sz.toString();
  }

  /// Parse style/attributes of [el] and merge run-level styling into [style].
  static Map<String, String> _mergeElementStyle(
      dom.Element el, Map<String, String> style) {
    final merged = Map<String, String>.from(style);
    final styleAttr = el.attributes['style'];
    if (styleAttr != null && styleAttr.isNotEmpty) {
      for (final m in _styleDeclRegExp.allMatches(styleAttr)) {
        final prop = m.group(1)!.trim().toLowerCase();
        final value = m.group(2)!.trim();
        switch (prop) {
          case 'color':
            final hex = cssColorToHex(value);
            if (hex != null) merged['color'] = hex;
            break;
          case 'background-color':
            final hex = cssColorToHex(value);
            if (hex != null) merged['highlight'] = hex;
            break;
          case 'font-size':
            final sz = cssFontSizeToSz(value);
            if (sz != null) merged['size'] = sz;
            break;
          case 'font-family':
            final family = value
                .split(',')
                .first
                .trim()
                .replaceAll(RegExp(r'''["']'''), '');
            if (family.isNotEmpty) merged['font'] = family;
            break;
          case 'font-weight':
            if (value == 'bold' || (int.tryParse(value) ?? 0) >= 600) {
              merged['bold'] = 'true';
            }
            break;
          case 'font-style':
            if (value == 'italic') merged['italic'] = 'true';
            break;
          case 'text-decoration':
            if (value.contains('underline')) merged['underline'] = 'true';
            if (value.contains('line-through')) merged['strike'] = 'true';
            break;
          case 'text-align':
            final algn = _cssAlignToAlgn(value);
            if (algn != null) merged['align'] = algn;
            break;
        }
      }
    }
    final alignAttr = el.attributes['align'];
    if (alignAttr != null) {
      final algn = _cssAlignToAlgn(alignAttr);
      if (algn != null) merged['align'] = algn;
    }
    return merged;
  }

  static String? _cssAlignToAlgn(String value) {
    switch (value.trim().toLowerCase()) {
      case 'left':
        return 'l';
      case 'center':
        return 'ctr';
      case 'right':
        return 'r';
      case 'justify':
        return 'just';
    }
    return null;
  }

  static Map<String, String> _makeRun(String text, Map<String, String> style,
      {bool isBreak = false}) {
    return {
      'text': text,
      'bold': style['bold'] ?? 'false',
      'italic': style['italic'] ?? 'false',
      if (style['underline'] == 'true') 'underline': 'true',
      if (style['strike'] == 'true') 'strike': 'true',
      if ((style['color'] ?? '').isNotEmpty) 'color': style['color']!,
      if ((style['highlight'] ?? '').isNotEmpty)
        'highlight': style['highlight']!,
      if ((style['size'] ?? '').isNotEmpty) 'size': style['size']!,
      if ((style['font'] ?? '').isNotEmpty) 'font': style['font']!,
      if ((style['align'] ?? '').isNotEmpty) 'align': style['align']!,
      if ((style['href'] ?? '').isNotEmpty) 'href': style['href']!,
      if (isBreak) 'isBreak': 'true',
    };
  }

  static List<Map<String, dynamic>> _extractBlocks(dom.Element element,
      [Map<String, String> inheritedStyle = const {}]) {
    final result = <Map<String, dynamic>>[];
    List<Map<String, String>> currentParagraphs = [];
    List<Map<String, String>> currentListItems = [];
    bool currentListOrdered = false;
    bool inList = false;

    void flushParagraphs() {
      if (currentParagraphs.isNotEmpty) {
        result.add({
          'type': 'text',
          'paragraphs': List.from(currentParagraphs),
        });
        currentParagraphs = [];
      }
    }

    void flushList() {
      if (currentListItems.isNotEmpty) {
        result.add({
          'type': 'list',
          'items': List.from(currentListItems),
          'ordered': currentListOrdered,
        });
        currentListItems = [];
      }
      inList = false;
    }

    for (final node in element.nodes) {
      if (node is dom.Text) {
        final normalized = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (normalized.isNotEmpty) {
          // A bare text node appearing after a list must NOT inherit the
          // inList state (rare in well-formed HTML, but a body like
          // `<ul>...</ul>loose text` would otherwise merge "loose text"
          // into the trailing list). Flush the list first so the text
          // lands in the paragraphs stream.
          if (inList) flushList();
          final run = _makeRun(normalized, inheritedStyle);
          if (currentParagraphs.isEmpty) run['paragraphStart'] = 'true';
          currentParagraphs.add(run);
        }
      } else if (node is dom.Element) {
        final tag = node.localName;
        final style = _mergeElementStyle(node, inheritedStyle);

        if (tag == 'br') {
          final run = _makeRun('', inheritedStyle, isBreak: true);
          if (inList) {
            if (currentListItems.isEmpty) run['itemStart'] = 'true';
            currentListItems.add(run);
          } else {
            if (currentParagraphs.isEmpty) {
              run['paragraphStart'] = 'true';
            }
            currentParagraphs.add(run);
          }
        } else if (tag == 'img') {
          flushParagraphs();
          flushList();
          final src = node.attributes['src'] ?? '';
          if (src.isNotEmpty) {
            result.add({'type': 'image', 'src': src});
          }
        } else if (tag == 'video' &&
            node.attributes.containsKey('data-video')) {
          // Track 11: video blocks become dedicated blocks (the PDF renderer
          // draws the poster; PPTX emits <p:pic> media shapes via its own
          // pass; the HTML exporter rewrites the tag for the player).
          flushParagraphs();
          flushList();
          result.add({
            'type': 'video',
            'data-video': node.attributes['data-video'] ?? '',
            'poster': node.attributes['poster'] ?? '',
          });
        } else if (tag == 'span' && node.attributes.containsKey('data-icon')) {
          // Track 15: icon blocks become dedicated blocks (PDF renders the
          // raster; PPTX emits <p:pic> of the rendered PNG; HTML inlines SVG).
          flushParagraphs();
          flushList();
          result.add({
            'type': 'icon',
            'data-icon': node.attributes['data-icon'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-smartart')) {
          // Track 10: SmartArt placeholders become dedicated blocks (PDF
          // renderer; PPTX emits <dgm:diagram> shapes via its own pass).
          flushParagraphs();
          flushList();
          result.add({
            'type': 'smartart',
            'data-smartart': node.attributes['data-smartart'] ?? '',
          });
        } else if (tag == 'div' &&
            node.attributes.containsKey('data-model3d')) {
          // Track 14: 3D model placeholders become dedicated blocks (PDF
          // draws the poster placeholder; PPTX emits the am3d shape via its
          // own pass; HTML replaces with the poster + note).
          flushParagraphs();
          flushList();
          result.add({
            'type': 'model3d',
            'data-model3d': node.attributes['data-model3d'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-chart')) {
          // Track 08: chart placeholders become dedicated blocks (consumed
          // by the PDF renderer; PPTX emits <c:chart> shapes via its own
          // pass and ignores these blocks).
          flushParagraphs();
          flushList();
          result.add({
            'type': 'chart',
            'data-chart': node.attributes['data-chart'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-action')) {
          // Track 18: action buttons become dedicated blocks (PDF renders a
          // labelled button; PPTX emits the p:sp with hlinkClick).
          flushParagraphs();
          flushList();
          result.add({
            'type': 'action',
            'data-action': node.attributes['data-action'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-equation')) {
          // Track 18: equations become dedicated blocks (PDF renders the
          // plain-text fallback; PPTX emits <a:math>).
          flushParagraphs();
          flushList();
          result.add({
            'type': 'equation',
            'data-equation': node.attributes['data-equation'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-ole')) {
          // Track 18, P6: OLE embedded objects become dedicated blocks.
          flushParagraphs();
          flushList();
          result.add({
            'type': 'ole',
            'data-ole': node.attributes['data-ole'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-zoom')) {
          // Track 20, P5: slide zoom becomes a dedicated block.
          flushParagraphs();
          flushList();
          result.add({
            'type': 'zoom',
            'data-zoom': node.attributes['data-zoom'] ?? '',
          });
        } else if (tag == 'div' &&
            node.attributes.containsKey('data-sectionzoom')) {
          // Track 20, P6: Section/Summary Zoom becomes a dedicated block.
          flushParagraphs();
          flushList();
          result.add({
            'type': 'sectionzoom',
            'data-sectionzoom': node.attributes['data-sectionzoom'] ?? '',
          });
        } else if (tag == 'div' && node.attributes.containsKey('data-cameo')) {
          // Track 20, P8: cameo (live camera) becomes a dedicated block.
          flushParagraphs();
          flushList();
          result.add({
            'type': 'cameo',
            'data-cameo': node.attributes['data-cameo'] ?? '',
          });
        } else if (tag == 'p' ||
            tag == 'div' ||
            tag == 'h1' ||
            tag == 'h2' ||
            tag == 'h3' ||
            tag == 'h4' ||
            tag == 'h5' ||
            tag == 'h6') {
          flushList();
          // Nested block content (images, lists, tables inside div/p).
          final hasBlockChildren = node.children.any((c) => const [
                'img',
                'ul',
                'ol',
                'table',
                'p',
                'div'
              ].contains(c.localName));
          if ((tag == 'div' || tag == 'p') && hasBlockChildren) {
            flushParagraphs();
            result.addAll(_extractBlocks(node, style));
            continue;
          }
          var subPars = _extractInlineParagraphs(node, style);
          if (subPars.isNotEmpty) {
            // For headings, make them bold
            if (tag != null && tag.startsWith('h')) {
              for (final p in subPars) {
                p['bold'] = 'true';
                p['italic'] = p['italic'] ?? 'false';
              }
            }
            subPars = _prepareRunGroup(subPars, 'paragraphStart');
            currentParagraphs.addAll(subPars);
          }
        } else if (tag == 'ul' || tag == 'ol') {
          flushParagraphs();
          flushList();
          inList = true;
          currentListOrdered = (tag == 'ol');
          for (final child in node.nodes) {
            if (child is dom.Element && child.localName == 'li') {
              final liStyle = _mergeElementStyle(child, style);
              final items = _prepareRunGroup(
                _extractInlineParagraphs(child, liStyle),
                'itemStart',
              );
              for (final item in items) {
                currentListItems.add(item);
              }
            }
          }
        } else if (tag == 'table') {
          flushParagraphs();
          flushList();
          final tableData = _extractTable(node);
          if (tableData.isNotEmpty) {
            result.add({
              'type': 'table',
              'rows': tableData,
              'headerRow': node.querySelector('tr th') != null,
            });
          }
        } else if (tag == 'strong' || tag == 'b') {
          var children = _extractInlineParagraphs(
            node,
            {...style, 'bold': 'true'},
          );
          if (inList && currentListItems.isEmpty) {
            children = _prepareRunGroup(children, 'itemStart');
          } else if (!inList && currentParagraphs.isEmpty) {
            children = _prepareRunGroup(children, 'paragraphStart');
          }
          for (final child in children) {
            if (inList) {
              currentListItems.add(child);
            } else {
              currentParagraphs.add(child);
            }
          }
        } else if (tag == 'em' || tag == 'i') {
          var children = _extractInlineParagraphs(
            node,
            {...style, 'italic': 'true'},
          );
          if (inList && currentListItems.isEmpty) {
            children = _prepareRunGroup(children, 'itemStart');
          } else if (!inList && currentParagraphs.isEmpty) {
            children = _prepareRunGroup(children, 'paragraphStart');
          }
          for (final child in children) {
            if (inList) {
              currentListItems.add(child);
            } else {
              currentParagraphs.add(child);
            }
          }
        } else {
          // Recurse into unknown elements
          final subBlocks = _extractBlocks(node, style);
          for (final block in subBlocks) {
            if (block['type'] == 'text') {
              currentParagraphs.addAll(
                  (block['paragraphs'] as List).cast<Map<String, String>>());
            } else if (block['type'] == 'list' ||
                block['type'] == 'image' ||
                block['type'] == 'table') {
              flushParagraphs();
              result.add(block);
            }
          }
        }
      }
    }

    flushParagraphs();
    flushList();
    return result;
  }

  /// Extract inline paragraphs from an element (text leaves only)
  static List<Map<String, String>> _extractInlineParagraphs(dom.Element element,
      [Map<String, String> inheritedStyle = const {}]) {
    final result = <Map<String, String>>[];
    for (final node in element.nodes) {
      if (node is dom.Text) {
        final normalized = node.text.replaceAll(RegExp(r'\s+'), ' ');
        if (normalized.trim().isNotEmpty) {
          result.add(_makeRun(normalized, inheritedStyle));
        }
      } else if (node is dom.Element) {
        final tag = node.localName;
        final style = _mergeElementStyle(node, inheritedStyle);
        if (tag == 'br') {
          result.add(_makeRun('', inheritedStyle, isBreak: true));
        } else if (tag == 'strong' || tag == 'b') {
          result.addAll(
              _extractInlineParagraphs(node, {...style, 'bold': 'true'}));
        } else if (tag == 'em' || tag == 'i') {
          result.addAll(
              _extractInlineParagraphs(node, {...style, 'italic': 'true'}));
        } else if (tag == 'u' || tag == 'ins') {
          result.addAll(
              _extractInlineParagraphs(node, {...style, 'underline': 'true'}));
        } else if (tag == 's' || tag == 'del' || tag == 'strike') {
          result.addAll(
              _extractInlineParagraphs(node, {...style, 'strike': 'true'}));
        } else if (tag == 'a') {
          final href = node.attributes['href'] ?? '';
          result.addAll(_extractInlineParagraphs(
              node, href.isNotEmpty ? {...style, 'href': href} : style));
        } else {
          result.addAll(_extractInlineParagraphs(node, style));
        }
      }
    }
    return result;
  }

  /// Extract table data as list of rows (each row is list of cell paragraphs)
  static List<List<Map<String, String>>> _extractTable(dom.Element tableEl) {
    final rows = <List<Map<String, String>>>[];
    for (final child in tableEl.nodes) {
      if (child is dom.Element) {
        if (child.localName == 'thead') {
          for (final th in child.nodes) {
            if (th is dom.Element && th.localName == 'tr') {
              rows.add(_extractTableRow(th));
            }
          }
        } else if (child.localName == 'tbody') {
          for (final tr in child.nodes) {
            if (tr is dom.Element && tr.localName == 'tr') {
              rows.add(_extractTableRow(tr));
            }
          }
        } else if (child.localName == 'tr') {
          rows.add(_extractTableRow(child));
        }
      }
    }
    return rows;
  }

  static List<Map<String, String>> _extractTableRow(dom.Element tr) {
    final cells = <Map<String, String>>[];
    for (final child in tr.nodes) {
      if (child is dom.Element &&
          (child.localName == 'th' || child.localName == 'td')) {
        final style = _mergeElementStyle(child, const {});
        final text = child.text.trim();
        final isHeader = child.localName == 'th';
        final cell = _makeRun(text, style);
        if (isHeader) cell['bold'] = 'true';
        cells.add(cell);
      }
    }
    return cells;
  }

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  // ---- PPTX transition XML from SlideEffect ----

  /// Track 33: warnings from the last transition build (unmappable effects
  /// fell back to fade). Read after generatePPT for the export dialog.
  static final List<String> transitionWarnings = [];

  /// PowerPoint 2010+ p14 transition namespace.
  static const String _p14Ns = 'http://schemas.microsoft.com/office/powerpoint/2010/main';

  /// Track 33, P2: effects that only exist in the p14 namespace.
  static const Set<String> _p14Transitions = {
    'curtain', 'ferris', 'flip', 'gallery', 'honeycomb', 'invert', 'orbit',
    'pageCurl', 'ripple', 'shred', 'vortex', 'origami', 'reveal',
  };

  /// Builds the `<p:transition>` element for [effect].
  ///
  /// [autoAdvanceMs] (milliseconds) sets the transition's `advTm` attribute so
  /// PowerPoint advances automatically (even without a visual transition).
  /// [durationMs] maps to the `spd` attribute (0.1–3s slider, Track 33 P4).
  /// [soundName] optionally adds `<p:snd>` with the given rId (Track 33 P3).
  static String _buildTransitionXml(
    SlideEffect effect, {
    int? autoAdvanceMs,
    int? durationMs,
    String? soundRid,
  }) {
    // OOXML-compliant transition: spd on parent, no dur on child
    final String type;
    String? subtype;
    switch (effect) {
      // Original effects
      case SlideEffect.fade:
        type = 'fade';
        break;
      case SlideEffect.pushLeft:
        type = 'push';
        subtype = 'l';
        break;
      case SlideEffect.pushRight:
        type = 'push';
        subtype = 'r';
        break;
      case SlideEffect.pushUp:
        type = 'push';
        subtype = 'u';
        break;
      case SlideEffect.pushDown:
        type = 'push';
        subtype = 'd';
        break;
      case SlideEffect.wipe:
        type = 'wipe';
        break;
      case SlideEffect.splitIn:
        type = 'split';
        subtype = 'in';
        break;
      case SlideEffect.splitOut:
        type = 'split';
        subtype = 'out';
        break;
      case SlideEffect.randomBar:
        type = 'randomBar';
        break;
      case SlideEffect.checkerboard:
        type = 'checker';
        break;
      case SlideEffect.blinds:
        type = 'blinds';
        break;
      case SlideEffect.clock:
        type = 'wheel';
        break;
      case SlideEffect.zoom:
        type = 'zoom';
        break;

      // New entrance effects → closest PPTX equivalents
      case SlideEffect.flyInLeft:
        type = 'push';
        subtype = 'l';
        break;
      case SlideEffect.flyInRight:
        type = 'push';
        subtype = 'r';
        break;
      case SlideEffect.flyInTop:
        type = 'push';
        subtype = 'u';
        break;
      case SlideEffect.flyInBottom:
        type = 'push';
        subtype = 'd';
        break;
      case SlideEffect.appear:
        type = 'fade';
        break;
      case SlideEffect.basicZoom:
        type = 'zoom';
        break;
      case SlideEffect.swivel:
        // ISO PresentationML has no rotate transition.
        type = 'fade';
        break;
      case SlideEffect.boomerang:
        type = 'push';
        subtype = 'l';
        break;

      // New emphasis effects → fade (PPTX has no emphasis transitions)
      case SlideEffect.pulse:
      case SlideEffect.growShrink:
      case SlideEffect.spin:
      case SlideEffect.teeter:
      case SlideEffect.flicker:
      case SlideEffect.colorPulse:
        type = 'fade';
        break;

      // New exit effects
      case SlideEffect.flyOutLeft:
        type = 'push';
        subtype = 'l';
        break;
      case SlideEffect.flyOutRight:
        type = 'push';
        subtype = 'r';
        break;
      case SlideEffect.disappear:
        type = 'fade';
        break;

      // Motion path effects
      case SlideEffect.arc:
      case SlideEffect.customPath:
        type = 'fade';
        break;

      // Track 33: ISO-standard transitions
      case SlideEffect.dissolve:
        type = 'dissolve';
        break;
      case SlideEffect.coverLeft:
        type = 'cover';
        subtype = 'l';
        break;
      case SlideEffect.coverRight:
        type = 'cover';
        subtype = 'r';
        break;
      case SlideEffect.coverUp:
        type = 'cover';
        subtype = 'u';
        break;
      case SlideEffect.coverDown:
        type = 'cover';
        subtype = 'd';
        break;
      case SlideEffect.uncoverLeft:
        type = 'uncover';
        subtype = 'l';
        break;
      case SlideEffect.uncoverRight:
        type = 'uncover';
        subtype = 'r';
        break;
      case SlideEffect.uncoverUp:
        type = 'uncover';
        subtype = 'u';
        break;
      case SlideEffect.uncoverDown:
        type = 'uncover';
        subtype = 'd';
        break;
      case SlideEffect.diamond:
        type = 'diamond';
        break;
      case SlideEffect.wedge:
        type = 'wedge';
        break;
      case SlideEffect.newsflash:
        type = 'newsflash';
        break;

      // Track 33: PowerPoint 2010+ p14-only transitions
      case SlideEffect.curtain:
      case SlideEffect.ferris:
      case SlideEffect.flip:
      case SlideEffect.gallery:
      case SlideEffect.honeycomb:
      case SlideEffect.invert:
      case SlideEffect.orbit:
      case SlideEffect.pageCurl:
      case SlideEffect.ripple:
      case SlideEffect.shred:
      case SlideEffect.vortex:
      case SlideEffect.origami:
      case SlideEffect.reveal:
        type = effect.name; // p14 element name matches the enum name
        break;

      // Track 33: 'cedar' has no PPTX equivalent — fall back to fade.
      case SlideEffect.cedar:
        type = 'fade';
        transitionWarnings
            .add('Cedar has no PPTX equivalent — exported as Fade.');
        break;

      default:
        // No visual transition — still emit timing when requested.
        if (autoAdvanceMs != null && autoAdvanceMs > 0) {
          return '<p:transition spd="slow" advClick="1" advTm="$autoAdvanceMs"/>';
        }
        return '';
    }

    final timing = autoAdvanceMs != null && autoAdvanceMs > 0
        ? ' advTm="$autoAdvanceMs"'
        : '';
    // Track 33, P4: duration slider (0.1–3s) maps to spd buckets.
    final spd = switch (durationMs) {
      null || < 300 => 'fast',
      > 2000 => 'slow',
      _ => 'med',
    };
    final isP14 = _p14Transitions.contains(type);
    final p14Attr = isP14 ? ' xmlns:p14="$_p14Ns"' : '';
    String xml =
        '<p:transition spd="$spd" advClick="1"$timing$p14Attr>';
    if (soundRid != null && soundRid.isNotEmpty) {
      xml += '<p:snd r:embed="$soundRid"/>';
    }
    final tag = isP14 ? 'p14:$type' : 'p:$type';
    xml += '<$tag';
    if (subtype != null) {
      xml += ' dir="$subtype"';
    }
    xml += '/>';
    xml += '</p:transition>';
    return xml;
  }
}
