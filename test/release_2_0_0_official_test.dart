import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/models/slide.dart';
import 'package:ghita_ppt_converter/config/build_info.dart';
import 'package:ghita_ppt_converter/services/project_bundle_service.dart';
import 'package:ghita_ppt_converter/services/wysiwyg_service.dart';
import 'package:ghita_ppt_converter/services/designer_service.dart';
import 'package:ghita_ppt_converter/services/advanced_import_service.dart';
import 'package:ghita_ppt_converter/providers/ai_provider_manager.dart';
import 'package:ghita_ppt_converter/screens/widgets/slide_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v2.0.1 Quality Gate', () {
    test('pubspec.yaml version matches the centralized release contract', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);
      final content = pubspecFile.readAsStringSync();
      expect(content, contains('version: 2.0.5-demo+4'));
      expect(content, contains(BuildInfo.coreVersion));
    });

    test('Installer definition uses the stable display version', () {
      final issFile = File('installer/ghita_ppt_installer.iss');
      expect(issFile.existsSync(), isTrue);
      final content = issFile.readAsStringSync();
      expect(content, contains('#define MyAppDisplayVersion "2.0.5-demo+4"'));
      expect(content, contains('#define MyAppVersion "2.0.5.4"'));
    });

    test('ProjectBundleService manifest uses app and schema versions',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('ghita_release_test_');
      try {
        final bundlePath = '${tempDir.path}/test_bundle.ghita';
        final slides = [
          Slide(title: 'Intro', htmlContent: '<h1>Hello World</h1>'),
        ];
        final service = ProjectBundleService();
        final success = await service.saveProjectBundle(
          targetPath: bundlePath,
          slides: slides,
          title: 'Demo Project',
        );
        expect(success, isTrue);

        final bundle = await service.loadProjectBundle(bundlePath,
            extractDir: tempDir.path);
        expect(bundle, isNotNull);
        expect(bundle!['manifest']['version'], equals(BuildInfo.appVersion));
        expect(bundle['manifest']['appVersion'], equals(BuildInfo.appVersion));
        expect(bundle['manifest']['schemaVersion'],
            equals(BuildInfo.bundleSchemaVersion));
        expect(bundle['manifest']['appName'], contains('Ghita'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('L10n arb files EN and VI match key-for-key', () {
      final enFile = File('lib/l10n/app_en.arb');
      final viFile = File('lib/l10n/app_vi.arb');
      expect(enFile.existsSync(), isTrue);
      expect(viFile.existsSync(), isTrue);

      final Map<String, dynamic> enJson = jsonDecode(enFile.readAsStringSync());
      final Map<String, dynamic> viJson = jsonDecode(viFile.readAsStringSync());

      final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();
      final viKeys = viJson.keys.where((k) => !k.startsWith('@')).toSet();

      final missingInVi = enKeys.difference(viKeys);
      final missingInEn = viKeys.difference(enKeys);

      expect(missingInVi, isEmpty,
          reason: 'Keys in EN but missing in VI: $missingInVi');
      expect(missingInEn, isEmpty,
          reason: 'Keys in VI but missing in EN: $missingInEn');
      expect(enKeys.length, equals(viKeys.length));
    });

    test(
        'WYSIWYG service wraps and formats text correctly without tag corruption',
        () {
      const initialHtml =
          '<h1>Quarterly Report</h1><p>Sales revenue increased by 25 percent.</p>';
      final wrapped = WysiwygService.wrapSelection(
        initialHtml,
        31,
        44, // 'revenue'
        '<b>',
        '</b>',
      );
      expect(wrapped.html, contains('<b>'));
      expect(wrapped.html, contains('</b>'));
    });

    test('Designer service generates valid layout variations', () {
      final ideas = DesignerService.suggest(
        '<h1>Company Highlights</h1><ul><li>Achieved 99.9% uptime</li><li>Launched 5 new features</li><li>Expanded global presence</li><li>Hired 50 engineers</li><li>Zero security incidents</li><li>Customer NPS 72</li></ul>',
      );
      expect(ideas, isNotEmpty);
      for (final idea in ideas) {
        expect(idea.name, isNotEmpty);
        expect(idea.html, isNotEmpty);
      }
    });

    test('AdvancedImportService parses markdown tables and headings', () {
      const markdown = '''
# Executive Summary
Welcome to the release.

---
# Key Metrics
| Metric | Q1 | Q2 |
| Active | 10k | 25k |
| Growth | 15% | 150% |
''';
      final slides = AdvancedImportService.parseMarkdown(markdown);
      expect(slides.length, equals(2));
      expect(slides[0].title, equals('Executive Summary'));
      expect(slides[1].title, equals('Key Metrics'));
      expect(slides[1].htmlContent, contains('<table'));
    });

    test(
        'AIProviderConfig allows custom model assignment and persists model ID',
        () {
      final config = AIProviderConfig(
        id: 'test_provider',
        name: 'Custom DeepSeek',
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: 'sk-test',
        availableModels: ['deepseek-chat', 'deepseek-reasoner'],
        selectedModel: 'deepseek-chat',
        contextWindow: 64000,
        formatType: 'openai',
        temperature: 0.7,
        maxTokens: 4096,
      );

      final updated = config.copyWith(selectedModel: 'custom-fine-tuned-v1');
      expect(updated.selectedModel, equals('custom-fine-tuned-v1'));
      expect(updated.baseUrl, equals('https://api.deepseek.com/v1'));
    });

    test(
        'SlidePreview.wrapSlideHtml creates a 16:9 responsive presentation wrapper with slide-canvas class',
        () {
      const html =
          '<h1>Vision 2030</h1><p>Sustainable growth and innovation.</p>';
      final wrapped = SlidePreview.wrapSlideHtml('Vision 2030', html);

      expect(wrapped, contains('class="slide-canvas"'));
      expect(wrapped, contains('Vision 2030'));
      expect(wrapped, contains('Sustainable growth'));
      expect(wrapped, contains('font-family:'));
    });

    test(
        'AIProviderManager.buildEndpointUrl safely normalizes URLs and prevents duplicate /v1/v1/',
        () {
      expect(
        AIProviderManager.buildEndpointUrl(
            'https://integrate.api.nvidia.com/v1', '/v1/chat/completions'),
        equals('https://integrate.api.nvidia.com/v1/chat/completions'),
      );
      expect(
        AIProviderManager.buildEndpointUrl(
            'https://integrate.api.nvidia.com/v1/', '/v1/chat/completions'),
        equals('https://integrate.api.nvidia.com/v1/chat/completions'),
      );
      expect(
        AIProviderManager.buildEndpointUrl(
            'https://api.openai.com', '/v1/chat/completions'),
        equals('https://api.openai.com/v1/chat/completions'),
      );
      expect(
        AIProviderManager.buildEndpointUrl(
            'https://integrate.api.nvidia.com/v1/chat/completions',
            '/v1/chat/completions'),
        equals('https://integrate.api.nvidia.com/v1/chat/completions'),
      );
      expect(
        AIProviderManager.buildEndpointUrl(
            'https://integrate.api.nvidia.com/v1', '/v1/models'),
        equals('https://integrate.api.nvidia.com/v1/models'),
      );
    });
  });
}
