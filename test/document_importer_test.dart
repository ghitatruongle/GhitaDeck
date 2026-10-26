import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/services/document_importer_service.dart';

void main() {
  group('DocumentImporterService Tests', () {
    test('parseMarkdownToSlides chunks headings and bullet lists', () {
      final importer = DocumentImporterService();
      const md = '''
# Slide Title 1
- Point A
- Point B

## Slide Title 2
- Point C
''';

      final slides = importer.parseMarkdownToSlides(md);
      expect(slides.length, 2);
      expect(slides[0].title, 'Slide Title 1');
      expect(slides[0].htmlContent, contains('<h1>Slide Title 1</h1>'));
      expect(slides[0].htmlContent, contains('<li>Point A</li>'));
      expect(slides[1].title, 'Slide Title 2');
      expect(slides[1].htmlContent, contains('<h1>Slide Title 2</h1>'));
    });
  });
}
