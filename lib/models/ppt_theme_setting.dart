/// Theme embedded into exported PPTX files (Track 04, OPT 11).
///
/// Maps the app's user-chosen colors and font onto the OOXML
/// `a:clrScheme`/`a:fontScheme` of the generated theme part. Values are
/// `RRGGBB` hex strings (no leading '#') and plain font family names, so the
/// class stays pure Dart and crosses the worker-isolate boundary as a map.
class PptThemeSetting {
  const PptThemeSetting({
    this.dk2 = '44546A',
    this.lt2 = 'E7E6E6',
    this.accent1 = '4472C4',
    this.accent2 = 'ED7D31',
    this.accent3 = 'A5A5A5',
    this.accent4 = 'FFC000',
    this.accent5 = '5B9BD5',
    this.accent6 = '70AD47',
    this.hlink = '0563C1',
    this.folHlink = '954F72',
    this.fontMajor = 'Calibri Light',
    this.fontMinor = 'Calibri',
  });

  final String dk2;
  final String lt2;
  final String accent1;
  final String accent2;
  final String accent3;
  final String accent4;
  final String accent5;
  final String accent6;
  final String hlink;
  final String folHlink;

  /// Headings font (`a:majorFont`).
  final String fontMajor;

  /// Body font (`a:minorFont`).
  final String fontMinor;

  /// The v1.6.3 hardcoded Office theme — byte-for-byte the default export.
  static const PptThemeSetting office = PptThemeSetting();

  /// Build from user settings: app primary → accent1, app accent → accent2,
  /// everything else keeps the Office defaults.
  PptThemeSetting withUserColors({required String accent1, required String accent2}) {
    return PptThemeSetting(
      dk2: dk2,
      lt2: lt2,
      accent1: _normalizeHex(accent1, fallback: this.accent1),
      accent2: _normalizeHex(accent2, fallback: this.accent2),
      accent3: accent3,
      accent4: accent4,
      accent5: accent5,
      accent6: accent6,
      hlink: hlink,
      folHlink: folHlink,
      fontMajor: fontMajor,
      fontMinor: fontMinor,
    );
  }

  PptThemeSetting copyWith({
    String? dk2,
    String? lt2,
    String? accent1,
    String? accent2,
    String? accent3,
    String? accent4,
    String? accent5,
    String? accent6,
    String? hlink,
    String? folHlink,
    String? fontMajor,
    String? fontMinor,
  }) {
    return PptThemeSetting(
      dk2: dk2 ?? this.dk2,
      lt2: lt2 ?? this.lt2,
      accent1: accent1 ?? this.accent1,
      accent2: accent2 ?? this.accent2,
      accent3: accent3 ?? this.accent3,
      accent4: accent4 ?? this.accent4,
      accent5: accent5 ?? this.accent5,
      accent6: accent6 ?? this.accent6,
      hlink: hlink ?? this.hlink,
      folHlink: folHlink ?? this.folHlink,
      fontMajor: fontMajor ?? this.fontMajor,
      fontMinor: fontMinor ?? this.fontMinor,
    );
  }

  Map<String, String> toMap() => {
        'dk2': dk2,
        'lt2': lt2,
        'accent1': accent1,
        'accent2': accent2,
        'accent3': accent3,
        'accent4': accent4,
        'accent5': accent5,
        'accent6': accent6,
        'hlink': hlink,
        'folHlink': folHlink,
        'fontMajor': fontMajor,
        'fontMinor': fontMinor,
      };

  static PptThemeSetting fromMap(Map<String, dynamic> map) {
    String str(String key, String fallback) {
      final value = map[key];
      return value is String && value.isNotEmpty ? value : fallback;
    }

    return PptThemeSetting(
      dk2: str('dk2', '44546A'),
      lt2: str('lt2', 'E7E6E6'),
      accent1: str('accent1', '4472C4'),
      accent2: str('accent2', 'ED7D31'),
      accent3: str('accent3', 'A5A5A5'),
      accent4: str('accent4', 'FFC000'),
      accent5: str('accent5', '5B9BD5'),
      accent6: str('accent6', '70AD47'),
      hlink: str('hlink', '0563C1'),
      folHlink: str('folHlink', '954F72'),
      fontMajor: str('fontMajor', 'Calibri Light'),
      fontMinor: str('fontMinor', 'Calibri'),
    );
  }

  /// Accept only six hex digits; anything else falls back so a bad value can
  /// never produce an invalid `srgbClr` (which would trigger a repair prompt).
  static String _normalizeHex(String raw, {required String fallback}) {
    final cleaned = raw.trim().replaceFirst(RegExp(r'^#'), '');
    return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(cleaned)
        ? cleaned.toUpperCase()
        : fallback;
  }
}
