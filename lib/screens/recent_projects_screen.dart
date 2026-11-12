import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/snackbar_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/presentation_state.dart';
import '../services/local_image_allowlist.dart';
import '../utils/error_mapper.dart';
import '../l10n/l10n.dart';

/// Recent Projects Screen — v1.2.0: FilePicker integration, project management
class RecentProjectsScreen extends StatefulWidget {
  const RecentProjectsScreen({super.key});

  @override
  State<RecentProjectsScreen> createState() => _RecentProjectsScreenState();
}

class _RecentProjectsScreenState extends State<RecentProjectsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _recentProjects = [];
  bool _isLoading = true;
  String _filter = '';

  /// The list after applying the search filter (case-insensitive on name/path).
  List<Map<String, dynamic>> get _filteredProjects {
    if (_filter.isEmpty) return _recentProjects;
    return _recentProjects
        .where((p) =>
            (p['name'] ?? '').toString().toLowerCase().contains(_filter) ||
            (p['path'] ?? '').toString().toLowerCase().contains(_filter))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadRecentProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('recent_projects');
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        if (!mounted) return;
        setState(() {
          _recentProjects = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading recent projects: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRecentProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('recent_projects', jsonEncode(_recentProjects));
    } catch (e) {
      debugPrint('Error saving recent projects: $e');
    }
  }

  Future<bool> _confirmReplaceUnsaved() async {
    final state = Provider.of<PresentationState>(context, listen: false);
    if (!state.hasUnsavedChanges) return true;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.unsavedTitle),
        content: Text(l10n.loadOverUnsavedBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.continueAction)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _openGhitaFile() async {
    if (!await _confirmReplaceUnsaved()) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ghita'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        LocalImageAllowlist.registerPickedFile(filePath);
        if (!mounted) return;
        final state = Provider.of<PresentationState>(context, listen: false);
        final success = await state.loadProjectFromFile(filePath);

        if (!mounted) return;

        if (success) {
          // Add to recent projects
          _addToRecent(filePath, result.files.single.name);
          showAppSnackBar(context, context.l10n.recentOpenedProjectNotice(result.files.single.name));
        } else {
          showAppSnackBar(context, context.l10n.recentGhitaOpenFailedNotice);
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorMapper.showErrorSnackBar(context, e);
      }
    }
  }

  void _addToRecent(String filePath, String fileName) {
    final entry = {
      'path': filePath,
      'name': fileName,
      'openedAt': DateTime.now().toIso8601String(),
    };
    // Remove duplicate
    _recentProjects.removeWhere((p) => p['path'] == filePath);
    // Add to front
    _recentProjects.insert(0, entry);
    // Keep max 10
    if (_recentProjects.length > 10) {
      _recentProjects = _recentProjects.sublist(0, 10);
    }
    _saveRecentProjects();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PresentationState>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.folder_special, size: 28, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  context.l10n.projectsManageTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar & actions
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.l10n.searchProjectsHint,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    // Filter the recent-projects list live as the user types.
                    onChanged: (value) => setState(() => _filter = value.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: Text(context.l10n.openGhitaFile),
                  onPressed: _openGhitaFile,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.newProject),
                  onPressed: () async {
                    final l10n = context.l10n;
                    final messenger = ScaffoldMessenger.of(context);
                    if (!await _confirmReplaceUnsaved()) return;
                    state.clearSlides();
                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(
                      content: Text(l10n.projectCreated),
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(
                        label: l10n.undoAction,
                        onPressed: () => state.undo(),
                      ),
                    ));
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Current project card
            if (state.slides.isNotEmpty) ...[
              Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.present_to_all, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  title: Text(
                    state.presentationTitle.isNotEmpty ? state.presentationTitle : context.l10n.currentProject,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    context.l10n.projectMetaEditing(state.slides.length, state.aspectRatio),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.save),
                        tooltip: context.l10n.saveGhitaTooltip,
                        onPressed: () async {
                          final path = await FilePicker.platform.saveFile(
                            dialogTitle: context.l10n.saveProjectDialog,
                            fileName: '${state.presentationTitle.isNotEmpty ? state.presentationTitle : "presentation"}.ghita',
                            type: FileType.custom,
                            allowedExtensions: ['ghita'],
                          );
                          if (path != null) {
                            LocalImageAllowlist.registerPickedFile(path);
                            final success = await state.saveProjectToFile(path);
                            if (!context.mounted) return;
                            if (success) {
                              _addToRecent(path, path.split(RegExp(r'[/\\]')).last);
                              showAppSnackBar(context, context.l10n.recentProjectSavedNotice);
                            } else {
                              showAppSnackBar(context, context.l10n.recentProjectSaveFailedNotice);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Recent projects list
            Text(
              context.l10n.recentProjects,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recentProjects.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_off, size: 64, color: theme.colorScheme.outline),
                              const SizedBox(height: 16),
                              Text(context.l10n.noRecentProjects),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.folder_open),
                                label: Text(context.l10n.openGhitaFile),
                                onPressed: _openGhitaFile,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                      itemCount: _filteredProjects.length,
                      itemBuilder: (ctx, idx) {
                        final project = _filteredProjects[idx];
                        final openedAt = DateTime.tryParse(project['openedAt'] ?? '') ?? DateTime.now();
                        final timeAgo = _formatTimeAgo(openedAt);

                        return Card(
                          key: ValueKey(project['path'] ?? idx),
                          child: ListTile(
                            leading: Icon(Icons.description, color: theme.colorScheme.primary),
                            title: Text(project['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(project['path'] ?? ''),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(timeAgo, style: theme.textTheme.bodySmall),
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  tooltip: context.l10n.openTooltip,
                                  onPressed: () async {
                                    final path = project['path'] as String?;
                                    if (path == null) return;
                                    if (!await _confirmReplaceUnsaved()) return;
                                    if (!context.mounted) return;
                                    final state = Provider.of<PresentationState>(context, listen: false);
                                    final success = await state.loadProjectFromFile(path);
                                    if (!context.mounted) return;
                                    if (success) {
                                      _addToRecent(path, project['name'] as String);
                                      showAppSnackBar(context, context.l10n.openedProject(project['name'] ?? ''));
                                    } else {
                                      showAppSnackBar(context, context.l10n.recentFileOpenFailedNotice);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  tooltip: context.l10n.removeFromListTooltip,
                                  onPressed: () {
                                    setState(() => _recentProjects.removeAt(idx));
                                    _saveRecentProjects();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
