import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/present_tools_service.dart';
import 'package:ghita_ppt_converter/services/present_deck_commands.dart';

/// Track 35 tests — Present Pro tools (FEAT 55, 56, 57 + OPT 21, 22, 23).
void main() {
  group('PresentToolsService tool state (P5)', () {
    test('toggling a tool on and off', () {
      final s = PresentToolsService();
      expect(s.tool, PresentTool.none);
      s.togglePen();
      expect(s.tool, PresentTool.pen);
      s.togglePen();
      expect(s.tool, PresentTool.none);
    });

    test('laser deactivates magnifier and vice versa', () {
      final s = PresentToolsService();
      s.toggleMagnifier();
      expect(s.magnifier, isTrue);
      s.toggleLaser();
      expect(s.magnifier, isFalse);
      expect(s.tool, PresentTool.laser);
    });
  });

  group('black/white screen (P7)', () {
    test('B and W are mutually exclusive', () {
      final s = PresentToolsService();
      s.toggleBlackScreen();
      expect(s.blackScreen, isTrue);
      s.toggleWhiteScreen();
      expect(s.blackScreen, isFalse);
      expect(s.whiteScreen, isTrue);
      s.clearScreens();
      expect(s.whiteScreen, isFalse);
      expect(s.blackScreen, isFalse);
    });
  });

  group('grid navigator (P4)', () {
    test('toggle opens and closes', () {
      final s = PresentToolsService();
      s.toggleGrid();
      expect(s.gridOpen, isTrue);
      s.closeGrid();
      expect(s.gridOpen, isFalse);
    });
  });

  group('magnifier (P6)', () {
    test('zoom clamps between 1.0 and 3.0', () {
      final s = PresentToolsService();
      s.toggleMagnifier();
      expect(s.zoom, 1.5);
      s.adjustZoom(10);
      expect(s.zoom, 3.0);
      s.adjustZoom(-10);
      expect(s.zoom, 1.0);
      expect(s.magnifier, isFalse); // drops below threshold → off
    });
  });

  group('ink strokes (P5)', () {
    test('start/continue/end accumulates strokes with % coordinates', () {
      final s = PresentToolsService();
      s.togglePen();
      s.startStroke(0, const OffsetPct(10, 20));
      s.continueStroke(const OffsetPct(30, 40));
      s.endStroke();
      expect(s.strokes.length, 1);
      final stroke = s.strokes.first;
      expect(stroke.slideIndex, 0);
      expect(stroke.tool, PresentTool.pen);
      expect(stroke.color.cssHex, '#ED1C24');
      expect(stroke.points.length, 2);
    });

    test('no stroke when tool is none', () {
      final s = PresentToolsService();
      s.startStroke(0, const OffsetPct(1, 1));
      expect(s.activeStroke, isNull);
      s.endStroke();
      expect(s.strokes, isEmpty);
    });

    test('highlighter uses its own colour and wider width', () {
      final s = PresentToolsService();
      s.toggleHighlighter();
      s.startStroke(0, const OffsetPct(0, 0));
      s.endStroke();
      expect(s.strokes.first.color.cssHex, '#FFF200');
      expect(s.strokes.first.width, 14.0);
    });

    test('removeSlide shifts indices and drops the deleted slide', () {
      final s = PresentToolsService();
      s.togglePen();
      s.startStroke(1, const OffsetPct(0, 0));
      s.endStroke();
      s.startStroke(2, const OffsetPct(0, 0));
      s.endStroke();
      s.removeSlide(1);
      expect(s.strokes.length, 1);
      expect(s.strokes.first.slideIndex, 1); // was 2, shifted down
    });

    test('strokes serialize round-trip', () {
      final s = PresentToolsService();
      s.togglePen();
      s.startStroke(1, const OffsetPct(5, 6));
      s.continueStroke(const OffsetPct(7, 8));
      s.endStroke();
      final map = s.strokes.first.toMap();
      final restored = PresentStroke.fromMap(map);
      expect(restored.slideIndex, 1);
      expect(restored.points.last.x, 7);
    });
  });

  group('session settings (P8)', () {
    test('persist and restore via JSON', () {
      const original = PresentSessionSettings(
        penColor: ColorHex(0xFF00FF00),
        highlighterColor: ColorHex(0xFF0000FF),
        penWidth: 5.0,
        laserOnByDefault: true,
      );
      final restored = PresentSessionSettings.fromJson(original.toJson());
      expect(restored.penColor.cssHex, '#00FF00');
      expect(restored.highlighterColor.cssHex, '#0000FF');
      expect(restored.penWidth, 5.0);
      expect(restored.laserOnByDefault, isTrue);
    });

    test('updateSettings propagates', () {
      final s = PresentToolsService();
      s.updateSettings(const PresentSessionSettings(penColor: ColorHex(0xFF000000)));
      expect(s.settings.penColor.cssHex, '#000000');
    });
  });

  group('keyboard mapping (P4/P7)', () {
    test('shortcut keys map to actions', () {
      PresentAction k(String key) =>
          PresentToolsService.actionForKey(key, ctrl: false);
      expect(k('g'), PresentAction.toggleGrid);
      expect(k('B'), PresentAction.toggleBlack);
      expect(k('w'), PresentAction.toggleWhite);
      expect(k('l'), PresentAction.toggleLaser);
      expect(k('P'), PresentAction.togglePen);
      expect(k('ArrowRight'), PresentAction.nextSlide);
      expect(k(' '), PresentAction.nextSlide);
      expect(k('ArrowLeft'), PresentAction.prevSlide);
      expect(k('x'), PresentAction.none);
    });
  });

  group('PresentDeckCommands (JS strings)', () {
    test('navigation commands call the player functions', () {
      expect(PresentDeckCommands.goToSlide(3), 'goToSlide(3);');
      expect(PresentDeckCommands.changeSlide(1), 'changeSlide(1);');
      expect(PresentDeckCommands.nextSlide(), 'changeSlide(1);');
      expect(PresentDeckCommands.prevSlide(), 'changeSlide(-1);');
      expect(PresentDeckCommands.getCurrentSlideExpr(), 'currentSlide');
    });

    test('installInkOverlay defines a guarded install with canvas', () {
      final js = PresentDeckCommands.installInkOverlay('#ED1C24', 3.0);
      expect(js, contains('ghitaInkInstalled'));
      expect(js, contains('id = "ghita-ink"'));
      expect(js, contains('penColor = "#ED1C24"'));
      expect(js, contains('penWidth = 3.0'));
      expect(js, contains('pointerdown'));
      expect(js, contains('"laser"'));
    });

    test('ink tool commands guard on ghitaInk and sanitise color', () {
      expect(PresentDeckCommands.setInkTool('pen'),
          'if (window.ghitaInk) window.ghitaInk.setTool("pen");');
      expect(PresentDeckCommands.setInkTool('junk'),
          'if (window.ghitaInk) window.ghitaInk.setTool("none");');
      expect(PresentDeckCommands.setInkColor('#000000'),
          'if (window.ghitaInk) window.ghitaInk.setColor("#000000");');
      expect(PresentDeckCommands.clearInk(),
          'if (window.ghitaInk) window.ghitaInk.clear();');
    });

    test('screen overlay commands add and remove a fixed div', () {
      expect(PresentDeckCommands.setScreen('#000000'),
          contains('ghita-screen-ov'));
      expect(PresentDeckCommands.setScreen('#000000'), contains('#000000'));
      expect(PresentDeckCommands.setScreen(''), contains('remove'));
    });

    test('magnifier zoom transforms #deck', () {
      expect(PresentDeckCommands.setZoom(2.0), contains('scale(2.0)'));
      expect(PresentDeckCommands.setZoom(1.0), contains('transform = ""'));
      expect(PresentDeckCommands.setZoom(4.0), contains('scale(3.0)')); // clamp
    });

    test('installProKeys wires grid/black/white/pen/laser shortcuts', () {
      final js = PresentDeckCommands.installProKeys();
      expect(js, contains('ghitaProKeys'));
      expect(js, contains('showGrid'));
      expect(js, contains('"g"'));
      expect(js, contains('"b"'));
      expect(js, contains('"w"'));
      expect(js, contains('"l"'));
      expect(js, contains('"m"'));
      expect(js, contains('totalSlides'));
    });

    test('presenter sync helpers', () {
      expect(PresentDeckCommands.installPresenterSync(), contains('presenterGoTo'));
      expect(PresentDeckCommands.presenterGoTo(4), 'presenterGoTo(4);');
      expect(PresentDeckCommands.presenterCurrent(), 'presenterCurrent();');
    });
  });
}
