import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../providers/presentation_state.dart';
import '../services/present_deck_commands.dart';
import '../services/present_tools_service.dart';
import '../services/setup_show_service.dart';
import '../services/webview_runtime_service.dart';

/// Fullscreen in-app presentation mode (Track 35 — Present Pro).
///
/// Loads the standalone HTML deck into a WebView2 and layers the pro tools on
/// top: ink pen / highlighter / laser (drawn inside the deck via JS pointer
/// events), magnifier (Ctrl+wheel), black/white screen (B/W), grid navigator
/// (G), direct slide jump (type number + Enter), and a key help overlay (?).
class PresentScreen extends StatefulWidget {
  final PresentationState state;
  final int startSlide;

  /// Track 36: slide order when presenting a custom show (null = whole deck).
  final List<int>? customShowOrder;

  /// Track 36: setup-show settings applied for this session.
  final SetupShowSettings? setupShow;

  const PresentScreen({
    super.key,
    required this.state,
    this.startSlide = 0,
    this.customShowOrder,
    this.setupShow,
  });

  @override
  State<PresentScreen> createState() => _PresentScreenState();
}

class _PresentScreenState extends State<PresentScreen> {
  final _controller = WebviewController();
  final _tools = PresentToolsService();
  final _runtime = WebViewRuntimeService();
  bool _ready = false;
  bool _failed = false;
  bool _showHelp = false;
  String? _errorMessage;
  int _currentSlide = 0;
  bool _inkInstalled = false;
  int _totalSlides = 0;
  Timer? _slidePollTimer;

  @override
  void initState() {
    super.initState();
    final order = widget.customShowOrder;
    final count = order != null && order.isNotEmpty
        ? order.length
        : widget.state.slides.length;
    _totalSlides = count;
    _currentSlide =
        count == 0 ? 0 : widget.startSlide.clamp(0, count - 1).toInt();
    _tools.addListener(_onToolsChanged);
    _init();
  }

  @override
  void dispose() {
    _slidePollTimer?.cancel();
    _tools.removeListener(_onToolsChanged);
    _tools.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onToolsChanged() {
    if (!mounted) return;
    setState(() {});
    // Push tool state into the deck JS (installed once deck is ready).
    _syncToolToDeck();
  }

  Future<void> _syncToolToDeck() async {
    if (!_ready || !_inkInstalled) return;
    try {
      await _controller.executeScript(
          PresentDeckCommands.setInkTool(_tools.tool == PresentTool.pen
              ? 'pen'
              : _tools.tool == PresentTool.highlighter
                  ? 'highlighter'
                  : _tools.tool == PresentTool.laser
                      ? 'laser'
                      : 'none'));
      final color = _tools.tool == PresentTool.highlighter
          ? _tools.settings.highlighterColor.cssHex
          : _tools.settings.penColor.cssHex;
      await _controller.executeScript(PresentDeckCommands.setInkColor(color));
      await _controller.executeScript(PresentDeckCommands.setInkWidth(
          _tools.tool == PresentTool.highlighter
              ? 14.0
              : _tools.settings.penWidth));
      if (_tools.blackScreen) {
        await _controller
            .executeScript(PresentDeckCommands.setScreen('#000000'));
      } else if (_tools.whiteScreen) {
        await _controller
            .executeScript(PresentDeckCommands.setScreen('#FFFFFF'));
      } else {
        await _controller.executeScript(PresentDeckCommands.setScreen(''));
      }
      await _controller.executeScript(PresentDeckCommands.setZoom(_tools.zoom));
    } catch (_) {
      // Deck may be navigating; ignore transient JS errors.
    }
  }

  Future<void> _init() async {
    try {
      await _controller.initialize().timeout(const Duration(seconds: 30));
      await _controller.setBackgroundColor(Colors.black);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      final html = widget.state.buildHtmlDeck(
        startIndex: _currentSlide,
        slideOrder: widget.customShowOrder,
      );
      // Track 36, P3: strip narration/animations when the setup show asks.
      final show = widget.setupShow;
      final useHtml = (show != null &&
              (show.showWithoutNarration || show.showWithoutAnimation))
          ? _stripDeckFeatures(html, show)
          : html;
      // Install the pro JS (ink overlay + keyboard) on document creation.
      await _controller.addScriptToExecuteOnDocumentCreated(
          PresentDeckCommands.installInkOverlay(
              _tools.settings.penColor.cssHex, _tools.settings.penWidth));
      await _controller.addScriptToExecuteOnDocumentCreated(
          PresentDeckCommands.installProKeys());
      await _controller
          .loadStringContent(useHtml)
          .timeout(const Duration(seconds: 30));
      _inkInstalled = true;
      await _syncToolToDeck();
      if (mounted) setState(() => _ready = true);
      _startSlidePoll();
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// Track 36, P3: remove narration `<audio>` tags and animation CSS/classes
  /// from the deck HTML when the setup show requests them off.
  static String _stripDeckFeatures(String html, SetupShowSettings show) {
    var out = html;
    if (show.showWithoutNarration) {
      out = out.replaceAll(RegExp(r'<audio\b[^>]*>[\s\S]*?</audio>'), '');
      out =
          out.replaceAll(RegExp(r'<audio\b[^>]*/>', caseSensitive: false), '');
    }
    if (show.showWithoutAnimation) {
      // Remove ghita-anim-* CSS blocks and inline animation styles.
      out = out.replaceAll(
          RegExp(r'\.ghita-anim-[^{]*\{[^}]*\}', caseSensitive: false), '');
      out = out.replaceAll(
          RegExp(r'animation-[a-z]+:\s*[^;]+;', caseSensitive: false), '');
    }
    return out;
  }

  void _startSlidePoll() {
    _slidePollTimer?.cancel();
    _slidePollTimer =
        Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (!mounted) return;
      try {
        final idx = await _controller
            .executeScript(PresentDeckCommands.getCurrentSlideExpr());
        if (idx is int &&
            idx != _currentSlide &&
            idx >= 0 &&
            idx < _totalSlides) {
          _currentSlide = idx;
          if (mounted) setState(() {});
        }
      } catch (_) {}
    });
  }

  void _handleAction(PresentAction action) {
    switch (action) {
      case PresentAction.nextSlide:
        _controller.executeScript(PresentDeckCommands.nextSlide());
      case PresentAction.prevSlide:
        _controller.executeScript(PresentDeckCommands.prevSlide());
      case PresentAction.toggleGrid:
        _tools.toggleGrid();
        _showGridNavigator();
      case PresentAction.toggleBlack:
        _tools.toggleBlackScreen();
      case PresentAction.toggleWhite:
        _tools.toggleWhiteScreen();
      case PresentAction.toggleLaser:
        _tools.toggleLaser();
      case PresentAction.togglePen:
        _tools.togglePen();
      case PresentAction.toggleHighlighter:
        _tools.toggleHighlighter();
      case PresentAction.toggleMagnifier:
        _tools.toggleMagnifier();
      case PresentAction.openHelp:
        setState(() => _showHelp = !_showHelp);
      case PresentAction.none:
        break;
    }
  }

  void _jumpToSlide(int index) {
    _currentSlide = index;
    _controller.executeScript(PresentDeckCommands.goToSlide(index));
  }

  void _showGridNavigator() {
    if (!_tools.gridOpen) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2233),
        title: Text(context.l10n.presentGridTitle,
            style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 420,
          height: 320,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 72,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _totalSlides,
            itemBuilder: (_, i) => InkWell(
              onTap: () {
                _jumpToSlide(i);
                Navigator.pop(ctx);
                _tools.closeGrid();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: i == _currentSlide
                      ? const Color(0xFF3A8FD4)
                      : const Color(0xFF2A3A5A),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tools.closeGrid();
            },
            child: Text(context.l10n.cancel,
                style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    ).then((_) => _tools.closeGrid());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_tools.gridOpen) {
            _tools.closeGrid();
          } else {
            Navigator.of(context).pop();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _handleAction(PresentAction.nextSlide),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _handleAction(PresentAction.prevSlide),
        const SingleActivator(LogicalKeyboardKey.keyG): () =>
            _handleAction(PresentAction.toggleGrid),
        const SingleActivator(LogicalKeyboardKey.keyB): () =>
            _handleAction(PresentAction.toggleBlack),
        const SingleActivator(LogicalKeyboardKey.keyW): () =>
            _handleAction(PresentAction.toggleWhite),
        const SingleActivator(LogicalKeyboardKey.keyL): () =>
            _handleAction(PresentAction.toggleLaser),
        const SingleActivator(LogicalKeyboardKey.keyP): () =>
            _handleAction(PresentAction.togglePen),
        const SingleActivator(LogicalKeyboardKey.keyM): () =>
            _handleAction(PresentAction.toggleMagnifier),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              if (_failed)
                _buildError(l10n)
              else if (!_ready)
                const Center(
                    child: CircularProgressIndicator(color: Colors.white))
              else
                Positioned.fill(child: Webview(_controller)),
              // WebView2 runtime banner (OPT 21 — fail fast instead of timeout).
              if (_runtime.probed && !_runtime.available && _ready)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: const Color(0xFF5B2A1A),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      l10n.webviewRuntimeMissing,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              // Black / white screen overlay.
              if (_tools.blackScreen || _tools.whiteScreen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => _tools.clearScreens(),
                    child: ColoredBox(
                      color: _tools.blackScreen ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              // Magnifier ring when active (P6).
              if (_tools.magnifier)
                Positioned.fill(child: _MagnifierRing(tools: _tools)),
              // Bottom-left tools bar.
              if (_ready)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _buildToolsBar(l10n),
                ),
              // Top-right exit + help.
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.help_outline,
                          color: Colors.white, size: 20),
                      tooltip: l10n.presentHelp,
                      onPressed: () => setState(() => _showHelp = !_showHelp),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(l10n.presentExit),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
              // Slide counter (top-left).
              Positioned(
                top: 14,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_currentSlide + 1} / $_totalSlides',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
              if (_showHelp) _buildHelpOverlay(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(l10n.presentLaunchFailed,
                style: TextStyle(color: Colors.grey.shade300, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? l10n.unknownError,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toolButton(Icons.edit, l10n.presentPen, PresentTool.pen,
              _tools.settings.penColor.cssHex),
          const SizedBox(width: 4),
          _toolButton(Icons.border_color, l10n.presentHighlighter,
              PresentTool.highlighter, _tools.settings.highlighterColor.cssHex),
          const SizedBox(width: 4),
          _toolButton(Icons.my_location, l10n.presentLaser, PresentTool.laser,
              _tools.settings.penColor.cssHex),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.zoom_in,
                color: _tools.magnifier ? Colors.lightBlueAccent : Colors.white,
                size: 18),
            tooltip: l10n.presentMagnifier,
            onPressed: () => _tools.toggleMagnifier(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.clear_all,
                color: _tools.strokes.isEmpty ? Colors.white38 : Colors.white,
                size: 18),
            tooltip: l10n.presentClearInk,
            onPressed: _tools.clearStrokes,
          ),
        ],
      ),
    );
  }

  Widget _toolButton(
      IconData icon, String tooltip, PresentTool tool, String colorHex) {
    final active = _tools.tool == tool;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(
          color: active ? const Color(0xFF3A8FD4) : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: Icon(icon, color: Colors.white, size: 18),
            tooltip: tooltip,
            onPressed: () => _tools.setTool(tool),
          ),
          Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _parseHex(colorHex),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpOverlay(AppLocalizations l10n) {
    final rows = [
      (l10n.presentHelpKeysG, 'G'),
      (l10n.presentHelpKeysB, 'B / W'),
      (l10n.presentHelpKeysP, 'P'),
      (l10n.presentHelpKeysL, 'L'),
      (l10n.presentHelpKeysM, 'Ctrl + Scroll'),
      (l10n.presentHelpKeysNumber, '1–9 + Enter'),
      (l10n.presentHelpKeysEsc, 'Esc'),
    ];
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showHelp = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          alignment: Alignment.center,
          child: Card(
            color: const Color(0xFF1A2233),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.presentHelp,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  for (final (label, key) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A3A5A),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(key,
                                style: const TextStyle(
                                    color: Colors.lightBlueAccent,
                                    fontSize: 12,
                                    fontFamily: 'monospace')),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(label,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(l10n.presentHelpClose,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _parseHex(String hex) {
    try {
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    } catch (_) {
      return const Color(0xFFED1C24);
    }
  }
}

/// Follows the mouse while magnifier is on — draws a ring and a scaled inset
/// of the deck (Track 35, P6). The deck itself is zoomed via JS; this ring
/// gives the visible focus indicator.
class _MagnifierRing extends StatefulWidget {
  final PresentToolsService tools;
  const _MagnifierRing({required this.tools});

  @override
  State<_MagnifierRing> createState() => _MagnifierRingState();
}

class _MagnifierRingState extends State<_MagnifierRing> {
  Offset _pos = Offset.zero;
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: (e) => setState(() {
        _pos = e.position;
        _visible = true;
      }),
      onPointerCancel: (_) => setState(() => _visible = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        onExit: (_) => setState(() => _visible = false),
        child: IgnorePointer(
          child: CustomPaint(
            painter: _MagnifierPainter(
              pos: _pos,
              visible: _visible,
              zoom: widget.tools.zoom,
            ),
          ),
        ),
      ),
    );
  }
}

class _MagnifierPainter extends CustomPainter {
  final Offset pos;
  final bool visible;
  final double zoom;

  _MagnifierPainter(
      {required this.pos, required this.visible, required this.zoom});

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final center = pos;
    const radius = 60.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF3A8FD4);
    canvas.drawCircle(center, radius, paint);
    // ignore: prefer_const_constructors
    final label = TextPainter(
      text: TextSpan(
        text: '${(zoom * 100).round()}%',
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, center + const Offset(-20, 66));
  }

  @override
  bool shouldRepaint(covariant _MagnifierPainter old) =>
      old.pos != pos || old.visible != visible || old.zoom != zoom;
}
