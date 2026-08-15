/// Free-form text/shape element (Track 17, FEAT 15, 16).
///
/// Positioned absolutely on the slide canvas using percentage coordinates
/// (x, y, w, h as % of the slide) so the element scales correctly across
/// PPTX, HTML and PDF exports. Stored in [Slide.visualElements] as a
/// `Map<String, dynamic>` under the key `"freeTexts"`.
library;

import 'dart:convert';
import '../services/wordart_service.dart';

class FreeTextShape {
  const FreeTextShape({
    this.id = '',
    this.text = '',
    this.x = 0.0,
    this.y = 0.0,
    this.w = 20.0,
    this.h = 10.0,
    this.rotation = 0.0,
    this.zOrder = 0,
    this.fontSize = 18.0,
    this.fontFamily = 'Segoe UI',
    this.fontWeight = 'normal',
    this.fontStyle = 'normal',
    this.color = '#000000',
    this.backgroundColor = 'transparent',
    this.borderColor = '',
    this.borderWidth = 0.0,
    this.shadow = false,
    this.wordArtStyle = 0,
  });

  final String id;
  final String text;
  final double x; // % of slide width
  final double y; // % of slide height
  final double w; // % of slide width
  final double h; // % of slide height
  final double rotation; // degrees
  final int zOrder;
  final double fontSize;
  final String fontFamily;
  final String fontWeight;
  final String fontStyle;
  final String color;
  final String backgroundColor;
  final String borderColor;
  final double borderWidth;
  final bool shadow;
  final int wordArtStyle; // 0 = none, 1..12 = WordArt preset

  FreeTextShape copyWith({
    String? id,
    String? text,
    double? x,
    double? y,
    double? w,
    double? h,
    double? rotation,
    int? zOrder,
    double? fontSize,
    String? fontFamily,
    String? fontWeight,
    String? fontStyle,
    String? color,
    String? backgroundColor,
    String? borderColor,
    double? borderWidth,
    bool? shadow,
    int? wordArtStyle,
  }) =>
      FreeTextShape(
        id: id ?? this.id,
        text: text ?? this.text,
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
        rotation: rotation ?? this.rotation,
        zOrder: zOrder ?? this.zOrder,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        fontWeight: fontWeight ?? this.fontWeight,
        fontStyle: fontStyle ?? this.fontStyle,
        color: color ?? this.color,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        borderColor: borderColor ?? this.borderColor,
        borderWidth: borderWidth ?? this.borderWidth,
        shadow: shadow ?? this.shadow,
        wordArtStyle: wordArtStyle ?? this.wordArtStyle,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        if (rotation != 0.0) 'rotation': rotation,
        if (zOrder != 0) 'zOrder': zOrder,
        if (fontSize != 18.0) 'fontSize': fontSize,
        if (fontFamily != 'Segoe UI') 'fontFamily': fontFamily,
        if (fontWeight != 'normal') 'fontWeight': fontWeight,
        if (fontStyle != 'normal') 'fontStyle': fontStyle,
        if (color != '#000000') 'color': color,
        if (backgroundColor != 'transparent') 'backgroundColor': backgroundColor,
        if (borderColor.isNotEmpty) 'borderColor': borderColor,
        if (borderWidth != 0.0) 'borderWidth': borderWidth,
        if (shadow) 'shadow': true,
        if (wordArtStyle != 0) 'wordArtStyle': wordArtStyle,
      };

  static FreeTextShape fromMap(Map<String, dynamic> map) => FreeTextShape(
        id: map['id']?.toString() ?? '',
        text: map['text']?.toString() ?? '',
        x: (map['x'] as num?)?.toDouble() ?? 0.0,
        y: (map['y'] as num?)?.toDouble() ?? 0.0,
        w: (map['w'] as num?)?.toDouble() ?? 20.0,
        h: (map['h'] as num?)?.toDouble() ?? 10.0,
        rotation: (map['rotation'] as num?)?.toDouble() ?? 0.0,
        zOrder: (map['zOrder'] as num?)?.toInt() ?? 0,
        fontSize: (map['fontSize'] as num?)?.toDouble() ?? 18.0,
        fontFamily: map['fontFamily']?.toString() ?? 'Segoe UI',
        fontWeight: map['fontWeight']?.toString() ?? 'normal',
        fontStyle: map['fontStyle']?.toString() ?? 'normal',
        color: map['color']?.toString() ?? '#000000',
        backgroundColor: map['backgroundColor']?.toString() ?? 'transparent',
        borderColor: map['borderColor']?.toString() ?? '',
        borderWidth: (map['borderWidth'] as num?)?.toDouble() ?? 0.0,
        shadow: map['shadow'] == true,
        wordArtStyle: (map['wordArtStyle'] as num?)?.toInt() ?? 0,
      );

  String toJson() => jsonEncode(toMap());

  static FreeTextShape fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const FreeTextShape();
      return fromMap(map);
    } catch (_) {
      return const FreeTextShape();
    }
  }

  /// HTML markup for inline rendering (used by the canvas overlay and
  /// the HTML deck — the canvas overlay reapplies styles via CSS).
  String get htmlMarkup {
    final bg = backgroundColor == 'transparent' ? 'transparent' : backgroundColor;
    final border = borderColor.isNotEmpty && borderWidth > 0
        ? 'border: ${borderWidth}px solid $borderColor;'
        : '';
    final shadowCss = shadow ? 'box-shadow: 2px 2px 8px rgba(0,0,0,0.3);' : '';
    final rot = rotation != 0 ? 'transform: rotate(${rotation}deg);' : '';
    final wa = wordArtStyle > 0 ? WordArtService.styleCss(wordArtStyle) : '';
    return '<div style="position:absolute; left:$x%; top:$y%; '
        'width:$w%; height:$h%; overflow:hidden; '
        'font-size:${fontSize}px; font-family:$fontFamily; '
        'font-weight:$fontWeight; font-style:$fontStyle; '
        'color:$color; background:$bg; $border $shadowCss $rot $wa '
        'display:flex; align-items:center; justify-content:center;'
        '">${_xml(text)}</div>';
  }

  String _xml(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}