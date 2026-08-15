import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../providers/presentation_state.dart';
import '../services/present_deck_commands.dart';
import '../services/present_tools_service.dart';

/// Presenter View (Track 35, P3) — one WebView2 running the full deck; JS
/// commands drive the current slide, the right panel shows the next-slide
/// thumbnail, speaker notes, timer and navigation. Uses a single WebView2
/// (instead of one preview per slide) to cut RAM and keep sync exact.
class PresenterViewScreen extends StatefulWidget {
  final PresentationState state;
  final int startSlide;

  const PresenterViewScreen({
    super.key,
    required this.state,
    this.startSlide = 0,
  });

  @override
  State<PresenterViewScreen> createState() => _PresenterViewScreenState();
}

class _PresenterViewScreenState extends State<PresenterViewScreen> {
  final _controller = WebviewController();
  final _tools = PresentToolsService();
  late int _currentSlide;
  late Timer _timer;
  int _elapsedSeconds = 0;
  bool _showNavigator = false;
  bool _ready = false;
  bool _failed = false;
  int _totalSlides = 0;

  @override
  void initState() {
    super.initState();
    final count = widget.state.slides.length;
    _totalSlides = count;
    _currentSlide =
        count == 0 ? 0 : widget.startSlide.clamp(0, count - 1).toInt();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    _initWebview();
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initWebview() async {
    try {
      await _controller.initialize().timeout(const Duration(seconds: 30));
      await _controller.setBackgroundColor(Colors.black);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.addScriptToExecuteOnDocumentCreated(
          PresentDeckCommands.installPresenterSync());
      await _controller.addScriptToExecuteOnDocumentCreated(
          PresentDeckCommands.installProKeys());
      await _controller.addScriptToExecuteOnDocumentCreated(
          PresentDeckCommands.installInkOverlay(
              _tools.settings.penColor.cssHex, _tools.settings.penWidth));
      final html = widget.state.buildHtmlDeck(startIndex: _currentSlide);
      await _controller.loadStringContent(html).timeout(const Duration(seconds: 30));
      if (mounted) setState(() => _ready = true);
      _startSync();
    } catch (e) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _startSync() {
    Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final idx =
            await _controller.executeScript(PresentDeckCommands.getCurrentSlideExpr());
        if (idx is int && idx != _currentSlide && idx >= 0 && idx < _totalSlides) {
          _currentSlide = idx;
          if (mounted) setState(() {});
        }
      } catch (_) {}
    });
  }

  void _nextSlide() {
    if (_currentSlide < _totalSlides - 1) {
      _currentSlide++;
      _controller.executeScript(PresentDeckCommands.goToSlide(_currentSlide));
      setState(() {});
    }
  }

  void _prevSlide() {
    if (_currentSlide > 0) {
      _currentSlide--;
      _controller.executeScript(PresentDeckCommands.goToSlide(_currentSlide));
      setState(() {});
    }
  }

  void _jumpTo(int index) {
    _currentSlide = index;
    _controller.executeScript(PresentDeckCommands.goToSlide(index));
    setState(() {});
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.state.slides;
    final l10n = context.l10n;
    if (slides.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No slides to present.',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    if (_currentSlide >= slides.length) {
      _currentSlide = slides.length - 1;
    }
    final current = slides[_currentSlide];
    final nextSlide =
        _currentSlide < slides.length - 1 ? slides[_currentSlide + 1] : null;
    final theme = Theme.of(context);
    // ignore: unused_local_variable
    final _ = theme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.pop(context),
          const SingleActivator(LogicalKeyboardKey.arrowRight): _nextSlide,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _prevSlide,
          const SingleActivator(LogicalKeyboardKey.space): _nextSlide,
          const SingleActivator(LogicalKeyboardKey.keyG): () =>
              setState(() => _showNavigator = !_showNavigator),
        },
        child: Focus(
          autofocus: true,
          child: Row(
            children: [
              // Left: the single WebView2 deck (70%).
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    _buildTopBar(theme, l10n),
                    Expanded(
                      child: _ready
                          ? Stack(
                              children: [
                                Positioned.fill(child: Webview(_controller)),
                                if (_tools.blackScreen || _tools.whiteScreen)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onTap: () => _tools.clearScreens(),
                                      child: ColoredBox(
                                        color: _tools.blackScreen
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : (_failed
                              ? Center(
                                  child: Text(
                                    l10n.presentLaunchFailed,
                                    style: TextStyle(color: Colors.grey.shade500),
                                  ),
                                )
                              : const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white))),
                    ),
                  ],
                ),
              ),

              // Right panel (30%).
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.grey.shade900,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.presenterNextSlide,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        flex: 2,
                        child: nextSlide != null
                            ? _NextSlideCard(
                                title: nextSlide.title,
                                html: nextSlide.htmlContent,
                                l10n: l10n,
                              )
                            : _EndCard(l10n: l10n),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.presenterSpeakerNotes,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: current.notes.isNotEmpty
                              ? SingleChildScrollView(
                                  child: Text(
                                    current.notes,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    l10n.presenterNoNotes,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(_elapsedSeconds),
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 14,
                              fontFamily: 'monospace',
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      if (_showNavigator) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 56,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                            itemCount: _totalSlides,
                            itemBuilder: (_, i) => InkWell(
                              onTap: () => _jumpTo(i),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: i == _currentSlide
                                      ? const Color(0xFF3A8FD4)
                                      : Colors.grey.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.center,
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, AppLocalizations l10n) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Text(
            '${l10n.slide} ${_currentSlide + 1} / $_totalSlides',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              size: 20,
              color: _currentSlide > 0 ? Colors.white : Colors.grey.shade700,
            ),
            onPressed: _currentSlide > 0 ? _prevSlide : null,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              size: 20,
              color: _currentSlide < _totalSlides - 1
                  ? Colors.white
                  : Colors.grey.shade700,
            ),
            onPressed: _currentSlide < _totalSlides - 1 ? _nextSlide : null,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _showNavigator ? Icons.grid_view : Icons.grid_on,
              size: 18,
              color: Colors.grey.shade400,
            ),
            onPressed: () => setState(() => _showNavigator = !_showNavigator),
            visualDensity: VisualDensity.compact,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatTime(_elapsedSeconds),
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Next-slide thumbnail card (text fallback — kept cheap so the single
/// WebView2 on the left is the only heavy renderer).
class _NextSlideCard extends StatelessWidget {
  final String title;
  final String html;
  final AppLocalizations l10n;

  const _NextSlideCard({
    required this.title,
    required this.html,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.shade800,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _plainText(html),
                  style: TextStyle(
                      color: Colors.grey.shade300, fontSize: 12, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _plainText(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _EndCard extends StatelessWidget {
  final AppLocalizations l10n;
  const _EndCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Text(
          l10n.presenterEndOfPresentation,
          style: TextStyle(color: Colors.grey.shade500),
        ),
      ),
    );
  }
}
