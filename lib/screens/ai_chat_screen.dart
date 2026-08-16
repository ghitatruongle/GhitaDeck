import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/l10n.dart';
import '../providers/ai_provider_manager.dart';
import '../providers/presentation_state.dart';
import '../services/copilot_service.dart';
import '../services/deck_translation_service.dart';

class AiChatScreen extends StatefulWidget {
  final AIProviderManager aiProviderManager;

  const AiChatScreen({super.key, required this.aiProviderManager});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const _chatHistoryKey = 'ai_chat_history';
  final _messageController = TextEditingController();
  final _messages = <Map<String, dynamic>>[];
  bool _isGenerating = false;
  bool _isStreaming = false;
  bool _outlineMode = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_chatHistoryKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        // Only load user/assistant messages (skip progress messages)
        final loaded = list.whereType<Map<String, dynamic>>().where((m) {
          final role = m['role'] as String?;
          return role == 'user' || role == 'assistant' || role == 'multi_slide';
        }).toList();
        if (loaded.isNotEmpty && mounted) {
          setState(() {
            _messages.addAll(loaded);
          });
        }
      } catch (_) {
        // Corrupted history — ignore
      }
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Only persist meaningful messages (skip progress/empty)
      final toSave = _messages.where((m) {
        final content = m['content'] as String?;
        return content != null && content.isNotEmpty;
      }).toList();
      await prefs.setString(_chatHistoryKey, jsonEncode(toSave));
    } catch (_) {
      // Storage full or unavailable — non-critical
    }
  }

  void _addMessage(Map<String, dynamic> message) {
    if (!mounted) return;
    setState(() {
      _messages.add(message);
    });
    unawaited(_saveChatHistory());
  }

  @override
  void dispose() {
    widget.aiProviderManager.cancelStream();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the header whenever the manager notifies (provider change,
    // model edit, etc.) — reading via Provider keeps the displayed name/model
    // in sync instead of going stale until the next external rebuild.
    final aiManager = Provider.of<AIProviderManager>(context);
    final selectedProvider = aiManager.selectedProvider;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header with provider selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            selectedProvider != null &&
                                    selectedProvider.formatType == 'anthropic'
                                ? Icons.smart_toy_outlined
                                : Icons.psychology_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Assistant',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (selectedProvider != null)
                                Text(
                                  '${selectedProvider.name} · ${selectedProvider.selectedModel}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note),
                    tooltip: 'System Prompt',
                    onPressed: _showSystemPromptEditor,
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Provider Settings',
                    onPressed: _showProviderSettings,
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(
                          value: false,
                          label: Text('Chat', style: TextStyle(fontSize: 12))),
                      ButtonSegment(
                          value: true,
                          label:
                              Text('Outline', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {_outlineMode},
                    onSelectionChanged: (sel) =>
                        setState(() => _outlineMode = sel.first),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Messages area
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['role'] == 'user';
                      final String content = message['content'] ?? '';
                      final List? slides = message['slides'];

                      return Align(
                        key: ValueKey('msg_$index'),
                        alignment:
                            isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.8),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUser
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUser ? 'You' : (selectedProvider?.name ?? 'AI'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isUser
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(content),
                              if (slides != null && slides.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      ...slides.map((s) {
                                        final title =
                                            s['title'] ?? 'Untitled';
                                        return ActionChip(
                                          avatar: const Icon(
                                              Icons.add_to_photos,
                                              size: 16),
                                          label: Text('Add "$title"',
                                              style:
                                                  const TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            Provider.of<PresentationState>(
                                                    context,
                                                    listen: false)
                                                .addSlide(Slide(
                                              title: title,
                                              htmlContent:
                                                  s['htmlContent'] ?? '',
                                            ));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      context.l10n.addedSlideNotice(title))),
                                            );
                                          },
                                        );
                                      }),
                                      if (slides.length > 1)
                                        ActionChip(
                                          avatar: const Icon(
                                              Icons.add_circle_outline,
                                              size: 16),
                                          label: Text(context.l10n.addAllSlides(slides.length),
                                              style:
                                                  const TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            final state = Provider.of<
                                                    PresentationState>(
                                                context,
                                                listen: false);
                                            for (final s in slides) {
                                              state.addSlide(Slide(
                                                title:
                                                    s['title'] ?? 'Untitled',
                                                htmlContent:
                                                    s['htmlContent'] ?? '',
                                              ));
                                            }
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Added all ${slides.length} slides!')),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              if (!isUser && content.contains('<') &&
                                  !content.startsWith('Error:') &&
                                  slides == null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.add_to_photos,
                                        size: 16),
                                    label: const Text('Add to Slides',
                                        style: TextStyle(fontSize: 12)),
                                    onPressed: () {
                                      Provider.of<PresentationState>(context,
                                              listen: false)
                                          .addSlide(Slide(
                                        title: 'AI Generated Slide',
                                        htmlContent: content,
                                      ));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Added to presentation slides!')),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 12),

          // Quick chips (Track 55, FEAT 88/89)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.auto_awesome, size: 14),
                label: Text(context.l10n.copilotCreateDeck),
                onPressed: _isGenerating
                    ? null
                    : () => _quickCreateDeck(),
              ),
              ActionChip(
                avatar: const Icon(Icons.subject, size: 14),
                label: Text(context.l10n.copilotSummarize),
                onPressed:
                    _isGenerating ? null : () => _quickSummarizeDeck(),
              ),
              ActionChip(
                avatar: const Icon(Icons.help_outline, size: 14),
                label: Text(context.l10n.copilotAskDeck),
                onPressed: _isGenerating ? null : () => _quickAskDeck(),
              ),
              ActionChip(
                avatar: const Icon(Icons.translate, size: 14),
                label: Text(context.l10n.translateDeck),
                onPressed: _isGenerating ? null : () => _quickTranslate(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // AI context toggle (Track 52, OPT 37) — privacy by choice.
          Row(
            children: [
              const SizedBox(width: 4),
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: widget.aiProviderManager.useDeckContext,
                  onChanged: (v) =>
                      widget.aiProviderManager.setUseDeckContext(v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.aiContextToggle,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Input section
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: _outlineMode
                  ? 'Describe a topic to build an outline...'
                  : 'Describe presentation topic or HTML slide content...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _isGenerating
                  ? (_isStreaming
                      ? IconButton(
                          icon: const Icon(Icons.stop_circle_outlined,
                              color: Colors.red),
                          tooltip: 'Stop generating',
                          onPressed: () =>
                              widget.aiProviderManager.cancelStream(),
                        )
                      : const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ))
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final text = _messageController.text.trim();
                        if (text.isNotEmpty && !_isGenerating) {
                          _messageController.clear();
                          if (_outlineMode) {
                            await _generateWithOutline(text);
                          } else {
                            await _generateHtmlForPresentation(text);
                          }
                        }
                      },
                    ),
            ),
            onSubmitted: (text) async {
              final trimmed = text.trim();
              if (trimmed.isNotEmpty && !_isGenerating) {
                _messageController.clear();
                if (_outlineMode) {
                  await _generateWithOutline(trimmed);
                } else {
                  await _generateHtmlForPresentation(trimmed);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'AI Presentation Assistant',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask AI to generate HTML slides for your presentation!\n'
            'e.g. "Create 3 slides about Machine Learning"',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateHtmlForPresentation(String prompt) async {
    _addMessage({'role': 'user', 'content': prompt});
    if (!mounted) return;
    setState(() {
      _isGenerating = true;
    });

    try {
      // Detect if user wants multiple slides
      final multiSlideMatch =
          RegExp(r'(?:create|generate|make|write)\s+(\d+)\s*(?:slide|presentation|topic)s?',
                  caseSensitive: false)
              .firstMatch(prompt);
      final slideCount = multiSlideMatch != null
          ? int.tryParse(multiSlideMatch.group(1) ?? '') ?? 3
          : 1;

      if (slideCount > 1) {
        final slides = await widget.aiProviderManager
            .generateMultipleSlides(prompt, slideCount: slideCount);

        if (mounted) {
          final content = 'Generated ${slides.length} slides for your topic.';
          _addMessage({
            'role': 'multi_slide',
            'content': content,
            'slides': slides,
          });
          if (mounted) setState(() => _isGenerating = false);
        }
      } else {
        // Single slide: stream the response so text appears as it arrives.
        final buffer = StringBuffer();
        _addMessage({'role': 'assistant', 'content': ''});
        if (!mounted) return;
        final msgIndex = _messages.length - 1;
        setState(() => _isStreaming = true);

        try {
          await for (final delta in
              widget.aiProviderManager.generateHtmlFromPromptStream(prompt)) {
            buffer.write(delta);
            if (mounted) {
              setState(() =>
                  _messages[msgIndex]['content'] = buffer.toString());
            }
          }
        } finally {
          if (mounted) setState(() => _isStreaming = false);
        }
        if (mounted) {
          setState(() {
            if (buffer.isEmpty) {
              _messages[msgIndex]['content'] = 'No response (cancelled?).';
            }
            _isGenerating = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _addMessage({'role': 'assistant', 'content': 'Error: ${e.toString()}'});
        if (mounted) setState(() => _isGenerating = false);
      }
    }
  }

  // ---- Quick actions (Track 55, FEAT 88/89) ----

  /// "Tạo bài thuyết trình" — ask for a topic, then build N slides.
  Future<void> _quickCreateDeck() async {
    final controller = TextEditingController(text: 'AI & Productivity');
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.copilotCreateDeck),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Topic',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('How many slides? (3–12)', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 6),
            child: const Text('Generate 6 slides'),
          ),
        ],
      ),
    );
    if (count == null || !mounted) return;
    final topic = controller.text.trim();
    if (topic.isEmpty) return;
    _outlineMode = true;
    await _generateWithOutline(topic);
  }

  /// "Tóm tắt deck" — send the deck outline to the AI and add a summary
  /// slide at the end.
  Future<void> _quickSummarizeDeck() async {
    final state = Provider.of<PresentationState>(context, listen: false);
    final slides = state.slides;
    if (slides.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.deckEmpty)));
      }
      return;
    }
    final prompt = CopilotService.buildDeckSummaryPrompt([
      for (final s in slides) {'title': s.title, 'htmlContent': s.htmlContent}
    ]);
    _addMessage({'role': 'user', 'content': 'Summarize my deck'});
    setState(() => _isGenerating = true);
    try {
      final html = await widget.aiProviderManager.generateSlideContent(prompt,
          customPrompt:
              'Return a concise 5-line summary as HTML (<h1>Summary</h1><ul><li>…).');
      state.addSlide(Slide(
        title: 'Summary',
        htmlContent: html,
      ));
      if (mounted) {
        _addMessage({'role': 'assistant', 'content': context.l10n.summarySlideAdded});
      }
    } catch (e) {
      if (mounted) {
        _addMessage({'role': 'assistant', 'content': 'Error: $e'});
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// "Hỏi về deck" — Q&A against the deck index.
  Future<void> _quickAskDeck() async {
    final state = Provider.of<PresentationState>(context, listen: false);
    final slides = state.slides;
    if (slides.isEmpty) return;
    final controller = TextEditingController();
    final question = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.copilotAskDeck),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: ctx.l10n.askDeckHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(ctx.l10n.send)),
        ],
      ),
    );
    if (question == null || question.isEmpty || !mounted) return;

    final index = CopilotService.buildDeckIndex([
      for (final s in slides) {'title': s.title, 'htmlContent': s.htmlContent}
    ]);
    final hits = CopilotService.searchDeckIndex(index, question);
    final contextText = hits.isEmpty
        ? '(no direct matches — the deck has ${slides.length} slides)'
        : hits
            .take(4)
            .map((i) => '#${i + 1}: ${index[i]['title']} — '
                '${index[i]['text'].toString().substring(0, index[i]['text'].toString().length.clamp(0, 160))}')
            .join('\n');
    _addMessage({'role': 'user', 'content': question});
    setState(() => _isGenerating = true);
    try {
      final answer = await widget.aiProviderManager.generateSlideContent(
        'Answer the question using ONLY these slide excerpts. '
        'Mention the slide number(s).\n\n$contextText\n\nQuestion: $question',
        customPrompt: 'Return a short HTML answer (<p> only).',
      );
      if (mounted) _addMessage({'role': 'assistant', 'content': answer});
    } catch (e) {
      if (mounted) _addMessage({'role': 'assistant', 'content': 'Error: $e'});
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// "Dịch toàn deck" (Track 56, FEAT 91) — translate every slide keeping
  /// HTML structure, with per-slide apply/cancel.
  Future<void> _quickTranslate() async {
    final state = Provider.of<PresentationState>(context, listen: false);
    final slides = state.slides;
    if (slides.isEmpty) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Translation uses the AI provider — one prompt per slide.')));
    }
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.l10n.translateDeck),
        children: [
          for (final lang in DeckTranslationService.supportedLanguages)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, lang),
              child: Text(DeckTranslationService.languageNames[lang] ?? lang),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;

    setState(() => _isGenerating = true);
    final translated = <int, String>{};
    var done = 0;
    for (var i = 0; i < slides.length; i++) {
      final slide = slides[i];
      final prompt = DeckTranslationService.buildTranslationPrompt(
          slide.htmlContent, target);
      try {
        final html = await widget.aiProviderManager.generateSlideContent(prompt,
            customPrompt: 'Translate HTML keeping tags/classes unchanged.');
        translated[i] = html;
        done++;
        if (mounted) {
          setState(() {
            _isGenerating = false; // re-enabled below per batch
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$done/${slides.length} translated…')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Slide ${i + 1} error: $e')));
          break;
        }
      }
      // Keep UI responsive between slides.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (mounted) setState(() => _isGenerating = false);

    if (translated.isEmpty || !mounted) return;
    final applyAll = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply translations?'),
        content:
            Text('${translated.length} slide(s) translated. Apply all?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply all')),
        ],
      ),
    );
    if (applyAll == true && mounted) {
      for (final entry in translated.entries) {
        final i = entry.key;
        final original = slides[i];
        state.updateSlide(
            i, original.copyWith(htmlContent: entry.value));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deck translated.')));
      }
    }
  }

  // ---- Outline mode ----

  Future<void> _generateWithOutline(String topic) async {
    _addMessage({'role': 'user', 'content': topic});
    if (!mounted) return;
    setState(() => _isGenerating = true);

    List<Map<String, dynamic>> outline;
    try {
      outline = await widget.aiProviderManager.generateOutline(topic);
    } catch (e) {
      if (mounted) {
        _addMessage({'role': 'assistant', 'content': 'Error: ${e.toString()}'});
        if (mounted) setState(() => _isGenerating = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isGenerating = false);

    final confirmed = await _showOutlineEditor(outline);
    if (confirmed == null || confirmed.isEmpty || !mounted) return;

    // Generate slides sequentially with a progress message.
    _addMessage({
      'role': 'assistant',
      'content': 'Generating 0/${confirmed.length} slides from outline...'
    });
    if (!mounted) return;
    final progressIndex = _messages.length - 1;
    setState(() => _isGenerating = true);
    final state = Provider.of<PresentationState>(context, listen: false);

    var generated = 0;
    for (final entry in confirmed) {
      try {
        final html = await widget.aiProviderManager
            .generateSlideFromOutline(topic, entry);
        state.addSlide(Slide(
          title: (entry['title'] ?? 'Untitled').toString(),
          htmlContent: html,
        ));
        generated++;
      } catch (e) {
        if (mounted) {
          _addMessage({
            'role': 'assistant',
            'content': 'Error on "${entry['title']}": $e'
          });
        }
        break;
      }
      if (mounted) {
        setState(() => _messages[progressIndex]['content'] =
            'Generating $generated/${confirmed.length} slides from outline...');
      }
    }
    if (mounted) {
      setState(() {
        _messages[progressIndex]['content'] =
            'Added $generated slide(s) from the outline to your presentation.';
        _isGenerating = false;
      });
      unawaited(_saveChatHistory());
    }
  }

  /// Show the editable outline; returns confirmed entries or null.
  Future<List<Map<String, dynamic>>?> _showOutlineEditor(
      List<Map<String, dynamic>> outline) {
    final entries = outline
        .map((e) => {
              'title': TextEditingController(text: e['title'].toString()),
              'bullets': TextEditingController(
                  text: ((e['bullets'] as List?) ?? const []).join('; ')),
            })
        .toList();
    // Keep every controller (including removed entries) for disposal.
    final allControllers = [
      for (final e in entries) ...[
        e['title'] as TextEditingController,
        e['bullets'] as TextEditingController,
      ]
    ];

    return showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Outline (${entries.length} slides)'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  key: ValueKey('entry_$index'),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller:
                                    entry['title'] as TextEditingController,
                                decoration: InputDecoration(
                                  labelText: 'Slide ${index + 1} title',
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'Remove slide',
                              onPressed: entries.length > 1
                                  ? () => setDialogState(
                                      () => entries.removeAt(index))
                                  : null,
                            ),
                          ],
                        ),
                        TextField(
                          controller:
                              entry['bullets'] as TextEditingController,
                          decoration: const InputDecoration(
                            labelText: 'Bullet points (separate with ;)',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate Slides'),
              onPressed: () {
                final confirmed = entries
                    .map((e) => {
                          'title':
                              (e['title'] as TextEditingController).text.trim(),
                          'bullets': (e['bullets'] as TextEditingController)
                              .text
                              .split(';')
                              .map((b) => b.trim())
                              .where((b) => b.isNotEmpty)
                              .toList(),
                        })
                    .where((e) => (e['title'] as String).isNotEmpty)
                    .toList();
                Navigator.pop(context, confirmed);
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Dispose controllers only after the exit animation finishes —
      // disposing earlier can crash TextField rebuilds during the fade-out.
      Future.delayed(const Duration(milliseconds: 400), () {
        for (final c in allControllers) {
          c.dispose();
        }
      });
    });
  }

  void _showSystemPromptEditor() {
    final manager = widget.aiProviderManager;
    final controller = TextEditingController(text: manager.systemPrompt);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom System Prompt'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'System Prompt',
              hintText:
                  'You are an expert in generating presentation HTML slides...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              manager.updateSystemPrompt(
                  'You are an expert in generating presentation HTML slides. '
                  'Return ONLY valid HTML fragment (no markdown, no explanation). '
                  'Use <h1> for title, <p> for paragraphs, <ul>/<li> for lists. '
                  'No external CSS/JS references.');
              Navigator.pop(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('System prompt reset to default!')),
              );
            },
            child: const Text('Reset to Default'),
          ),
          ElevatedButton(
            onPressed: () {
              manager.updateSystemPrompt(controller.text.trim());
              Navigator.pop(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('System prompt saved!')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() {
      // Dispose after the exit animation finishes (covers barrier dismiss too).
      Future.delayed(const Duration(milliseconds: 400), () {
        controller.dispose();
      });
    });
  }

  void _showProviderSettings() {
    final manager = widget.aiProviderManager;
    final currentProvider =
        manager.selectedProvider ?? AIProviderConfig.defaultProvider();
    final apiKeyController = TextEditingController(text: currentProvider.apiKey);
    final nameController = TextEditingController(text: currentProvider.name);
    final baseUrlController =
        TextEditingController(text: currentProvider.baseUrl);
    final temperatureController = TextEditingController(
        text: currentProvider.temperature.toStringAsFixed(1));
    final maxTokensController = TextEditingController(
        text: currentProvider.maxTokens.toString());
    final models = List<String>.from(currentProvider.availableModels);
    String selectedModel = currentProvider.selectedModel;
    String newModelInput = '';
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('AI Provider Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Provider Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.openai.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: models.contains(selectedModel) ? selectedModel : models.first,
                  decoration: const InputDecoration(
                    labelText: 'Active Model',
                    border: OutlineInputBorder(),
                  ),
                  items: models.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedModel = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text('Available Models:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...models.map((m) {
                      final isActive = m == selectedModel;
                      return Chip(
                        label: Text(m,
                            style: TextStyle(
                                fontSize: 11,
                                color: isActive
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface)),
                        backgroundColor: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        deleteIcon: Icon(Icons.close, size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        onDeleted: () {
                          if (models.length <= 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Provider must have at least 1 model.')),
                            );
                            return;
                          }
                          setDialogState(() {
                            models.remove(m);
                            if (selectedModel == m) {
                              selectedModel = models.first;
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Add new model',
                          hintText: 'e.g. gpt-4-turbo',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) => newModelInput = val.trim(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add model',
                      onPressed: () {
                        final trimmed = newModelInput.trim();
                        if (trimmed.isEmpty) return;
                        if (models.any((m) => m.toLowerCase() == trimmed.toLowerCase())) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"$trimmed" already exists.')),
                          );
                          return;
                        }
                        setDialogState(() {
                          models.add(trimmed);
                          selectedModel = trimmed;
                          newModelInput = '';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk-...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: temperatureController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Temperature (0.0 - 2.0)',
                    hintText: '0.7',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxTokensController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Tokens',
                    hintText: '4096',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final temperature =
                    double.tryParse(temperatureController.text.trim()) ?? 0.7;
                final maxTokens =
                    int.tryParse(maxTokensController.text.trim()) ?? 4096;
                if (models.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Provider must have at least 1 model.')),
                  );
                  return;
                }
                if (!models.contains(selectedModel)) {
                  selectedModel = models.first;
                }
                final updated = currentProvider.copyWith(
                  name: nameController.text.trim(),
                  baseUrl: baseUrlController.text.trim(),
                  apiKey: apiKeyController.text.trim(),
                  availableModels: models,
                  selectedModel: selectedModel,
                  temperature: temperature.clamp(0.0, 2.0),
                  maxTokens: maxTokens.clamp(1, 128000),
                );
                manager.updateProvider(updated);
                Navigator.pop(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Provider settings saved!')),
                );
              },
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Dispose controllers after the exit animation finishes — covers Cancel,
      // Save, and barrier dismiss without leaking.
      Future.delayed(const Duration(milliseconds: 400), () {
        apiKeyController.dispose();
        nameController.dispose();
        baseUrlController.dispose();
        temperatureController.dispose();
        maxTokensController.dispose();
      });
    });
  }
}
