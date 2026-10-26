import 'dart:io';

import 'package:path/path.dart' as p;

/// Local-only engine audit trail (T14).
///
/// Every Rust init attempt, fallback and backend transition lands in
/// `<AppData>\GhitaDeck\engine.log` (or `$HOME` on non-Windows) as one short
/// line. The log is deliberately PII-free (no deck content, no user paths, no
/// URLs), purely local (no network) and written best-effort — an audit
/// failure must never break an export. The path resolves with plain `dart:io`
/// so the log also works in widget-test/headless contexts.
class EngineAuditLog {
  EngineAuditLog._();

  /// Test hook: redirects the log to a fixed path.
  static String? debugOverridePath;

  static String _path() {
    if (debugOverridePath != null) return debugOverridePath!;
    final base = Platform.isWindows
        ? (Platform.environment['APPDATA'] ?? Directory.systemTemp.path)
        : (Platform.environment['HOME'] ?? Directory.systemTemp.path);
    return p.join(base, 'GhitaDeck', 'engine.log');
  }

  static Future<void> append(String event, [String? detail]) async {
    try {
      final line = '${DateTime.now().toIso8601String()} $event'
          '${detail == null || detail.isEmpty ? '' : ' — $detail'}\n';
      final file = File(_path());
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Best effort — never breaks an export.
    }
  }

  /// Last [n] lines (tests and diagnostics).
  static Future<List<String>> readLines(int n) async {
    try {
      final file = File(_path());
      if (!file.existsSync()) return const [];
      final lines = file.readAsLinesSync();
      return lines.length > n ? lines.sublist(lines.length - n) : lines;
    } catch (_) {
      return const [];
    }
  }
}
