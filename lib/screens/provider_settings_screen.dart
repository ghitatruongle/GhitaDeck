import 'package:flutter/material.dart';
import '../providers/ai_provider_manager.dart';
import '../services/api_fallback_cascade_service.dart';
import '../services/local_ai_detector_service.dart';
import '../utils/snackbar_helper.dart';
import '../l10n/l10n.dart';

class ProviderSettingsScreen extends StatefulWidget {
  final AIProviderManager aiProviderManager;
  final bool autoOpenAdd;

  const ProviderSettingsScreen({
    super.key,
    required this.aiProviderManager,
    this.autoOpenAdd = false,
  });

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  final Map<String, PingResult?> _pingResults = {};
  final Map<String, bool> _loadingPing = {};
  final Map<String, bool> _loadingFetch = {};
  final APIFallbackCascadeService _cascadeService = APIFallbackCascadeService();
  final LocalAIDetectorService _localDetector = LocalAIDetectorService();

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showEditProviderDialog();
      });
    }
  }

  Future<void> _testPing(AIProviderConfig config) async {
    setState(() => _loadingPing[config.id] = true);
    final res = await _cascadeService.testProviderPing(config);
    if (mounted) {
      setState(() {
        _pingResults[config.id] = res;
        _loadingPing[config.id] = false;
      });
      if (!res.isSuccess) {
        showAppSnackBar(context, context.l10n.providerConnectionErrorNotice(config.name, res.errorMessage ?? 'Không phản hồi'));
      }
    }
  }

  Future<void> _fetchModels(AIProviderConfig config) async {
    setState(() => _loadingFetch[config.id] = true);
    final models = await widget.aiProviderManager.fetchAvailableModels(config);
    if (mounted) {
      setState(() => _loadingFetch[config.id] = false);
      if (models.isNotEmpty) {
        showAppSnackBar(context, context.l10n.providerModelsUpdatedNotice(models.length, config.name));
      } else {
        showAppSnackBar(context, context.l10n.providerModelsFetchFailedNotice(config.name));
      }
    }
  }

  Future<void> _scanLocalAI() async {
    showAppSnackBar(context, context.l10n.providerLocalScanNotice);
    final detected = await _localDetector.scanLocalAIServices();
    if (mounted) {
      if (detected.isEmpty) {
        showAppSnackBar(context, context.l10n.providerLocalScanEmptyNotice);
      } else {
        var added = 0;
        final knownUrls = widget.aiProviderManager.providers
            .map((provider) => _canonicalLocalUrl(provider.baseUrl))
            .toSet();
        for (final service in detected) {
          final baseUrl = _canonicalLocalUrl(service.baseUrl);
          if (!knownUrls.add(baseUrl)) continue;
          final uri = Uri.tryParse(baseUrl);
          final port = uri?.hasPort == true ? uri!.port : 0;
          widget.aiProviderManager.addProvider(AIProviderConfig(
            id: 'local_${port}_${DateTime.now().microsecondsSinceEpoch}',
            name: service.name.replaceAll(' OpenAI API', ''),
            baseUrl: baseUrl,
            apiKey: '',
            availableModels: List<String>.from(service.models),
            selectedModel: service.models.first,
            contextWindow: 32768,
            formatType: 'openai',
          ));
          added++;
        }
        showAppSnackBar(context, added > 0                ? 'Tìm thấy ${detected.length} dịch vụ AI Local, đã thêm $added cấu hình mới.'                : 'Các dịch vụ AI Local tìm thấy đã có trong danh sách.');
        setState(() {});
      }
    }
  }

  String _canonicalLocalUrl(String value) {
    var url = value.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host == 'localhost' && uri.port == 11434) {
      if (!uri.path.endsWith('/v1')) url = '$url/v1';
    }
    return url.toLowerCase();
  }

  void _showCustomModelDialog(AIProviderConfig config) {
    final controller = TextEditingController(text: config.selectedModel);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nhập Model cho ${config.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gõ bất kỳ tên model nào nhà cung cấp hỗ trợ (ví dụ: gpt-4o-mini, deepseek-chat, gemini-2.0-flash, qwen2.5-coder:32b, claude-3-7-sonnet...):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tên Model (Model ID)',
                hintText: 'Nhập model ID...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.psychology),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final newModel = controller.text.trim();
              if (newModel.isNotEmpty) {
                final models = List<String>.from(config.availableModels);
                if (!models.contains(newModel)) {
                  models.insert(0, newModel);
                }
                final updated = config.copyWith(
                  selectedModel: newModel,
                  availableModels: models,
                );
                widget.aiProviderManager.updateProvider(updated);
                setState(() {});
                Navigator.pop(ctx);
                showAppSnackBar(context, context.l10n.providerModelSelectedNotice(newModel));
              }
            },
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
  }

  void _showEditProviderDialog([AIProviderConfig? existing]) {
    final isNew = existing == null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.baseUrl ?? 'https://api.openai.com/v1');
    final keyCtrl = TextEditingController(text: existing?.apiKey ?? '');
    final modelCtrl = TextEditingController(text: existing?.selectedModel ?? 'gpt-4o-mini');
    String formatType = existing?.formatType ?? 'openai';
    double temperature = existing?.temperature ?? 0.7;
    int maxTokens = existing?.maxTokens ?? 4096;
    bool obscureKey = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isNew ? 'Thêm Nhà Cung Cấp AI' : 'Chỉnh Sửa ${existing.name}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNew) ...[
                    const Text('Mẫu thiết lập nhanh (Nhấn để điền sẵn):',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.bolt, size: 14, color: Colors.cyan),
                          label: const Text('DeepSeek', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameCtrl.text = 'DeepSeek';
                              urlCtrl.text = 'https://api.deepseek.com/v1';
                              modelCtrl.text = 'deepseek-chat';
                              formatType = 'openai';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.cloud_outlined, size: 14, color: Colors.blueAccent),
                          label: const Text('SiliconFlow', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameCtrl.text = 'SiliconFlow';
                              urlCtrl.text = 'https://api.siliconflow.cn/v1';
                              modelCtrl.text = 'deepseek-ai/DeepSeek-V3';
                              formatType = 'openai';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.alt_route, size: 14, color: Colors.purpleAccent),
                          label: const Text('OpenRouter', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameCtrl.text = 'OpenRouter';
                              urlCtrl.text = 'https://openrouter.ai/api/v1';
                              modelCtrl.text = 'anthropic/claude-3.5-sonnet';
                              formatType = 'openai';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.speed, size: 14, color: Colors.orange),
                          label: const Text('Groq', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameCtrl.text = 'Groq Cloud';
                              urlCtrl.text = 'https://api.groq.com/openai/v1';
                              modelCtrl.text = 'llama-3.3-70b-versatile';
                              formatType = 'openai';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.laptop, size: 14, color: Colors.teal),
                          label: const Text('LM Studio / Local', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameCtrl.text = 'LM Studio';
                              urlCtrl.text = 'http://localhost:1234/v1';
                              modelCtrl.text = 'local-model';
                              formatType = 'openai';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.computer, size: 14, color: Colors.deepOrange),
                          label: const Text('Ollama', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameCtrl.text = 'Ollama Local';
                              urlCtrl.text = 'http://localhost:11434/v1';
                              modelCtrl.text = 'llama3.1';
                              formatType = 'openai';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.auto_awesome, size: 14, color: Colors.blue),
                          label: const Text('Gemini API', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameCtrl.text = 'Google Gemini';
                              urlCtrl.text = 'https://generativelanguage.googleapis.com';
                              modelCtrl.text = 'gemini-2.0-flash';
                              formatType = 'gemini';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.edit_note, size: 14),
                          label: const Text('Tùy chỉnh riêng (Custom)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameCtrl.text = 'My Custom Provider';
                              urlCtrl.text = 'https://api.example.com/v1';
                              modelCtrl.text = '';
                              formatType = 'openai';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên hiển thị',
                      hintText: 'Ví dụ: DeepSeek, SiliconFlow, LM Studio, Custom AI...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: formatType,
                    decoration: const InputDecoration(
                      labelText: 'Định dạng API (Format Type)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'openai', child: Text('OpenAI Compatible (OpenAI, DeepSeek, Groq, OpenRouter...)')),
                      DropdownMenuItem(value: 'gemini', child: Text('Google Gemini API')),
                      DropdownMenuItem(value: 'anthropic', child: Text('Anthropic Claude API')),
                      DropdownMenuItem(value: 'ollama', child: Text('Ollama (Local)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          formatType = val;
                          if (isNew) {
                            if (val == 'gemini') {
                              urlCtrl.text = 'https://generativelanguage.googleapis.com';
                              modelCtrl.text = 'gemini-2.0-flash';
                            } else if (val == 'anthropic') {
                              urlCtrl.text = 'https://api.anthropic.com';
                              modelCtrl.text = 'claude-3-5-sonnet-20241022';
                            } else if (val == 'ollama') {
                              urlCtrl.text = 'http://localhost:11434/v1';
                              modelCtrl.text = 'llama3.1';
                            }
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://api.example.com/v1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyCtrl,
                    obscureText: obscureKey,
                    decoration: InputDecoration(
                      labelText: 'API Key (để trống nếu dùng local)',
                      hintText: 'sk-...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureKey = !obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Model mặc định (Tùy ý nhập)',
                      hintText: 'Ví dụ: gpt-4o, deepseek-chat, gemini-2.0-flash...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Độ sáng tạo (Temp): ${temperature.toStringAsFixed(1)}', style: const TextStyle(fontSize: 13)),
                      ),
                      Slider(
                        value: temperature,
                        min: 0.0,
                        max: 1.5,
                        divisions: 15,
                        onChanged: (val) => setDialogState(() => temperature = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final baseUrl = urlCtrl.text.trim();
                final model = modelCtrl.text.trim();
                final apiKey = keyCtrl.text.trim();

                if (name.isEmpty || baseUrl.isEmpty || model.isEmpty) {
                  showAppSnackBar(context, context.l10n.providerMissingFieldsNotice);
                  return;
                }

                if (isNew) {
                  final newConfig = AIProviderConfig(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    baseUrl: baseUrl,
                    apiKey: apiKey,
                    availableModels: [model],
                    selectedModel: model,
                    contextWindow: 128000,
                    formatType: formatType,
                    temperature: temperature,
                    maxTokens: maxTokens,
                  );
                  widget.aiProviderManager.addProvider(newConfig);
                } else {
                  final models = List<String>.from(existing.availableModels);
                  if (!models.contains(model)) models.insert(0, model);
                  final updated = existing.copyWith(
                    name: name,
                    baseUrl: baseUrl,
                    apiKey: apiKey,
                    selectedModel: model,
                    availableModels: models,
                    formatType: formatType,
                    temperature: temperature,
                    maxTokens: maxTokens,
                  );
                  widget.aiProviderManager.updateProvider(updated);
                }

                setState(() {});
                Navigator.pop(ctx);
              },
              child: Text(isNew ? 'Thêm' : 'Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProvider(AIProviderConfig config) {
    if (widget.aiProviderManager.providers.length <= 1) {
      showAppSnackBar(context, context.l10n.providerOnlyOneNotice);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa ${config.name}?'),
        content: Text('Bạn có chắc chắn muốn xóa cấu hình nhà cung cấp "${config.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              widget.aiProviderManager.removeProvider(config.id);
              setState(() {});
              Navigator.pop(ctx);
              showAppSnackBar(context, context.l10n.providerDeletedNotice(config.name));
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providers = widget.aiProviderManager.providers;
    final selectedId = widget.aiProviderManager.selectedProvider?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý AI Provider & Kết Nối'),
        actions: [
          FilledButton.tonalIcon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm Provider'),
            onPressed: () => _showEditProviderDialog(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.radar),
            tooltip: 'Tự động quét AI Local (Ollama, LM Studio...)',
            onPressed: _scanLocalAI,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: providers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hub_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Chưa có nhà cung cấp AI nào được cấu hình.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm Nhà Cung Cấp'),
                    onPressed: () => _showEditProviderDialog(),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: providers.length,
              itemBuilder: (context, index) {
                final p = providers[index];
                final ping = _pingResults[p.id];
                final isPingLoading = _loadingPing[p.id] ?? false;
                final isFetchLoading = _loadingFetch[p.id] ?? false;
                final isDefault = p.id == selectedId;

                Color latencyColor = Colors.grey;
                if (ping != null) {
                  if (!ping.isSuccess) {
                    latencyColor = Colors.red;
                  } else if (ping.latencyMs < 500) {
                    latencyColor = Colors.green;
                  } else if (ping.latencyMs < 1500) {
                    latencyColor = Colors.amber.shade800;
                  } else {
                    latencyColor = Colors.orange;
                  }
                }

                return Card(
                  key: ValueKey(p.id),
                  elevation: isDefault ? 3 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDefault
                          ? theme.colorScheme.primary
                          : theme.dividerColor.withValues(alpha: 0.2),
                      width: isDefault ? 2 : 1,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Header (Name, Badge, Active radio)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                p.formatType == 'gemini'
                                    ? Icons.auto_awesome
                                    : p.formatType == 'anthropic'
                                        ? Icons.psychology
                                        : p.formatType == 'ollama'
                                            ? Icons.computer
                                            : Icons.hub,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        p.name,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isDefault)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Đang kích hoạt',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    '${p.baseUrl} • ${p.formatType.toUpperCase()}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isDefault)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Chọn dùng'),
                                onPressed: () {
                                  widget.aiProviderManager.selectProvider(p);
                                  setState(() {});
                                },
                              ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showEditProviderDialog(p);
                                } else if (val == 'delete') {
                                  _confirmDeleteProvider(p);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Chỉnh sửa'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Xóa', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const Divider(height: 20),

                        // Row 2: Model Picker & Custom Model Input
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Model:',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.dividerColor),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: p.availableModels.contains(p.selectedModel)
                                        ? p.selectedModel
                                        : (p.availableModels.isNotEmpty ? p.availableModels.first : null),
                                    isExpanded: true,
                                    hint: Text(p.selectedModel.isNotEmpty ? p.selectedModel : 'Chọn model'),
                                    items: [
                                      ...p.availableModels.map(
                                        (m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(m, style: const TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        final updated = p.copyWith(selectedModel: val);
                                        widget.aiProviderManager.updateProvider(updated);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.edit_note, size: 18),
                              tooltip: 'Nhập model tùy ý (Custom Model ID)',
                              onPressed: () => _showCustomModelDialog(p),
                            ),
                            const SizedBox(width: 4),
                            IconButton.outlined(
                              icon: isFetchLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync, size: 18),
                              tooltip: 'Tải danh sách Model từ API',
                              onPressed: isFetchLoading ? null : () => _fetchModels(p),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Row 3: Diagnostic test ping & stats
                        Row(
                          children: [
                            OutlinedButton.icon(
                              icon: isPingLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.speed, size: 16),
                              label: const Text('Test Ping'),
                              onPressed: isPingLoading ? null : () => _testPing(p),
                            ),
                            const SizedBox(width: 12),
                            if (ping != null)
                              Chip(
                                avatar: Icon(
                                  ping.isSuccess ? Icons.check_circle : Icons.error,
                                  color: latencyColor,
                                  size: 16,
                                ),
                                label: Text(
                                  ping.isSuccess ? '${ping.latencyMs} ms' : (ping.errorMessage ?? 'Error'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: latencyColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: latencyColor.withValues(alpha: 0.1),
                                side: BorderSide(color: latencyColor.withValues(alpha: 0.3)),
                              ),
                            const Spacer(),
                            Text(
                              '${p.availableModels.length} models khả dụng',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
