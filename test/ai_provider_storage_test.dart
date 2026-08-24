// T04 (v2.0.1-beta.2) — provider persistence & secure-storage round-trip
// (phase 4).
//
// This file NEEDS the Flutter binding (flutter_secure_storage + shared_prefs
// platform channels) and deliberately performs no real HTTP, so the binding's
// _MockHttpOverrides is harmless here.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghita_ppt_converter/providers/ai_provider_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStore = <String, String>{};

  setUp(() async {
    secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = call.arguments as Map?;
        final key = args?['key'] as String?;
        switch (call.method) {
          case 'write':
          case 'writeAll':
            if (key != null) {
              secureStore[key] = args?['value'] as String? ?? '';
            }
            return null;
          case 'read':
            return key != null ? secureStore[key] : null;
          case 'containsKey':
            return key != null && secureStore.containsKey(key);
          case 'delete':
            secureStore.remove(key);
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  test('a saved API key survives a full reload through secure storage',
      () async {
    final first = AIProviderManager();
    await first.loadProviders();
    first.selectProvider(first.providers.first);
    expect(first.providers.first.requiresApiKey, isTrue);

    await first.saveApiKeyForSelected('sk-secure-123');
    expect(secureStore.values, contains('sk-secure-123'),
        reason: 'the key must be persisted outside shared prefs');
    expect(first.providers.first.apiKey, 'sk-secure-123');
    first.dispose();

    // Fresh process simulation: a brand-new manager hydrates from storage.
    final second = AIProviderManager();
    await second.loadProviders();
    expect(second.providers.first.apiKey, 'sk-secure-123');
    second.dispose();
  });

  test('system prompt persists and reloads', () async {
    final first = AIProviderManager();
    await first.loadProviders();
    const custom = 'You are a Vietnamese slide generator.';
    first.updateSystemPrompt(custom);
    expect(first.systemPrompt, custom);
    first.dispose();

    final second = AIProviderManager();
    await second.loadProviders();
    expect(second.systemPrompt, custom);
    second.dispose();
  });

  test('provider CRUD notifies listeners and persists the selection',
      () async {
    final manager = AIProviderManager();
    await manager.loadProviders();

    var notifications = 0;
    manager.addListener(() => notifications++);

    final custom = AIProviderConfig(
      id: 'custom-1',
      name: 'My relay',
      baseUrl: 'https://relay.example.com',
      apiKey: '',
      availableModels: const ['m1'],
      selectedModel: 'm1',
      contextWindow: 4096,
    );
    manager.addProvider(custom);
    expect(manager.providers.any((p) => p.id == 'custom-1'), isTrue);

    manager.selectProvider(custom);
    expect(notifications, greaterThanOrEqualTo(2));

    manager.removeProvider('custom-1');
    expect(manager.providers.any((p) => p.id == 'custom-1'), isFalse);
    manager.dispose();
  });
}
