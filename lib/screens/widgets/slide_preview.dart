import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../services/ai_html_guard.dart';

/// Renders a single slide's HTML as a high-fidelity 16:9 Presentation Canvas Preview.
/// Uses WebView2 when available, with automatic fallback to Flutter text rendering.
class SlidePreview extends StatefulWidget {
  final String title;
  final String html;

  const SlidePreview({super.key, required this.title, required this.html});

  /// Extracts the background color from raw HTML before cleaning data attributes.
  static String _extractBgColor(String html) {
    final bgMatch = RegExp(r"""data-bg-color=["']([^"']+)["']""",
            caseSensitive: false)
        .firstMatch(html);
    return bgMatch?.group(1) ?? '#1a1a2e';
  }

  static String wrapSlideHtml(String title, String html) {
    final bg = _extractBgColor(html);
    final cleaned = AIHtmlGuard.guard(html,
            maxBytes: AIHtmlGuard.presentationMaxBytes)
        .html
        .replaceAll(RegExp(r'data-bg-color="[^"]*"', caseSensitive: false), '')
        .replaceAll(RegExp(r"data-bg-color='[^']*'", caseSensitive: false), '');

    return '''
<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: file:; media-src data: file:; font-src data:; style-src 'unsafe-inline';">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    width: 100%;
    height: 100%;
    overflow: hidden;
    background: $bg;
    color: #e2e8f0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  .slide-canvas {
    width: 100%;
    height: 100%;
    padding: 3.5vw 4.5vw;
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    overflow: hidden;
    position: relative;
  }
  h1 {
    font-size: clamp(1.6rem, 3.6vw, 2.8rem);
    font-weight: 700;
    color: #ffffff;
    line-height: 1.25;
    margin-bottom: 0.4em;
    letter-spacing: -0.02em;
  }
  h2 {
    font-size: clamp(1.1rem, 2.4vw, 1.8rem);
    font-weight: 600;
    color: #cbd5e1;
    line-height: 1.35;
    margin-bottom: 0.6em;
  }
  h3 {
    font-size: clamp(0.95rem, 1.8vw, 1.4rem);
    font-weight: 600;
    color: #94a3b8;
    margin-bottom: 0.4em;
  }
  p {
    font-size: clamp(0.85rem, 1.6vw, 1.2rem);
    line-height: 1.6;
    color: #e2e8f0;
    margin-bottom: 0.6em;
  }
  ul, ol {
    margin: 0.4em 0 0.6em 1.4em;
    line-height: 1.65;
    font-size: clamp(0.85rem, 1.5vw, 1.15rem);
  }
  li { margin-bottom: 0.35em; color: #e2e8f0; }
  blockquote {
    border-left: 4px solid #3b82f6;
    padding-left: 14px;
    margin: 0.8em 0;
    color: #94a3b8;
    font-style: italic;
  }
  code {
    font-family: Consolas, "Courier New", monospace;
    background: rgba(0, 0, 0, 0.35);
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 0.9em;
    color: #fca5a5;
  }
  pre {
    background: #0f172a;
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 8px;
    padding: 12px 16px;
    margin: 0.8em 0;
    overflow-x: auto;
  }
  pre code {
    background: transparent;
    padding: 0;
    color: #e2e8f0;
  }
  table {
    border-collapse: collapse;
    width: 100%;
    margin: 0.8em 0;
    font-size: clamp(0.8rem, 1.4vw, 1.05rem);
  }
  th, td {
    padding: 8px 12px;
    border: 1px solid rgba(255,255,255,0.15);
    text-align: left;
  }
  th {
    background: rgba(255,255,255,0.1);
    color: #ffffff;
    font-weight: 600;
  }
  img {
    max-width: 100%;
    max-height: 50vh;
    object-fit: contain;
    border-radius: 6px;
  }
  b, strong { color: #ffffff; font-weight: 700; }
  aside.notes { display: none; }
  /* Shape container */
  [data-shape-html] {
    position: absolute;
    box-sizing: border-box;
  }
</style>
</head>
<body>
  <div class="slide-canvas">
    $cleaned
  </div>
</body>
</html>''';
  }

  @override
  State<SlidePreview> createState() => _SlidePreviewState();
}

class _SlidePreviewState extends State<SlidePreview> {
  final _controller = WebviewController();
  bool _failed = false;
  bool _showWebView = false;
  String? _pendingHtml;

  @override
  void initState() {
    super.initState();
    _tryWebView2();
  }

  Future<void> _tryWebView2() async {
    try {
      await _controller.initialize().timeout(const Duration(seconds: 3));
      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      final initialHtml = SlidePreview.wrapSlideHtml(widget.title, widget.html);
      await _controller.loadStringContent(initialHtml).timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() => _showWebView = true);
      }
      if (_pendingHtml != null) {
        await _controller.loadStringContent(_pendingHtml!);
        _pendingHtml = null;
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant SlidePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html || oldWidget.title != widget.title) {
      final newHtml = SlidePreview.wrapSlideHtml(widget.title, widget.html);
      if (_showWebView) {
        _controller.loadStringContent(newHtml);
      } else {
        _pendingHtml = newHtml;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final textPreview = _buildTextPreview(context);

    if (!_showWebView && !_failed) {
      return textPreview;
    }

    if (_failed || !_showWebView) {
      return textPreview;
    }

    return Stack(
      children: [
        textPreview,
        RepaintBoundary(
          child: Webview(_controller),
        ),
      ],
    );
  }

  Widget _buildTextPreview(BuildContext context) {
    final bgHex = SlidePreview._extractBgColor(widget.html);
    Color bgColor;
    try {
      final hexValue = bgHex.replaceFirst('#', '');
      bgColor = Color(int.parse('FF$hexValue', radix: 16));
    } catch (_) {
      bgColor = const Color(0xFF1A1A2E);
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title.isNotEmpty) ...[
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
            ],
            _buildHtmlPreview(widget.html),
          ],
        ),
      ),
    );
  }

  Widget _buildHtmlPreview(String html) {
    var content = html;
    final h1Matches = RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false).allMatches(content);
    for (final m in h1Matches) {
      final text = _stripTags(m.group(1) ?? '');
      content = content.replaceFirst(m.group(0)!, '## $text');
    }
    final h2Matches = RegExp(r'<h2[^>]*>(.*?)</h2>', caseSensitive: false).allMatches(content);
    for (final m in h2Matches) {
      final text = _stripTags(m.group(1) ?? '');
      content = content.replaceFirst(m.group(0)!, '### $text');
    }
    final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false).allMatches(content);
    for (final m in pMatches) {
      final text = _stripTags(m.group(1) ?? '');
      content = content.replaceFirst(m.group(0)!, text);
    }
    final liMatches = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false).allMatches(content);
    for (final m in liMatches) {
      final text = _stripTags(m.group(1) ?? '');
      content = content.replaceFirst(m.group(0)!, 'BULLET $text');
    }
    content = content.replaceAll(RegExp(r'<[^>]+>'), '');
    content = content.replaceAll('&amp;', '&');
    content = content.replaceAll('&lt;', '<');
    content = content.replaceAll('&gt;', '>');
    content = content.replaceAll('&nbsp;', ' ');
    content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    final lines = content.trim().split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.where((l) => l.trim().isNotEmpty).map((line) {
        final trimmed = line.trim();
        if (trimmed.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              trimmed.substring(3),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          );
        }
        if (trimmed.startsWith('### ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              trimmed.substring(4),
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          );
        }
        if (trimmed.startsWith('BULLET ')) {
          return Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                Expanded(child: Text(trimmed.substring(7), style: const TextStyle(fontSize: 11, color: Colors.grey))),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            trimmed,
            style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
          ),
        );
      }).toList(),
    );
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
