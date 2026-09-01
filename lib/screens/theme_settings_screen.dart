import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../models/ppt_theme_setting.dart';
import '../providers/theme_provider.dart';
import '../theme/office_colors.dart';
import '../utils/snackbar_helper.dart';

/// Theme Settings Screen - Customize colors, fonts, and presets
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  final _primaryColorController = TextEditingController();
  final _accentColorController = TextEditingController();

  @override
  void dispose() {
    _primaryColorController.dispose();
    _accentColorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    if (!themeProvider.isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Theme Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export theme',
            onPressed: () => _exportTheme(themeProvider),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import theme',
            onPressed: () => _importTheme(themeProvider),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to default',
            onPressed: () {
              themeProvider.resetToDefault();
              _showSnackBar(context.l10n.themeResetNotice);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preset Themes Section
            _buildSectionTitle(context, 'Preset Themes'),
            const SizedBox(height: 12),
            _buildPresetThemesGrid(themeProvider),
            const SizedBox(height: 24),

            // Custom Colors Section
            _buildSectionTitle(context, 'Custom Colors'),
            const SizedBox(height: 12),
            _buildColorPicker(
              context,
              label: 'Primary Color',
              color: themeProvider.primaryColor,
              onColorChanged: (color) {
                themeProvider.setPrimaryColor(color);
              },
            ),
            const SizedBox(height: 12),
            _buildColorPicker(
              context,
              label: 'Accent Color',
              color: themeProvider.accentColor,
              onColorChanged: (color) {
                themeProvider.setAccentColor(color);
              },
            ),
            const SizedBox(height: 24),

            // Font Section
            _buildSectionTitle(context, 'Typography'),
            const SizedBox(height: 12),
            _buildFontSelector(themeProvider),
            const SizedBox(height: 24),

            // Export theme preview (Track 04, P8)
            _buildExportThemePreview(themeProvider),
            const SizedBox(height: 24),

            // Preview Section
            _buildSectionTitle(context, 'Preview'),
            const SizedBox(height: 12),
            _buildPreview(themeProvider, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildPresetThemesGrid(ThemeProvider provider) {
    final presets = [
      const PresetThemeInfo(
        name: 'Office Blue',
        description: 'Classic Microsoft Office',
        icon: Icons.business_center,
        primary: OfficeColors.officeBlue,
        accent: OfficeColors.accentOrange,
        preset: PresetTheme.officeBlue,
      ),
      const PresetThemeInfo(
        name: 'Dark Professional',
        description: 'Elegant dark theme',
        icon: Icons.dark_mode,
        primary: Color(0xFF1F2937),
        accent: Color(0xFF10B981),
        preset: PresetTheme.darkProfessional,
      ),
      const PresetThemeInfo(
        name: 'Light Minimal',
        description: 'Clean and minimal',
        icon: Icons.light_mode,
        primary: Color(0xFF6B7280),
        accent: Color(0xFFF59E0B),
        preset: PresetTheme.lightMinimal,
      ),
      PresetThemeInfo(
        name: 'Custom',
        description: 'Your custom theme',
        icon: Icons.palette,
        primary: provider.primaryColor,
        accent: provider.accentColor,
        preset: PresetTheme.custom,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final info = presets[index];
        final isSelected = provider.presetTheme == info.preset;

        return InkWell(
          onTap: () {
            provider.applyPreset(info.preset);
            _showSnackBar(context.l10n.themePresetAppliedNotice(info.name));
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? info.primary.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: isSelected
                    ? info.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: info.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(info.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  // Row height is pinned by the 40px chip; texts must be
                  // shrinkable or they overflow at higher text scales.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          info.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          info.description,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Color preview
                Container(
                  width: 12,
                  height: 32,
                  decoration: BoxDecoration(
                    color: info.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorPicker(
    BuildContext context, {
    required String label,
    required Color color,
    required ValueChanged<Color> onColorChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.colorize),
          tooltip: 'Pick color',
          onPressed: () => _pickColor(context, color, onColorChanged),
        ),
      ],
    );
  }

  // ---- Export theme preview (Track 04) ----

  /// Compact preview of the theme that will be written into exported PPTX
  /// files: the clrScheme swatches and the major/minor fonts.
  Widget _buildExportThemePreview(ThemeProvider provider) {
    String hex(Color color) => color.toARGB32().toRadixString(16).padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    // Mirrors the export mapping in AdvancedExportDialog: primary → accent1,
    // accent → accent2; the untouched Office Blue preset keeps the Office
    // defaults.
    final exportTheme = provider.presetTheme == PresetTheme.officeBlue
        ? PptThemeSetting.office
        : PptThemeSetting(
            accent1: hex(provider.primaryColor),
            accent2: hex(provider.accentColor),
            fontMinor: provider.fontFamily,
          );
    final swatches = <(String, String)>[
      ('accent1', exportTheme.accent1),
      ('accent2', exportTheme.accent2),
      ('accent3', exportTheme.accent3),
      ('accent4', exportTheme.accent4),
      ('accent5', exportTheme.accent5),
      ('accent6', exportTheme.accent6),
      ('hlink', exportTheme.hlink),
      ('folHlink', exportTheme.folHlink),
    ];
    Color fromHex(String value) => Color(int.parse('FF$value', radix: 16));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.exportThemePreview,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, value) in swatches)
                  Tooltip(
                    message: '$label #$value',
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: fromHex(value),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'majorFont: ${exportTheme.fontMajor}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'minorFont: ${exportTheme.fontMinor}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSelector(ThemeProvider provider) {
    final fonts = [
      'Segoe UI',
      'Arial',
      'Roboto',
      'Helvetica',
      'Times New Roman',
      'Courier New',
    ];

    return DropdownButtonFormField<String>(
      initialValue: provider.fontFamily,
      decoration: const InputDecoration(
        labelText: 'Font Family',
        prefixIcon: Icon(Icons.text_fields),
        border: OutlineInputBorder(),
      ),
      items: fonts.map((font) {
        return DropdownMenuItem(
          value: font,
          child: Text(font, style: TextStyle(fontFamily: font)),
        );
      }).toList(),
      onChanged: (font) {
        if (font != null) provider.setFontFamily(font);
      },
    );
  }

  Widget _buildPreview(ThemeProvider provider, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: provider.primaryColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.slideshow, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'GhitaPPT Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: provider.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Sample text
            Text(
              'This is a sample text using the selected theme.',
              style: TextStyle(
                fontSize: 14,
                fontFamily: provider.fontFamily,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            // Sample buttons
            Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: provider.primaryColor,
                  ),
                  onPressed: () {},
                  child: const Text('Primary'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: provider.accentColor,
                  ),
                  onPressed: () {},
                  child: const Text('Accent'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Sample chip
            Chip(
              label: const Text('Sample Chip'),
              backgroundColor: provider.primaryColor.withValues(alpha: 0.1),
              labelStyle: TextStyle(color: provider.primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    Color initial,
    ValueChanged<Color> onColorChanged,
  ) async {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
      Colors.black,
    ];

    final result = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SizedBox(
          width: 300,
          height: 200,
          child: GridView.count(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: colors.map((c) {
              return GestureDetector(
                onTap: () => Navigator.pop(context, c),
                child: Container(
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: c == initial ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      onColorChanged(result);
    }
  }

  void _exportTheme(ThemeProvider provider) {
    try {
      final json = provider.exportToJson();
      Clipboard.setData(ClipboardData(text: json));
      _showSnackBar(context.l10n.themeCopiedNotice);
    } catch (e) {
      _showSnackBar(context.l10n.themeExportFailedNotice);
    }
  }

  void _importTheme(ThemeProvider provider) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        final success = provider.importFromJson(data!.text!);
        if (success && mounted) {
          _showSnackBar(context.l10n.themeImportedNotice);
        } else if (mounted) {
          _showSnackBar(context.l10n.themeImportInvalidNotice);
        }
      } else if (mounted) {
        _showSnackBar(context.l10n.themeClipboardEmptyNotice);
      }
    } catch (e) {
      // importFromJson can throw on malformed JSON — don't crash.
      if (mounted) _showSnackBar(context.l10n.themeImportInvalidNotice);
    }
  }

  void _showSnackBar(String message) {
    showAppSnackBar(context, message, duration: const Duration(seconds: 2));
  }
}

class PresetThemeInfo {
  final String name;
  final String description;
  final IconData icon;
  final Color primary;
  final Color accent;
  final PresetTheme preset;

  const PresetThemeInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.primary,
    required this.accent,
    required this.preset,
  });
}
