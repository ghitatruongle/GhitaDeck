import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/html_sanitizer_service.dart';

void main() {
  group('HtmlSanitizerService', () {
    test('removes executable tags, handlers and unsafe URLs', () {
      const input = '''
        <h1 onclick="alert(1)">Safe title</h1>
        <script>alert(1)</script>
        <a href="javascript:alert(1)">link</a>
        <img src="data:text/html,<script>alert(1)</script>">
      ''';
      final result = HtmlSanitizerService.sanitize(input);
      expect(result.html, isNot(contains('<script')));
      expect(result.html, isNot(contains('onclick')));
      expect(result.html, isNot(contains('javascript:')));
      expect(result.warnings, isNotEmpty);
    });

    test('counts text without charging embedded base64 media', () {
      final media = 'data:image/png;base64,${List.filled(200000, 'A').join()}';
      expect(
        HtmlSanitizerService.textContentLength('<img src="$media"><p>ok</p>'),
        lessThan(100000),
      );
      expect(HtmlSanitizerService.validate('<p>ok</p>'), isNull);
    });

    test('rejects empty or overlong text content', () {
      expect(HtmlSanitizerService.validate(''), isNotNull);
      expect(HtmlSanitizerService.validate('<script>blocked</script>'), isNotNull);
      expect(
        HtmlSanitizerService.validate(
          '<p>${List.filled(100001, 'x').join()}</p>',
        ),
        contains('too long'),
      );
    });
  });
}
