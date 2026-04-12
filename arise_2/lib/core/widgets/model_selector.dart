import 'package:flutter/material.dart';
import '../theme/arise_colors.dart';
import '../services/model_service.dart';

/// Popover-style model selector panel.
class ModelSelector extends StatefulWidget {
  const ModelSelector({super.key, required this.service});
  final ModelService service;

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    widget.service.onModelsUpdated = () {
      if (mounted) setState(() {});
    };
    widget.service.fetchModels();
  }

  void _togglePopover() {
    if (_isOpen) {
      _closePopover();
    } else {
      _openPopover();
    }
  }

  void _openPopover() {
    _overlayEntry = _createOverlay();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closePopover() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlay() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closePopover,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            width: 260,
            child: CompositedTransformFollower(
              link: _layerLink,
              offset: const Offset(0, 42),
              showWhenUnlinked: false,
              child: Material(
                color: Colors.transparent,
                child: _ModelPopoverPanel(
                  service: widget.service,
                  onSelect: (model) {
                    widget.service.selectModel(model);
                    _closePopover();
                  },
                  onManage: () {
                    _closePopover();
                    showDialog(
                      context: context,
                      builder: (_) =>
                          _ModelManagerDialog(service: widget.service),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _closePopover();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _togglePopover,
          hoverColor: AriseColors.surfaceContainerHighest,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _isOpen
                  ? AriseColors.surfaceContainerHighest
                  : AriseColors.surfaceContainerHigh.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isOpen
                    ? AriseColors.secondary.withValues(alpha: 0.3)
                    : AriseColors.outlineVariant.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: AriseColors.secondary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 7),
                Text(
                  widget.service.activeModel?.displayName ?? 'No Model',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AriseColors.secondary,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  _isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: AriseColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The floating popover panel showing the model list.
class _ModelPopoverPanel extends StatelessWidget {
  const _ModelPopoverPanel({
    required this.service,
    required this.onSelect,
    required this.onManage,
  });

  final ModelService service;
  final ValueChanged<OllamaModel> onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    // Filter models designed exclusively for strictly Coding
    final conversationModels = service.models
        .where((m) => m.role != 'Coding')
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AriseColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AriseColors.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AriseColors.secondary.withValues(alpha: 0.05),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'CONVERSATION MODELS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AriseColors.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 1.5,
                fontSize: 9,
              ),
            ),
          ),
          if (conversationModels.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 24,
                    color: AriseColors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No conversational models found',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AriseColors.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...conversationModels.map((model) {
            final isActive = model.name == service.activeModel?.name;
            return InkWell(
              onTap: () => onSelect(model),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: isActive
                    ? AriseColors.secondary.withValues(alpha: 0.08)
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.displayName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isActive
                                      ? AriseColors.secondary
                                      : AriseColors.onSurface,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                          Text(
                            '${model.size} • ${model.quantization}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AriseColors.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                                  fontSize: 9,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AriseColors.secondary,
                      ),
                  ],
                ),
              ),
            );
          }),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AriseColors.outlineVariant.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: InkWell(
              onTap: onManage,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: AriseColors.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add / Manage Models',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AriseColors.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen dialog for managing Ollama models and Cloud APIs.
class _ModelManagerDialog extends StatefulWidget {
  const _ModelManagerDialog({required this.service});
  final ModelService service;

  @override
  State<_ModelManagerDialog> createState() => _ModelManagerDialogState();
}

class _ModelManagerDialogState extends State<_ModelManagerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AriseColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 600,
        height: 500,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Icon(
                    Icons.model_training_rounded,
                    size: 20,
                    color: AriseColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'MODEL MANAGER',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AriseColors.secondary,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AriseColors.onSurfaceVariant,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Panel
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.service.ollamaConnected
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                      : AriseColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.service.ollamaConnected
                            ? const Color(0xFF4CAF50)
                            : AriseColors.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.service.ollamaConnected
                          ? 'Ollama native backend connected and listening'
                          : 'Ollama not detected — fallback to cloud or restart daemon',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AriseColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorColor: AriseColors.secondary,
                labelColor: AriseColors.secondary,
                unselectedLabelColor: AriseColors.onSurfaceVariant,
                tabs: const [
                  Tab(text: "Installed"),
                  Tab(text: "Installing"),
                  Tab(text: "Cloud Models"),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInstalledTab(),
                    _buildInstallingTab(),
                    _buildCloudTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstalledTab() {
    if (widget.service.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.service.models.isEmpty) {
      return const Center(child: Text("No local models currently installed."));
    }

    // Need to use Stateful builder or pass service down. Simple hook into setState via build.
    return ListView.separated(
      itemCount: widget.service.models.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final model = widget.service.models[index];
        final isActive = model.name == widget.service.activeModel?.name;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AriseColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(
                    color: AriseColors.secondary.withValues(alpha: 0.3),
                  )
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AriseColors.onSurface,
                      ),
                    ),
                    Text(
                      '${model.size} • ${model.quantization}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AriseColors.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Role Dropdown
              DropdownButton<String>(
                value: model.role,
                dropdownColor: AriseColors.surfaceContainerHigh,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AriseColors.onSurface),
                underline: const SizedBox(),
                items: ['Conversation', 'Coding', 'Both', 'Idle']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    widget.service
                        .setModelRole(model.name, val)
                        .then((_) => setState(() {}));
                  }
                },
              ),
              const SizedBox(width: 12),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AriseColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AriseColors.secondary,
                      fontSize: 9,
                    ),
                  ),
                ),
              if (!isActive)
                const SizedBox(
                  width: 53,
                ), // Spacer representing missing active chip
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AriseColors.onSurfaceVariant.withValues(alpha: 0.4),
                onPressed: () => widget.service
                    .deleteModel(model.name)
                    .then((_) => setState(() {})),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstallingTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input text field for generic "Install Ollama Model"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AriseColors.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AriseColors.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.download_rounded,
                size: 18,
                color: AriseColors.secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. qwen2.5:14b or deepseek-coder-v2',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AriseColors.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                  onSubmitted: (val) {
                    widget.service.pullModel(val);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.service.installingModels.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                "No models currently pulling.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AriseColors.onSurfaceVariant,
                ),
              ),
            ),
          ),

        // List installing models
        if (widget.service.installingModels.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: widget.service.installingModels.length,
              itemBuilder: (context, index) {
                final installing = widget.service.installingModels[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AriseColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AriseColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            installing.name,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '${installing.progress}%',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AriseColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        installing.status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AriseColors.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: installing.progress / 100.0,
                          backgroundColor: AriseColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AriseColors.primary,
                          ),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Speed: ${installing.speed}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AriseColors.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCloudTab() {
    String selectedProvider = 'OpenAI';
    final TextEditingController apiKeyController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Note: in a real stateful tab, you'd hoist this state into a persistent builder.
        // Done simply here for brevity.
        Text(
          'Integrate managed cloud APIs using encrypted Spring Boot AES storage.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        StatefulBuilder(
          builder: (context, setFieldState) {
            return Row(
              children: [
                DropdownButton<String>(
                  value: selectedProvider,
                  dropdownColor: AriseColors.surfaceContainerHigh,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AriseColors.onSurface,
                  ),
                  underline: const SizedBox(),
                  items: ['OpenAI', 'Anthropic', 'Google', 'DeepSeek']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setFieldState(() => selectedProvider = val);
                    }
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AriseColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AriseColors.outlineVariant.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                    child: TextField(
                      controller: apiKeyController,
                      obscureText: true,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter API Key *************',
                        hintStyle: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: AriseColors.onSurfaceVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.service.addCloudModel(
                      selectedProvider,
                      apiKeyController.text,
                    );
                    apiKeyController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved cloud API key.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AriseColors.secondary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Add Cloud Model'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
