import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:webview_windows/webview_windows.dart';

/// Tracks WebView2 runtime availability (Track 35, OPT 21).
///
/// Probed once at app startup (with a short timeout) so the presenter can show
/// a banner immediately instead of waiting out a 30s WebView2 timeout when it
/// tries to Present. On machines without the WebView2 runtime the static
/// `getWebViewVersion()` returns null / throws quickly.
class WebViewRuntimeService with ChangeNotifier {
  WebViewRuntimeService() {
    _probe();
  }

  bool? _available; // null = unknown (still probing)
  bool get available => _available == true;
  bool get unknown => _available == null;
  bool _probed = false;
  bool get probed => _probed;

  Future<void> _probe() async {
    final ok = await probeWebView2();
    _available = ok;
    _probed = true;
    notifyListeners();
  }

  /// Force a re-probe (e.g. after the user installed the runtime).
  Future<void> recheck() => _probe();

  /// True when the WebView2 runtime responds to a version query within the
  /// short timeout. Exposed for unit tests (no plugin channel needed — the
  /// query itself is what fails on a missing runtime).
  static Future<bool> probeWebView2() async {
    try {
      final version = await WebviewController.getWebViewVersion()
          .timeout(const Duration(seconds: 5));
      return version != null && version.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
