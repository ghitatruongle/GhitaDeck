import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Ribbon/QAT customization model (Track 60, FEAT 97).
///
/// The ribbon is modeled as: tabs → groups → commands. Commands use the
/// normalized ids from [ShortcutAction] plus a few extra (export, print,
/// present, save). Config is persisted to SharedPreferences and can be
/// exported/imported as JSON.
class RibbonConfigService {
  RibbonConfigService._();

  static const String _prefsKey = 'ribbon_config_v1';
  static const String _qatKey = 'qat_commands_v1';

  /// Default ribbon: 6 tabs (matches the built-in toolbar).
  static List<RibbonTab> defaultTabs() => const [
        RibbonTab(id: 'home', name: 'Trang chủ', groups: [
          RibbonGroup(id: 'home_clipboard', name: 'Clipboard', commands: [
            'undo', 'redo', 'copy', 'paste', 'cut',
          ]),
          RibbonGroup(id: 'home_slides', name: 'Slides', commands: [
            'new_slide', 'duplicate_slide', 'delete_slide',
          ]),
          RibbonGroup(id: 'home_present', name: 'Trình chiếu', commands: [
            'start_presentation', 'start_from_current', 'presenter_view',
          ]),
        ]),
        RibbonTab(id: 'insert', name: 'Chèn', groups: [
          RibbonGroup(id: 'insert_elements', name: 'Yếu tố', commands: [
            'insert_image', 'insert_chart', 'insert_table', 'insert_video',
            'insert_icon', 'insert_smartart',
          ]),
        ]),
        RibbonTab(id: 'design', name: 'Thiết kế', groups: [
          RibbonGroup(id: 'design_theme', name: 'Chủ đề', commands: [
            'theme', 'background', 'designer',
          ]),
          RibbonGroup(id: 'design_layout', name: 'Bố cục', commands: [
            'layout', 'transition',
          ]),
        ]),
        RibbonTab(id: 'animations', name: 'Hoạt hình', groups: [
          RibbonGroup(id: 'anim_effects', name: 'Hiệu ứng', commands: [
            'animation', 'effect_options',
          ]),
        ]),
        RibbonTab(id: 'view', name: 'Xem', groups: [
          RibbonGroup(id: 'view_modes', name: 'Chế độ', commands: [
            'view_normal', 'view_sorter', 'view_notes', 'view_reading',
          ]),
          RibbonGroup(id: 'view_show', name: 'Hiển thị', commands: [
            'grid', 'ruler', 'fullscreen',
          ]),
        ]),
        RibbonTab(id: 'review', name: 'Xem lại', groups: [
          RibbonGroup(id: 'review_comments', name: 'Nhận xét', commands: [
            'comments', 'spellcheck', 'translate',
          ]),
        ]),
      ];

  /// All known command ids (ribbon + QAT candidates).
  static const List<String> allCommands = [
    'undo', 'redo', 'copy', 'paste', 'cut',
    'new_slide', 'duplicate_slide', 'delete_slide',
    'save', 'export', 'print', 'start_presentation', 'start_from_current',
    'presenter_view', 'insert_image', 'insert_chart', 'insert_table',
    'insert_video', 'insert_icon', 'insert_smartart', 'theme', 'background',
    'designer', 'layout', 'transition', 'animation', 'effect_options',
    'view_normal', 'view_sorter', 'view_notes', 'view_reading', 'grid',
    'ruler', 'fullscreen', 'comments', 'spellcheck', 'translate', 'search',
    'dictation', 'reuse', 'collaboration', 'cloud', 'profile', 'zoom_in',
    'zoom_out', 'zoom_reset',
  ];

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  static Future<List<RibbonTab>> loadTabs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return defaultTabs();
    try {
      final decoded = jsonDecode(raw) as List;
      final tabs = decoded
          .whereType<Map<String, dynamic>>()
          .map(RibbonTab.fromJson)
          .toList();
      return tabs.isNotEmpty ? tabs : defaultTabs();
    } catch (_) {
      return defaultTabs();
    }
  }

  static Future<void> saveTabs(List<RibbonTab> tabs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(tabs.map((t) => t.toJson()).toList()));
  }

  static Future<void> resetTabs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  // -------------------------------------------------------------------------
  // QAT
  // -------------------------------------------------------------------------

  static const List<String> defaultQat = [
    'save', 'undo', 'redo', 'export', 'print',
  ];

  static Future<List<String>> loadQat() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_qatKey);
    if (raw == null) return defaultQat;
    return raw.where(allCommands.contains).toList();
  }

  static Future<void> saveQat(List<String> commands) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_qatKey, commands);
  }

  static Future<void> resetQat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_qatKey);
  }

  // -------------------------------------------------------------------------
  // Export / Import JSON
  // -------------------------------------------------------------------------

  static String exportJson(List<RibbonTab> tabs, List<String> qat) =>
      jsonEncode({
        'version': 1,
        'tabs': tabs.map((t) => t.toJson()).toList(),
        'qat': qat,
      });

  static ({List<RibbonTab> tabs, List<String> qat}) importJson(String json) {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final tabs = (decoded['tabs'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(RibbonTab.fromJson)
          .toList();
      final qat = (decoded['qat'] as List? ?? [])
          .whereType<String>()
          .where(allCommands.contains)
          .toList();
      return (tabs: tabs.isNotEmpty ? tabs : defaultTabs(), qat: qat);
    } catch (_) {
      return (tabs: defaultTabs(), qat: defaultQat);
    }
  }
}

class RibbonTab {
  final String id;
  final String name;
  final List<RibbonGroup> groups;

  const RibbonTab({
    required this.id,
    required this.name,
    this.groups = const [],
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'groups': groups.map((g) => g.toJson()).toList()};

  factory RibbonTab.fromJson(Map<String, dynamic> map) => RibbonTab(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        groups: (map['groups'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(RibbonGroup.fromJson)
            .toList(),
      );
}

class RibbonGroup {
  final String id;
  final String name;
  final List<String> commands;

  const RibbonGroup({
    required this.id,
    required this.name,
    this.commands = const [],
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'commands': commands};

  factory RibbonGroup.fromJson(Map<String, dynamic> map) => RibbonGroup(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        commands: (map['commands'] as List? ?? [])
            .whereType<String>()
            .toList(),
      );
}
