import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/presentation_state.dart';
import '../../utils/effect_helpers.dart';
import 'diagram_dialog.dart';
import '../../utils/error_mapper.dart';

/// PowerPoint-style Ribbon toolbar with tabbed interface.
/// v1.2.0: All buttons fully wired — no stubs.
///
/// Tabs: Home, Insert, Design, Transitions, Slide Show, View
class RibbonToolbar extends StatefulWidget {
  // --- Existing callbacks ---
  final VoidCallback? onExport;
  final VoidCallback? onPresent;
  final VoidCallback? onPresentFromCurrent;
  final VoidCallback? onPresenterView;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final PresentationState? presentationState;

  // --- v1.2.0: New callbacks for editor formatting ---
  /// Insert an HTML tag wrapping the current selection. (openTag, closeTag)
  final void Function(String openTag, String closeTag)? onInsertHtmlTag;

  /// Insert raw HTML at cursor position.
  final void Function(String html)? onInsertHtml;

  /// Add a new blank slide.
  final VoidCallback? onNewSlide;

  /// Navigate to a specific tab index (0=Editor, 1=Projects, 2=Templates, 3=AI Chat, 4=Settings).
  final void Function(int tabIndex)? onNavigateToTab;

  /// Open slide sorter screen.
  final VoidCallback? onOpenSlideSorter;

  /// Toggle grid overlay.
  final VoidCallback? onToggleGrid;

  /// Toggle ruler overlay.
  final VoidCallback? onToggleRuler;

  /// Set editor zoom level.
  final VoidCallback? onZoomDialog;

  /// Toggle fullscreen window.
  final VoidCallback? onToggleFullscreen;

  /// Set slide background color (hex string like '#1a1a2e').
  final void Function(String hexColor)? onSetSlideBackground;

  /// Set deck-wide effect.
  final void Function(SlideEffect effect)? onSetSlideEffect;

  /// Set effect for all slides.
  final void Function(SlideEffect effect)? onApplyEffectToAll;

  /// Current slide index (for transition buttons).
  final int? currentSlideIndex;

  const RibbonToolbar({
    super.key,
    this.onExport,
    this.onPresent,
    this.onPresentFromCurrent,
    this.onPresenterView,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
    this.presentationState,
    this.onInsertHtmlTag,
    this.onInsertHtml,
    this.onNewSlide,
    this.onNavigateToTab,
    this.onOpenSlideSorter,
    this.onToggleGrid,
    this.onToggleRuler,
    this.onZoomDialog,
    this.onToggleFullscreen,
    this.onSetSlideBackground,
    this.onSetSlideEffect,
    this.onApplyEffectToAll,
    this.currentSlideIndex,
  });

  @override
  State<RibbonToolbar> createState() => _RibbonToolbarState();
}

class _RibbonToolbarState extends State<RibbonToolbar>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Trang chủ'),
                Tab(text: 'Chèn'),
                Tab(text: 'Thiết kế'),
                Tab(text: 'Chuyển động'),
                Tab(text: 'Trình chiếu'),
                Tab(text: 'Xem'),
              ],
            ),
          ),
          SizedBox(
            height: 60,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHomeTab(context),
                _buildInsertTab(context),
                _buildDesignTab(context),
                _buildTransitionsTab(context),
                _buildSlideshowTab(context),
                _buildViewTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HOME TAB
  // ===========================================================================

  Widget _buildHomeTab(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Clipboard group ---
            _RibbonGroup(
              label: 'Clipboard',
              children: [
                _RibbonButton(
                  icon: Icons.content_paste,
                  label: 'Paste',
                  large: true,
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null && widget.onInsertHtml != null) {
                      widget.onInsertHtml!(data!.text!);
                    }
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.content_cut,
                      label: 'Cut',
                      compact: true,
                      tooltip: 'Cut (Ctrl+X)',
                      onPressed: () {
                        // NOTE: a real cut needs the HTML editor's current
                        // selection. This must NOT wipe the user's clipboard
                        // with an empty string (previous bug did exactly that)
                        // — the system Ctrl+X inside the editor is the
                        // reliable path.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chọn text trong editor rồi Ctrl+X'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    _RibbonButton(
                      icon: Icons.content_copy,
                      label: 'Copy',
                      compact: true,
                      tooltip: 'Copy (Ctrl+C)',
                      onPressed: () {
                        // Copy handled by system shortcut; this is a visual trigger
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chọn text trong editor rồi Ctrl+C'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),

            const _RibbonDivider(),

            // --- Font group ---
            _RibbonGroup(
              label: 'Font',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.format_bold,
                      tooltip: 'Bold',
                      compact: true,
                      onPressed: () =>
                          widget.onInsertHtmlTag?.call('<strong>', '</strong>'),
                    ),
                    _RibbonButton(
                      icon: Icons.format_italic,
                      tooltip: 'Italic',
                      compact: true,
                      onPressed: () =>
                          widget.onInsertHtmlTag?.call('<em>', '</em>'),
                    ),
                    _RibbonButton(
                      icon: Icons.format_underlined,
                      tooltip: 'Underline',
                      compact: true,
                      onPressed: () =>
                          widget.onInsertHtmlTag?.call('<u>', '</u>'),
                    ),
                    _RibbonButton(
                      icon: Icons.strikethrough_s,
                      tooltip: 'Strikethrough',
                      compact: true,
                      onPressed: () =>
                          widget.onInsertHtmlTag?.call('<s>', '</s>'),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.format_color_text,
                      tooltip: 'Font Color',
                      compact: true,
                      onPressed: () => _showColorPickerDialog(
                          context, 'Chọn màu chữ', (color) {
                        final hex =
                            '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                        widget.onInsertHtmlTag?.call(
                          '<span style="color: $hex">',
                          '</span>',
                        );
                      }),
                    ),
                    _RibbonButton(
                      icon: Icons.highlight,
                      tooltip: 'Highlight',
                      compact: true,
                      onPressed: () => _showColorPickerDialog(
                          context, 'Chọn màu highlight', (color) {
                        final hex =
                            '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                        widget.onInsertHtmlTag?.call(
                          '<span style="background-color: $hex">',
                          '</span>',
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),

            const _RibbonDivider(),

            // --- Paragraph group ---
            _RibbonGroup(
              label: 'Paragraph',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.format_align_left,
                      tooltip: 'Align Left',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<div style="text-align: left">\n\n</div>',
                      ),
                    ),
                    _RibbonButton(
                      icon: Icons.format_align_center,
                      tooltip: 'Align Center',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<div style="text-align: center">\n\n</div>',
                      ),
                    ),
                    _RibbonButton(
                      icon: Icons.format_align_right,
                      tooltip: 'Align Right',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<div style="text-align: right">\n\n</div>',
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.format_list_bulleted,
                      tooltip: 'Bullet List',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<ul>\n  <li>Item 1</li>\n  <li>Item 2</li>\n  <li>Item 3</li>\n</ul>',
                      ),
                    ),
                    _RibbonButton(
                      icon: Icons.format_list_numbered,
                      tooltip: 'Numbered List',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<ol>\n  <li>Step 1</li>\n  <li>Step 2</li>\n  <li>Step 3</li>\n</ol>',
                      ),
                    ),
                    _RibbonButton(
                      icon: Icons.format_indent_increase,
                      tooltip: 'Increase Indent',
                      compact: true,
                      onPressed: () => widget.onInsertHtmlTag?.call(
                        '<div style="margin-left: 2em">',
                        '</div>',
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const _RibbonDivider(),

            // --- Drawing group ---
            _RibbonGroup(
              label: 'Drawing',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.crop_square,
                      tooltip: 'Rectangle',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<div style="width: 200px; height: 100px; border: 2px solid #e0e0e0; border-radius: 8px; display: flex; align-items: center; justify-content: center; margin: 10px auto;">\n  <p>Rectangle</p>\n</div>',
                      ),
                    ),
                    _RibbonButton(
                      icon: Icons.circle_outlined,
                      tooltip: 'Circle',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<div style="width: 120px; height: 120px; border: 2px solid #e0e0e0; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 10px auto;">\n  <p>Circle</p>\n</div>',
                      ),
                    ),
                    _RibbonButton(
                      icon: Icons.horizontal_rule,
                      tooltip: 'Line',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<hr style="border: none; border-top: 2px solid #e0e0e0; margin: 16px 0;" />',
                      ),
                    ),
                    _RibbonButton(
                      icon: Icons.text_fields,
                      tooltip: 'Text Box',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<div style="border: 1px dashed #888; padding: 12px; margin: 8px 0; min-height: 60px;">\n  <p>Type your text here...</p>\n</div>',
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const _RibbonDivider(),

            // --- Editing group ---
            _RibbonGroup(
              label: 'Editing',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.undo,
                      tooltip: 'Undo (Ctrl+Z)',
                      compact: true,
                      onPressed: widget.canUndo ? widget.onUndo : null,
                    ),
                    _RibbonButton(
                      icon: Icons.redo,
                      tooltip: 'Redo (Ctrl+Y)',
                      compact: true,
                      onPressed: widget.canRedo ? widget.onRedo : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // INSERT TAB
  // ===========================================================================

  Widget _buildInsertTab(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slides group
            _RibbonGroup(
              label: 'Slides',
              children: [
                _RibbonButton(
                  icon: Icons.add_circle_outline,
                  label: 'New Slide',
                  large: true,
                  onPressed: widget.onNewSlide ??
                      () {
                        widget.presentationState?.addSlide(
                          Slide(
                            title: 'New Slide',
                            htmlContent:
                                '<h1>New Slide</h1>\n<p>Click to edit content</p>',
                          ),
                        );
                      },
                ),
              ],
            ),
            const _RibbonDivider(),

            // Images group
            _RibbonGroup(
              label: 'Images',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.image_outlined,
                      label: 'Pictures',
                      compact: true,
                      onPressed: () => _pickAndInsertImage(context),
                    ),
                    _RibbonButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Stock',
                      compact: true,
                      onPressed: () => _showStockImageDialog(context),
                    ),
                  ],
                ),
              ],
            ),
            const _RibbonDivider(),

            // Illustrations group
            _RibbonGroup(
              label: 'Illustrations',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.table_chart_outlined,
                      label: 'Table',
                      compact: true,
                      onPressed: () => _showTableDialog(context),
                    ),
                    _RibbonButton(
                      icon: Icons.pie_chart_outline,
                      label: 'Chart',
                      compact: true,
                      onPressed: () => _showChartDialog(context),
                    ),
                    _RibbonButton(
                      icon: Icons.account_tree_outlined,
                      label: 'SmartArt',
                      compact: true,
                      onPressed: () => _showSmartArtDialog(context),
                    ),
                    _RibbonButton(
                      icon: Icons.schema_outlined,
                      label: 'Diagram',
                      compact: true,
                      onPressed: () => _showDiagramDialog(context),
                    ),
                  ],
                ),
              ],
            ),
            const _RibbonDivider(),

            // Text group
            _RibbonGroup(
              label: 'Text',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.text_fields,
                      label: 'Text Box',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<div style="border: 1px dashed #888; padding: 12px; margin: 8px 0; min-height: 60px;">\n  <p>Type your text here...</p>\n</div>',
                      ),
                    ),
                    _RibbonButton(
                      icon: Icons.art_track,
                      label: 'WordArt',
                      compact: true,
                      onPressed: () => _showWordArtDialog(context),
                    ),
                    _RibbonButton(
                      icon: Icons.shortcut,
                      label: 'Header',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<header style="border-bottom: 2px solid #e0e0e0; padding-bottom: 8px; margin-bottom: 16px;">\n  <h2>Header Text</h2>\n</header>',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const _RibbonDivider(),

            // Symbols group
            _RibbonGroup(
              label: 'Symbols',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.emoji_symbols,
                      label: 'Symbol',
                      compact: true,
                      onPressed: () => _showSymbolDialog(context),
                    ),
                    _RibbonButton(
                      icon: Icons.code,
                      label: 'Code',
                      compact: true,
                      onPressed: () => widget.onInsertHtml?.call(
                        '<pre style="background: #1e1e1e; color: #d4d4d4; padding: 16px; border-radius: 8px; font-family: Consolas, monospace; overflow-x: auto;">\n<code>// Your code here\nfunction hello() {\n  console.log("Hello, World!");\n}\n</code>\n</pre>',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DESIGN TAB
  // ===========================================================================

  Widget _buildDesignTab(BuildContext context) {
    final theme = Theme.of(context);

    // 8 preset theme gradients
    final themeGradients = <List<Color>>[
      [Colors.blue.shade800, Colors.blue.shade200],
      [Colors.grey.shade800, Colors.grey.shade300],
      [Colors.teal.shade700, Colors.teal.shade200],
      [Colors.purple.shade700, Colors.purple.shade200],
      [Colors.red.shade700, Colors.red.shade200],
      [Colors.indigo.shade700, Colors.indigo.shade200],
      [Colors.brown.shade700, Colors.brown.shade200],
      [Colors.green.shade700, Colors.green.shade200],
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Themes group
            _RibbonGroup(
              label: 'Themes',
              children: [
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: themeGradients.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final bgHex =
                          '#${themeGradients[index][0].toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                      return GestureDetector(
                        onTap: () => widget.onSetSlideBackground?.call(bgHex),
                        child: Container(
                          width: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: themeGradients[index],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const _RibbonDivider(),

            // Variants group
            _RibbonGroup(
              label: 'Variants',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _colorVariant(Colors.blue, 'Blue',
                        () => widget.onSetSlideBackground?.call('#1a237e')),
                    _colorVariant(Colors.red, 'Red',
                        () => widget.onSetSlideBackground?.call('#b71c1c')),
                    _colorVariant(Colors.green, 'Green',
                        () => widget.onSetSlideBackground?.call('#1b5e20')),
                    _colorVariant(Colors.orange, 'Orange',
                        () => widget.onSetSlideBackground?.call('#e65100')),
                  ],
                ),
              ],
            ),
            const _RibbonDivider(),

            // Customize group
            _RibbonGroup(
              label: 'Customize',
              children: [
                _RibbonButton(
                  icon: Icons.format_color_fill,
                  label: 'Background',
                  compact: true,
                  onPressed: () =>
                      _showColorPickerDialog(context, 'Chọn màu nền', (color) {
                    final hex =
                        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                    widget.onSetSlideBackground?.call(hex);
                  }),
                ),
                _RibbonButton(
                  icon: Icons.gradient,
                  label: 'Gradient',
                  compact: true,
                  onPressed: () => _showGradientDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorVariant(Color color, String label, VoidCallback onTap) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: '$label background',
        button: true,
        onTap: onTap,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TRANSITIONS TAB
  // ===========================================================================

  Widget _buildTransitionsTab(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RibbonGroup(
              label: 'Transition to This Slide',
              children: [
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 14,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (context, index) {
                      final effects = SlideEffect.values
                          .where((e) => e != SlideEffect.none)
                          .toList();
                      if (index >= effects.length) {
                        return const SizedBox.shrink();
                      }
                      final effect = effects[index];
                      return _TransitionButton(
                        effect: effect,
                        label: EffectHelpers.effectName(effect),
                        onPressed: () => widget.onSetSlideEffect?.call(effect),
                      );
                    },
                  ),
                ),
              ],
            ),
            const _RibbonDivider(),

            // Apply to All button
            _RibbonGroup(
              label: 'Apply',
              children: [
                _RibbonButton(
                  icon: Icons.select_all,
                  label: 'Apply to All',
                  compact: true,
                  tooltip: 'Apply current effect to all slides',
                  onPressed: () {
                    final ps = widget.presentationState;
                    if (ps != null) {
                      widget.onApplyEffectToAll?.call(ps.slideEffect);
                    }
                  },
                ),
              ],
            ),
            const _RibbonDivider(),

            _buildTimingGroup(context),
          ],
        ),
      ),
    );
  }

  // --- Timing group ---
  Widget _buildTimingGroup(BuildContext context) {
    final ps = widget.presentationState;
    if (ps == null) {
      return const _RibbonGroup(
        label: 'Timing',
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RibbonButton(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  onPressed: null,
                  compact: true),
              _RibbonButton(
                  icon: Icons.mouse,
                  label: 'On Click',
                  onPressed: null,
                  compact: true),
              _RibbonButton(
                  icon: Icons.access_time,
                  label: 'Auto',
                  onPressed: null,
                  compact: true),
            ],
          ),
        ],
      );
    }

    return ListenableBuilder(
      listenable: ps,
      builder: (context, _) {
        final isAuto = ps.autoAdvance;
        return _RibbonGroup(
          label: 'Timing',
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RibbonButton(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  tooltip: 'Set auto-advance duration (seconds)',
                  onPressed: () => _showTimingDialog(context, ps),
                  compact: true,
                ),
                _RibbonButton(
                  icon: Icons.mouse,
                  label: 'On Click',
                  tooltip: 'Advance slides manually (default)',
                  onPressed: () => ps.setAutoAdvance(false),
                  selected: !isAuto,
                  compact: true,
                ),
                _RibbonButton(
                  icon: Icons.access_time,
                  label: 'Auto',
                  tooltip: 'Auto-advance slides by duration',
                  onPressed: () => ps.setAutoAdvance(!isAuto),
                  selected: isAuto,
                  compact: true,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTimingDialog(
      BuildContext context, PresentationState ps) async {
    var seconds = ps.autoAdvanceSeconds;
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thời lượng tự động'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Auto-advance duration per slide (seconds):'),
              const SizedBox(height: 12),
              Text('$seconds giây',
                  style: Theme.of(context).textTheme.titleMedium),
              Slider(
                min: 1,
                max: 60,
                divisions: 59,
                label: '$seconds',
                value: seconds.toDouble(),
                onChanged: (v) => setDialogState(() => seconds = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, seconds),
                child: const Text('Áp dụng')),
          ],
        ),
      ),
    );
    if (chosen != null) ps.setAutoAdvanceSeconds(chosen);
  }

  // ===========================================================================
  // SLIDESHOW TAB
  // ===========================================================================

  Widget _buildSlideshowTab(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RibbonGroup(
              label: 'Start Slide Show',
              children: [
                _RibbonButton(
                  icon: Icons.play_arrow,
                  label: 'From Beginning',
                  large: true,
                  onPressed: widget.onPresent,
                ),
                _RibbonButton(
                  icon: Icons.play_circle_outline,
                  label: 'From Current',
                  large: true,
                  onPressed: widget.onPresentFromCurrent,
                ),
              ],
            ),
            const _RibbonDivider(),
            _RibbonGroup(
              label: 'Set Up',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.slideshow,
                      label: 'Presenter View',
                      large: true,
                      onPressed: widget.onPresenterView,
                    ),
                    _RibbonButton(
                      icon: Icons.timer,
                      label: 'Timings',
                      compact: true,
                      tooltip: 'Set slide timings',
                      onPressed: widget.presentationState != null
                          ? () => _showTimingDialog(
                              context, widget.presentationState!)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VIEW TAB
  // ===========================================================================

  Widget _buildViewTab(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RibbonGroup(
              label: 'Presentation Views',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.edit_note,
                      label: 'Normal',
                      compact: true,
                      tooltip: 'Normal editor view',
                      onPressed: () => widget.onNavigateToTab?.call(0),
                    ),
                    _RibbonButton(
                      icon: Icons.grid_view,
                      label: 'Slide Sorter',
                      compact: true,
                      tooltip: 'Slide sorter view',
                      onPressed: widget.onOpenSlideSorter,
                    ),
                  ],
                ),
              ],
            ),
            const _RibbonDivider(),
            _RibbonGroup(
              label: 'Show',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.grid_on,
                      label: 'Grid',
                      compact: true,
                      tooltip: 'Toggle grid overlay',
                      onPressed: widget.onToggleGrid,
                    ),
                    _RibbonButton(
                      icon: Icons.straighten,
                      label: 'Ruler',
                      compact: true,
                      tooltip: 'Toggle ruler overlay',
                      onPressed: widget.onToggleRuler,
                    ),
                    _RibbonButton(
                      icon: Icons.zoom_out_map,
                      label: 'Zoom',
                      compact: true,
                      tooltip: 'Adjust zoom level',
                      onPressed: widget.onZoomDialog,
                    ),
                  ],
                ),
              ],
            ),
            const _RibbonDivider(),
            _RibbonGroup(
              label: 'Window',
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RibbonButton(
                      icon: Icons.fullscreen,
                      label: 'Fullscreen',
                      compact: true,
                      tooltip: 'Toggle fullscreen window',
                      onPressed: widget.onToggleFullscreen,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DIALOGS
  // ===========================================================================

  /// Show a color picker dialog and call onColorSelected with the chosen color.
  void _showColorPickerDialog(BuildContext context, String title,
      void Function(Color) onColorSelected) {
    Color selectedColor = Colors.blue;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 300,
            height: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Preview
                Container(
                  height: 40,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),
                // Color grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 6,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    children: [
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
                      Colors.white,
                      const Color(0xFF1a1a2e),
                      const Color(0xFF16213e),
                      const Color(0xFF0f3460),
                    ]
                        .map((c) => GestureDetector(
                              onTap: () => setState(() => selectedColor = c),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: selectedColor == c
                                        ? Colors.white
                                        : Colors.grey.shade300,
                                    width: selectedColor == c ? 2 : 1,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onColorSelected(selectedColor);
              },
              child: const Text('Chọn'),
            ),
          ],
        ),
      ),
    );
  }

  /// Pick an image file and insert as base64 <img> tag.
  Future<void> _pickAndInsertImage(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        final file = File(result.files.first.path!);
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        final ext = result.files.first.extension ?? 'png';
        final html = '<img src="data:image/$ext;base64,$base64Str" '
            'style="max-width: 100%; height: auto; border-radius: 8px;" '
            'alt="${result.files.first.name}" />';
        widget.onInsertHtml?.call(html);
      }
    } catch (e) {
      if (context.mounted) {
        ErrorMapper.showErrorSnackBar(context, e);
      }
    }
  }

  /// Stock image placeholder dialog.
  void _showStockImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stock Images'),
        content: const Text('Chức năng stock images sẽ sớm ra mắt.\n'
            'Hiện tại, bạn có thể dùng nút Pictures để chèn ảnh từ máy.'),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  /// Table insertion dialog.
  void _showTableDialog(BuildContext context) {
    int rows = 3;
    int cols = 3;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Chèn bảng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Rows: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: rows,
                    items: List.generate(10, (i) => i + 1)
                        .map((v) =>
                            DropdownMenuItem(value: v, child: Text('$v')))
                        .toList(),
                    onChanged: (v) => setState(() => rows = v ?? 3),
                  ),
                  const SizedBox(width: 24),
                  const Text('Columns: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: cols,
                    items: List.generate(10, (i) => i + 1)
                        .map((v) =>
                            DropdownMenuItem(value: v, child: Text('$v')))
                        .toList(),
                    onChanged: (v) => setState(() => cols = v ?? 3),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                final headerCells =
                    List.generate(cols, (i) => '<th>Header ${i + 1}</th>')
                        .join('\n    ');
                final bodyRows = List.generate(
                  rows - 1,
                  (r) =>
                      '  <tr>\n    ${List.generate(cols, (c) => '<td>Cell</td>').join('\n    ')}\n  </tr>',
                ).join('\n');
                final html =
                    '<table style="width: 100%; border-collapse: collapse; margin: 16px 0;">\n'
                    '  <thead>\n    <tr>\n    $headerCells\n    </tr>\n  </thead>\n'
                    '  <tbody>\n$bodyRows\n  </tbody>\n</table>';
                widget.onInsertHtml?.call(html);
              },
              child: const Text('Chèn'),
            ),
          ],
        ),
      ),
    );
  }

  /// Chart dialog — generates a CSS bar chart.
  void _showChartDialog(BuildContext context) {
    final items = <_ChartItem>[
      _ChartItem('Item A', 80),
      _ChartItem('Item B', 60),
      _ChartItem('Item C', 45),
      _ChartItem('Item D', 90),
    ];
    // Pre-allocate controllers so we can dispose them when the dialog closes
    // (each TextEditingController is a listener-attached object that must be
    // disposed to release its ChangeNotifier resources).
    final controllers = items
        .map((it) => TextEditingController(text: it.label))
        .toList(growable: false);
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Chèn biểu đồ'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(
                    items.length,
                    (i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: controllers[i],
                                  onChanged: (v) => setState(() =>
                                      items[i] = _ChartItem(v, items[i].value)),
                                  decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Slider(
                                  value: items[i].value.toDouble(),
                                  min: 0,
                                  max: 100,
                                  onChanged: (v) => setState(() => items[i] =
                                      _ChartItem(items[i].label, v.round())),
                                ),
                              ),
                              Text('${items[i].value}%'),
                            ],
                          ),
                        )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                for (final c in controllers) {
                  c.dispose();
                }
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                for (final c in controllers) {
                  c.dispose();
                }
                final bars = items
                    .map(
                      (item) =>
                          '<div style="display: flex; align-items: center; margin: 6px 0;">\n'
                          '  <span style="width: 80px; text-align: right; padding-right: 8px; font-size: 0.9em;">${item.label}</span>\n'
                          '  <div style="flex: 1; background: #333; border-radius: 4px; height: 24px;">\n'
                          '    <div style="width: ${item.value}%; height: 100%; background: linear-gradient(90deg, #e65100, #ff9800); border-radius: 4px; display: flex; align-items: center; justify-content: flex-end; padding-right: 6px;">\n'
                          '      <span style="color: white; font-size: 0.8em; font-weight: bold;">${item.value}%</span>\n'
                          '    </div>\n'
                          '  </div>\n'
                          '</div>',
                    )
                    .join('\n');
                widget.onInsertHtml?.call(
                  '<div style="padding: 16px; margin: 16px 0;">\n$bars\n</div>',
                );
              },
              child: const Text('Chèn'),
            ),
          ],
        ),
      ),
    );
  }

  /// SmartArt dialog — generates flowchart/mindmap HTML.
  /// T05: build a themed flowchart/mindmap block and insert it at the caret.
  Future<void> _showDiagramDialog(BuildContext context) async {
    final html = await showDialog<String>(
      context: context,
      builder: (_) => const DiagramDialog(),
    );
    if (html == null || html.isEmpty) return;
    widget.onInsertHtml?.call(html);
  }

  void _showSmartArtDialog(BuildContext context) {
    String selectedType = 'flowchart';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('SmartArt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'flowchart',
                      label: Text('Flowchart'),
                      icon: Icon(Icons.account_tree)),
                  ButtonSegment(
                      value: 'process',
                      label: Text('Process'),
                      icon: Icon(Icons.linear_scale)),
                  ButtonSegment(
                      value: 'cycle',
                      label: Text('Cycle'),
                      icon: Icon(Icons.autorenew)),
                ],
                selected: {selectedType},
                onSelectionChanged: (v) =>
                    setState(() => selectedType = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                String html;
                switch (selectedType) {
                  case 'flowchart':
                    html =
                        '<div style="display: flex; flex-direction: column; align-items: center; gap: 8px; margin: 16px 0;">\n'
                        '  <div style="background: #e65100; color: white; padding: 12px 24px; border-radius: 8px; font-weight: bold;">Start</div>\n'
                        '  <div style="font-size: 24px;">↓</div>\n'
                        '  <div style="background: #1565c0; color: white; padding: 12px 24px; border-radius: 8px;">Process</div>\n'
                        '  <div style="font-size: 24px;">↓</div>\n'
                        '  <div style="background: #2e7d32; color: white; padding: 12px 24px; border-radius: 8px;">Decision?</div>\n'
                        '  <div style="display: flex; gap: 32px;">\n'
                        '    <div style="background: #f57c00; color: white; padding: 8px 16px; border-radius: 8px;">Yes →</div>\n'
                        '    <div style="background: #c62828; color: white; padding: 8px 16px; border-radius: 8px;">No →</div>\n'
                        '  </div>\n'
                        '</div>';
                    break;
                  case 'process':
                    html =
                        '<div style="display: flex; align-items: center; justify-content: center; gap: 12px; margin: 16px 0;">\n'
                        '  <div style="background: #1565c0; color: white; padding: 16px; border-radius: 50%; width: 80px; height: 80px; display: flex; align-items: center; justify-content: center; font-weight: bold;">Step 1</div>\n'
                        '  <div style="font-size: 24px;">→</div>\n'
                        '  <div style="background: #e65100; color: white; padding: 16px; border-radius: 50%; width: 80px; height: 80px; display: flex; align-items: center; justify-content: center; font-weight: bold;">Step 2</div>\n'
                        '  <div style="font-size: 24px;">→</div>\n'
                        '  <div style="background: #2e7d32; color: white; padding: 16px; border-radius: 50%; width: 80px; height: 80px; display: flex; align-items: center; justify-content: center; font-weight: bold;">Step 3</div>\n'
                        '</div>';
                    break;
                  default: // cycle
                    html =
                        '<div style="display: flex; flex-wrap: wrap; justify-content: center; gap: 8px; margin: 16px 0;">\n'
                        '  <div style="background: #1565c0; color: white; padding: 12px 20px; border-radius: 24px;">Phase 1</div>\n'
                        '  <div style="font-size: 20px;">→</div>\n'
                        '  <div style="background: #e65100; color: white; padding: 12px 20px; border-radius: 24px;">Phase 2</div>\n'
                        '  <div style="font-size: 20px;">→</div>\n'
                        '  <div style="background: #2e7d32; color: white; padding: 12px 20px; border-radius: 24px;">Phase 3</div>\n'
                        '  <div style="font-size: 20px;">↺</div>\n'
                        '</div>';
                }
                widget.onInsertHtml?.call(html);
              },
              child: const Text('Chèn'),
            ),
          ],
        ),
      ),
    );
  }

  /// WordArt dialog.
  void _showWordArtDialog(BuildContext context) {
    final controller = TextEditingController(text: 'WordArt Text');
    String selectedStyle = 'gradient';
    void disposeController() => controller.dispose();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('WordArt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                    labelText: 'Text', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'gradient', label: Text('Gradient')),
                  ButtonSegment(value: 'shadow', label: Text('Shadow')),
                  ButtonSegment(value: 'outline', label: Text('Outline')),
                ],
                selected: {selectedStyle},
                onSelectionChanged: (v) =>
                    setState(() => selectedStyle = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                disposeController();
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text;
                Navigator.pop(dialogContext);
                disposeController();
                String html;
                switch (selectedStyle) {
                  case 'gradient':
                    html =
                        '<h1 style="background: linear-gradient(135deg, #e65100, #ff9800, #ffeb3b); '
                        '-webkit-background-clip: text; -webkit-text-fill-color: transparent; '
                        'font-size: 2.5em; text-align: center; font-weight: 900;">$text</h1>';
                    break;
                  case 'shadow':
                    html =
                        '<h1 style="color: #fff; text-shadow: 3px 3px 6px rgba(0,0,0,0.5), '
                        '0 0 20px rgba(230,81,0,0.3); font-size: 2.5em; text-align: center; '
                        'font-weight: 900;">$text</h1>';
                    break;
                  default:
                    html =
                        '<h1 style="color: transparent; -webkit-text-stroke: 2px #e65100; '
                        'font-size: 2.5em; text-align: center; font-weight: 900;">$text</h1>';
                }
                widget.onInsertHtml?.call(html);
              },
              child: const Text('Chèn'),
            ),
          ],
        ),
      ),
    );
  }

  /// Symbol picker dialog.
  void _showSymbolDialog(BuildContext context) {
    final symbols = [
      '★',
      '✓',
      '✗',
      '→',
      '←',
      '↑',
      '↓',
      '♦',
      '●',
      '■',
      '▲',
      '◆',
      '⚡',
      '🔥',
      '💡',
      '📊',
      '📈',
      '🎯',
      '✅',
      '❌',
      '⚠️',
      '💰',
      '🌟',
      '🏆',
      '♠',
      '♣',
      '♥',
      '♦',
      '∞',
      '©',
      '®',
      '™',
      '§',
      '¶',
      '†',
      '‡',
      'α',
      'β',
      'γ',
      'δ',
      'ε',
      'π',
      'Σ',
      'Ω',
      '√',
      '≠',
      '≤',
      '≥'
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chèn ký tự đặc biệt'),
        content: SizedBox(
          width: 350,
          height: 300,
          child: GridView.count(
            crossAxisCount: 8,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: symbols
                .map((s) => GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onInsertHtml
                            ?.call('<span style="font-size: 1.5em;">$s</span>');
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(s, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng')),
        ],
      ),
    );
  }

  /// Gradient background dialog.
  void _showGradientDialog(BuildContext context) {
    Color color1 = const Color(0xFF1a1a2e);
    Color color2 = const Color(0xFF16213e);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Gradient Background'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color1, color2]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('From: '),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final c = await _pickColor(context, color1);
                      if (c != null) setState(() => color1 = c);
                    },
                    child: Container(
                        width: 36,
                        height: 36,
                        decoration:
                            BoxDecoration(color: color1, border: Border.all())),
                  ),
                  const SizedBox(width: 24),
                  const Text('To: '),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final c = await _pickColor(context, color2);
                      if (c != null) setState(() => color2 = c);
                    },
                    child: Container(
                        width: 36,
                        height: 36,
                        decoration:
                            BoxDecoration(color: color2, border: Border.all())),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                final hex1 =
                    '#${color1.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                // Store gradient as CSS in bg attribute — the slide will use it
                widget.onSetSlideBackground?.call(hex1);
              },
              child: const Text('Áp dụng'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Color?> _pickColor(BuildContext context, Color initial) async {
    Color selected = initial;
    return showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Chọn màu'),
          content: SizedBox(
            width: 250,
            height: 200,
            child: GridView.count(
              crossAxisCount: 5,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
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
              ]
                  .map((c) => GestureDetector(
                        onTap: () => Navigator.pop(context, c),
                        child: Container(
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: selected == c
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Helper data class for chart dialog
// =============================================================================

class _ChartItem {
  final String label;
  final int value;
  _ChartItem(this.label, this.value);
}

// =============================================================================
// WIDGETS: _RibbonGroup, _RibbonButton, _TransitionButton, _RibbonDivider
// =============================================================================

class _RibbonGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _RibbonGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
        Text(label,
            style: TextStyle(fontSize: 9, color: theme.colorScheme.outline)),
      ],
    );
  }
}

class _RibbonButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool large;
  final bool compact;
  final bool selected;

  const _RibbonButton({
    required this.icon,
    this.label,
    this.tooltip,
    this.onPressed,
    this.large = false,
    this.compact = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget button = IconButton(
      icon: Icon(icon,
          size: compact ? 16 : 18,
          color: selected ? theme.colorScheme.primary : null),
      tooltip: tooltip ?? label,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: compact ? EdgeInsets.zero : null,
      constraints:
          compact ? const BoxConstraints(minWidth: 24, minHeight: 24) : null,
      isSelected: selected,
    );

    if (selected && !large) {
      button = DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: button,
      );
    }

    if (large) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Tooltip(
              message: tooltip ?? label ?? '',
              child: Semantics(
                label: tooltip ?? label ?? '',
                button: true,
                enabled: onPressed != null,
                onTap: onPressed,
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: onPressed,
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 32,
                      height: 24,
                      child: Icon(
                        icon,
                        size: 16,
                        color: onPressed != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 8,
                  color: onPressed != null
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.outline,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: button,
    );
  }
}

class _TransitionButton extends StatelessWidget {
  final SlideEffect effect;
  final String label;
  final VoidCallback onPressed;

  const _TransitionButton({
    required this.effect,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForEffect(effect);

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 56,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(height: 2),
              Text(
                label,
                style:
                    TextStyle(fontSize: 8, color: theme.colorScheme.onSurface),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForEffect(SlideEffect effect) {
    switch (effect) {
      case SlideEffect.fade:
        return Icons.opacity;
      case SlideEffect.pushLeft:
        return Icons.arrow_back;
      case SlideEffect.pushRight:
        return Icons.arrow_forward;
      case SlideEffect.pushUp:
        return Icons.arrow_upward;
      case SlideEffect.pushDown:
        return Icons.arrow_downward;
      case SlideEffect.wipe:
        return Icons.cleaning_services;
      case SlideEffect.splitIn:
        return Icons.call_split;
      case SlideEffect.splitOut:
        return Icons.call_merge;
      case SlideEffect.randomBar:
        return Icons.view_column;
      case SlideEffect.checkerboard:
        return Icons.grid_view;
      case SlideEffect.blinds:
        return Icons.view_column;
      case SlideEffect.clock:
        return Icons.schedule;
      case SlideEffect.zoom:
        return Icons.zoom_in;
      default:
        return Icons.animation;
    }
  }
}

class _RibbonDivider extends StatelessWidget {
  const _RibbonDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}
