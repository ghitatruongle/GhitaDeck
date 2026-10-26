import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_deck/models/slide_template.dart';
import 'package:ghita_deck/providers/presentation_state.dart';
import 'package:ghita_deck/providers/ai_provider_manager.dart';

void main() {
  group('SlideTemplate model', () {
    test('creates with required fields', () {
      final template = SlideTemplate(
        id: 'test',
        name: 'Test Template',
        description: 'A test template',
        htmlContent: '<h1>Hello</h1>',
        recommendedEffect: SlideEffect.fade,
        icon: Icons.slideshow,
        accentColor: const Color(0xFF2196F3),
      );

      expect(template.id, 'test');
      expect(template.name, 'Test Template');
      expect(template.description, 'A test template');
      expect(template.htmlContent, '<h1>Hello</h1>');
      expect(template.recommendedEffect, SlideEffect.fade);
    });

    test('converts to map and back', () {
      final template = SlideTemplate(
        id: 'biz',
        name: 'Business',
        description: 'Professional blue',
        htmlContent: '<h1>Title</h1><p>Content</p>',
        recommendedEffect: SlideEffect.fade,
        icon: Icons.business,
        accentColor: const Color(0xFF1a3a5c),
      );

      final map = template.toMap();
      final restored = SlideTemplate.fromMap(map);

      expect(restored.id, template.id);
      expect(restored.name, template.name);
      expect(restored.htmlContent, template.htmlContent);
      expect(restored.recommendedEffect, SlideEffect.fade);
    });

    test('fromMap handles missing recommendedEffect gracefully', () {
      final map = <String, dynamic>{
        'id': 'minimal',
        'name': 'Minimal',
        'description': 'Clean design',
        'htmlContent': '<h1>Hi</h1>',
        'icon': 983173,
        'accentColor': 4287669583,
      };
      final template = SlideTemplate.fromMap(map);
      expect(template.recommendedEffect, SlideEffect.none);
    });
  });

  group('AIProviderConfig multi-model', () {
    test('has valid models list', () {
      final provider = AIProviderConfig(
        id: 'openai_test',
        name: 'OpenAI Test',
        baseUrl: 'https://api.openai.com',
        apiKey: '',
        availableModels: ['gpt-4o', 'gpt-4o-mini', 'gpt-3.5-turbo'],
        selectedModel: 'gpt-4o',
        contextWindow: 128000,
        formatType: 'openai',
      );

      expect(provider.availableModels.length, 3);
      expect(provider.selectedModel, 'gpt-4o');
      expect(provider.isValid, isTrue);
    });

    test('copyWith updates selectedModel', () {
      final provider = AIProviderConfig(
        id: 'test',
        name: 'Test',
        baseUrl: 'https://api.test.com',
        apiKey: 'key123',
        availableModels: ['model-a', 'model-b'],
        selectedModel: 'model-a',
        contextWindow: 4096,
      );

      final updated = provider.copyWith(selectedModel: 'model-b');
      expect(updated.selectedModel, 'model-b');
      expect(updated.availableModels, provider.availableModels);
    });

    test('isValid returns false when selectedModel is empty', () {
      final provider = AIProviderConfig(
        id: 'test',
        name: 'Test',
        baseUrl: 'https://api.test.com',
        apiKey: 'key',
        availableModels: ['model-a'],
        selectedModel: '',
        contextWindow: 4096,
      );

      expect(provider.isValid, isFalse);
    });

    test('fromMap backward compatibility with old single model field', () {
      final map = <String, dynamic>{
        'id': 'legacy',
        'name': 'Legacy Provider',
        'baseUrl': 'https://api.legacy.com',
        'model': 'old-model-v1',
        'contextWindow': 8192,
        'formatType': 'openai',
      };
      final provider = AIProviderConfig.fromMap(map);
      expect(provider.availableModels, ['old-model-v1']);
      expect(provider.selectedModel, 'old-model-v1');
    });

    test('fromMap with availableModels list', () {
      final map = <String, dynamic>{
        'id': 'modern',
        'name': 'Modern Provider',
        'baseUrl': 'https://api.modern.com',
        'availableModels': ['m1', 'm2', 'm3'],
        'selectedModel': 'm2',
        'contextWindow': 16384,
        'formatType': 'custom',
      };
      final provider = AIProviderConfig.fromMap(map);
      expect(provider.availableModels.length, 3);
      expect(provider.selectedModel, 'm2');
      expect(provider.formatType, 'custom');
    });
  });
}
