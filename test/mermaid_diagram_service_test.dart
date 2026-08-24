// T02 (v2.0.1-beta.2) — MermaidDiagramService tests (phases 3–4).
//
// The service renders diagram *blocks* (flowchart / mindmap) as sanitized
// HTML — it does not parse Mermaid syntax, so the hostile-input contract is:
// user text with quotes, angle brackets and ampersands must come out escaped,
// never as live markup.
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/services/mermaid_diagram_service.dart';

void main() {
  final service = MermaidDiagramService();

  group('generateFlowchartHtml', () {
    test('empty step list produces no block at all', () {
      expect(service.generateFlowchartHtml(const []), '');
    });

    test('numbers each step and wires arrows between neighbours only',
        () {
      final html = service.generateFlowchartHtml(
          ['Thu thập yêu cầu', 'Phân tích', 'Triển khai']);

      expect(html, contains('diagram-flowchart'));
      expect(html, contains('1. Thu thập yêu cầu'));
      expect(html, contains('2. Phân tích'));
      expect(html, contains('3. Triển khai'));
      expect('➔'.allMatches(html), hasLength(2),
          reason: 'n steps are joined by exactly n−1 arrows');
    });

    test('escapes quotes, angle brackets and ampersands in step text', () {
      final html = service.generateFlowchartHtml(
          ['<script>alert("x")</script>', 'A & B']);

      expect(html, contains('&lt;script&gt;'));
      expect(html, isNot(contains('<script>')),
          reason: 'raw script tags must never reach the output');
      expect(html, contains('A &amp; B'));
      expect(html, contains('&quot;x&quot;'),
          reason: 'attribute-breaking quotes get escaped too');
    });
  });

  group('generateMindmapHtml', () {
    test('renders the central topic and every subtopic card', () {
      final html =
          service.generateMindmapHtml('Kế hoạch 2026', ['Ngân sách', 'Nhân sự']);

      expect(html, contains('diagram-mindmap'));
      expect(html, contains('Kế hoạch 2026'));
      expect(html, contains('Ngân sách'));
      expect(html, contains('Nhân sự'));
    });

    test('empty subtopic list still emits the framed block', () {
      final html = service.generateMindmapHtml('Chủ đề', const []);
      expect(html, contains('diagram-mindmap'));
      expect(html, contains('Chủ đề'));
    });

    test('escapes hostile text in both the topic and the subtopics', () {
      final html = service.generateMindmapHtml(
          '<img src=x onerror=alert(1)>', ['Q&A "session"']);

      expect(html, isNot(contains('<img')));
      expect(html, contains('&lt;img'));
      expect(html, contains('Q&amp;A &quot;session&quot;'));
    });
  });

  group('theme accent (T05)', () {
    test('accent colours the flowchart chips and mindmap cards', () {
      final flow = service.generateFlowchartHtml(['A', 'B'],
          accentColor: '#8B5CF6');
      expect(flow, contains('background: #8B5CF6'));

      final mind = service.generateMindmapHtml('T', ['x'],
          accentColor: '#F59E0B');
      expect(mind, contains('background: #F59E0B'));
    });

    test('defaults stay stable when no accent is given', () {
      expect(service.generateFlowchartHtml(['A']),
          contains('background: #3B82F6'));
      expect(service.generateMindmapHtml('T', const ['a']),
          contains('background: #10B981'));
    });

    test('a malformed accent falls back instead of injecting markup', () {
      final flow = service.generateFlowchartHtml(['A'],
          accentColor: '"><script>');
      expect(flow, contains('background: #3B82F6'));
      expect(flow, isNot(contains('<script>')));
    });
  });
}
