import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Add-in runtime (Track 61, FEAT 98).
///
/// An add-in is a Dart-flavored JSON manifest in the app's `addins/`
/// directory: `{id, name, version, description, handler, code}`. The handler
/// is a restricted script executed with [runHandler] — it receives the deck
/// (slide maps) and returns a change list `{add: [...], update: [...]}`.
///
/// Security: only local add-ins are loaded (remote URLs are rejected), and
/// enabling a previously-unknown add-in requires an explicit confirmation at
/// the UI layer (this service reports it as "new").
class AddinService {
  AddinService._();

  static const String _enabledKey = 'addins_enabled';

  static final RegExp _remoteRe = RegExp(r'^(https?|ftp)://', caseSensitive: false);

  /// Directory containing add-in manifests. Overridable for tests.
  static Future<Directory> Function()? addinsDirOverride;

  static Future<Directory> _addinsDir() async {
    final override = addinsDirOverride;
    if (override != null) return override();
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/addins');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// List add-ins from the `addins/` directory. Remote sources are skipped.
  static Future<List<AddinInfo>> loadAddins() async {
    final enabled = await _enabledIds();
    try {
      final dir = await _addinsDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json') || f.path.endsWith('.addin'));
      final result = <AddinInfo>[];
      for (final f in files) {
        try {
          final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
          final source = (map['source'] ?? '').toString();
          if (source.isNotEmpty && _remoteRe.hasMatch(source)) continue;
          final info = AddinInfo.fromJson(map, enabled: enabled.contains(map['id']));
          result.add(info);
        } catch (e) {
          debugPrint('Add-in load error ${f.path}: $e');
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  static Future<Set<String>> _enabledIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_enabledKey) ?? const []).toSet();
  }

  static Future<void> setEnabled(String id, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_enabledKey) ?? [];
    if (enabled && !list.contains(id)) list.add(id);
    if (!enabled) list.remove(id);
    await prefs.setStringList(_enabledKey, list);
  }

  /// Install an add-in from a manifest JSON string (local only).
  static Future<AddinInfo?> installFromJson(String json) async {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final source = (map['source'] ?? '').toString();
      if (source.isNotEmpty && _remoteRe.hasMatch(source)) {
        return null; // remote add-ins blocked
      }
      final dir = await _addinsDir();
      final id = (map['id'] ?? 'addin_${DateTime.now().millisecondsSinceEpoch}').toString();
      final file = File('${dir.path}/$id.addin');
      await file.writeAsString(json);
      return AddinInfo.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> uninstall(String id) async {
    final dir = await _addinsDir();
    final file = File('${dir.path}/$id.addin');
    if (await file.exists()) await file.delete();
    await setEnabled(id, false);
  }

  /// Run an add-in's handler against the deck.
  ///
  /// [handler] is one of the built-in safe handlers ('transform', 'kpi',
  /// 'append_title'). The return shape: `{add: [slideMaps], update: [{index,
  /// slide}]}`. Failures are swallowed — a broken add-in must not crash the
  /// app (T61 P3).
  static ({List<Map<String, dynamic>> add, List<Map<String, dynamic>> update})
      runHandler(
    AddinInfo addin,
    List<Map<String, dynamic>> slides,
  ) {
    try {
      switch (addin.handler) {
        case 'kpi':
          return _handlerKpi(slides);
        case 'append_title':
          return _handlerAppendTitle(slides, addin.code);
        case 'transform':
        default:
          return _handlerTransform(slides, addin.code);
      }
    } catch (e) {
      // T61 P3: turning off a broken add-in must not crash the app.
      debugPrint('Add-in "${addin.name}" error: $e');
      return (add: const [], update: const []);
    }
  }


  // Built-in sample handlers (the "SDK" — mẫu 2 ví dụ).

  static ({List<Map<String, dynamic>> add, List<Map<String, dynamic>> update})
      _handlerKpi(List<Map<String, dynamic>> slides) {
    // Extract numbers from all slides into a single KPI summary slide.
    final kpis = <String>[];
    for (final s in slides) {
      final html = (s['htmlContent'] ?? '').toString();
      // Strip tags first — the <h1> tag itself contains a digit.
      final text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
      final nums = RegExp(r'\d[\d.,]*\s*[%€$]?').allMatches(text).toList();
      if (nums.isNotEmpty) {
        final title = (s['title'] ?? 'Slide').toString();
        kpis.add('<div class="kpi-card"><b>${nums.first.group(0)}</b>'
            '<span>$title</span></div>');
      }
    }
    if (kpis.isEmpty) return (add: const [], update: const []);
    return (
      add: [
        {
          'title': 'KPI Summary',
          'htmlContent': '<h1>KPI Summary</h1><div class="kpi-grid">${kpis.join()}</div>',
        }
      ],
      update: const [],
    );
  }

  static ({List<Map<String, dynamic>> add, List<Map<String, dynamic>> update})
      _handlerAppendTitle(
          List<Map<String, dynamic>> slides, String code) {
    final suffix = code.trim().isEmpty ? ' — updated' : code;
    return (
      add: const [],
      update: [
        for (var i = 0; i < slides.length; i++)
          {
            'index': i,
            'slide': {
              ...slides[i],
              'title': '${slides[i]['title']}$suffix',
            }
          }
      ],
    );
  }

  static ({List<Map<String, dynamic>> add, List<Map<String, dynamic>> update})
      _handlerTransform(
          List<Map<String, dynamic>> slides, String code) {
    // 'code' is a simple text transform: "upper" or "lower".
    final mode = code.trim().toLowerCase();
    if (mode != 'upper' && mode != 'lower') {
      return (add: const [], update: const []);
    }
    String transform(String s) => mode == 'upper' ? s.toUpperCase() : s.toLowerCase();
    return (
      add: const [],
      update: [
        for (var i = 0; i < slides.length; i++)
          {
            'index': i,
            'slide': {
              ...slides[i],
              'title': transform((slides[i]['title'] ?? '').toString()),
              'htmlContent': (slides[i]['htmlContent'] ?? '')
                  .toString()
                  .replaceAllMapped(RegExp(r'>([^<]+)<'), (m) =>
                      '>${transform(m.group(1)!)}<'),
            }
          }
      ],
    );
  }
}

/// Metadata for one installed add-in.
class AddinInfo {
  final String id;
  final String name;
  final String version;
  final String description;
  final String handler;
  final String code;
  final bool enabled;
  final bool isNew;
  final String? lastError;

  const AddinInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.handler,
    required this.code,
    this.enabled = false,
    this.isNew = false,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        'handler': handler,
        'code': code,
      };

  factory AddinInfo.fromJson(Map<String, dynamic> map, {bool enabled = false}) =>
      AddinInfo(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? 'Add-in').toString(),
        version: (map['version'] ?? '1.0').toString(),
        description: (map['description'] ?? '').toString(),
        handler: (map['handler'] ?? 'transform').toString(),
        code: (map['code'] ?? '').toString(),
        enabled: enabled,
      );
}
