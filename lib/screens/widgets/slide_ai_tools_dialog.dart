import 'package:flutter/material.dart';
import '../../models/slide.dart';
import '../../providers/ai_provider_manager.dart';
import '../../utils/error_mapper.dart';
import '../../utils/snackbar_helper.dart';
import '../../l10n/l10n.dart';

class SlideAiToolsDialog extends StatefulWidget {
  final Slide slide;
  final AIProviderManager aiProviderManager;
  final Function(Slide updatedSlide) onSlideUpdated;

  const SlideAiToolsDialog({
    super.key,
    required this.slide,
    required this.aiProviderManager,
    required this.onSlideUpdated,
  });

  @override
  State<SlideAiToolsDialog> createState() => _SlideAiToolsDialogState();
}

class _SlideAiToolsDialogState extends State<SlideAiToolsDialog> {
  bool _isLoading = false;
  String _selectedLanguage = 'Tiếng Anh';

  final List<String> _languages = [
    'Tiếng Anh',
    'Tiếng Việt',
    'Tiếng Nhật',
    'Tiếng Trung',
    'Tiếng Hàn',
    'Tiếng Pháp',
    'Tiếng Đức',
    'Tiếng Tây Ban Nha',
  ];

  Future<void> _runAiAction(String promptTask, {bool isNotes = false}) async {
    final provider = widget.aiProviderManager.selectedProvider;
    if (provider == null || provider.apiKey.isEmpty) {
      showAppSnackBar(context, context.l10n.aiToolsApiKeyNotice);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userPrompt = '''
Nội dung slide hiện tại:
Title: ${widget.slide.title}
HTML Content:
${widget.slide.htmlContent}

Yêu cầu thực hiện:
$promptTask
''';

      final responseText = await widget.aiProviderManager.generateSlideContent(
        userPrompt,
        customPrompt: 'You are an AI presentation assistant. Return clear output.',
      );

      if (isNotes) {
        final updated = widget.slide.copyWith(notes: responseText.trim());
        widget.onSlideUpdated(updated);
        if (mounted) {
          showAppSnackBar(context, context.l10n.aiToolsScriptCreatedNotice);
        }
      } else {
        final updated = widget.slide.copyWith(htmlContent: responseText.trim());
        widget.onSlideUpdated(updated);
        if (mounted) {
          showAppSnackBar(context, context.l10n.aiToolsSlideUpdatedNotice);
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorMapper.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.deepOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Trợ Lý AI Slide: ${widget.slide.title}'),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('AI đang xử lý slide của bạn...'),
                  ],
                ),
              )
            else
              Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: const Text('Tối Ưu & Viết Lại (Rewrite & Polish)'),
                    subtitle: const Text('Sửa câu từ súc tích, chuyên nghiệp hơn'),
                    onTap: () => _runAiAction(
                        'Rewrite and polish this slide HTML content to be concise and impactful.'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.mic_none),
                    title: const Text('Tạo Kịch Bản Diễn Giả (Speaker Notes)'),
                    subtitle: const Text('Tự động viết bài nói chi tiết cho slide này'),
                    onTap: () => _runAiAction(
                      'Generate comprehensive speaker notes script for a presenter presenting this slide.',
                      isNotes: true,
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.translate),
                    title: const Text('Dịch Thuật Slide'),
                    subtitle: DropdownButton<String>(
                      isDense: true,
                      value: _selectedLanguage,
                      items: _languages
                          .map((l) => DropdownMenuItem(value: l, child: Text('Sang $l')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedLanguage = val);
                      },
                    ),
                    onTap: () => _runAiAction(
                        'Translate the slide title, text, and bullet points accurately into $_selectedLanguage.'),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
