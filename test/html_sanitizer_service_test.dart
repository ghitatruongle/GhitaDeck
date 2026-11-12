import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/services/html_sanitizer_service.dart';

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

    test('removes legacy executable containers and unsafe srcset candidates',
        () {
      final result = HtmlSanitizerService.sanitize(
        '<applet code="Evil.class"></applet>'
        '<frameset><frame src="x"></frame></frameset>'
        '<img srcset="https://safe.example/a.png 1x, //evil.example/b.png 2x, '
        'javascript:alert(1) 3x" src="https://safe.example/c.png">',
      );
      final lower = result.html.toLowerCase();
      expect(lower, isNot(contains('<applet')));
      expect(lower, isNot(contains('<frame')));
      expect(lower, isNot(contains('evil.example')));
      expect(lower, isNot(contains('srcset')));
      expect(lower, contains('https://safe.example/c.png'));
    });

    test('strips protocol-relative and ftp resource urls and svg data links',
        () {
      final result = HtmlSanitizerService.sanitize(
        '<img src="//evil.example/beacon.png" lowsrc="//evil.example/l.png">'
        '<video src="ftp://evil.example/x.mp4"></video>'
        '<a href="data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=">link</a>',
      );
      final lower = result.html.toLowerCase();
      expect(lower, isNot(contains('evil.example')));
      expect(lower, isNot(contains('ftp:')));
      expect(lower, isNot(contains('data:image/svg+xml')));
      expect(lower, contains('link'));
    });

    test('keeps https image sources for user-initiated export prefetch', () {
      final result = HtmlSanitizerService
          .sanitize('<img src="https://example.com/pic.png">');
      expect(result.html, contains('https://example.com/pic.png'));
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
