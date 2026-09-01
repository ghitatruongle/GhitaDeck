import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_provider_manager.dart';
import '../utils/snackbar_helper.dart';
import '../l10n/l10n.dart';

// =============================================================================
// Configuration Wizard — 4-step AI provider setup
// v1.2.0: Uses unified AIProviderManager, all bugs fixed
// =============================================================================

class ConfigurationWizard extends StatefulWidget {
  const ConfigurationWizard({super.key});

  @override
  State<ConfigurationWizard> createState() => _ConfigurationWizardState();
}

class _ConfigurationWizardState extends State<ConfigurationWizard> {
  int _currentStep = 0;
  AIProviderConfig? _currentProvider;

  @override
  void initState() {
    super.initState();
  }

  List<Widget> _buildSteps() {
    // Rebuild steps with current provider data only when needed
    return [
      _ProviderTypeStep(onProviderCreated: _updateCurrentProvider),
      _APIKeyStep(
        providerConfig: _currentProvider ?? AIProviderConfig.defaultProvider(),
        onConfigUpdated: _updateCurrentProvider,
      ),
      _ModelSelectionStep(
        providerConfig: _currentProvider ?? AIProviderConfig.defaultProvider(),
        onConfigUpdated: _updateCurrentProvider,
      ),
      _SummaryStep(
        providerConfig: _currentProvider ?? AIProviderConfig.defaultProvider(),
        onConfigurationComplete: _completeConfiguration,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = _buildSteps();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấu hình Nhà cung cấp AI'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentStep + 1) / steps.length,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),

          // Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: List.generate(steps.length, (index) {
                final isActive = index == _currentStep;
                final isCompleted = index < _currentStep;
                return Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? theme.colorScheme.primary
                              : isActive
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: Center(
                          child: isCompleted
                              ? Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                      if (index < steps.length - 1) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isCompleted
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: steps[_currentStep],
            ),
          ),

          // Navigation buttons — v1.2.0: validation-aware
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _currentStep--),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Quay lại'),
                  )
                else
                  const SizedBox(width: 120),

                ElevatedButton.icon(
                  onPressed: _canAdvance()
                      ? () {
                          if (_currentStep < steps.length - 1) {
                            setState(() => _currentStep++);
                          } else {
                            _completeConfiguration();
                          }
                        }
                      : null, // Disable if can't advance
                  icon: Icon(_currentStep < steps.length - 1
                      ? Icons.arrow_forward
                      : Icons.check_circle),
                  label: Text(_currentStep < steps.length - 1
                      ? 'Tiếp theo'
                      : 'Hoàn thành'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// v1.2.0: Check if current step is valid before allowing advance
  bool _canAdvance() {
    switch (_currentStep) {
      case 0:
        return _currentProvider != null &&
            _currentProvider!.name.isNotEmpty &&
            _currentProvider!.baseUrl.isNotEmpty;
      case 1:
        return true; // API key is optional for local providers
      case 2:
        return _currentProvider?.selectedModel.isNotEmpty ?? false;
      case 3:
        return _currentProvider != null;
      default:
        return false;
    }
  }

  void _updateCurrentProvider(AIProviderConfig config) {
    setState(() {
      _currentProvider = config;
    });
  }

  Future<void> _completeConfiguration() async {
    if (_currentProvider == null) {
      showAppSnackBar(context, context.l10n.wizardCompleteStepsNotice);
      return;
    }

    // Save to unified AIProviderManager
    final manager = Provider.of<AIProviderManager>(context, listen: false);
    manager.addProvider(_currentProvider!);

    // v1.2.0 fix: Select the new provider before saving API key
    // (addProvider only auto-selects if _selectedProvider is null,
    //  but root provider always has a default selected)
    manager.selectProvider(_currentProvider!);

    // Save API key to secure storage if provided
    if (_currentProvider!.apiKey.isNotEmpty) {
      await manager.saveApiKeyForSelected(_currentProvider!.apiKey);
    }

    if (!mounted) return;
    showAppSnackBar(
      context,
      context.l10n.wizardProviderConfiguredNotice(_currentProvider!.name));

    if (mounted) Navigator.pop(context);
  }
}

// =============================================================================
// Step 1: Provider Type Selection
// =============================================================================

class _ProviderTypeStep extends StatefulWidget {
  final Function(AIProviderConfig) onProviderCreated;

  const _ProviderTypeStep({required this.onProviderCreated});

  @override
  State<_ProviderTypeStep> createState() => _ProviderTypeStepState();
}

class _ProviderTypeStepState extends State<_ProviderTypeStep> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _baseUrlController =
      TextEditingController(text: 'https://api.openai.com');
  String _selectedProviderType = 'openai';

  final List<Map<String, dynamic>> _providerTypes = [
    {
      'id': 'openai',
      'name': 'OpenAI',
      'baseUrl': 'https://api.openai.com',
      'icon': Icons.smart_toy,
      'color': Colors.green,
      'formatType': 'openai',
    },
    {
      'id': 'deepseek',
      'name': 'DeepSeek',
      'baseUrl': 'https://api.deepseek.com/v1',
      'icon': Icons.bolt,
      'color': Colors.cyan,
      'formatType': 'openai',
    },
    {
      'id': 'siliconflow',
      'name': 'SiliconFlow',
      'baseUrl': 'https://api.siliconflow.cn/v1',
      'icon': Icons.cloud_outlined,
      'color': Colors.blueAccent,
      'formatType': 'openai',
    },
    {
      'id': 'anthropic',
      'name': 'Anthropic (Claude)',
      'baseUrl': 'https://api.anthropic.com',
      'icon': Icons.psychology,
      'color': Colors.purple,
      'formatType': 'anthropic',
    },
    {
      'id': 'gemini',
      'name': 'Google Gemini',
      'baseUrl': 'https://generativelanguage.googleapis.com',
      'icon': Icons.auto_awesome,
      'color': Colors.blue,
      'formatType': 'gemini',
    },
    {
      'id': 'ollama',
      'name': 'Ollama (Local)',
      'baseUrl': 'http://localhost:11434/v1',
      'icon': Icons.computer,
      'color': Colors.orange,
      'formatType': 'openai',
    },
    {
      'id': 'custom',
      'name': 'Tùy chỉnh riêng (Custom)',
      'baseUrl': 'https://api.example.com/v1',
      'icon': Icons.tune,
      'color': Colors.teal,
      'formatType': 'openai',
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bước 1: Chọn loại nhà cung cấp AI',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn loại dịch vụ AI bạn muốn cấu hình',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Provider type grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: _providerTypes.length,
            itemBuilder: (context, index) {
              final provider = _providerTypes[index];
              final isSelected = _selectedProviderType == provider['id'];

              return GestureDetector(
                key: ValueKey(provider['id']),
                onTap: () {
                  setState(() {
                    _selectedProviderType = provider['id'];
                    _baseUrlController.text = provider['baseUrl'];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : theme.colorScheme.surface,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        provider['icon'] as IconData,
                        size: 32,
                        color: isSelected
                            ? provider['color'] as Color
                            : (provider['color'] as Color).withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        provider['name'] as String,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Tên nhà cung cấp',
              hintText: 'Ví dụ: My OpenAI Connection',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outlined),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.example.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link_outlined),
            ),
          ),

          const SizedBox(height: 24),

          // Next button (with validation)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_nameController.text.isNotEmpty &&
                    _baseUrlController.text.isNotEmpty) {
                  final selectedType = _providerTypes.firstWhere(
                    (p) => p['id'] == _selectedProviderType,
                  );
                  final provider = AIProviderConfig(
                    id: '${_selectedProviderType}_${DateTime.now().millisecondsSinceEpoch}',
                    name: _nameController.text,
                    baseUrl: _baseUrlController.text,
                    apiKey: '',
                    availableModels: _getDefaultModels(_selectedProviderType),
                    selectedModel: _getDefaultModels(_selectedProviderType).first,
                    contextWindow: _getDefaultContextWindow(_selectedProviderType),
                    formatType: selectedType['formatType'] as String,
                  );
                  widget.onProviderCreated(provider);
                } else {
                  showAppSnackBar(context, context.l10n.wizardProviderFieldsNotice);
                }
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Tiếp theo'),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getDefaultModels(String providerType) {
    switch (providerType) {
      case 'openai':
        return ['gpt-4o', 'gpt-4o-mini', 'gpt-3.5-turbo', 'o1-preview'];
      case 'deepseek':
        return ['deepseek-chat', 'deepseek-reasoner'];
      case 'siliconflow':
        return ['deepseek-ai/DeepSeek-V3', 'deepseek-ai/DeepSeek-R1', 'Qwen/Qwen2.5-72B-Instruct'];
      case 'anthropic':
        return ['claude-3-5-sonnet-20240620', 'claude-3-opus-20240229', 'claude-3-haiku-20240307'];
      case 'gemini':
        return ['gemini-2.5-flash', 'gemini-2.5-pro'];
      case 'ollama':
        return ['llama3.1', 'mistral', 'qwen2.5'];
      case 'custom':
        return ['default-model'];
      default:
        return ['gpt-4o'];
    }
  }

  int _getDefaultContextWindow(String providerType) {
    switch (providerType) {
      case 'openai':
        return 128000;
      case 'deepseek':
        return 64000;
      case 'siliconflow':
        return 64000;
      case 'anthropic':
        return 200000;
      case 'gemini':
        return 1000000;
      case 'ollama':
        return 32768;
      default:
        return 32768;
    }
  }
}

// =============================================================================
// Step 2: API Key Configuration
// =============================================================================

class _APIKeyStep extends StatefulWidget {
  final AIProviderConfig providerConfig;
  final Function(AIProviderConfig) onConfigUpdated;

  const _APIKeyStep({
    required this.providerConfig,
    required this.onConfigUpdated,
  });

  @override
  State<_APIKeyStep> createState() => _APIKeyStepState();
}

class _APIKeyStepState extends State<_APIKeyStep> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _keyController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    // v1.2.0: Initialize with real key, not masked version
    _keyController = TextEditingController(text: widget.providerConfig.apiKey);
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsKey = widget.providerConfig.requiresApiKey;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bước 2: Cấu hình API Key',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            needsKey
                ? 'Nhập API key cho ${widget.providerConfig.name}'
                : 'Nhà cung cấp local không yêu cầu API key',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          if (!needsKey) ...[
            Card(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nhà cung cấp local (${widget.providerConfig.baseUrl}) không cần API key. '
                        'Bạn có thể bỏ qua bước này.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _keyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'Nhập API key của bạn',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                    validator: (value) {
                      if (needsKey && (value == null || value.isEmpty)) {
                        return 'Vui lòng nhập API key';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Test connection button
                  if (_keyController.text.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final manager = Provider.of<AIProviderManager>(context, listen: false);
                        final testConfig = widget.providerConfig.copyWith(
                          apiKey: _keyController.text,
                        );

                        showAppSnackBar(context, context.l10n.providerTestingNotice);

                        final result = await manager.testProviderPing(testConfig);

                        if (!context.mounted) return;

                        showAppSnackBar(context, result.isSuccess                                ? '✓ Kết nối thành công (${result.latencyMs}ms)'                                : '✗ Không thể kết nối: ${result.errorMessage ?? "Lỗi không xác định"}');
                      },
                      icon: const Icon(Icons.wifi_find),
                      label: const Text('Kiểm tra kết nối'),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (!needsKey || _formKey.currentState!.validate()) {
                  final updatedConfig = widget.providerConfig.copyWith(
                    apiKey: _keyController.text,
                  );
                  widget.onConfigUpdated(updatedConfig);
                }
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Tiếp theo'),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Step 3: Model Selection
// =============================================================================

class _ModelSelectionStep extends StatefulWidget {
  final AIProviderConfig providerConfig;
  final Function(AIProviderConfig) onConfigUpdated;

  const _ModelSelectionStep({
    required this.providerConfig,
    required this.onConfigUpdated,
  });

  @override
  State<_ModelSelectionStep> createState() => _ModelSelectionStepState();
}

class _ModelSelectionStepState extends State<_ModelSelectionStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _modelController;
  final TextEditingController _temperatureController =
      TextEditingController(text: '0.7');
  final TextEditingController _maxTokensController =
      TextEditingController(text: '4096');
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _modelController =
        TextEditingController(text: widget.providerConfig.selectedModel);
  }

  @override
  void dispose() {
    _modelController.dispose();
    _temperatureController.dispose();
    _maxTokensController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final models = widget.providerConfig.availableModels.isNotEmpty
        ? widget.providerConfig.availableModels
        : _getModelsForProvider(widget.providerConfig.formatType);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bước 3: Chọn Model và Tham số',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn model từ gợi ý hoặc tự nhập model ID tùy ý cho ${widget.providerConfig.name}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom model text input with suggestions
                TextFormField(
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: 'Model ID (Gõ tùy ý hoặc chọn bên dưới)',
                    hintText: 'Ví dụ: gpt-4o-mini, deepseek-chat, gemini-2.0-flash...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.model_training),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _modelController.clear(),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập hoặc chọn Model';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    widget.onConfigUpdated(
                      widget.providerConfig.copyWith(selectedModel: value.trim()),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Quick model suggestion chips
                if (models.isNotEmpty) ...[
                  const Text('Gợi ý models:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: models.map((m) {
                      final isSelected = _modelController.text == m;
                      return ChoiceChip(
                        label: Text(m, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _modelController.text = m);
                            widget.onConfigUpdated(
                              widget.providerConfig.copyWith(selectedModel: m),
                            );
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Fetch models button
                OutlinedButton.icon(
                  onPressed: _isFetching
                      ? null
                      : () async {
                          setState(() => _isFetching = true);
                          final manager = Provider.of<AIProviderManager>(context, listen: false);
                          final config = widget.providerConfig.copyWith(
                            selectedModel: _modelController.text.trim(),
                          );
                          final l10n = context.l10n;
                          showAppSnackBar(context, l10n.wizardFetchingModelsNotice);
                          final fetched = await manager.fetchAvailableModels(config);
                          if (!mounted) return;
                          setState(() => _isFetching = false);
                          if (fetched.isNotEmpty) {
                            widget.onConfigUpdated(
                              widget.providerConfig.copyWith(
                                availableModels: fetched,
                                selectedModel: fetched.first,
                              ),
                            );
                            setState(() => _modelController.text = fetched.first);
                          }
                          if (!mounted) return;
                          final modelMsg = fetched.isNotEmpty
                              ? l10n.wizardModelsFoundNotice(fetched.length)
                              : l10n.wizardModelsNotFoundNotice;
                          // Directly preceded by the State.mounted guard.
                          // ignore: use_build_context_synchronously
                          showAppSnackBar(context, modelMsg);
                        },
                  icon: _isFetching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Lấy danh sách models từ API'),
                ),

                const SizedBox(height: 16),

                // Temperature
                TextFormField(
                  controller: _temperatureController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Temperature (0.0 - 2.0)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.thermostat),
                  ),
                  validator: (value) {
                    final num = double.tryParse(value ?? '');
                    if (num == null || num < 0 || num > 2) {
                      return 'Temperature phải từ 0.0 đến 2.0';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Max tokens
                TextFormField(
                  controller: _maxTokensController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Tokens',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  validator: (value) {
                    final num = int.tryParse(value ?? '');
                    if (num == null || num <= 0) {
                      return 'Max tokens phải là số dương';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final updatedConfig = widget.providerConfig.copyWith(
                          temperature: double.tryParse(_temperatureController.text) ?? 0.7,
                          maxTokens: int.tryParse(_maxTokensController.text) ?? 4096,
                        );
                        widget.onConfigUpdated(updatedConfig);
                      }
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Tiếp theo'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// v1.2.0: Return models filtered by provider format type
  List<String> _getModelsForProvider(String formatType) {
    switch (formatType) {
      case 'openai':
        return ['gpt-4o', 'gpt-4o-mini', 'gpt-3.5-turbo', 'o1-preview'];
      case 'anthropic':
        return ['claude-3-5-sonnet-20240620', 'claude-3-opus-20240229', 'claude-3-haiku-20240307'];
      case 'gemini':
        return ['gemini-2.5-flash', 'gemini-2.5-pro'];
      default:
        return ['gpt-4o', 'gpt-3.5-turbo'];
    }
  }
}

// =============================================================================
// Step 4: Summary
// =============================================================================

class _SummaryStep extends StatelessWidget {
  final AIProviderConfig providerConfig;
  final Function() onConfigurationComplete;

  const _SummaryStep({
    required this.providerConfig,
    required this.onConfigurationComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKey = providerConfig.apiKey.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bước 4: Hoàn thành cấu hình',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Xem lại cấu hình của bạn và bắt đầu sử dụng',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasKey ? Icons.check_circle : Icons.warning,
                        color: hasKey ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          providerConfig.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  _buildSummaryRow(context, 'Base URL', providerConfig.baseUrl, Icons.link),
                  _buildSummaryRow(context, 'Model', providerConfig.selectedModel, Icons.model_training),
                  _buildSummaryRow(
                    context,
                    'API Key',
                    hasKey ? '••••••${providerConfig.apiKey.substring(providerConfig.apiKey.length > 4 ? providerConfig.apiKey.length - 4 : 0)}' : 'Chưa cấu hình',
                    Icons.vpn_key,
                  ),
                  _buildSummaryRow(context, 'Format', providerConfig.formatType, Icons.code),
                  _buildSummaryRow(context, 'Context Window', '${providerConfig.contextWindow}', Icons.memory),
                  _buildSummaryRow(context, 'Temperature', '${providerConfig.temperature}', Icons.thermostat),
                  _buildSummaryRow(context, 'Max Tokens', '${providerConfig.maxTokens}', Icons.numbers),

                  if (!hasKey && providerConfig.requiresApiKey) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cảnh báo: Chưa có API key. Bạn cần thêm key trước khi sử dụng.',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onConfigurationComplete,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Bắt đầu sử dụng'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
