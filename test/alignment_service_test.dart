import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/guide_settings.dart';
import 'package:ghita_ppt_converter/services/alignment_service.dart';

void main() {
  const a = Alignable(id: 'a', x: 10, y: 10, w: 20, h: 20);
  const b = Alignable(id: 'b', x: 40, y: 40, w: 30, h: 30);
  const c = Alignable(id: 'c', x: 60, y: 20, w: 10, h: 10);

  group('Track 27 — Align', () {
    test('align left to slide edge', () {
      final out = AlignmentService.align([a, b], kind: AlignKind.left);
      expect(out[0].x, 0);
      expect(out[1].x, 0);
    });

    test('align right to slide edge keeps widths', () {
      final out = AlignmentService.align([a, b], kind: AlignKind.right);
      expect(out[0].x + out[0].w, 100);
      expect(out[1].x + out[1].w, 100);
    });

    test('align horizontal centre to slide', () {
      final out = AlignmentService.align([a, b], kind: AlignKind.centerH);
      expect(out[0].x + out[0].w / 2, 50);
      expect(out[1].x + out[1].w / 2, 50);
    });

    test('align vertical middle to slide', () {
      final out = AlignmentService.align([a, b], kind: AlignKind.middle);
      expect(out[0].y + out[0].h / 2, 50);
      expect(out[1].y + out[1].h / 2, 50);
    });

    test('align to selection bbox', () {
      final bbox = AlignmentService.bboxOf([a, b, c]);
      expect(bbox.x, 10);
      expect(bbox.w, 60); // from x=10 to x+ w = 70
      final out = AlignmentService.align(
        [a, b],
        kind: AlignKind.left,
        relativeTo: bbox,
      );
      expect(out[0].x, 10);
      expect(out[1].x, 10);
    });

    test('align leaves perpendicular axis untouched', () {
      final out = AlignmentService.align([a], kind: AlignKind.left);
      expect(out[0].y, 10);
    });
  });

  group('Track 27 — Distribute', () {
    test('horizontal distribute spaces left edges evenly keeping ends fixed', () {
      // x positions 10, 40, 60 → span = 50 → gap = 25.
      final out = AlignmentService.distribute([a, b, c], kind: DistributeKind.horizontal);
      expect(out[0].x, 10);
      expect(out[1].x, 35);
      expect(out[2].x, 60);
    });

    test('vertical distribute keeps y-axis even', () {
      final out = AlignmentService.distribute([a, b, c], kind: DistributeKind.vertical);
      expect(out[0].y, 10);
      expect(out[2].y, 40);
    });

    test('fewer than 3 items returns unchanged', () {
      final out = AlignmentService.distribute([a, b], kind: DistributeKind.horizontal);
      expect(out, [a, b]);
    });
  });

  group('Track 27 — Smart guides & snap', () {
    test('snaps to another element edge within threshold', () {
      // Drag a so its right edge (10+20+dx=30+dx) nears b's left edge (40).
      final snap = AlignmentService.snapPosition(
        a,
        8,
        0, // → right edge at 38, within 3 of 40
        others: [b],
      );
      expect(snap, isNotNull);
      expect(snap!.x, closeTo(20, 1e-6)); // a.x such that a.x+20 = 40
      expect(snap.y, 10);
    });

    test('returns null when nothing is close', () {
      // dx=15 → left 25, centre 35, right 45 — nearest candidate (b.x=40)
      // is 5 away, beyond the 3% threshold.
      final snap = AlignmentService.snapPosition(
        a,
        15,
        15,
        others: [b],
      );
      expect(snap, isNull);
    });

    test('snaps to slide centre', () {
      const item = Alignable(id: 'x', x: 20, y: 0, w: 40, h: 10);
      // Centre at 20+20+dx = 40+dx → near 50 when dx = 9.5
      final snap = AlignmentService.snapPosition(
        item,
        9.5,
        0,
        others: [],
      );
      expect(snap, isNotNull);
      expect(snap!.x + item.w / 2, closeTo(50, 1e-6));
    });

    test('snaps to user guide (right edge lands on the guide)', () {
      final snap = AlignmentService.snapPosition(
        a,
        7,
        0,
        others: [],
        userGuidesX: [37],
      );
      expect(snap, isNotNull);
      expect(snap!.x, closeTo(17, 1e-6)); // x + w = 37
    });

    test('snaps to grid when enabled', () {
      const item = Alignable(id: 'g', x: 12.4, y: 8.1, w: 10, h: 10);
      final snap = AlignmentService.snapPosition(
        item,
        0,
        0,
        others: [const Alignable(id: 'far', x: 80, y: 80, w: 5, h: 5)],
        snapGrid: true,
        gridSize: 5,
      );
      // 12.4 → 10 (within 2), 8.1 → 10 (within 2) — grid snaps both axes.
      expect(snap, isNotNull);
      expect(snap!.x, closeTo(10, 1e-6));
      expect(snap.y, closeTo(10, 1e-6));
    });
  });

  group('Track 27 — Ruler ticks & guides model', () {
    test('rulerTicks returns major positions', () {
      final ticks = AlignmentService.rulerTicks(lengthPx: 1000, scale: 10);
      expect(ticks, [0, 500, 1000]);
    });

    test('GuideLine round-trips', () {
      const g = GuideLine(position: 33.5, horizontal: true, locked: true);
      final back = GuideLine.fromMap(g.toMap());
      expect(back.position, 33.5);
      expect(back.horizontal, isTrue);
      expect(back.locked, isTrue);
    });

    test('GuideSettings toMap/fromMap round-trips deck meta', () {
      const s = GuideSettings(
        guides: [GuideLine(position: 25, horizontal: false)],
        snapToGrid: false,
        showGrid: true,
        gridSize: 10,
      );
      final back = GuideSettings.fromMap(s.toMap());
      expect(back.guides.single.position, 25);
      expect(back.snapToGrid, isFalse);
      expect(back.showGrid, isTrue);
      expect(back.gridSize, 10);
    });
  });
}
