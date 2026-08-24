import 'ai_html_guard.dart';

/// Single sanitization policy for HTML entering the document model.
///
/// The editor keeps its historical text-content limit separately because
/// embedded media should not consume the text budget. The guard itself still
/// removes executable content and dangerous resource URLs everywhere.
class HtmlSanitizerService {
  HtmlSanitizerService._();

  static const int maxTextCharacters = 100000;
  static const int maxPresentationBytes = AIHtmlGuard.presentationMaxBytes;

  static GuardResult sanitize(String html) => AIHtmlGuard.guard(
        html,
        maxBytes: maxPresentationBytes,
      );

  static int textContentLength(String html) {
    const placeholder = 'data:payload';
    return html
        .replaceAllMapped(
          RegExp(
            r'data:[^;]+;base64,[A-Za-z0-9+/=\s]+',
            caseSensitive: false,
          ),
          (_) => placeholder,
        )
        .length;
  }

  static String? validate(String html) {
    if (html.trim().isEmpty) return 'HTML content cannot be empty.';
    if (textContentLength(html) > maxTextCharacters) {
      return 'HTML content is too long (max 100KB of text).';
    }
    final result = sanitize(html);
    if (result.html.trim().isEmpty) {
      return 'HTML contains only blocked elements.';
    }
    return null;
  }
}
