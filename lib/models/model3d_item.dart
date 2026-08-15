/// 3D model definition (Track 14, FEAT 10).
library;
///
/// Pure Dart + serializable: the model travels inside slide HTML as a
/// `<div data-model3d='…json…'>` block (chart/smartart style). The GLB
/// payload lives in `src` as a data: URI; the poster is a self-generated
/// SVG (also stored inline) so previews never need a 3D renderer.
import 'dart:convert';

class Model3DData {
  const Model3DData({
    this.src = '',
    this.posterSvg = '',
    this.rotate = false,
    this.name = '3D Model',
  });

  /// GLB payload as a data: URI (`data:model/gltf-binary;base64,…`) or empty.
  final String src;

  /// Self-generated poster SVG markup (shown in the app/HTML/PDF previews
  /// and used as the PowerPoint raster poster source).
  final String posterSvg;

  /// Auto-rotate: plays the model's first embedded animation on slide entry
  /// (PowerPoint emits the a3danim machinery; models without embedded
  /// animations simply show the poster).
  final bool rotate;

  final String name;

  Model3DData copyWith({
    String? src,
    String? posterSvg,
    bool? rotate,
    String? name,
  }) =>
      Model3DData(
        src: src ?? this.src,
        posterSvg: posterSvg ?? this.posterSvg,
        rotate: rotate ?? this.rotate,
        name: name ?? this.name,
      );

  Map<String, dynamic> toMap() => {
        if (src.isNotEmpty) 'src': src,
        if (posterSvg.isNotEmpty) 'posterSvg': posterSvg,
        if (rotate) 'rotate': true,
        if (name.isNotEmpty) 'name': name,
      };

  static Model3DData fromJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const Model3DData();
      return Model3DData(
        src: map['src']?.toString() ?? '',
        posterSvg: map['posterSvg']?.toString() ?? '',
        rotate: map['rotate'] == true,
        name: map['name']?.toString() ?? '3D Model',
      );
    } catch (_) {
      return const Model3DData();
    }
  }

  String toJson() => jsonEncode(toMap());

  static Model3DData sample() => const Model3DData(
        src: 'data:model/gltf-binary;base64,QUJD',
        rotate: true,
        name: 'Mẫu 3D',
      );
}
