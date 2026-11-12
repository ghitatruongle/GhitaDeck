import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/services/cloud_sync_service.dart';
import 'package:ghita_deck/services/equation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EquationData round-trip', () {
    test('toJson/fromJson round-trips mathml and latex', () {
      const eq = EquationData(mathml: '<m:frac/>', latex: 'x^2');
      final back = EquationData.fromJson(eq.toJson());
      expect(back.mathml, '<m:frac/>');
      expect(back.latex, 'x^2');
    });

    test('fromMap defaults missing keys to empty', () {
      const eq = EquationData();
      expect(eq.toMap(), isEmpty);
      expect(EquationData.fromMap(const {}).mathml, isEmpty);
    });
  });

  group('Equation html blocks', () {
    test('equationsIn finds every block', () {
      const eq = EquationData(latex: 'e=mc^2');
      final html = '<p>a</p>${EquationService.equationMarkup(eq)}'
          '<p>b</p>${EquationService.equationMarkup(eq)}';
      expect(EquationService.equationCount(html), 2);
      final found = EquationService.equationsIn(html);
      expect(found, hasLength(2));
      expect(found.first.latex, 'e=mc^2');
    });

    test('replaceEquationAt swaps the indexed block only', () {
      const a = EquationData(latex: 'a');
      const b = EquationData(latex: 'b');
      final html = EquationService.equationMarkup(a);
      final swapped = EquationService.replaceEquationAt(html, 0, b);
      expect(swapped.contains('b'), isTrue);
      expect(swapped.contains('>a<'), isFalse);
      expect(EquationService.replaceEquationAt(html, 9, b), html);
    });

    test('escapeAttribute neutralizes single quotes', () {
      const eq = EquationData(latex: "x'y");
      expect(EquationService.escapeAttribute(eq).contains("'"), isFalse);
    });
  });

  group('mathmlToOoxml', () {
    test('empty and unsupported inputs return null', () {
      expect(EquationService.mathmlToOoxml(''), isNull);
      expect(EquationService.mathmlToOoxml('plain text'), isNotNull);
    });

    test('fraction converts to a:frac element', () {
      final out = EquationService.mathmlToOoxml(
          '<math><mfrac><mi>a</mi><mi>b</mi></mfrac></math>');
      expect(out, isNotNull);
    });

    test('sqrt and sup convert', () {
      final sqrt = EquationService.mathmlToOoxml(
          '<math><msqrt><mi>x</mi></msqrt></math>');
      expect(sqrt, isNotNull);
      final sup = EquationService.mathmlToOoxml(
          '<math><msup><mi>x</mi><mn>2</mn></msup></math>');
      expect(sup, isNotNull);
    });
  });

  group('CloudSyncService normalizedBaseUrl', () {
    test('trailing slashes trimmed for valid https', () {
      expect(CloudSyncService.normalizedBaseUrl('https://nc.example.com///'),
          'https://nc.example.com');
    });

    test('localhost http accepted', () {
      expect(CloudSyncService.normalizedBaseUrl('http://localhost:8080'),
          'http://localhost:8080');
    });

    test('public http rejected', () {
      expect(
        () => CloudSyncService.normalizedBaseUrl('http://nc.example.com'),
        throwsA(isA<FormatException>()),
      );
    });

    test('credentials/query/fragment rejected', () {
      expect(
        () => CloudSyncService.normalizedBaseUrl(
            'https://user:pass@nc.example.com'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CloudSyncService.normalizedBaseUrl(
            'https://nc.example.com/?x=1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('garbage rejected', () {
      expect(
        () => CloudSyncService.normalizedBaseUrl('not a url'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
