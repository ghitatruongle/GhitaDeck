import 'package:http/http.dart' as http;
import '../providers/ai_provider_manager.dart';

/// Validates API keys against provider endpoints.
/// Supports OpenAI-compatible, Anthropic, and Gemini format types.
class APIKeyRotationService {
  /// Tests whether an API key is valid for the given provider.
  /// Returns true if the key is accepted (HTTP 200 or 404 for some providers).
  Future<bool> testAPIKey(String baseUrl, String apiKey, String providerId) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      Uri url;

      if (providerId.contains('gemini') || providerId.contains('google')) {
        final endpoint = AIProviderManager.buildEndpointUrl(baseUrl, '/v1beta/models');
        url = Uri.parse(endpoint).replace(queryParameters: {'key': apiKey});
      } else if (providerId.contains('anthropic')) {
        final endpoint = AIProviderManager.buildEndpointUrl(baseUrl, '/v1/models');
        url = Uri.parse(endpoint);
        if (apiKey.isNotEmpty) {
          headers['x-api-key'] = apiKey;
          headers['anthropic-version'] = '2023-06-01';
        }
      } else {
        // OpenAI-compatible (OpenAI, Ollama, NVIDIA, custom endpoints)
        final endpoint = AIProviderManager.buildEndpointUrl(baseUrl, '/v1/models');
        url = Uri.parse(endpoint);
        if (apiKey.isNotEmpty) {
          headers['Authorization'] = 'Bearer $apiKey';
        }
      }

      final response = await http.get(url, headers: headers).timeout(
        const Duration(seconds: 5),
      );

      // 200 = valid key, 404 = endpoint exists but no models list (still valid connection)
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      return false;
    }
  }

  /// Tests an API key and returns detailed result with latency measurement.
  Future<APIKeyTestResult> testAPIKeyDetailed(
    String baseUrl,
    String apiKey,
    String providerId,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      Uri url;

      if (providerId.contains('gemini') || providerId.contains('google')) {
        final endpoint = AIProviderManager.buildEndpointUrl(baseUrl, '/v1beta/models');
        url = Uri.parse(endpoint).replace(queryParameters: {'key': apiKey});
      } else if (providerId.contains('anthropic')) {
        final endpoint = AIProviderManager.buildEndpointUrl(baseUrl, '/v1/models');
        url = Uri.parse(endpoint);
        if (apiKey.isNotEmpty) {
          headers['x-api-key'] = apiKey;
          headers['anthropic-version'] = '2023-06-01';
        }
      } else {
        final endpoint = AIProviderManager.buildEndpointUrl(baseUrl, '/v1/models');
        url = Uri.parse(endpoint);
        if (apiKey.isNotEmpty) {
          headers['Authorization'] = 'Bearer $apiKey';
        }
      }

      final response = await http.get(url, headers: headers).timeout(
        const Duration(seconds: 5),
      );
      stopwatch.stop();

      final isValid = response.statusCode == 200 || response.statusCode == 404;
      return APIKeyTestResult(
        isValid: isValid,
        latencyMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        errorMessage: isValid ? null : 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      stopwatch.stop();
      return APIKeyTestResult(
        isValid: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        statusCode: -1,
        errorMessage: e.toString(),
      );
    }
  }
}

/// Result of an API key validation test.
class APIKeyTestResult {
  final bool isValid;
  final int latencyMs;
  final int statusCode;
  final String? errorMessage;

  const APIKeyTestResult({
    required this.isValid,
    required this.latencyMs,
    required this.statusCode,
    this.errorMessage,
  });
}
