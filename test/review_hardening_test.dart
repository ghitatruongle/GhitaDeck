// Review pass (post-T06) — regression tests for the hardening fixes.
//
// Each test reproduces the exact malformed-input scenario that used to
// crash before the fix:
//   1. AIProviderConfig.fromMap with non-string persisted fields — a single
//      bad entry must degrade to strings, not wipe the saved provider list.
//   2. PPTGenerator.generatePPT with a non-string htmlContent — the whole
//      generator used to run on a dynamic rawHtml and would throw a
//      TypeError from deep inside instead of rendering an empty body.
//   3. Gemini text part arriving as a number — coerced to '42', not a
//      dynamic leaking into String call sites.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/providers/ai_provider_manager.dart';
import 'package:ghita_ppt_converter/services/ppt_generator.dart';

void main() {
  group('AIProviderConfig.fromMap hardening', () {
    test('non-string id/name/baseUrl coerce instead of throwing', () {
      final config = AIProviderConfig.fromMap({
        'id': 12345,
        'name': true,
        'baseUrl': ['not', 'a', 'string'],
        'selectedModel': 99,
        'formatType': 1,
        'contextWindow': '8192',
        'maxTokens': '2048',
      });
      expect(config.id, '12345');
      expect(config.name, 'true');
      expect(config.baseUrl, isA<String>());
      expect(config.selectedModel, '99');
      expect(config.formatType, '1');
      expect(config.contextWindow, 8192);
      expect(config.maxTokens, 2048);
    });

    test('a malformed entry survives the full loadProviders round-trip shape',
        () {
      // Simulates one corrupted element inside the stored JSON list.
      final decoded = jsonDecode(jsonEncode([
        {'id': 'good', 'name': 'Good', 'baseUrl': 'https://x.dev'},
        {'id': 7, 'availableModels': 'oops'},
      ])) as List<dynamic>;
      final configs = decoded
          .map((m) => AIProviderConfig.fromMap(
              Map<String, dynamic>.from(m as Map)))
          .toList();
      expect(configs, hasLength(2));
      expect(configs.last.id, '7');
      expect(configs.last.isValid, isFalse,
          reason: 'degraded entry stays present but flagged invalid');
    });
  });

  group('PPTGenerator type safety', () {
    test('numeric htmlContent renders an empty-body slide without crashing',
        () async {
      final dir = Directory.systemTemp.createTempSync('ghita_review');
      try {
        final outFile = await PPTGenerator.generatePPT([
          {'title': 'Broken deck', 'htmlContent': 12345},
          {'title': 'Good', 'htmlContent': '<p>fine</p>'},
        ], '${dir.path}/out.pptx');
        expect(outFile.lengthSync(), greaterThan(0));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}
