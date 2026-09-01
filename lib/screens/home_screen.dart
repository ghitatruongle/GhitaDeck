import 'dart:convert';

import 'package:flutter/material.dart';
import 'widgets/setup_show_dialog.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/snackbar_helper.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/app_provider.dart';
import '../config/build_info.dart';
import '../providers/ai_provider_manager.dart';
import '../providers/presentation_state.dart';
import '../providers/shortcuts_provider.dart';
import '../utils/keyboard_shortcuts.dart';
import '../utils/shortcut_intents.dart';
import 'present_screen.dart';
import 'presenter_view_screen.dart';
import 'slide_sorter_screen.dart';
import 'editor/editor_shell.dart';
import 'editor/editor_state.dart';
import 'recent_projects_screen.dart';
import 'template_studio_screen.dart';
import 'ai_chat_screen.dart';
import 'settings_screen.dart';
import 'widgets/command_palette_dialog.dart';
import 'widgets/shortcuts_help_dialog.dart';
import 'widgets/ribbon_toolbar.dart';
import 'widgets/quick_access_toolbar.dart';
import 'widgets/status_bar.dart';
import 'widgets/advanced_export_dialog.dart';
import 'widgets/office_buttons.dart';
import '../theme/office_colors.dart';
import '../l10n/l10n.dart';

/// HomeScreen ΓÇö Microsoft Office 365 style layout
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showSidebar = true;
  bool _showGrid = false;
  bool _showRuler = false;
  late final FocusNode _focusNode;
  // Owned here so the ribbon toolbar, status bar and editor shell all drive
  // the SAME editor state (previously the ribbon was never wired and its
  // formatting buttons silently did nothing).
  late final EditorState _editorState;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _editorState = EditorState();
    // Local-AI port scan is no longer pre-warmed here; AI surfaces call
    // scanLocalAI() on demand (served by the manager's 5-minute cache).
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _editorState.dispose();
    super.dispose();
  }

  /// Build shortcuts map from ShortcutsProvider
  Map<ShortcutActivator, Intent> _buildShortcutsMap(
      ShortcutsProvider provider) {
    final shortcuts = <ShortcutActivator, Intent>{};

    // Map each action to its intent
    shortcuts[provider.getShortcut(ShortcutAction.newSlide)] =
        const NewSlideIntent();
    shortcuts[provider.getShortcut(ShortcutAction.saveProject)] =
        const SaveProjectIntent();
    shortcuts[provider.getShortcut(ShortcutAction.exportPresentation)] =
        const ExportIntent();
    shortcuts[provider.getShortcut(ShortcutAction.undo)] = const UndoIntent();
    shortcuts[provider.getShortcut(ShortcutAction.redo)] = const RedoIntent();
    shortcuts[provider.getShortcut(ShortcutAction.startPresentation)] =
        const PresentIntent();
    shortcuts[provider.getShortcut(ShortcutAction.startFromCurrentSlide)] =
        const PresentFromCurrentIntent();
    shortcuts[provider.getShortcut(ShortcutAction.presenterView)] =
        const PresenterViewIntent();
    shortcuts[provider.getShortcut(ShortcutAction.toggleSidebar)] =
        const ToggleSidebarIntent();
    shortcuts[provider.getShortcut(ShortcutAction.toggleGrid)] =
        const ToggleGridIntent();
    shortcuts[provider.getShortcut(ShortcutAction.toggleRuler)] =
        const ToggleRulerIntent();
    shortcuts[provider.getShortcut(ShortcutAction.commandPalette)] =
        const CommandPaletteIntent();

    // v1.6.3: wire the remaining declared shortcuts that previously had
    // defaults but no handler (Ctrl+D, Delete, arrows, Ctrl+G, Ctrl+A/C/V/X,
    // Ctrl+=/-/0). Text fields keep priority for arrows/Delete/Ctrl+A/C/V/X
    // because their own EditableText bindings sit deeper in the focus tree.
    shortcuts[provider.getShortcut(ShortcutAction.duplicateSlide)] =
        const DuplicateSlideIntent();
    shortcuts[provider.getShortcut(ShortcutAction.deleteSlide)] =
        const DeleteSlideIntent();
    shortcuts[provider.getShortcut(ShortcutAction.previousSlide)] =
        const PreviousSlideIntent();
    shortcuts[provider.getShortcut(ShortcutAction.nextSlide)] =
        const NextSlideIntent();
    shortcuts[provider.getShortcut(ShortcutAction.goToSlide)] =
        const GoToSlideIntent();
    shortcuts[provider.getShortcut(ShortcutAction.selectAll)] =
        const SelectAllIntent();
    shortcuts[provider.getShortcut(ShortcutAction.copy)] = const CopyIntent();
    shortcuts[provider.getShortcut(ShortcutAction.paste)] =
        const PasteIntent();
    shortcuts[provider.getShortcut(ShortcutAction.cut)] = const CutIntent();
    shortcuts[provider.getShortcut(ShortcutAction.zoomIn)] =
        const ZoomInIntent();
    shortcuts[provider.getShortcut(ShortcutAction.zoomOut)] =
        const ZoomOutIntent();
    shortcuts[provider.getShortcut(ShortcutAction.zoomReset)] =
        const ZoomResetIntent();

    return shortcuts;
  }

  /// Build actions map
  Map<Type, Action<Intent>> _buildActionsMap(
    AppProvider appProvider,
    PresentationState ps,
  ) {
    return {
      NewSlideIntent: CallbackAction<NewSlideIntent>(
        onInvoke: (_) {
          ps.addSlide(Slide(
              title: context.l10n.newSlide,
              htmlContent: '<h1>New Slide</h1>\n<p>Click to edit</p>'));
          return null;
        },
      ),
      SaveProjectIntent: CallbackAction<SaveProjectIntent>(
        onInvoke: (_) {
          ps.savePresentation();
          return null;
        },
      ),
      ExportIntent: CallbackAction<ExportIntent>(
        onInvoke: (_) {
          // Open the advanced export dialog (format, aspect ratio, quality, slide selection)
          showDialog(
            context: context,
            builder: (_) => const AdvancedExportDialog(),
          );
          return null;
        },
      ),
      UndoIntent: CallbackAction<UndoIntent>(
        onInvoke: (_) {
          if (ps.canUndo) ps.undo();
          return null;
        },
      ),
      RedoIntent: CallbackAction<RedoIntent>(
        onInvoke: (_) {
          if (ps.canRedo) ps.redo();
          return null;
        },
      ),
      PresentIntent: CallbackAction<PresentIntent>(
        onInvoke: (_) {
          _present(context, ps);
          return null;
        },
      ),
      PresentFromCurrentIntent: CallbackAction<PresentFromCurrentIntent>(
        onInvoke: (_) {
          _present(context, ps, startSlide: ps.currentSlideIndex);
          return null;
        },
      ),
      PresenterViewIntent: CallbackAction<PresenterViewIntent>(
        onInvoke: (_) {
          _openPresenterView(context, ps);
          return null;
        },
      ),
      ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
        onInvoke: (_) {
          setState(() {
            _showSidebar = !_showSidebar;
          });
          return null;
        },
      ),
      ToggleGridIntent: CallbackAction<ToggleGridIntent>(
        onInvoke: (_) {
          setState(() {
            _showGrid = !_showGrid;
          });
          return null;
        },
      ),
      ToggleRulerIntent: CallbackAction<ToggleRulerIntent>(
        onInvoke: (_) {
          setState(() {
            _showRuler = !_showRuler;
          });
          return null;
        },
      ),
      CommandPaletteIntent: CallbackAction<CommandPaletteIntent>(
        onInvoke: (_) {
          _openCommandPalette(context);
          return null;
        },
      ),

      // ---- v1.6.3: handlers for the newly-wired shortcuts ----

      DuplicateSlideIntent: CallbackAction<DuplicateSlideIntent>(
        onInvoke: (_) {
          if (ps.slides.isNotEmpty &&
              ps.currentSlideIndex < ps.slides.length) {
            ps.duplicateSlide(ps.currentSlideIndex);
          }
          return null;
        },
      ),
      DeleteSlideIntent: CallbackAction<DeleteSlideIntent>(
        onInvoke: (_) {
          if (ps.slides.isEmpty) return null;
          final idx = ps.currentSlideIndex;
          if (idx < 0 || idx >= ps.slides.length) return null;
          final slide = ps.slides[idx];
          final title = slide.title;
          ps.removeSlide(idx);
          _editorState.handleSlideRemoved(idx, ps.slides.length);
          showAppSnackBar(
            context,
            context.l10n.deletedWithUndo(title),
            duration: const Duration(seconds: 3),
            actionLabel: context.l10n.undoAction,
            onAction: () => ps.insertSlide(
                idx,
                slide.copyWith(
                    timestamp: DateTime.now().millisecondsSinceEpoch)),
          );
          return null;
        },
      ),
      PreviousSlideIntent: CallbackAction<PreviousSlideIntent>(
        onInvoke: (_) {
          _navigateSlide(context, ps, -1);
          return null;
        },
      ),
      NextSlideIntent: CallbackAction<NextSlideIntent>(
        onInvoke: (_) {
          _navigateSlide(context, ps, 1);
          return null;
        },
      ),
      GoToSlideIntent: CallbackAction<GoToSlideIntent>(
        onInvoke: (_) {
          _goToSlideDialog(context, ps);
          return null;
        },
      ),
      SelectAllIntent: CallbackAction<SelectAllIntent>(
        onInvoke: (_) {
          if (appProvider.currentIndex != 0) return null;
          final controller = _editorState.htmlController;
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
          return null;
        },
      ),
      CopyIntent: CallbackAction<CopyIntent>(
        onInvoke: (_) {
          if (appProvider.currentIndex != 0) return null;
          final controller = _editorState.htmlController;
          final selection = controller.selection;
          if (selection.isValid && selection.start < selection.end) {
            Clipboard.setData(ClipboardData(
                text: controller.text
                    .substring(selection.start, selection.end)));
          }
          return null;
        },
      ),
      CutIntent: CallbackAction<CutIntent>(
        onInvoke: (_) {
          if (appProvider.currentIndex != 0) return null;
          final controller = _editorState.htmlController;
          final selection = controller.selection;
          if (selection.isValid && selection.start < selection.end) {
            final text = controller.text;
            Clipboard.setData(ClipboardData(
                text: text.substring(selection.start, selection.end)));
            final newText =
                text.replaceRange(selection.start, selection.end, '');
            controller.text = newText;
            controller.selection =
                TextSelection.collapsed(offset: selection.start);
          }
          return null;
        },
      ),
      PasteIntent: CallbackAction<PasteIntent>(
        onInvoke: (_) async {
          if (appProvider.currentIndex != 0) return null;
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          final text = data?.text;
          if (text == null || text.isEmpty) return null;
          final controller = _editorState.htmlController;
          final selection = controller.selection;
          if (selection.isValid &&
              selection.start >= 0 &&
              selection.end <= controller.text.length) {
            final newText = controller.text
                .replaceRange(selection.start, selection.end, text);
            controller.text = newText;
            controller.selection = TextSelection.collapsed(
                offset: selection.start + text.length);
          } else {
            controller.text = '${controller.text}$text';
          }
          return null;
        },
      ),
      ZoomInIntent: CallbackAction<ZoomInIntent>(
        onInvoke: (_) {
          _editorState.zoomIn();
          return null;
        },
      ),
      ZoomOutIntent: CallbackAction<ZoomOutIntent>(
        onInvoke: (_) {
          _editorState.zoomOut();
          return null;
        },
      ),
      ZoomResetIntent: CallbackAction<ZoomResetIntent>(
        onInvoke: (_) {
          _editorState.setZoom(1.0);
          return null;
        },
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final aiManager = Provider.of<AIProviderManager>(context);
    final ps = Provider.of<PresentationState>(context);
    final shortcutsProvider = Provider.of<ShortcutsProvider>(context);
    final theme = Theme.of(context);
    final isEditorTab = appProvider.currentIndex == 0;
    final isDark = theme.brightness == Brightness.dark;

    return Shortcuts(
      shortcuts: _buildShortcutsMap(shortcutsProvider),
      child: Actions(
        actions: _buildActionsMap(appProvider, ps),
        child: Focus(
          autofocus: true,
          child: ChangeNotifierProvider.value(
            value: _editorState,
            child: Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF1B1A19) : OfficeColors.gray98,
            body: Semantics(
              container: true,
              label: context.l10n.workspaceSemantics,
              child: Row(
                children: [
                  // ===== OFFICE SIDEBAR (NavigationRail) =====
                  if (_showSidebar)
                    RepaintBoundary(
                      child: _buildOfficeSidebar(context, appProvider, ps, isDark),
                    ),

                  // ===== MAIN CONTENT =====
                  Expanded(
                    child: Column(
                      children: [
                        // === OFFICE TITLE BAR ===
                        _buildOfficeTitleBar(
                            context, appProvider, ps, isEditorTab, isDark),

                        // === RIBBON (editor tab only) ===
                        if (isEditorTab)
                          RibbonToolbar(
                            presentationState: ps,
                            onPresent: () => _present(context, ps),
                            onPresentFromCurrent: () => _present(context, ps,
                                startSlide: ps.currentSlideIndex),
                            onPresenterView: () =>
                                _openPresenterView(context, ps),
                            onUndo: () => ps.undo(),
                            onRedo: () => ps.redo(),
                            canUndo: ps.canUndo,
                            canRedo: ps.canRedo,
                            onNewSlide: () {
                              ps.addSlide(Slide(
                                  title: context.l10n.newSlide,
                                  htmlContent:
                                      '<h1>New Slide</h1>\n<p>Click to edit</p>'));
                            },
                            onNavigateToTab: (idx) =>
                                appProvider.updateIndex(idx),
                            onOpenSlideSorter: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const SlideSorterScreen()));
                            },
                            onSetSlideEffect: (effect) => ps.setEffect(effect),
                            onApplyEffectToAll: (effect) {
                              for (int i = 0; i < ps.slides.length; i++) {
                                ps.setSlideEffectOverride(i, effect);
                              }
                            },
                            onSetSlideBackground: (hex) {
                              final idx = ps.currentSlideIndex;
                              if (idx >= 0 && idx < ps.slides.length) {
                                final updated =
                                    ps.slides[idx].copyWith(bgColor: hex);
                                ps.updateSlide(idx, updated);
                              }
                            },
                            onToggleGrid: () =>
                                setState(() => _showGrid = !_showGrid),
                            onToggleRuler: () =>
                                setState(() => _showRuler = !_showRuler),
                            onToggleFullscreen: _toggleFullscreen,
                            // Editor formatting wiring ΓÇö without these the
                            // ribbon's Bold/Italic/lists/insert actions were
                            // silently no-ops (rendered enabled, did nothing).
                            onInsertHtmlTag: _editorState.insertHtmlTag,
                            onInsertHtml: _editorState.insertHtml,
                            onExport: () => showDialog(
                                context: context,
                                builder: (_) => const AdvancedExportDialog()),
                            onZoomDialog: _showZoomDialog,
                            currentSlideIndex: ps.currentSlideIndex,
                          ),

                        // === MAIN CONTENT AREA ===
                        Expanded(
                          child: Stack(
                            children: [
                              IndexedStack(
                                index: appProvider.currentIndex,
                                children: [
                                  const EditorShell(),
                                  const RecentProjectsScreen(),
                                  const TemplateStudioScreen(),
                                  AiChatScreen(aiProviderManager: aiManager),
                                  const SettingsScreen(),
                                ],
                              ),
                              // Grid overlay
                              if (_showGrid && isEditorTab)
                                IgnorePointer(
                                  child: CustomPaint(
                                    size: Size.infinite,
                                    painter: _OfficeGridPainter(
                                        color: isDark
                                            ? OfficeColors.gray30
                                            : OfficeColors.gray90),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // === STATUS BAR ===
                      if (isEditorTab)
                        ListenableBuilder(
                          listenable: _editorState,
                          builder: (context, _) => StatusBar(
                            currentSlide: ps.slides.isNotEmpty
                                ? ps.currentSlideIndex + 1
                                : 0,
                            totalSlides: ps.slides.length,
                            zoomLevel: _editorState.zoomLevel,
                            onZoomChanged: (v) => _editorState.setZoom(v),
                            autoSaveStatus: ps.exportStatus ?? 'saved',
                            language: context.l10n.localeName,
                            // Track 63 (OPT 24): live word count + deck size.
                            wordCount: ps.slides.isNotEmpty
                                ? _countWords(
                                    ps.slides[ps.currentSlideIndex].htmlContent)
                                : 0,
                            deckSizeBytes: _estimateDeckBytes(ps.slides),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }

  // ===========================================================================
  // OFFICE SIDEBAR (72px wide, clean design)
  // ===========================================================================
  Widget _buildOfficeSidebar(BuildContext context, AppProvider appProvider,
      PresentationState ps, bool isDark) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252423) : OfficeColors.gray95,
        border: Border(
          right: BorderSide(
            color:
                isDark ? OfficeColors.gray30 : OfficeColors.ribbonBorderLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // === App Logo + Title ===
          Container(
            // The logo, caption and vertical padding need 52 px at the
            // default text scale. Reserve a little headroom so the caption
            // never overflows the compact sidebar header.
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: OfficeColors.officeBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        height: 20,
                        width: 20,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.slideshow,
                          size: 18,
                          color: OfficeColors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'GhitaPPT',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: isDark ? OfficeColors.gray90 : OfficeColors.gray30,
                      fontFamily: 'Segoe UI',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // === Navigation items ===
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                OfficeSidebarItem(
                  icon: Icons.edit_note,
                  label: context.l10n.editorTitle,
                  tooltip: '${context.l10n.editorTitle} (Ctrl+1)',
                  isSelected: appProvider.currentIndex == 0,
                  onTap: () => appProvider.updateIndex(0),
                  isDark: isDark,
                ),
                OfficeSidebarItem(
                  icon: Icons.folder_outlined,
                  label: context.l10n.projectsTitle,
                  tooltip: context.l10n.recentProjects,
                  isSelected: appProvider.currentIndex == 1,
                  onTap: () => appProvider.updateIndex(1),
                  isDark: isDark,
                ),
                OfficeSidebarItem(
                  icon: Icons.style_outlined,
                  label: context.l10n.templatesTitle,
                  tooltip: context.l10n.templatesTitle,
                  isSelected: appProvider.currentIndex == 2,
                  onTap: () => appProvider.updateIndex(2),
                  isDark: isDark,
                ),
                OfficeSidebarItem(
                  icon: Icons.smart_toy_outlined,
                  label: context.l10n.aiChatTitle,
                  tooltip: context.l10n.aiChat,
                  isSelected: appProvider.currentIndex == 3,
                  onTap: () => appProvider.updateIndex(3),
                  isDark: isDark,
                ),
                OfficeSidebarItem(
                  icon: Icons.settings_outlined,
                  label: context.l10n.settingsTitle,
                  tooltip: context.l10n.settingsTitle,
                  isSelected: appProvider.currentIndex == 4,
                  onTap: () => appProvider.updateIndex(4),
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // === Bottom actions ===
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // New Slide button
                OfficeSidebarButton(
                  icon: Icons.add_circle_outline,
                  tooltip: context.l10n.newSlide,
                  onTap: () {
                    ps.addSlide(Slide(
                        title: context.l10n.newSlide,
                        htmlContent:
                            '<h1>New Slide</h1>\n<p>Click to edit</p>'));
                    appProvider.updateIndex(0);
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                // Theme toggle
                OfficeSidebarButton(
                  icon: isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  tooltip: isDark
                      ? context.l10n.lightModeFull
                      : context.l10n.darkModeFull,
                  onTap: () => appProvider.toggleTheme(),
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                // Collapse sidebar
                OfficeSidebarButton(
                  icon: Icons.menu_open,
                  tooltip: context.l10n.hideSidebar,
                  onTap: () => setState(() => _showSidebar = false),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // OFFICE TITLE BAR
  // ===========================================================================
  Widget _buildOfficeTitleBar(
    BuildContext context,
    AppProvider appProvider,
    PresentationState ps,
    bool isEditorTab,
    bool isDark,
  ) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252423) : OfficeColors.white,
        border: Border(
          bottom: BorderSide(
            color:
                isDark ? OfficeColors.gray30 : OfficeColors.ribbonBorderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Show sidebar button if hidden
          if (!_showSidebar)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: OfficeHeaderButton(
                icon: Icons.menu,
                tooltip: context.l10n.showSidebar,
                onTap: () => setState(() => _showSidebar = true),
                isDark: isDark,
              ),
            ),

          // Quick Access Toolbar
          QuickAccessToolbar(
            onUndo: () => ps.undo(),
            onRedo: () => ps.redo(),
            onSave: () => ps.savePresentation(),
            onPresent: () => _present(context, ps),
            canUndo: ps.canUndo,
            canRedo: ps.canRedo,
          ),

          const Spacer(),

          // Title
          Text(
            ps.presentationTitle.isNotEmpty
                ? ps.presentationTitle
                : context.l10n.untitledPresentation,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? OfficeColors.gray90 : OfficeColors.gray20,
              fontFamily: 'Segoe UI',
            ),
          ),

          // Badge showing it's a Ghita file
          if (ps.slides.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B3A4F)
                    : OfficeColors.officeBlueLight,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '.ghita',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF50B8F4)
                      : OfficeColors.officeBlue,
                ),
              ),
            ),
          ],

          const Spacer(),

          // Action buttons (Office style)
          OfficeHeaderButton(
            icon: Icons.search,
            tooltip: '${context.l10n.search} (Ctrl+K)',
            onTap: () => _openCommandPalette(context),
            isDark: isDark,
          ),
          OfficeHeaderButton(
            icon: Icons.keyboard_outlined,
            tooltip: context.l10n.shortcuts,
            onTap: () => _openShortcutsHelp(context),
            isDark: isDark,
          ),
          OfficeHeaderButton(
            icon: Icons.help_outline,
            tooltip: context.l10n.help,
            onTap: () {
              showAppSnackBar(context,
          context.l10n.homeOffice365StyleNotice(
              BuildInfo.productName, BuildInfo.displayVersion));
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // === Status bar metrics (Track 63, OPT 24) ===
  int _countWords(String html) {
    final text = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.length;
  }

  int _estimateDeckBytes(List<Slide> slides) {
    try {
      return utf8.encode(jsonEncode(slides.map((s) => s.toMap()).toList()))
          .length;
    } catch (_) {
      return 0;
    }
  }

  // === Navigation helpers ===
  void _openCommandPalette(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => CommandPaletteDialog(
        items: [
          CommandPaletteItem(
              title: context.l10n.slideEditor,
              category: context.l10n.navigation,
              icon: Icons.edit_note,
              onSelect: () => appProvider.updateIndex(0)),
          CommandPaletteItem(
              title: context.l10n.projectsTitle,
              category: context.l10n.navigation,
              icon: Icons.folder_special,
              onSelect: () => appProvider.updateIndex(1)),
          CommandPaletteItem(
              title: context.l10n.templatesTitle,
              category: context.l10n.navigation,
              icon: Icons.style,
              onSelect: () => appProvider.updateIndex(2)),
          CommandPaletteItem(
              title: context.l10n.aiChatTitle,
              category: context.l10n.navigation,
              icon: Icons.chat_bubble,
              onSelect: () => appProvider.updateIndex(3)),
          CommandPaletteItem(
              title: context.l10n.settingsTitle,
              category: context.l10n.navigation,
              icon: Icons.settings,
              onSelect: () => appProvider.updateIndex(4)),
          CommandPaletteItem(
              title: context.l10n.toggleTheme,
              category: context.l10n.system,
              icon: Icons.palette,
              onSelect: () => appProvider.toggleTheme()),
        ],
      ),
    );
  }

  void _openShortcutsHelp(BuildContext context) {
    showDialog(context: context, builder: (_) => const ShortcutsHelpDialog());
  }

  Future<void> _present(BuildContext context, PresentationState state,
      {int startSlide = 0}) async {
    if (state.slides.isEmpty) {
      showAppSnackBar(context, context.l10n.noSlides);
      return;
    }
    // Track 36: Set Up Show dialog ΓÇö mode, options, pen colour, custom show.
    final result = await showSetupShowDialog(
      context,
      initial: state.setupShow,
      customShows: state.customShows,
      slideCount: state.slides.length,
    );
    if (result == null || !context.mounted) return;
    state.setupShow = result.settings;
    state.activeCustomShow = result.customShow;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PresentScreen(
        state: state,
        startSlide: startSlide,
        customShowOrder: result.customShow?.validIndices(state.slides.length),
        setupShow: result.settings,
      ),
    ));
  }

  void _openPresenterView(BuildContext context, PresentationState state) {
    if (state.slides.isEmpty) {
      showAppSnackBar(context, context.l10n.noSlides);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PresenterViewScreen(
          state: state, startSlide: state.currentSlideIndex),
    ));
  }

  /// Zoom control for the editor (View tab ribbon button). Shares the same
  /// zoom state as the editor preview.
  Future<void> _showZoomDialog() {
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Zoom'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(_editorState.zoomLevel * 100).round()}%',
                    style: Theme.of(context).textTheme.titleLarge),
                Slider(
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  value: _editorState.zoomLevel,
                  onChanged: (v) {
                    _editorState.setZoom(v);
                    setDialogState(() {});
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => _editorState.zoomOut(),
                      child: const Text('ΓêÆ'),
                    ),
                    TextButton(
                      onPressed: () => _editorState.setZoom(1.0),
                      child: const Text('100%'),
                    ),
                    TextButton(
                      onPressed: () => _editorState.zoomIn(),
                      child: const Text('+'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.close),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle the window between windowed and fullscreen (window_manager).
  Future<void> _toggleFullscreen() async {
    try {
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      } else {
        await windowManager.setFullScreen(true);
      }
    } catch (_) {
      // window_manager not initialized (e.g. tests) ΓÇö ignore silently.
    }
  }

  /// Navigate [delta] slides from the current one (arrow-key shortcuts).
  /// Only when the editor tab is active; text fields keep priority for
  /// arrows via their own deeper bindings.
  void _navigateSlide(BuildContext context, PresentationState ps, int delta) {
    if (ps.slides.isEmpty) return;
    final target = ps.currentSlideIndex + delta;
    if (target < 0 || target >= ps.slides.length) return;
    ps.setCurrentSlide(target);
    _editorState.selectSlide(target);
    _editorState.editSlide(target, ps);
  }

  /// Show a dialog to jump to a specific slide number (Ctrl+G).
  Future<void> _goToSlideDialog(BuildContext context, PresentationState ps) async {
    if (ps.slides.isEmpty) return;
    final controller = TextEditingController(
        text: '${ps.currentSlideIndex + 1}');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to slide'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Slide number (1-${ps.slides.length})',
            isDense: true,
          ),
          onSubmitted: (value) {
            final n = int.tryParse(value);
            if (n != null && n >= 1 && n <= ps.slides.length) {
              Navigator.pop(context, n);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n != null && n >= 1 && n <= ps.slides.length) {
                Navigator.pop(context, n);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      final target = result - 1;
      ps.setCurrentSlide(target);
      _editorState.selectSlide(target);
      _editorState.editSlide(target, ps);
    }
  }
}

// =============================================================================
// OFFICE GRID PAINTER
// =============================================================================
class _OfficeGridPainter extends CustomPainter {
  final Color color;
  _OfficeGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const gridSize = 20.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
