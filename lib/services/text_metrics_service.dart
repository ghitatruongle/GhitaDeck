import 'dart:io';
import 'dart:typed_data';

/// Real-font text metrics for the PPTX layout pipeline (Track 02).
///
/// The exporter lays slide content out as vertically flowing shapes whose
/// sizes it must estimate before writing OOXML (PowerPoint performs the final
/// wrapping). Since those estimates drive shape bounds and the "fit content"
/// shrink, they should come from the actual fonts on the machine instead of
/// flat EMU constants.
///
/// [TextMetricsService] parses the OpenType `hhea`/`OS/2` tables of the
/// Windows system fonts (Calibri, Segoe UI, Arial — the families PowerPoint
/// itself defaults to), so real ascender, descender, line gap, average
/// advance and cap height feed the estimators. On machines without those
/// files a baked-in approximation is used instead.
///
/// All measurements are relative to the font's units-per-em, so callers can
/// scale them to any point size: 1 pt = 12700 EMU.
class FontMetrics {
  const FontMetrics({
    required this.family,
    required this.unitsPerEm,
    required this.ascender,
    required this.descender,
    required this.lineGap,
    required this.avgCharWidth,
    required this.capHeight,
  });

  final String family;

  /// head.unitsPerEm.
  final int unitsPerEm;

  /// Positive, in font units (hhea.ascender).
  final int ascender;

  /// Negative, in font units (hhea.descender).
  final int descender;

  /// hhea.lineGap.
  final int lineGap;

  /// OS/2.xAvgCharWidth.
  final int avgCharWidth;

  /// OS/2.sCapHeight (derived from the ascender when the font omits it).
  final int capHeight;

  /// PowerPoint "Multiple 1.0" line height, as a fraction of the em.
  double get lineHeightEm => (ascender - descender + lineGap) / unitsPerEm;

  /// Average glyph advance, as a fraction of the em.
  double get avgCharWidthEm => avgCharWidth / unitsPerEm;

  double get capHeightEm =>
      (capHeight > 0 ? capHeight : (ascender * 0.70).round()) / unitsPerEm;
}

/// Session cache of parsed metrics plus the estimation helpers used by the
/// PPTX exporter (and the "fit content" shrink pass).
class TextMetricsService {
  TextMetricsService._();

  static FontMetrics? _cached;

  /// The resolved metrics for this machine (system font when available,
  /// otherwise the baked-in fallback).
  static FontMetrics get metrics => _cached ??= _resolve();

  static const FontMetrics fallbackMetrics = FontMetrics(
    family: 'Fallback',
    unitsPerEm: 2048,
    ascender: 1638, // ≈ 0.80 em (Segoe UI class)
    descender: -430, // ≈ -0.21 em
    lineGap: 184, // ≈ 0.09 em
    avgCharWidth: 1024, // ≈ 0.50 em
    capHeight: 1434, // ≈ 0.70 em
  );

  /// Reset the cached table (tests, font changes).
  static void clearCache() => _cached = null;

  /// Parse the metrics of one specific family (Calibri / Segoe UI / Arial),
  /// or null when its font file is unavailable.
  static FontMetrics? metricsForFamily(String family) {
    final path = _fontPaths[family];
    if (path == null) return null;
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      return _parseTtf(file.readAsBytesSync(), family);
    } catch (_) {
      return null;
    }
  }

  /// Test/benchmark-only hook: pin the metrics table to a specific family so
  /// estimation and rendering ground truth can use the same font. Production
  /// code never calls this.
  static void debugOverrideMetrics(FontMetrics? metrics) => _cached = metrics;

  static const Map<String, String> _fontPaths = {
    'Calibri': r'C:\Windows\Fonts\calibri.ttf',
    'Segoe UI': r'C:\Windows\Fonts\segoeui.ttf',
    'Arial': r'C:\Windows\Fonts\arial.ttf',
  };

  // ---- { P1: surveyed estimation sites } -------------------------------
  // The flat EMU constants this service replaces live in
  //   lib/services/ppt_generator.dart → _buildSlideXml → estimatedHeight():
  //     text  : 360000 EMU per paragraph group + 91440
  //     list  : 360000 EMU per item + 91440
  //     table : 400000 EMU per row
  //     image : aspect-scaled (unchanged — images scale by their own pixels)

  static FontMetrics _resolve() {
    for (final entry in _fontPaths.entries) {
      try {
        final file = File(entry.value);
        if (!file.existsSync()) continue;
        final parsed = _parseTtf(file.readAsBytesSync(), entry.key);
        if (parsed != null) return parsed;
      } catch (_) {
        // Try the next family.
      }
    }
    return fallbackMetrics;
  }

  /// Parse ascender/descender/lineGap (hhea) and xAvgCharWidth/capHeight
  /// (OS/2) from a TTF/OTF (or TTC first font).
  static FontMetrics? _parseTtf(Uint8List bytes, String family) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 12) return null;

    var base = 0;
    if (_tag(bytes, 0) == 'ttcf') {
      // TrueType collection: first font directory offset.
      if (bytes.length < 16) return null;
      final numFonts = data.getUint32(8);
      if (numFonts < 1) return null;
      base = data.getUint32(12);
    }
    if (base + 12 > bytes.length) return null;

    final numTables = data.getUint16(base + 4);
    if (numTables <= 0) return null;

    int? headOffset;
    int? hheaOffset;
    int? os2Offset;
    for (var i = 0; i < numTables; i++) {
      final record = base + 12 + i * 16;
      if (record + 16 > bytes.length) break;
      final tag = _tag(bytes, record);
      final offset = data.getUint32(record + 8);
      if (tag == 'head') headOffset = offset;
      if (tag == 'hhea') hheaOffset = offset;
      if (tag == 'OS/2') os2Offset = offset;
    }
    if (headOffset == null || hheaOffset == null) return null;

    final unitsPerEm = data.getUint16(headOffset + 18);
    if (unitsPerEm == 0) return null;

    final ascender = data.getInt16(hheaOffset + 4);
    final descender = data.getInt16(hheaOffset + 6);
    final lineGap = data.getInt16(hheaOffset + 8);
    var avgCharWidth = 512;
    var capHeight = 0;
    if (os2Offset != null) {
      avgCharWidth = data.getUint16(os2Offset + 2);
      capHeight = data.getInt16(os2Offset + 88);
    }
    return FontMetrics(
      family: family,
      unitsPerEm: unitsPerEm,
      ascender: ascender,
      descender: descender,
      lineGap: lineGap,
      avgCharWidth: avgCharWidth,
      capHeight: capHeight,
    );
  }

  static String _tag(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return '';
    return String.fromCharCodes(bytes.sublist(offset, offset + 4));
  }

  // ---- Estimation helpers ---------------------------------------------

  static const int _emuPerPt = 12700;

  /// Line height in EMU for a run at [sz] hundredths of a point.
  static int lineHeightEmu(int sz, {double scale = 1.0}) =>
      (sz / 100 * scale * _emuPerPt * metrics.lineHeightEm).round();

  /// xAvgCharWidth averages the font's whole glyph set (wide glyphs
  /// included); calibration against real layouts (Segoe UI, 10 prose
  /// samples) shows plain text is ~6% narrower than the table value.
  static const double _proseAdjust = 0.94;

  /// Space and punctuation advances are well below the average glyph.
  static const double _spaceEm = 0.30;
  static const double _punctEm = 0.35;
  static const String _punctChars = '.,;:!?()[]{}\'"\u2013\u2014\u2026';

  /// Code units of [_punctChars] as a lookup set. The estimator walks every
  /// character of every text run during the PPTX layout pass, so the naive
  /// `_punctChars.codeUnits.contains(unit)` would allocate a new growable
  /// `List<int>` *per character* — a set lookup avoids that entirely.
  static final Set<int> _punctCodeUnits =
      Set<int>.unmodifiable(_punctChars.codeUnits);

  /// Estimated advance width (EMU) of [text] at [sz] hundredths of a point,
  /// split by character class: spaces ~0.30 em, punctuation ~0.35 em, other
  /// glyphs = average advance (bold faces ~5% wider).
  static int _runWidthEmu(
    String text,
    int sz, {
    double scale = 1.0,
    bool bold = false,
  }) {
    final widthEm = _runWidthEm(text, bold);
    return (widthEm * sz / 100 * scale * _emuPerPt).round();
  }

  static double _runWidthEm(String text, bool bold) {
    var spaces = 0;
    var punct = 0;
    for (final unit in text.codeUnits) {
      if (unit == 0x20) {
        spaces++;
      } else if (_punctCodeUnits.contains(unit)) {
        punct++;
      }
    }
    final other = text.length - spaces - punct;
    final base = bold ? metrics.avgCharWidthEm * 1.05 : metrics.avgCharWidthEm;
    return other * base * _proseAdjust + spaces * _spaceEm + punct * _punctEm;
  }

  /// Width of [text] in em units (calibration/debug helper for the
  /// benchmarks: expected = _runWidthEm / fontSize-em).
  static double debugRunWidthEm(String text, {bool bold = false}) =>
      _runWidthEm(text, bold);

  /// Estimated height (EMU) of a full paragraph consisting of [runs]
  /// (already split by the given block-grouping) wrapped to [widthEmu].
  ///
  /// PowerPoint wraps the paragraph as a whole: all run advances add up and
  /// the largest run defines the line height.
  static int paragraphHeightEmu(
    Iterable<Map<String, String>> runs, {
    required int widthEmu,
    double scale = 1.0,
  }) {
    var totalWidth = 0;
    var maxLineHeight = 0;
    for (final run in runs) {
      final text = (run['text'] ?? '').replaceAll('\n', ' ');
      final sz = _runSz(run, defaultSize: '1800');
      final bold = run['bold'] == 'true';
      totalWidth += _runWidthEmu(text, sz, scale: scale, bold: bold);
      final lh = lineHeightEmu(sz, scale: scale);
      if (lh > maxLineHeight) maxLineHeight = lh;
    }
    if (maxLineHeight <= 0) return 0;
    final lines =
        totalWidth <= 0 ? 1 : (totalWidth / (widthEmu <= 0 ? 1 : widthEmu)).ceil();
    return lines * maxLineHeight;
  }

  /// Per-row height (EMU) for an OOXML table: the tallest cell text block of
  /// the row, plus the default vertical cell insets PowerPoint applies
  /// (top/bottom 0.05" each = 45720 EMU) when no explicit insets are set.
  static int tableRowHeightEmu(
    List<Map<String, String>> cells, {
    required int cellWidthEmu,
    double scale = 1.0,
    bool header = false,
  }) {
    var maxText = 0;
    for (final cell in cells) {
      final text = (cell['text'] ?? '').replaceAll('\n', ' ');
      final sz = _runSz(cell, defaultSize: '1600');
      final bold = header || cell['bold'] == 'true';
      final h = paragraphHeightEmu(
        [
          {
            'text': text,
            'size': '$sz',
            'bold': bold ? 'true' : 'false',
          }
        ],
        widthEmu: cellWidthEmu,
        scale: scale,
      );
      if (h > maxText) maxText = h;
    }
    return maxText + 2 * 45720; // top + bottom default cell inset
  }

  static int _runSz(Map<String, String> run,
      {required String defaultSize}) {
    final raw = run['size'];
    if (raw == null || raw.isEmpty) {
      return int.tryParse(defaultSize) ?? 1800;
    }
    return int.tryParse(raw) ?? 1800;
  }
}