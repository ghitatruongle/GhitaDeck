import 'package:flutter_test/flutter_test.dart';

import 'package:ghita_deck/services/url_scheme_guard.dart';

void main() {
  group('UrlSchemeGuard.allowsUrl', () {
    test('allows https for any host', () {
      expect(UrlSchemeGuard.allowsUrl('https://api.example.com/v1'), isTrue);
      expect(UrlSchemeGuard.allowsUrl('https://localhost:8443'), isTrue);
      expect(UrlSchemeGuard.allowsUrl('https://169.254.1.1'), isTrue);
    });

    test('allows http only for loopback and link-local hosts', () {
      expect(UrlSchemeGuard.allowsUrl('http://localhost:11434/v1'), isTrue);
      expect(UrlSchemeGuard.allowsUrl('http://LOCALHOST:11434/v1'), isTrue);
      expect(UrlSchemeGuard.allowsUrl('http://127.0.0.1:8080'), isTrue);
      expect(UrlSchemeGuard.allowsUrl('http://127.255.0.3'), isTrue);
      expect(UrlSchemeGuard.allowsUrl('http://[::1]:9000'), isTrue);
      expect(UrlSchemeGuard.allowsUrl('http://169.254.10.20'), isTrue);
    });

    test('rejects plain http to non-local hosts', () {
      expect(UrlSchemeGuard.allowsUrl('http://api.example.com'), isFalse);
      expect(UrlSchemeGuard.allowsUrl('http://203.0.113.10'), isFalse);
      expect(UrlSchemeGuard.allowsUrl('http://169.255.1.1'), isFalse);
      expect(UrlSchemeGuard.allowsUrl('http://localhost.attacker.com'),
          isFalse);
    });

    test('rejects non-http schemes and malformed urls', () {
      expect(UrlSchemeGuard.allowsUrl('ftp://x'), isFalse);
      expect(UrlSchemeGuard.allowsUrl('file:///C:/tmp'), isFalse);
      expect(UrlSchemeGuard.allowsUrl('javascript:alert(1)'), isFalse);
      expect(UrlSchemeGuard.allowsUrl('not a url'), isFalse);
      expect(UrlSchemeGuard.allowsUrl(''), isFalse);
    });
  });

  group('UrlSchemeGuard.check', () {
    test('reports the rejection reason', () {
      expect(
        UrlSchemeGuard.check('https://x.com'),
        UrlSchemeCheckResult.allowed,
      );
      expect(
        UrlSchemeGuard.check('http://localhost'),
        UrlSchemeCheckResult.allowed,
      );
      expect(
        UrlSchemeGuard.check('http://x.com'),
        UrlSchemeCheckResult.insecureScheme,
      );
      expect(
        UrlSchemeGuard.check('ftp://x'),
        UrlSchemeCheckResult.insecureScheme,
      );
      expect(
        UrlSchemeGuard.check('nope'),
        UrlSchemeCheckResult.invalidUrl,
      );
    });
  });

  group('UrlSchemeGuard host classifiers', () {
    test('classifies loopback hosts', () {
      expect(UrlSchemeGuard.isLoopbackHost('localhost'), isTrue);
      expect(UrlSchemeGuard.isLoopbackHost('LocalHost'), isTrue);
      expect(UrlSchemeGuard.isLoopbackHost('127.0.0.1'), isTrue);
      expect(UrlSchemeGuard.isLoopbackHost('127.9.9.9'), isTrue);
      expect(UrlSchemeGuard.isLoopbackHost('::1'), isTrue);
      expect(UrlSchemeGuard.isLoopbackHost('127.0.0.999'), isFalse);
      expect(UrlSchemeGuard.isLoopbackHost('128.0.0.1'), isFalse);
      expect(UrlSchemeGuard.isLoopbackHost('localhost.'), isFalse);
    });

    test('classifies link-local hosts', () {
      expect(UrlSchemeGuard.isLinkLocalHost('169.254.0.1'), isTrue);
      expect(UrlSchemeGuard.isLinkLocalHost('169.254.255.254'), isTrue);
      expect(UrlSchemeGuard.isLinkLocalHost('169.253.0.1'), isFalse);
      expect(UrlSchemeGuard.isLinkLocalHost('169.254.0.256'), isFalse);
      expect(UrlSchemeGuard.isLinkLocalHost('localhost'), isFalse);
    });
  });
}
