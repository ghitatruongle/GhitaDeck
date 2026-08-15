import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/custom_show.dart';
import 'package:ghita_ppt_converter/services/setup_show_service.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';

/// Track 36 tests — Set Up Show & Custom Shows (FEAT 58, 59, 60).
void main() {
  group('CustomShow model (P1)', () {
    test('round-trips through JSON', () {
      const show = CustomShow(
        id: 's1',
        name: 'Intro only',
        slideIndices: [0, 1, 2],
      );
      final restored = CustomShow.fromJson(show.toJson());
      expect(restored.id, 's1');
      expect(restored.name, 'Intro only');
      expect(restored.slideIndices, [0, 1, 2]);
    });

    test('validIndices clamps to the live deck size', () {
      const show = CustomShow(slideIndices: [0, 1, 2, 5, 9]);
      expect(show.validIndices(5), [0, 1, 2]);
      expect(show.validIndices(10), [0, 1, 2, 5, 9]);
      expect(show.validIndices(0), isEmpty);
    });

    test('copyWith replaces fields', () {
      const show = CustomShow(id: 'a', name: 'A');
      final next = show.copyWith(name: 'B', slideIndices: const [1]);
      expect(next.name, 'B');
      expect(next.slideIndices, [1]);
    });
  });

  group('CustomShowService (P6)', () {
    test('serializes/deserializes a list', () {
      final shows = [
        const CustomShow(id: 'a', name: 'A', slideIndices: [0]),
        const CustomShow(id: 'b', name: 'B', slideIndices: [1, 2]),
      ];
      final json = CustomShowService.toJsonList(shows);
      final restored = CustomShowService.fromJsonList(json);
      expect(restored.length, 2);
      expect(restored[1].name, 'B');
    });

    test('fromJsonList tolerates garbage', () {
      expect(CustomShowService.fromJsonList('not json'), isEmpty);
      expect(CustomShowService.fromJsonList('[1,2,3]'), isEmpty);
    });

    test('defaultShow covers the whole deck', () {
      final show = CustomShowService.defaultShow(8);
      expect(show.slideIndices, [0, 1, 2, 3, 4, 5, 6, 7]);
    });

    test('toggleIndex adds and removes while keeping order', () {
      var indices = CustomShowService.toggleIndex([], 3);
      expect(indices, [3]);
      indices = CustomShowService.toggleIndex(indices, 1);
      expect(indices, [1, 3]);
      indices = CustomShowService.toggleIndex(indices, 3);
      expect(indices, [1]);
    });
  });

  group('SetupShowSettings (P2–P5)', () {
    test('defaults to presenter mode with no options', () {
      const s = SetupShowSettings();
      expect(s.mode, ShowMode.presenter);
      expect(s.loopContinuously, isFalse);
      expect(s.showWithoutNarration, isFalse);
      expect(s.showWithoutAnimation, isFalse);
      expect(s.advanceSeconds, 0);
      expect(s.autoAdvance, isFalse);
    });

    test('round-trips through JSON', () {
      const s = SetupShowSettings(
        mode: ShowMode.kiosk,
        loopContinuously: true,
        showWithoutNarration: true,
        showWithoutAnimation: true,
        advanceSeconds: 10,
        penColorHex: '#22B14C',
      );
      final restored = SetupShowSettings.fromJson(s.toJson());
      expect(restored.mode, ShowMode.kiosk);
      expect(restored.loopContinuously, isTrue);
      expect(restored.showWithoutNarration, isTrue);
      expect(restored.showWithoutAnimation, isTrue);
      expect(restored.advanceSeconds, 10);
      expect(restored.penColorHex, '#22B14C');
    });

    test('fromJson tolerates garbage and unknown mode', () {
      final fallback = SetupShowSettings.fromJson('x');
      expect(fallback.mode, ShowMode.presenter);
      final unknown = SetupShowSettings.fromJson(
          jsonEncode({'mode': 'silly', 'loopContinuously': true}));
      expect(unknown.mode, ShowMode.presenter);
      expect(unknown.loopContinuously, isTrue);
    });

    test('copyWith changes single fields', () {
      const s = SetupShowSettings();
      final next = s.copyWith(mode: ShowMode.browsed, advanceSeconds: 30);
      expect(next.mode, ShowMode.browsed);
      expect(next.advanceSeconds, 30);
      expect(next.loopContinuously, isFalse);
    });
  });

  group('PPTX p:custShow (P7)', () {
    test('custom show written into presentation.xml', () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t36_');
      try {
        const show = CustomShow(
          id: 's1',
          name: 'Intro',
          slideIndices: [0, 2],
        );
        final slides = [
          {'title': 'A', 'htmlContent': '<h1>A</h1>'},
          {'title': 'B', 'htmlContent': '<h1>B</h1>'},
          {'title': 'C', 'htmlContent': '<h1>C</h1>'},
        ];
        await PPTGenerator.generatePPT(
          slides,
          '${dir.path}/out.pptx',
          customShow: show,
        );
        final archive = ZipDecoder()
            .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
        final pres = utf8.decode(archive.files
            .firstWhere((e) => e.name == 'ppt/presentation.xml')
            .content as List<int>);
        expect(pres, contains('<p:custShowLst>'));
        expect(pres, contains('name="Intro"'));
        expect(pres, contains('<p:sld id="256"/>')); // slide index 0
        expect(pres, contains('<p:sld id="258"/>')); // slide index 2
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('no custShowLst when no custom show given', () async {
      final dir = await Directory.systemTemp.createTemp('ghita_t36b_');
      try {
        await PPTGenerator.generatePPT([
          {'title': 'A', 'htmlContent': '<h1>A</h1>'},
        ], '${dir.path}/out.pptx');
        final archive = ZipDecoder()
            .decodeBytes(File('${dir.path}/out.pptx').readAsBytesSync());
        final pres = utf8.decode(archive.files
            .firstWhere((e) => e.name == 'ppt/presentation.xml')
            .content as List<int>);
        expect(pres, isNot(contains('<p:custShowLst>')));
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
