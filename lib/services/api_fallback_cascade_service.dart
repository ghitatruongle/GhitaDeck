import 'dart:async';
import 'package:http/http.dart' as http;
import '../providers/ai_provider_manager.dart';

/// Service managing API latency testing, Key Rotation, and Fallback Cascade Execution.
class APIFallbackCascadeService {
  /// Measures ping latency (ms) for a given provider configuration.
  Future<PingResult> testProviderPing(AIProviderConfig config) async {
    final stopwatch = Stopwatch()..start();
    final client = http.Client();
    try {
      final Uri uri;
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      if (config.formatType == 'gemini') {
        final endpoint = AIProviderManager.buildEndpointUrl(config.baseUrl, '/v1beta/models');
        uri = Uri.parse(endpoint).replace(queryParameters: {'key': config.apiKey});
      } else if (config.formatType == 'anthropic') {
        final endpoint = AIProviderManager.buildEndpointUrl(config.baseUrl, '/v1/models');
        uri = Uri.parse(endpoint);
        headers['x-api-key'] = config.apiKey;
        headers['anthropic-version'] = '2023-06-01';
      } else {
        final endpoint = AIProviderManager.buildEndpointUrl(config.baseUrl, '/v1/models');
        uri = Uri.parse(endpoint);
        if (config.apiKey.isNotEmpty) {
          headers['Authorization'] = 'Bearer ${config.apiKey}';
        }
      }

      final response = await client.get(uri, headers: headers).timeout(
            const Duration(seconds: 5),
          );

      stopwatch.stop();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return PingResult(
          isSuccess: true,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        return PingResult(
          isSuccess: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      stopwatch.stop();
      return PingResult(
        isSuccess: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    } finally {
      client.close();
    }
  }

  /// Executes an AI task trying configured providers in sequence until one
  /// succeeds.
  ///
  /// [onFallback] fires every time a provider fails and the cascade moves on —
  /// the UI uses it to surface a fallback banner. [shouldStop] is consulted
  /// between attempts so a Stop action aborts the whole chain instead of
  /// walking the remaining providers.
  Future<T> executeWithFallback<T>(
    List<AIProviderConfig> providers,
    Future<T> Function(AIProviderConfig config) task, {
    void Function(AIProviderConfig failed, Object error, int attempt)?
        onFallback,
    bool Function()? shouldStop,
  }) async {
    if (providers.isEmpty) {
      throw Exception('No AI providers available for fallback execution.');
    }

    final errors = <String>[];
    for (var attempt = 0; attempt < providers.length; attempt++) {
      if (shouldStop != null && shouldStop()) {
        throw Exception('AI generation stopped by the user after '
            '${errors.length} failed attempt(s).');
      }
      final provider = providers[attempt];
      try {
        return await task(provider);
      } catch (e) {
        errors.add('${provider.name}: $e');
        onFallback?.call(provider, e, attempt + 1);
      }
    }

    throw Exception('All AI providers in fallback cascade failed:\n${errors.join('\n')}');
  }
}
