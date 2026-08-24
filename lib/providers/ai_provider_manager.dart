import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/ai_html_guard.dart';
import '../services/api_key_rotation_service.dart';
import '../services/local_ai_detector_service.dart';
import 'config_service.dart';

// =============================================================================
// AI Provider Configuration
// =============================================================================

class AIProviderConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final List<String> availableModels;
  final String selectedModel;
  final int contextWindow;
  final String formatType; // openai, anthropic, gemini, custom
  final double temperature;
  final int maxTokens;

  // v1.2.0: Enhanced fields (merged from EnhancedAIProviderConfig)
  final ProviderHealthStatus healthStatus;
  final DateTime? lastHealthCheck;

  AIProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.availableModels,
    required this.selectedModel,
    required this.contextWindow,
    this.formatType = 'openai',
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.healthStatus = ProviderHealthStatus.unknown,
    this.lastHealthCheck,
  });

  AIProviderConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    List<String>? availableModels,
    String? selectedModel,
    int? contextWindow,
    String? formatType,
    double? temperature,
    int? maxTokens,
    ProviderHealthStatus? healthStatus,
    DateTime? lastHealthCheck,
  }) {
    return AIProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      availableModels: availableModels ?? this.availableModels,
      selectedModel: selectedModel ?? this.selectedModel,
      contextWindow: contextWindow ?? this.contextWindow,
      formatType: formatType ?? this.formatType,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      healthStatus: healthStatus ?? this.healthStatus,
      lastHealthCheck: lastHealthCheck ?? this.lastHealthCheck,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      // apiKey intentionally excluded from serialization to non-secure storage.
      'availableModels': availableModels,
      'selectedModel': selectedModel,
      'contextWindow': contextWindow,
      'formatType': formatType,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'healthStatus': healthStatus.index,
      'lastHealthCheck': lastHealthCheck?.toIso8601String(),
    };
  }

  factory AIProviderConfig.fromMap(Map<String, dynamic> map) {
    // `is` checks instead of casts: one malformed persisted field (an int
    // id, a String maxTokens…) must degrade to a default instead of throwing
    // a TypeError that wipes the whole saved provider list back to defaults.
    final rawModels = map['availableModels'];
    final modelsList = rawModels is List
        ? rawModels.map((e) => e.toString()).toList()
        : <String>[];
    int? asInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
    double? asDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    return AIProviderConfig(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      baseUrl: map['baseUrl']?.toString() ?? '',
      apiKey: '', // apiKey is loaded separately from secure storage
      availableModels: modelsList.isNotEmpty
          ? modelsList
          : [map['model']?.toString() ?? ''],
      selectedModel: map['selectedModel']?.toString() ??
          (modelsList.isNotEmpty
              ? modelsList.first
              : map['model']?.toString() ?? ''),
      contextWindow: asInt(map['contextWindow']) ?? 4096,
      formatType: map['formatType']?.toString() ?? 'openai',
      temperature: asDouble(map['temperature']) ?? 0.7,
      maxTokens: asInt(map['maxTokens']) ?? 4096,
      healthStatus: _parseHealthStatus(map['healthStatus']),
      lastHealthCheck: map['lastHealthCheck'] != null
          ? DateTime.tryParse(map['lastHealthCheck'].toString())
          : null,
    );
  }

  /// v1.2.0: Safe health status parsing with bounds check.
  static ProviderHealthStatus _parseHealthStatus(dynamic value) {
    final idx = (value as int?) ?? 0;
    if (idx >= 0 && idx < ProviderHealthStatus.values.length) {
      return ProviderHealthStatus.values[idx];
    }
    return ProviderHealthStatus.unknown;
  }

  static AIProviderConfig defaultProvider() {
    return AIProviderConfig(
      id: 'openai_default',
      name: 'OpenAI (GPT-4o / GPT-3.5)',
      baseUrl: 'https://api.openai.com',
      apiKey: '',
      availableModels: ['gpt-4o', 'gpt-4o-mini', 'gpt-3.5-turbo', 'o1-preview'],
      selectedModel: 'gpt-4o',
      contextWindow: 128000,
      formatType: 'openai',
      temperature: 0.7,
      maxTokens: 4096,
    );
  }

  static AIProviderConfig anthropicDefault() {
    return AIProviderConfig(
      id: 'anthropic_default',
      name: 'Anthropic (Claude)',
      baseUrl: 'https://api.anthropic.com',
      apiKey: '',
      availableModels: [
        'claude-3-5-sonnet-20240620',
        'claude-3-opus-20240229',
        'claude-3-haiku-20240307',
      ],
      selectedModel: 'claude-3-5-sonnet-20240620',
      contextWindow: 200000,
      formatType: 'anthropic',
      temperature: 0.7,
      maxTokens: 4096,
    );
  }

  static AIProviderConfig geminiDefault() {
    return AIProviderConfig(
      id: 'gemini_default',
      name: 'Google Gemini',
      baseUrl: 'https://generativelanguage.googleapis.com',
      apiKey: '',
      availableModels: ['gemini-2.5-flash', 'gemini-2.5-pro'],
      selectedModel: 'gemini-2.5-flash',
      contextWindow: 1000000,
      formatType: 'gemini',
      temperature: 0.7,
      maxTokens: 8192,
    );
  }

  static AIProviderConfig ollamaDefault() {
    return AIProviderConfig(
      id: 'ollama_default',
      name: 'Ollama (Local)',
      baseUrl: 'http://localhost:11434/v1',
      apiKey: '',
      availableModels: ['llama3.1', 'mistral', 'qwen2.5'],
      selectedModel: 'llama3.1',
      contextWindow: 32768,
      formatType: 'openai',
      temperature: 0.7,
      maxTokens: 4096,
    );
  }

  static List<AIProviderConfig> allDefaults() {
    return [
      defaultProvider(),
      anthropicDefault(),
      geminiDefault(),
      ollamaDefault(),
    ];
  }

  /// Whether this provider needs an API key (local endpoints don't).
  bool get requiresApiKey {
    final host = Uri.tryParse(baseUrl)?.host ?? '';
    return host != 'localhost' && host != '127.0.0.1' && host != '0.0.0.0';
  }

  /// Validate that this provider has all required non-secret fields.
  bool get isValid => id.isNotEmpty && baseUrl.isNotEmpty && selectedModel.isNotEmpty;

  /// Convenience getter for backward compatibility.
  String get model => selectedModel;
}

// =============================================================================
// Provider Health Status
// =============================================================================

enum ProviderHealthStatus {
  unknown,
  healthy,
  degraded,
  failed;

  String get displayName {
    switch (this) {
      case ProviderHealthStatus.unknown:
        return 'Chưa kiểm tra';
      case ProviderHealthStatus.healthy:
        return 'Hoạt động tốt';
      case ProviderHealthStatus.degraded:
        return 'Chậm / không ổn định';
      case ProviderHealthStatus.failed:
        return 'Không kết nối được';
    }
  }

  String get iconName {
    switch (this) {
      case ProviderHealthStatus.unknown:
        return 'help_outline';
      case ProviderHealthStatus.healthy:
        return 'check_circle';
      case ProviderHealthStatus.degraded:
        return 'warning';
      case ProviderHealthStatus.failed:
        return 'error_outline';
    }
  }
}

// =============================================================================
// Ping Result
// =============================================================================

class PingResult {
  final bool isSuccess;
  final int latencyMs;
  final String? errorMessage;

  const PingResult({
    required this.isSuccess,
    required this.latencyMs,
    this.errorMessage,
  });
}

// =============================================================================
// AI Provider Manager — Unified (merged from EnhancedAIProviderManager)
// =============================================================================

class AIProviderManager with ChangeNotifier {
  List<AIProviderConfig> _providers = [];
  AIProviderConfig? _selectedProvider;
  final ConfigService _configService = ConfigService();
  final APIKeyRotationService _rotationService = APIKeyRotationService();
  final LocalAIDetectorService _localDetector = LocalAIDetectorService();

  // Shared HTTP client for connection pooling (v1.2.0)
  final http.Client _sharedClient = http.Client();

  /// POST through the shared client with a hard deadline so a stalled
  /// provider can never hang generation forever (previously no timeout at
  /// all on any non-streaming call).
  Future<http.Response> _postWithTimeout(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _sharedClient
        .post(url, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));
  }

  // Health monitoring timer (v1.2.0)
  Timer? _healthTimer;
  bool _disposed = false;

  // Custom system prompt for slide generation
  String _systemPrompt =
      'You are an expert in generating presentation HTML slides. '
      'Return ONLY valid HTML fragment (no markdown, no explanation). '
      'Use <h1> for title, <p> for paragraphs, <ul>/<li> for lists. '
      'No external CSS/JS references.';

  String get systemPrompt => _systemPrompt;
  List<AIProviderConfig> get providers => _providers;
  AIProviderConfig? get selectedProvider => _selectedProvider;

  /// Whether the AI should be told the deck's current context (Track 52,
  /// OPT 37). Off by default — privacy by choice.
  bool _useDeckContext = false;
  bool get useDeckContext => _useDeckContext;
  void setUseDeckContext(bool value) {
    if (_useDeckContext == value) return;
    _useDeckContext = value;
    notifyListeners();
  }

  /// Build the deck-context block appended to the system prompt when
  /// [useDeckContext] is on. Pure static so it is unit-testable.
  static const int maxDeckContextCharacters = 20000;

  static String _boundedContext(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= maxDeckContextCharacters) return trimmed;
    return '${trimmed.substring(0, maxDeckContextCharacters)}\n[context truncated]';
  }

  static String buildDeckContextPrompt({
    required String layoutType,
    required String themeSummary,
    required String uiLanguage,
    String? currentSlideSummary,
    String? deckOutline,
  }) {
    final buf = StringBuffer()
      ..writeln('\n--- Deck context (follow it exactly) ---')
      ..writeln('Current slide layout: ${_boundedContext(layoutType)}')
      ..writeln('Theme: ${_boundedContext(themeSummary)}')
      ..writeln('UI language: ${_boundedContext(uiLanguage)}');
    if (currentSlideSummary != null && currentSlideSummary.trim().isNotEmpty) {
      buf.writeln('Current slide content: ${_boundedContext(currentSlideSummary)}');
    }
    if (deckOutline != null && deckOutline.trim().isNotEmpty) {
      buf.writeln('Deck outline: ${_boundedContext(deckOutline)}');
    }
    buf.writeln(
        'Style your generated HTML to match this theme (colors/fonts/classes) '
        'and keep it consistent with the deck.');
    return buf.toString();
  }

  @override
  void dispose() {
    _disposed = true;
    _healthTimer?.cancel();
    _sharedClient.close();
    super.dispose();
  }

  // ===========================================================================
  // Provider CRUD & Persistence
  // ===========================================================================

  Future<void> loadProviders() async {
    try {
      _providers = await _configService.loadProviders();
      if (_providers.isEmpty) {
        _providers = [AIProviderConfig.defaultProvider()];
      }
      // Re-inject apiKey from secure storage for each provider.
      for (var i = 0; i < _providers.length; i++) {
        final p = _providers[i];
        final storedKey = await _configService.loadApiKey(p.id);
        if (storedKey != null && storedKey.isNotEmpty) {
          _providers[i] = p.copyWith(apiKey: storedKey);
        }
      }

      final savedId = await _configService.getSelectedProviderId();
      _selectedProvider = _providers.firstWhere(
        (p) => p.id == savedId,
        orElse: () => _providers.first,
      );

      // Load custom system prompt
      final savedPrompt = await _configService.loadSystemPrompt();
      if (savedPrompt != null && savedPrompt.isNotEmpty) {
        _systemPrompt = savedPrompt;
      }

      // Start health monitoring (v1.2.0)
      _startHealthMonitoring();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading providers: $e');
      _providers = [AIProviderConfig.defaultProvider()];
      _selectedProvider = _providers.first;
      notifyListeners();
    }
  }

  void updateSystemPrompt(String prompt) {
    _systemPrompt = prompt;
    unawaited(_configService.saveSystemPrompt(prompt));
    notifyListeners();
  }

  void selectProvider(AIProviderConfig provider) {
    if (_selectedProvider != provider) {
      _selectedProvider = provider;
      unawaited(_configService.saveSelectedProvider(provider.id));
      notifyListeners();
    }
  }

  void addProvider(AIProviderConfig newProvider) {
    _providers.add(newProvider);
    if (_selectedProvider == null) {
      _selectedProvider = newProvider;
      unawaited(_configService.saveSelectedProvider(newProvider.id));
    }
    unawaited(_configService.saveProviders(_providers));
    if (newProvider.apiKey.isNotEmpty) {
      unawaited(_configService.saveApiKey(newProvider.id, newProvider.apiKey));
    }
    notifyListeners();
  }

  void updateProvider(AIProviderConfig updatedProvider) {
    if (_disposed) return; // v1.2.0: guard against post-dispose notify
    final index = _providers.indexWhere((p) => p.id == updatedProvider.id);
    if (index != -1) {
      _providers[index] = updatedProvider;
      if (_selectedProvider?.id == updatedProvider.id) {
        _selectedProvider = updatedProvider;
      }
      unawaited(_configService.saveProviders(_providers));
      if (updatedProvider.apiKey.isNotEmpty) {
        unawaited(_configService.saveApiKey(updatedProvider.id, updatedProvider.apiKey));
      }
      notifyListeners();
    }
  }

  void removeProvider(String providerId) {
    _providers.removeWhere((p) => p.id == providerId);
    if (_selectedProvider?.id == providerId) {
      _selectedProvider = _providers.isNotEmpty ? _providers.first : null;
    }
    unawaited(_configService.saveSelectedProvider(_selectedProvider?.id));
    unawaited(_configService.saveProviders(_providers));
    unawaited(_configService.saveApiKey(providerId, ''));
    notifyListeners();
  }

  /// Save (encrypt) the API key to secure storage for the selected provider.
  Future<void> saveApiKeyForSelected(String apiKey) async {
    final provider = _selectedProvider;
    if (provider == null) throw Exception('No provider selected');
    final idx = _providers.indexWhere((p) => p.id == provider.id);
    if (idx == -1) throw Exception('Provider not found in list');
    await _configService.saveApiKey(provider.id, apiKey);
    _providers[idx] = provider.copyWith(apiKey: apiKey);
    notifyListeners();
  }

  // ===========================================================================
  // Health Monitoring (v1.2.0 — from EnhancedAIProviderManager)
  // ===========================================================================

  /// OPT 29: many providers → poll less often (10 min), few → 5 min.
  static Duration _healthInterval(int providerCount) =>
      providerCount >= 4
          ? const Duration(minutes: 10)
          : const Duration(minutes: 5);

  void _startHealthMonitoring() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(
      _healthInterval(_providers.length),
      (timer) {
        if (_disposed) {
          timer.cancel();
          return;
        }
        _performHealthChecks();
      },
    );
  }

  Future<void> _performHealthChecks() async {
    // Snapshot + parallel: a sequential loop would take N×timeout seconds
    // with many providers; Future.wait bounds it to one timeout. Snapshot
    // also avoids ConcurrentModificationError when a check removes a
    // provider mid-flight.
    final providers = List.of(_providers);
    if (providers.isEmpty) return; // P3: nothing to ping, no sockets opened.
    await Future.wait(providers.map((p) => testProviderPing(p)));
  }

  /// Test a provider's connection and update its health status.
  Future<PingResult> testProviderPing(AIProviderConfig config) async {
    final stopwatch = Stopwatch()..start();
    try {
      final isValid = await _rotationService.testAPIKey(
        config.baseUrl,
        config.apiKey,
        config.id,
      );
      stopwatch.stop();

      final status = isValid ? ProviderHealthStatus.healthy : ProviderHealthStatus.failed;
      final updated = config.copyWith(
        healthStatus: status,
        lastHealthCheck: DateTime.now(),
      );
      updateProvider(updated);

      return PingResult(
        isSuccess: isValid,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      final updated = config.copyWith(
        healthStatus: ProviderHealthStatus.failed,
        lastHealthCheck: DateTime.now(),
      );
      updateProvider(updated);

      return PingResult(
        isSuccess: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }

  List<LocalAIServiceInfo>? _scanCache;
  DateTime? _scanCacheAt;

  /// OPT 28: cached local-AI scan — repeated calls within 5 minutes reuse
  /// the previous result instead of re-probing localhost ports.
  Future<List<LocalAIServiceInfo>> scanLocalAI({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _scanCache != null &&
        _scanCacheAt != null &&
        now.difference(_scanCacheAt!) < const Duration(minutes: 5)) {
      return _scanCache!;
    }
    final result = await _localDetector.scanLocalAIServices();
    _scanCache = result;
    _scanCacheAt = now;
    return result;
  }

  // ===========================================================================
  // Model Fetching
  // ===========================================================================

  Future<List<String>> fetchAvailableModels(AIProviderConfig config) async {
    try {
      final List<String> fetchedModels = [];
      final base = config.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

      if (config.formatType == 'gemini') {
        // Percent-encode the key via queryParameters
        final endpoint = buildEndpointUrl(config.baseUrl, '/v1beta/models');
        final url = Uri.parse(endpoint)
            .replace(queryParameters: {'key': config.apiKey});
        final res = await _sharedClient.get(url).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['models'] is List) {
            for (final m in data['models']) {
              final name = (m['name'] ?? '').toString().replaceAll('models/', '');
              if (name.isNotEmpty &&
                  !name.contains('embedding') &&
                  !name.contains('aqa') &&
                  !name.contains('imagen')) {
                fetchedModels.add(name);
              }
            }
          }
        }
      } else if (config.formatType == 'anthropic') {
        final endpoint = buildEndpointUrl(config.baseUrl, '/v1/models');
        final url = Uri.parse(endpoint);
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'x-api-key': config.apiKey,
          'anthropic-version': '2023-06-01',
        };
        final res = await _sharedClient.get(url, headers: headers).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['data'] is List) {
            for (final m in data['data']) {
              final id = (m['id'] ?? '').toString();
              if (id.isNotEmpty) fetchedModels.add(id);
            }
          }
        }
      } else {
        // OpenAI / DeepSeek / OpenRouter / Ollama / Groq / Together / NVIDIA
        final endpoint = buildEndpointUrl(config.baseUrl, '/v1/models');
        final url = Uri.parse(endpoint);
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (config.apiKey.isNotEmpty) {
          headers['Authorization'] = 'Bearer ${config.apiKey}';
        }
        if (base.contains('openrouter.ai')) {
          headers['HTTP-Referer'] = 'https://ghitappt.com';
          headers['X-Title'] = 'GhitaPPT';
        }

        try {
          final res = await _sharedClient.get(url, headers: headers).timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data['data'] is List) {
              for (final m in data['data']) {
                final id = (m['id'] ?? '').toString();
                if (id.isNotEmpty) fetchedModels.add(id);
              }
            } else if (data['models'] is List) {
              for (final m in data['models']) {
                final id = (m['name'] ?? m['id'] ?? m['model'] ?? '').toString();
                if (id.isNotEmpty) fetchedModels.add(id);
              }
            }
          }
        } catch (_) {}

        // Fallback for native Ollama /api/tags if /v1/models returned nothing
        if (fetchedModels.isEmpty &&
            (base.contains('11434') ||
                config.formatType == 'ollama' ||
                config.name.toLowerCase().contains('ollama'))) {
          try {
            final ollamaTagsUrl =
                Uri.parse('${base.replaceAll(RegExp(r'/v1$'), '')}/api/tags');
            final tagsRes = await _sharedClient
                .get(ollamaTagsUrl)
                .timeout(const Duration(seconds: 5));
            if (tagsRes.statusCode == 200) {
              final data = jsonDecode(tagsRes.body);
              if (data['models'] is List) {
                for (final m in data['models']) {
                  final name = (m['name'] ?? m['model'] ?? '').toString();
                  if (name.isNotEmpty) fetchedModels.add(name);
                }
              }
            }
          } catch (_) {}
        }
      }

      if (fetchedModels.isNotEmpty) {
        final uniqueModels = fetchedModels.toSet().toList();
        final updated = config.copyWith(
          availableModels: uniqueModels,
          selectedModel: uniqueModels.contains(config.selectedModel)
              ? config.selectedModel
              : uniqueModels.first,
          healthStatus: ProviderHealthStatus.healthy,
          lastHealthCheck: DateTime.now(),
        );
        updateProvider(updated);
        return uniqueModels;
      }
    } catch (e) {
      debugPrint('Error fetching models: $e');
    }
    return config.availableModels;
  }

  // ===========================================================================
  // Error Handling & Validation
  // ===========================================================================

  static String _friendlyErrorMessage(int statusCode, String body) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Check your prompt and try again.';
      case 401:
        return 'API key invalid or expired. Please check your settings.';
      case 403:
        return 'Access denied. Check your API key permissions.';
      case 404:
        return 'API endpoint not found. Check the Base URL in settings.';
      case 429:
        return 'Rate limit exceeded. Please wait a moment and try again.';
      case 500:
        return 'Server error. The AI service may be temporarily unavailable.';
      case 502:
        return 'Bad gateway. The service is temporarily unavailable.';
      case 503:
        return 'Service temporarily overloaded. Please try again later.';
      default:
        if (statusCode >= 500) {
          return 'Server error ($statusCode). Please try again later.';
        }
        return 'API Error $statusCode: ${body.length > 100 ? '${body.substring(0, 100)}...' : body}';
    }
  }

  static String? validateProvider(AIProviderConfig provider) {
    if (provider.id.trim().isEmpty) return 'Provider ID cannot be empty.';
    if (provider.name.trim().isEmpty) return 'Provider name cannot be empty.';
    if (provider.baseUrl.trim().isEmpty) return 'Base URL cannot be empty.';
    final uri = Uri.tryParse(provider.baseUrl.trim());
    if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
      return 'Base URL is not a valid URL (must start with http:// or https://).';
    }
    if (provider.availableModels.isEmpty) return 'Provider must have at least 1 model configured.';
    if (provider.selectedModel.isEmpty) return 'No model selected. Please choose an active model.';
    if (provider.contextWindow <= 0) return 'Context window must be a positive number.';
    if (provider.temperature < 0 || provider.temperature > 2) return 'Temperature must be between 0.0 and 2.0.';
    if (provider.maxTokens <= 0) return 'Max tokens must be a positive number.';
    return null;
  }

  // ===========================================================================
  // Provider Readiness Check
  // ===========================================================================

  AIProviderConfig _ensureReady() {
    final provider = _selectedProvider;
    if (provider == null) {
      throw Exception('No provider selected. Please configure a provider in settings.');
    }
    if (provider.apiKey.isEmpty && provider.requiresApiKey) {
      throw Exception('API key not set for "${provider.name}". Enter it in Provider Settings.');
    }
    if (!provider.isValid) {
      throw Exception('Provider "${provider.name}" is not fully configured.');
    }
    return provider;
  }

  // ===========================================================================
  // Single Slide Generation
  // ===========================================================================

  Future<String> generateHtmlFromPrompt(String prompt) async {
    final provider = _ensureReady();
    try {
      switch (provider.formatType) {
        case 'openai':
        case 'custom':
          return await _callOpenAI(provider, prompt);
        case 'anthropic':
          return await _callAnthropic(provider, prompt);
        case 'gemini':
          return await _callGemini(provider,
              'Generate single slide HTML presentation content for: $prompt', _systemPrompt);
        default:
          return await _callOpenAI(provider, prompt);
      }
    } catch (e) {
      throw Exception('Failed to generate HTML: $e');
    }
  }

  /// Generate slide content with an optional custom system prompt.
  ///
  /// Track 52: when [deckContext] is provided it is appended to the system
  /// prompt so the model follows the deck's theme/layout; the returned HTML
  /// is passed through [AIHtmlGuard.guard] to strip dangerous tags.
  Future<String> generateSlideContent(String prompt,
      {String? customPrompt, String? deckContext}) async {
    final provider = _ensureReady();
    var sysPrompt = customPrompt ?? _systemPrompt;
    if (deckContext != null && deckContext.trim().isNotEmpty) {
      sysPrompt = '$sysPrompt\n$deckContext';
    }
    try {
      final String html;
      switch (provider.formatType) {
        case 'openai':
        case 'custom':
          html = await _callOpenAI(provider, prompt, systemPrompt: sysPrompt);
        case 'anthropic':
          html = await _callAnthropic(provider, prompt,
              systemPrompt: sysPrompt);
        case 'gemini':
          html = await _callGemini(provider, prompt, sysPrompt);
        default:
          html = await _callOpenAI(provider, prompt, systemPrompt: sysPrompt);
      }
      return AIHtmlGuard.guard(html).html;
    } catch (e) {
      throw Exception('Failed to generate slide content: $e');
    }
  }

  // ===========================================================================
  // Multi-Slide Generation
  // ===========================================================================

  Future<List<Map<String, String>>> generateMultipleSlides(String topic, {int slideCount = 3}) async {
    final provider = _ensureReady();
    final multiSlideSystemPrompt = '$_systemPrompt\n'
        'Return a JSON array of slide objects. Each object must have:\n'
        '  - "title": slide title (string)\n'
        '  - "html": HTML content for the slide body (string)\n'
        'Return ONLY valid JSON. No markdown, no extra text.\n'
        'Generate exactly $slideCount slides for the topic.';

    try {
      final result = switch (provider.formatType) {
        'openai' || 'custom' => await _callOpenAIMulti(provider, topic, multiSlideSystemPrompt),
        'anthropic' => await _callAnthropicMulti(provider, topic, multiSlideSystemPrompt),
        'gemini' => await _callGemini(provider, topic, multiSlideSystemPrompt),
        _ => await _callOpenAIMulti(provider, topic, multiSlideSystemPrompt),
      };
      return _parseSlideJson(result, slideCount);
    } catch (e) {
      throw Exception('Failed to generate slides: $e');
    }
  }

  // ===========================================================================
  // Outline Mode
  // ===========================================================================

  Future<List<Map<String, dynamic>>> generateOutline(String topic, {int slideCount = 5}) async {
    final provider = _ensureReady();
    final outlinePrompt =
        'You are a presentation planner. Create an outline for a presentation.\n'
        'Return ONLY a valid JSON array with exactly $slideCount objects. Each object has:\n'
        '  - "title": slide title (string)\n'
        '  - "bullets": array of 2-4 short bullet point strings\n'
        'No markdown, no extra text.';

    final raw = switch (provider.formatType) {
      'openai' || 'custom' => await _callOpenAIMulti(provider, topic, outlinePrompt),
      'anthropic' => await _callAnthropicMulti(provider, topic, outlinePrompt),
      'gemini' => await _callGemini(provider, topic, outlinePrompt),
      _ => await _callOpenAIMulti(provider, topic, outlinePrompt),
    };
    return parseOutlineJson(raw);
  }

  static List<Map<String, dynamic>> parseOutlineJson(String raw) {
    final jsonStr = _extractJsonArrayStatic(raw) ?? raw;
    try {
      final List<dynamic> entries = jsonDecode(jsonStr);
      return entries
          .whereType<Map<String, dynamic>>()
          .map((e) => {
                'title': (e['title'] ?? 'Untitled').toString(),
                'bullets': ((e['bullets'] as List?) ?? const [])
                    .map((b) => b.toString())
                    .toList(),
              })
          .toList();
    } catch (_) {
      throw Exception('Could not parse outline from AI response.');
    }
  }

  Future<String> generateSlideFromOutline(String topic, Map<String, dynamic> outlineEntry) async {
    final title = (outlineEntry['title'] ?? '').toString();
    final bullets = ((outlineEntry['bullets'] as List?) ?? const []).join('; ');
    final prompt = 'Topic: $topic. Create the slide titled "$title" covering: $bullets';
    return generateHtmlFromPrompt(prompt);
  }

  // ===========================================================================
  // Streaming Generation
  // ===========================================================================

  http.Client? _streamClient;
  bool _streamCancelled = false;
  static const Duration _streamDeadline = Duration(minutes: 2);

  /// Test hook: shortens the overall streaming deadline so the suite can
  /// simulate expiry instead of waiting out the production two-minute window.
  @visibleForTesting
  static Duration? streamDeadlineOverride;

  void cancelStream() {
    _streamCancelled = true;
    _streamClient?.close();
    _streamClient = null;
  }

  /// Safely resolves the target URL by joining [baseUrl] and [defaultPath]
  /// without causing duplicate path segments like `/v1/v1/chat/completions`.
  static String buildEndpointUrl(String baseUrl, String defaultPath) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return defaultPath;

    final pathLower = defaultPath.toLowerCase();
    var urlLower = url.toLowerCase();

    // Keep a user-supplied full endpoint only when it is the endpoint the
    // caller actually requested. For model discovery/health checks, reduce it
    // back to the API root before joining the requested path.
    if (urlLower.endsWith('/chat/completions')) {
      if (pathLower.endsWith('/chat/completions')) return url;
      url = url.substring(0, url.length - '/chat/completions'.length);
    } else if (urlLower.endsWith('/messages')) {
      if (pathLower.endsWith('/messages')) return url;
      url = url.substring(0, url.length - '/messages'.length);
    } else if (urlLower.contains(':generatecontent') ||
        urlLower.contains(':streamgeneratecontent')) {
      if (pathLower.contains(':generatecontent') ||
          pathLower.contains(':streamgeneratecontent')) {
        return url;
      }
      final modelsAt = urlLower.indexOf('/models/');
      if (modelsAt >= 0) url = url.substring(0, modelsAt);
    }
    urlLower = url.toLowerCase();

    if (urlLower.endsWith(pathLower)) return url;

    // Avoid duplicated API version segments when the base already contains it.
    if (pathLower.startsWith('/v1/') && urlLower.endsWith('/v1')) {
      return '$url${defaultPath.substring(3)}';
    }
    if (pathLower.startsWith('/v1beta/') && urlLower.endsWith('/v1beta')) {
      return '$url${defaultPath.substring(7)}';
    }

    final path = defaultPath.startsWith('/') ? defaultPath : '/$defaultPath';
    return '$url$path';
  }

  Stream<String> generateHtmlFromPromptStream(String prompt) {
    final provider = _ensureReady();
    return generateSlideStream(provider, prompt);
  }

  Stream<String> generateSlideStream(
      AIProviderConfig provider, String prompt) async* {
    _streamClient?.close();
    _streamClient = http.Client();
    _streamCancelled = false;
    final client = _streamClient!;

    try {
      final http.Request request;
      switch (provider.formatType) {
        case 'anthropic':
          final endpoint = buildEndpointUrl(provider.baseUrl, '/v1/messages');
          request = http.Request('POST', Uri.parse(endpoint))
            ..headers.addAll({
              'x-api-key': provider.apiKey,
              'anthropic-version': '2023-06-01',
              'Content-Type': 'application/json',
            })
            ..body = jsonEncode({
              'model': provider.selectedModel,
              'max_tokens': provider.maxTokens,
              'system': _systemPrompt,
              'stream': true,
              'messages': [
                {
                  'role': 'user',
                  'content': 'Generate presentation HTML slide content for: $prompt',
                },
              ],
            });
          break;
        case 'gemini':
          final endpoint = buildEndpointUrl(
            provider.baseUrl,
            '/v1beta/models/${provider.selectedModel}:streamGenerateContent?alt=sse',
          );
          request = http.Request('POST', Uri.parse(endpoint))
            ..headers.addAll({
              'x-goog-api-key': provider.apiKey,
              'Content-Type': 'application/json',
            })
            ..body = jsonEncode(_geminiBody(provider,
                'Generate single slide HTML presentation content for: $prompt', _systemPrompt));
          break;
        default: // openai / custom
          final endpoint = buildEndpointUrl(provider.baseUrl, '/v1/chat/completions');
          request = http.Request('POST', Uri.parse(endpoint))
            ..headers.addAll({
              'Authorization': 'Bearer ${provider.apiKey}',
              'Content-Type': 'application/json',
            })
            ..body = jsonEncode({
              'model': provider.selectedModel,
              'stream': true,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {
                  'role': 'user',
                  'content': 'Generate single slide HTML presentation content for: $prompt',
                },
              ],
              'temperature': provider.temperature,
              'max_tokens': provider.maxTokens,
            });
      }

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception(_friendlyErrorMessage(response.statusCode, body));
      }

      // Parse SSE lines across chunk boundaries.
      // v1.2.0: Also handle Anthropic event: lines
      var buffer = '';
      final deadline = Stopwatch()..start();
      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .timeout(const Duration(seconds: 30))) {
        if (deadline.elapsed > (streamDeadlineOverride ?? _streamDeadline)) {
          throw TimeoutException('AI streaming exceeded the overall deadline.');
        }
        // client.close() alone cannot abort an in-flight SSE response, so
        // the cancellation flag must be honoured here for Stop to work.
        if (_streamCancelled) return;
        buffer += chunk;
        // Split on REAL newlines — SSE events are LF-delimited and a single
        // network chunk routinely carries several of them (or half of one).
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final line in lines) {
          final delta = parseStreamLine(provider.formatType, line);
          if (delta != null && delta.isNotEmpty) yield delta;
        }
      }
      final delta = parseStreamLine(provider.formatType, buffer);
      if (delta != null && delta.isNotEmpty) yield delta;
    } on http.ClientException {
      if (!_streamCancelled) rethrow;
    } finally {
      if (identical(_streamClient, client)) _streamClient = null;
      client.close();
    }
  }

  /// Parse a single SSE line into a text delta (public for unit testing).
  /// v1.2.0: Improved Anthropic streaming — handles event: lines and message_delta.
  static String? parseStreamLine(String formatType, String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    // Skip Anthropic event: lines (we only care about data: lines)
    if (trimmed.startsWith('event:')) return null;

    if (!trimmed.startsWith('data:')) return null;
    final payload = trimmed.substring(5).trim();
    if (payload.isEmpty || payload == '[DONE]') return null;

    try {
      final data = jsonDecode(payload);
      switch (formatType) {
        case 'anthropic':
          // Handle content_block_delta for text streaming
          if (data['type'] == 'content_block_delta') {
            return data['delta']?['text'] as String?;
          }
          // Handle message_delta for stop reasons
          if (data['type'] == 'message_delta') {
            return null;
          }
          return null;
        case 'gemini':
          final candidates = data['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) return null;
          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts == null || parts.isEmpty) return null;
          return parts[0]['text'] as String?;
        default: // openai / custom
          final choices = data['choices'] as List?;
          if (choices == null || choices.isEmpty) return null;
          return choices[0]['delta']?['content'] as String?;
      }
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // JSON Parsing Helpers
  // ===========================================================================

  List<Map<String, String>> _parseSlideJson(String raw, int expectedCount) {
    final jsonStr = _extractJsonArray(raw);
    if (jsonStr == null) {
      return [{'title': 'Generated Slide', 'htmlContent': raw}];
    }
    try {
      final List<dynamic> slides = jsonDecode(jsonStr);
      return slides.map((s) {
        final map = s as Map<String, dynamic>;
        return {
          'title': (map['title'] ?? 'Slide').toString(),
          'htmlContent': (map['html'] ?? map['htmlContent'] ?? map['content'] ?? '').toString(),
        };
      }).toList();
    } catch (e) {
      return [{'title': 'Generated Slide', 'htmlContent': raw}];
    }
  }

  String? _extractJsonArray(String text) => _extractJsonArrayStatic(text);

  static String? _extractJsonArrayStatic(String text) {
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)?.trim();
    }
    const maxScan = 102400;
    final scanStart = text.length > maxScan ? text.length - maxScan : 0;
    final start = text.indexOf('[', scanStart);
    if (start == -1) return null;
    var depth = 0;
    var inString = false;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (inString) {
        if (c == r'\') {
          i++;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == '[') {
        depth++;
      } else if (c == ']') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }

  // ===========================================================================
  // OpenAI API Calls (shared client v1.2.0)
  // ===========================================================================

  Future<String> _callOpenAI(AIProviderConfig config, String prompt, {String? systemPrompt}) async {
    try {
      final response = await _postWithTimeout(
        Uri.parse(buildEndpointUrl(config.baseUrl, '/v1/chat/completions')),
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': config.selectedModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt ?? _systemPrompt},
            {
              'role': 'user',
              'content': 'Generate single slide HTML presentation content for: $prompt',
            },
          ],
          'temperature': config.temperature,
          'max_tokens': config.maxTokens,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        if (choices == null || choices.isEmpty) {
          throw Exception('API returned empty choices.');
        }
        final content = choices[0]['message']?['content'];
        return (content ?? '').toString();
      } else {
        throw Exception(_friendlyErrorMessage(response.statusCode, response.body));
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        throw Exception('Network error: Unable to reach ${config.name}. Check your connection.');
      }
      rethrow;
    }
  }

  Future<String> _callOpenAIMulti(AIProviderConfig config, String topic, String systemPrompt) async {
    try {
      final response = await _postWithTimeout(
        Uri.parse(buildEndpointUrl(config.baseUrl, '/v1/chat/completions')),
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': config.selectedModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': topic},
          ],
          'temperature': config.temperature,
          'max_tokens': config.maxTokens,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        if (choices == null || choices.isEmpty) {
          throw Exception('API returned empty choices.');
        }
        final content = choices[0]['message']?['content'];
        return (content ?? '').toString();
      } else {
        throw Exception(_friendlyErrorMessage(response.statusCode, response.body));
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        throw Exception('Network error: unable to reach ${config.name}.');
      }
      rethrow;
    }
  }

  // ===========================================================================
  // Anthropic API Calls (shared client v1.2.0)
  // ===========================================================================

  Future<String> _callAnthropic(AIProviderConfig config, String prompt, {String? systemPrompt}) async {
    try {
      final response = await _postWithTimeout(
        Uri.parse(buildEndpointUrl(config.baseUrl, '/v1/messages')),
        headers: {
          'x-api-key': config.apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': config.selectedModel,
          'max_tokens': config.maxTokens,
          'system': systemPrompt ?? _systemPrompt,
          'messages': [
            {
              'role': 'user',
              'content': 'Generate presentation HTML slide content for: $prompt',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final contentList = data['content'] as List?;
        if (contentList == null || contentList.isEmpty) {
          throw Exception('Anthropic returned empty content.');
        }
        return (contentList[0]['text'] ?? '').toString();
      } else {
        throw Exception(_friendlyErrorMessage(response.statusCode, response.body));
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        throw Exception('Network error: unable to reach ${config.name}.');
      }
      rethrow;
    }
  }

  Future<String> _callAnthropicMulti(AIProviderConfig config, String topic, String systemPrompt) async {
    try {
      final response = await _postWithTimeout(
        Uri.parse(buildEndpointUrl(config.baseUrl, '/v1/messages')),
        headers: {
          'x-api-key': config.apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': config.selectedModel,
          'max_tokens': config.maxTokens,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': topic},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final contentList = data['content'] as List?;
        if (contentList == null || contentList.isEmpty) {
          throw Exception('Anthropic returned empty content.');
        }
        return (contentList[0]['text'] ?? '').toString();
      } else {
        throw Exception(_friendlyErrorMessage(response.statusCode, response.body));
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        throw Exception('Network error: unable to reach ${config.name}.');
      }
      rethrow;
    }
  }

  // ===========================================================================
  // Gemini API Calls (shared client v1.2.0)
  // ===========================================================================

  static Map<String, dynamic> _geminiBody(AIProviderConfig config, String userText, String systemPrompt) {
    return {
      'systemInstruction': {
        'parts': [{'text': systemPrompt}]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': userText}]
        }
      ],
      'generationConfig': {
        'temperature': config.temperature,
        'maxOutputTokens': config.maxTokens,
      },
    };
  }

  Future<String> _callGemini(AIProviderConfig config, String userText, String systemPrompt) async {
    try {
      final response = await _postWithTimeout(
        Uri.parse(buildEndpointUrl(config.baseUrl, '/v1beta/models/${config.selectedModel}:generateContent')),
        headers: {
          'x-goog-api-key': config.apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(_geminiBody(config, userText, systemPrompt)),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('Gemini returned no candidates.');
        }
        final parts = candidates[0]['content']?['parts'] as List?;
        if (parts == null || parts.isEmpty) return '';
        return parts[0]['text']?.toString() ?? '';
      } else {
        throw Exception(_friendlyErrorMessage(response.statusCode, response.body));
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        throw Exception('Network error: unable to reach ${config.name}.');
      }
      rethrow;
    }
  }
}
