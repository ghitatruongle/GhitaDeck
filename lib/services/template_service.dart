import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/slide_template.dart';
import '../providers/presentation_state.dart';

/// Track 59 (FEAT 96 + OPT 46/47): template parameterization, favorites,
/// online store, create-from-deck.
class TemplateService {
  static const String _templatesMetaAsset = 'assets/templates/templates.json';
  static const String _templatesDir = 'assets/templates/';
  static const String _favoritesKey = 'template_favorites';
  static const String _userTemplatesKey = 'user_templates_v1';
  static const String _onlineStoreUrlKey = 'template_online_store_url';

  List<SlideTemplate>? _cachedTemplates;

  /// Apply theme parameters `{primary}`, `{accent}`, `{font}` inside a
  /// template's HTML (OPT 47). Unknown placeholders are left as-is.
  static String applyTheme(String html,
      {String primary = '#1F4E79',
      String accent = '#ED7D31',
      String font = 'Segoe UI'}) {
    var out = html;
    out = out.replaceAll('{primary}', primary);
    out = out.replaceAll('{accent}', accent);
    out = out.replaceAll('{font}', font);
    // Also handle inline font-family fallbacks.
    out = out.replaceAll('{font-family}', font);
    return out;
  }

  /// Build a template from the current deck: slide 1's HTML + theme colors
  /// (OPT: "Tạo template từ deck hiện tại"). Hard-coded theme colors become
  /// `{primary}`/`{accent}` placeholders so the template adapts to any theme.
  static SlideTemplate templateFromDeck(
    PresentationState state, {
    String name = 'Deck template',
    String category = 'User',
    Color? primary,
    Color? accent,
  }) {
    final slides = state.slides;
    final html =
        slides.isEmpty ? '<h1>Title</h1><p>Content</p>' : slides.first.htmlContent;
    final primaryHex = _toHex(primary ?? const Color(0xFF1F4E79));
    final accentHex = _toHex(accent ?? const Color(0xFFED7D31));
    var paramHtml = html;
    if (primaryHex.isNotEmpty) {
      paramHtml = paramHtml.replaceAll(primaryHex, '{primary}');
    }
    if (accentHex.isNotEmpty) {
      paramHtml = paramHtml.replaceAll(accentHex, '{accent}');
    }
    return SlideTemplate(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: 'Created from your current deck.',
      htmlContent: paramHtml,
      recommendedEffect: SlideEffect.none,
      icon: Icons.dashboard,
      accentColor: accent ?? const Color(0xFFED7D31),
      category: category,
    );
  }

  static String _toHex(Color c) {
    final a = c.toARGB32();
    final r = (a >> 16) & 0xFF;
    final g = (a >> 8) & 0xFF;
    final b = a & 0xFF;
    return '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  // -------------------------------------------------------------------------
  // Favorites
  // -------------------------------------------------------------------------

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoritesKey) ?? const []).toSet();
  }

  Future<void> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoritesKey) ?? [];
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    await prefs.setStringList(_favoritesKey, list);
  }

  // -------------------------------------------------------------------------
  // User templates (persist deck-created templates locally)
  // -------------------------------------------------------------------------

  Future<List<SlideTemplate>> loadUserTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userTemplatesKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SlideTemplate.fromMap)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveUserTemplate(SlideTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadUserTemplates();
    current.removeWhere((t) => t.id == template.id);
    current.insert(0, template);
    await prefs.setString(
        _userTemplatesKey, jsonEncode(current.map((t) => t.toMap()).toList()));
  }

  Future<void> deleteUserTemplate(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadUserTemplates();
    current.removeWhere((t) => t.id == id);
    await prefs.setString(
        _userTemplatesKey, jsonEncode(current.map((t) => t.toMap()).toList()));
  }

  // -------------------------------------------------------------------------
  // Online store (FEAT 96 — self-host, JSON list; disabled by default)
  // -------------------------------------------------------------------------

  String? _onlineStoreUrl;
  bool get hasOnlineStore => _onlineStoreUrl != null && _onlineStoreUrl!.isNotEmpty;

  Future<void> configureOnlineStore(String url) async {
    _onlineStoreUrl = url.trim().isEmpty ? null : url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_onlineStoreUrlKey, _onlineStoreUrl ?? '');
  }

  Future<void> loadOnlineStoreConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_onlineStoreUrlKey) ?? '';
    _onlineStoreUrl = url.trim().isEmpty ? null : url.trim();
  }

  /// Fetch template list from the configured URL (JSON array of template
  /// maps, same shape as assets manifest). Empty on failure / disabled.
  Future<List<SlideTemplate>> fetchOnlineTemplates() async {
    await loadOnlineStoreConfig();
    if (!hasOnlineStore) return const [];
    try {
      final client = http.Client();
      try {
        final response = await client
            .get(Uri.parse(_onlineStoreUrl!))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) return const [];
        final list = jsonDecode(response.body) as List;
        return list.whereType<Map<String, dynamic>>().map((m) {
          final html = (m['htmlContent'] ?? '').toString();
          return SlideTemplate(
            id: (m['id'] ?? 'remote_${DateTime.now().microsecondsSinceEpoch}').toString(),
            name: (m['name'] ?? 'Remote').toString(),
            description: (m['description'] ?? '').toString(),
            htmlContent: html,
            recommendedEffect: SlideEffect.none,
            icon: SlideTemplate.iconForCodePoint(m['iconCodePoint'] as int?),
            accentColor:
                Color((m['accentColor'] as int?) ?? 0xFF2196F3),
            category: (m['category'] ?? 'Online').toString(),
          );
        }).toList();
      } finally {
        client.close();
      }
    } catch (_) {
      return const [];
    }
  }


  /// Load all available templates from assets.
  Future<List<SlideTemplate>> loadTemplates() async {
    if (_cachedTemplates != null) return _cachedTemplates!;

    try {
      final manifestContent = await rootBundle.loadString(_templatesMetaAsset);
      final List<dynamic> metaList = json.decode(manifestContent);
      final templates = <SlideTemplate>[];

      for (final meta in metaList) {
        final htmlFile = meta['htmlFile'] as String;
        try {
          final htmlContent = await rootBundle.loadString('$_templatesDir$htmlFile');
          templates.add(SlideTemplate(
            id: meta['id'] as String,
            name: meta['name'] as String,
            description: meta['description'] as String,
            htmlContent: htmlContent,
            recommendedEffect: SlideEffect.values.firstWhere(
              (e) => e.name == meta['recommendedEffect'],
              orElse: () => SlideEffect.none,
            ),
            icon: SlideTemplate.iconForCodePoint(
                meta['iconCodePoint'] as int?),
            accentColor: Color((meta['accentColor'] as int?) ?? 0xFF2196F3),
            category: (meta['category'] as String?) ?? 'General',
          ));
        } catch (e) {
          debugPrint('Failed to load template HTML: $htmlFile — $e');
        }
      }

      _cachedTemplates = templates;
      return templates;
    } catch (e) {
      debugPrint('Failed to load templates metadata: $e');
      return [];
    }
  }

  Future<SlideTemplate?> getTemplateById(String id) async {
    final templates = await loadTemplates();
    try {
      return templates.firstWhere((t) => t.id == id);
    } on StateError {
      return null;
    }
  }

  /// Get templates filtered by category.
  Future<List<SlideTemplate>> getTemplatesByCategory(String category) async {
    final templates = await loadTemplates();
    if (category == 'All') return templates;
    return templates.where((t) => t.category == category).toList();
  }

  /// Get all unique categories.
  Future<List<String>> getCategories() async {
    final templates = await loadTemplates();
    final categories = templates.map((t) => t.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  void invalidateCache() {
    _cachedTemplates = null;
  }
}
