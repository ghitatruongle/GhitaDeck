/// WordArt style service (Track 17, FEAT 15).
///
/// 12 WordArt presets: fills (solid/gradient), wave, outline, shadow,
/// reflection, glow. Each style provides CSS (for HTML/canvas overlay)
/// and OOXML effect/fill XML (for PPTX export).
library;

class WordArtService {
  WordArtService._();

  static const List<_WordArtStyle> _styles = [
    _WordArtStyle('Fill – Black, text 1', // 1
        'background: linear-gradient(135deg, #333, #666); -webkit-background-clip: text; -webkit-text-fill-color: transparent;'),
    _WordArtStyle('Fill – Blue, Accent 1', // 2
        'background: linear-gradient(135deg, #1a73e8, #6ab7ff); -webkit-background-clip: text; -webkit-text-fill-color: transparent;'),
    _WordArtStyle('Fill – Orange, Accent 2', // 3
        'background: linear-gradient(135deg, #e8710a, #ffb74d); -webkit-background-clip: text; -webkit-text-fill-color: transparent;'),
    _WordArtStyle('Fill – Green, Accent 6', // 4
        'background: linear-gradient(135deg, #0d652d, #81c784); -webkit-background-clip: text; -webkit-text-fill-color: transparent;'),
    _WordArtStyle('Gradient – Linear', // 5
        'background: linear-gradient(90deg, #ff5f6d, #ffc371); -webkit-background-clip: text; -webkit-text-fill-color: transparent;'),
    _WordArtStyle('Gradient – Radial', // 6
        'background: radial-gradient(circle, #667eea, #764ba2); -webkit-background-clip: text; -webkit-text-fill-color: transparent;'),
    _WordArtStyle('Gradient – Diagonal', // 7
        'background: linear-gradient(135deg, #f093fb, #f5576c); -webkit-background-clip: text; -webkit-text-fill-color: transparent;'),
    _WordArtStyle('Wave', // 8
        'background: linear-gradient(180deg, #1a73e8, #34a853, #fbbc04, #ea4335); -webkit-background-clip: text; -webkit-text-fill-color: transparent; text-decoration: wavy underline;'),
    _WordArtStyle('Outline', // 9
        '-webkit-text-stroke: 1px #333; color: transparent;'),
    _WordArtStyle('Shadow', // 10
        'text-shadow: 3px 3px 6px rgba(0,0,0,0.3);'),
    _WordArtStyle('Reflection', // 11
        'box-shadow: 0 4px 8px rgba(0,0,0,0.15); background: linear-gradient(180deg, #333 60%, transparent 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent;'),
    _WordArtStyle('Glow', // 12
        'text-shadow: 0 0 10px #1a73e8, 0 0 20px #1a73e8, 0 0 30px #1a73e8;'),
  ];

  /// Number of available WordArt styles.
  static int get count => _styles.length;

  /// CSS snippet for style [index] (1-based, 0 = plain).
  static String styleCss(int index) =>
      index >= 1 && index <= _styles.length ? _styles[index - 1].css : '';

  /// Display name of style [index] (1-based).
  static String styleName(int index) =>
      index >= 1 && index <= _styles.length ? _styles[index - 1].name : 'None';

  /// OOXML `<a:effectLst>` for a WordArt style (used by PPTX export).
  static String pptxEffectLst(int index) {
    switch (index) {
      case 9: // Outline
        return '<a:ln w="12700"><a:solidFill><a:srgbClr val="333333"/></a:solidFill></a:ln>';
      case 10: // Shadow
        return '<a:effectLst><a:outerShdw blurRad="50800" dist="25400" dir="2700000"><a:srgbClr val="000000"><a:alpha val="50000"/></a:srgbClr></a:outerShdw></a:effectLst>';
      case 12: // Glow
        return '<a:effectLst><a:glow rad="50800"><a:srgbClr val="1A73E8"/></a:glow></a:effectLst>';
      default:
        return '';
    }
  }

  /// OOXML `<a:gradFill>` for WordArt gradient styles (5/6/7).
  static String pptxGradFill(int index) {
    switch (index) {
      case 5:
        return '<a:gradFill><a:gradLin ang="0"><a:gsLst><a:gs pos="0"><a:srgbClr val="FF5F6D"/></a:gs><a:gs pos="100000"><a:srgbClr val="FFC371"/></a:gs></a:gsLst></a:gradLin></a:gradFill>';
      case 6:
        return '<a:gradFill><a:gradLin ang="5400000"><a:gsLst><a:gs pos="0"><a:srgbClr val="667EEA"/></a:gs><a:gs pos="100000"><a:srgbClr val="764BA2"/></a:gs></a:gsLst></a:gradLin></a:gradFill>';
      case 7:
        return '<a:gradFill><a:gradLin ang="8100000"><a:gsLst><a:gs pos="0"><a:srgbClr val="F093FB"/></a:gs><a:gs pos="100000"><a:srgbClr val="F5576C"/></a:gs></a:gsLst></a:gradLin></a:gradFill>';
      default:
        return '';
    }
  }
}

class _WordArtStyle {
  final String name;
  final String css;
  const _WordArtStyle(this.name, this.css);
}