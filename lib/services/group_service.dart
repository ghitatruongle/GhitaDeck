import '../models/drawn_shape.dart';
import 'shape_engine.dart';

/// A group of drawn shapes kept together (Track 26, P4–P5).
///
/// Groups are stored in `Slide.visualElements['groups']` as maps:
/// `{ id, memberIds: [...], x, y, w, h }` where x/y/w/h is the group
/// bounding box in % (recomputed on every move/scale). Members keep their
/// own geometry — the group just moves/scales them as one.
class ShapeGroup {
  final String id;
  final List<String> memberIds;
  final double x, y, w, h; // % of slide — union bounding box

  const ShapeGroup({
    required this.id,
    required this.memberIds,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  ShapeGroup copyWith({List<String>? memberIds, double? x, double? y, double? w, double? h}) =>
      ShapeGroup(
        id: id,
        memberIds: memberIds ?? this.memberIds,
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'memberIds': memberIds,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };

  static ShapeGroup fromMap(Map<String, dynamic> map) => ShapeGroup(
        id: map['id']?.toString() ?? '',
        memberIds: map['memberIds'] is List
            ? List<String>.from(map['memberIds'] as List)
            : [],
        x: (map['x'] as num?)?.toDouble() ?? 0,
        y: (map['y'] as num?)?.toDouble() ?? 0,
        w: (map['w'] as num?)?.toDouble() ?? 0,
        h: (map['h'] as num?)?.toDouble() ?? 0,
      );
}

/// Group operations (Track 26).
class GroupService {
  GroupService._();

  /// Compute the union bounding box of [shapes] in % of the slide.
  static ({double x, double y, double w, double h}) bboxOf(
      List<DrawnShape> shapes) {
    var minX = 100.0, minY = 100.0, maxX = 0.0, maxY = 0.0;
    for (final s in shapes) {
      if (s.x < minX) minX = s.x;
      if (s.y < minY) minY = s.y;
      if (s.x + s.w > maxX) maxX = s.x + s.w;
      if (s.y + s.h > maxY) maxY = s.y + s.h;
    }
    return (x: minX, y: minY, w: maxX - minX, h: maxY - minY);
  }

  /// Group [memberIds] (must exist in [shapes]) into a new group.
  static ShapeGroup createGroup(List<DrawnShape> shapes, List<String> memberIds) {
    final members =
        shapes.where((s) => memberIds.contains(s.id)).toList();
    final bbox = bboxOf(members);
    return ShapeGroup(
      id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
      memberIds: [for (final m in members) m.id],
      x: bbox.x,
      y: bbox.y,
      w: bbox.w,
      h: bbox.h,
    );
  }

  /// Move a whole group by (dx, dy) %: every member shifts, the group box
  /// follows. Returns the updated member list.
  static List<DrawnShape> moveGroup(
      List<DrawnShape> shapes, ShapeGroup group, double dx, double dy) {
    return [
      for (final s in shapes)
        if (group.memberIds.contains(s.id))
          s.copyWith(x: s.x + dx, y: s.y + dy)
        else
          s,
    ];
  }

  /// Scale a group by [factor] around its centre: members scale and move so
  /// relative positions are preserved.
  static List<DrawnShape> scaleGroup(
      List<DrawnShape> shapes, ShapeGroup group, double factor) {
    final cx = group.x + group.w / 2;
    final cy = group.y + group.h / 2;
    return [
      for (final s in shapes)
        if (group.memberIds.contains(s.id))
          s.copyWith(
            x: cx - (cx - s.x) * factor,
            y: cy - (cy - s.y) * factor,
            w: s.w * factor,
            h: s.h * factor,
          )
        else
          s,
    ];
  }

  // ---- PPTX export (P5): <p:grpSp> wrapping ----------------------------

  /// Render `<p:grpSp>` OOXML for [group] with its [members]. The group's
  /// xfrm is placed at the group box; children live in child coordinates
  /// relative to the group's top-left (chOff="0" chExt=group size).
  static String renderPptxGroupXml({
    required int groupShapeId,
    required ShapeGroup group,
    required List<DrawnShape> members,
  }) {
    const slideWEmu = 9144000;
    const slideHEmu = 6858000;
    final offX = (group.x / 100 * slideWEmu).round();
    final offY = (group.y / 100 * slideHEmu).round();
    final extCx = (group.w / 100 * slideWEmu).round();
    final extCy = (group.h / 100 * slideHEmu).round();
    final buf = StringBuffer()
      ..write('      <p:grpSp>\n')
      ..write('        <p:nvGrpSpPr><p:cNvPr id="$groupShapeId" name="Group ${group.id}"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\n')
      ..write('        <p:grpSpPr><a:xfrm><a:off x="$offX" y="$offY"/><a:ext cx="$extCx" cy="$extCy"/><a:chOff x="0" y="0"/><a:chExt cx="$extCx" cy="$extCy"/></a:xfrm></p:grpSpPr>\n');
    var memberShapeId = groupShapeId + 1;
    for (final member in members) {
      // Member coordinates are relative to the group box in child space.
      final mOffX = ((member.x - group.x) / 100 * extCx).round();
      final mOffY = ((member.y - group.y) / 100 * extCy).round();
      final mExtCx = (member.w / 100 * extCx).round();
      final mExtCy = (member.h / 100 * extCy).round();
      buf.write(ShapeEngine.renderPptxShape(
        shapeId: memberShapeId++,
        shape: member.copyWith(x: 0, y: 0, w: 100, h: 100),
        offX: mOffX,
        offY: mOffY,
        extCx: mExtCx,
        extCy: mExtCy,
      ));
    }
    buf.write('      </p:grpSp>\n');
    return buf.toString();
  }
}
