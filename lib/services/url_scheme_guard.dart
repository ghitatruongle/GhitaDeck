enum UrlSchemeCheckResult {
  allowed,
  invalidUrl,
  insecureScheme,
}

class UrlSchemeGuard {
  const UrlSchemeGuard._();

  static final RegExp _loopbackIpv4 = RegExp(r'^127(\.\d{1,3}){3}$');
  static final RegExp _linkLocalIpv4 = RegExp(r'^169\.254(\.\d{1,3}){2}$');

  static bool isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' || normalized == '::1') return true;
    if (!_loopbackIpv4.hasMatch(normalized)) return false;
    return _octetsInRange(normalized);
  }

  static bool isLinkLocalHost(String host) {
    final normalized = host.toLowerCase();
    if (!_linkLocalIpv4.hasMatch(normalized)) return false;
    return _octetsInRange(normalized);
  }

  static bool _octetsInRange(String host) {
    return host.split('.').every((octet) {
      final value = int.tryParse(octet);
      return value != null && value >= 0 && value <= 255;
    });
  }

  static UrlSchemeCheckResult checkUri(Uri uri) {
    if (!uri.hasScheme || !uri.hasAuthority) {
      return UrlSchemeCheckResult.invalidUrl;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https') return UrlSchemeCheckResult.allowed;
    if (scheme == 'http') {
      final host = uri.host;
      if (isLoopbackHost(host) || isLinkLocalHost(host)) {
        return UrlSchemeCheckResult.allowed;
      }
    }
    return UrlSchemeCheckResult.insecureScheme;
  }

  static UrlSchemeCheckResult check(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return UrlSchemeCheckResult.invalidUrl;
    return checkUri(uri);
  }

  static bool allowsUri(Uri uri) =>
      checkUri(uri) == UrlSchemeCheckResult.allowed;

  static bool allowsUrl(String url) =>
      check(url) == UrlSchemeCheckResult.allowed;
}
