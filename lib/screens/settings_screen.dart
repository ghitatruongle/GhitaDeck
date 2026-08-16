import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../providers/ai_provider_manager.dart';
import 'provider_settings_screen.dart';
import 'configuration_wizard.dart';
import 'theme_settings_screen.dart';
import 'widgets/shortcuts_customization_dialog.dart';
import '../utils/error_mapper.dart';
import '../providers/locale_provider.dart';
import '../l10n/l10n.dart';
import '../l10n/app_localizations.dart';

/// Settings Screen — v1.2.0: Real Backup/Restore, Configuration Wizard, Local AI scan
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, TextEditingController> _keyControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initKeyControllers();
    });
  }

  void _initKeyControllers() {
    final manager = Provider.of<AIProviderManager>(context, listen: false);
    for (final p in manager.providers) {
      _keyControllers[p.id] = TextEditingController(text: p.apiKey);
    }
  }

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final aiManager = Provider.of<AIProviderManager>(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.settings, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                l10n.settingsTitle,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 1: Appearance
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(l10n.appearance,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.interfaceMode),
                    subtitle: Text(l10n
                        .currentMode(_themeLabel(appProvider.themeMode, l10n))),
                    trailing: SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment(
                            value: ThemeMode.light,
                            icon: const Icon(Icons.light_mode),
                            label: Text(l10n.lightMode)),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            icon: const Icon(Icons.dark_mode),
                            label: Text(l10n.darkMode)),
                        ButtonSegment(
                            value: ThemeMode.system,
                            icon: const Icon(Icons.brightness_auto),
                            label: Text(l10n.autoMode)),
                      ],
                      selected: {appProvider.themeMode},
                      onSelectionChanged: (set) {
                        if (set.isNotEmpty) appProvider.setThemeMode(set.first);
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.color_lens_outlined,
                        color: theme.colorScheme.primary),
                    title: Text(l10n.customTheme),
                    subtitle: Text(l10n.customThemeSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ThemeSettingsScreen(),
                          ));
                    },
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.keyboard_outlined,
                        color: theme.colorScheme.primary),
                    title: Text(l10n.shortcuts),
                    subtitle: Text(l10n.shortcuts),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ShortcutsCustomizationDialog(),
                      );
                    },
                  ),
                  const Divider(height: 24),
                  Consumer<LocaleProvider>(
                    builder: (context, localeProvider, _) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.language_outlined,
                            color: theme.colorScheme.primary),
                        title: Text(l10n.language),
                        subtitle: Text(localeProvider.isVietnamese
                            ? l10n.vietnamese
                            : l10n.english),
                        trailing: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'en', label: Text('EN')),
                            ButtonSegment(value: 'vi', label: Text('VI')),
                          ],
                          selected: {localeProvider.locale.languageCode},
                          onSelectionChanged: (set) {
                            if (set.isNotEmpty) {
                              localeProvider.setLocale(Locale(set.first));
                            }
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: AI Providers
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.vpn_key_outlined,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(l10n.aiProvider,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Thêm Custom Provider'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProviderSettingsScreen(
                                    aiProviderManager: aiManager,
                                    autoOpenAdd: true,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.auto_fix_high, size: 18),
                            label: const Text('Wizard'),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ConfigurationWizard()));
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.tune, size: 18),
                            label: Text(l10n.details),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProviderSettingsScreen(
                                        aiProviderManager: aiManager),
                                  ));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Evict controllers for providers that no longer exist so
                  // removed providers don't leak TextEditingController
                  // instances across add/remove cycles.
                  ..._evictStaleKeyControllers(aiManager),
                  ...aiManager.providers.map((p) {
                    final controller = _keyControllers.putIfAbsent(
                        p.id, () => TextEditingController(text: p.apiKey));
                    final isCurrent = p.id == aiManager.selectedProvider?.id;
                    final healthIcon = switch (p.healthStatus) {
                      ProviderHealthStatus.healthy => Icons.check_circle,
                      ProviderHealthStatus.degraded => Icons.warning,
                      ProviderHealthStatus.failed => Icons.error_outline,
                      ProviderHealthStatus.unknown => Icons.help_outline,
                    };
                    final healthColor = switch (p.healthStatus) {
                      ProviderHealthStatus.healthy => Colors.green,
                      ProviderHealthStatus.degraded => Colors.orange,
                      ProviderHealthStatus.failed => Colors.red,
                      ProviderHealthStatus.unknown => Colors.grey,
                    };

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(healthIcon, size: 16, color: healthColor),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 170,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(p.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12)),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text('Active',
                                            style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: theme
                                                    .colorScheme.onPrimary)),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  'Model: ${p.selectedModel.isNotEmpty ? p.selectedModel : "Default"}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: 'API Key...',
                                isDense: true,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.save, size: 18),
                                  tooltip: l10n.saveApiKeyTooltip,
                                  onPressed: () {
                                    final updated = p.copyWith(
                                        apiKey: controller.text.trim());
                                    aiManager.updateProvider(updated);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text(l10n.apiKeySaved(p.name))),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Backup & Restore (v1.2.0: Real implementation)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(l10n.backupRestore,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.download),
                          label: Text(l10n.exportBackup),
                          onPressed: () => _exportBackup(context, aiManager),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.upload),
                          label: Text(l10n.importBackup),
                          onPressed: () => _importBackup(context, aiManager),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 4: About
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(l10n.infoSection,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ghita PPT Converter'),
                    subtitle: Text(l10n.versionInfo('2.0.0', '2026')),
                    trailing: const Chip(label: Text('v2.0.0')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Export all settings to a JSON file
  Future<void> _exportBackup(
      BuildContext context, AIProviderManager aiManager) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted) return;

      // Collect all settings
      final backup = {
        'version': '2.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'themeMode':
            Provider.of<AppProvider>(context, listen: false).themeMode.name,
        'providers': aiManager.providers.map((p) => p.toMap()).toList(),
        'systemPrompt': aiManager.systemPrompt,
        'selectedProviderId': aiManager.selectedProvider?.id,
        'recentProjects': prefs.getString('recent_projects'),
        'appThemeMode': prefs.getString('app_theme_mode'),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName:
            'ghita_ppt_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (path != null) {
        final file = File(path);
        await file.writeAsString(jsonStr, flush: true);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Đã xuất backup thành công: ${path.split(RegExp(r'[/\\]')).last}'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ErrorMapper.showErrorSnackBar(context, e);
    }
  }

  /// Import settings from a JSON file
  Future<void> _importBackup(
      BuildContext context, AIProviderManager aiManager) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();
        final backup = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (!context.mounted) return;

        // Confirm before restoring
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Khôi phục cài đặt?'),
            content: Text(
                'File backup từ ${backup['exportedAt'] ?? "unknown"}.\n'
                'Số providers: ${(backup['providers'] as List?)?.length ?? 0}\n\n'
                'Cài đặt hiện tại sẽ bị ghi đè. Tiếp tục?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Khôi phục')),
            ],
          ),
        );

        if (confirm != true || !context.mounted) return;

        // Restore providers
        if (backup['providers'] is List) {
          final providerList = (backup['providers'] as List)
              .map((m) =>
                  AIProviderConfig.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList();
          for (final p in providerList) {
            aiManager.addProvider(p);
          }
        }

        // Restore system prompt
        if (backup['systemPrompt'] is String) {
          aiManager.updateSystemPrompt(backup['systemPrompt'] as String);
        }

        // Restore theme
        if (backup['themeMode'] is String) {
          final mode = ThemeMode.values.firstWhere(
            (m) => m.name == backup['themeMode'],
            orElse: () => ThemeMode.system,
          );
          Provider.of<AppProvider>(context, listen: false).setThemeMode(mode);
        }

        // Restore recent projects
        if (backup['recentProjects'] is String) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'recent_projects', backup['recentProjects'] as String);
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Đã khôi phục cài đặt thành công!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ErrorMapper.showErrorSnackBar(context, e);
    }
  }

  /// Dispose TextEditingControllers belonging to providers that no longer
/// exist, so removed providers don't leak controllers across cycles.
  Iterable<Widget> _evictStaleKeyControllers(AIProviderManager aiManager) {
    for (final id in List.of(_keyControllers.keys)) {
      if (!aiManager.providers.any((p) => p.id == id)) {
        final removed = _keyControllers.remove(id);
        removed?.dispose();
      }
    }
    return const <Widget>[];
  }

  String _themeLabel(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.lightModeFull;
      case ThemeMode.dark:
        return l10n.darkModeFull;
      case ThemeMode.system:
        return l10n.systemMode;
    }
  }
}
