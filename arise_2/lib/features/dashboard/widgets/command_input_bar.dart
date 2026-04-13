import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/arise_colors.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/model_service.dart';
import '../../../core/services/live_feed_service.dart';
import '../../../core/services/device_service.dart';
import '../../../core/widgets/model_selector.dart';

class CommandInputBar extends StatefulWidget {
  const CommandInputBar({super.key});

  @override
  State<CommandInputBar> createState() => _CommandInputBarState();
}

class _CommandInputBarState extends State<CommandInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  bool _hasText = false;
  bool _isVoiceActive = false;
  StreamSubscription? _voiceStateSub;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
    _controller.addListener(() {
      setState(() => _hasText = _controller.text.isNotEmpty);
    });
    _voiceStateSub = liveFeedService.voiceStateStream.listen((state) {
      if (mounted) {
        setState(() {
          if (state == 'VOICE_MODE_ON') _isVoiceActive = true;
          if (state == 'VOICE_MODE_OFF') _isVoiceActive = false;
        });
      }
    });

    deviceService.scanDevices();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _voiceStateSub?.cancel();
    super.dispose();
  }

  void _toggleVoice() {
    if (_isVoiceActive) {
      chatService.stopVoiceMode();
    } else {
      chatService.startVoiceMode();
    }
  }

  void _submit() {
    if (!_hasText) return;
    chatService.sendMessage(_controller.text);
    _controller.clear();
  }

  void _showDevicePicker(BuildContext context, String type) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final isInput = type == 'Microphone';
    final devices = deviceService.devices
        .where((d) => isInput ? d.isInput : d.isOutput)
        .toList();
    if (devices.isEmpty) return;

    final currentDevice = isInput
        ? deviceService.selectedInput
        : deviceService.selectedOutput;

    final selected = await showMenu<AudioDevice>(
      context: context,
      position: position,
      items: devices.map((d) {
        return PopupMenuItem<AudioDevice>(
          value: d,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(d.name),
              if (currentDevice?.id == d.id)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AriseColors.primary,
                ),
            ],
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      setState(() {
        if (isInput) {
          deviceService.selectInputDevice(selected);
        } else {
          deviceService.selectOutputDevice(selected);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: chatService.isGenerating,
      initialData: false,
      builder: (context, snapshot) {
        final isGenerating = snapshot.data ?? false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.hub_rounded,
                    size: 14,
                    color: AriseColors.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Model: ${modelService.activeModel?.name ?? 'Initializing...'}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AriseColors.outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  StreamBuilder<String>(
                    stream: liveFeedService.modelStatus,
                    initialData: liveFeedService.currentStatus,
                    builder: (context, statusSnapshot) {
                      final status = statusSnapshot.data ?? 'Ready ✓';
                      final isLoading = status == 'Loading...';
                      return Row(
                        children: [
                          if (isLoading)
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AriseColors.primary,
                              ),
                            ),
                          if (isLoading) const SizedBox(width: 6),
                          Text(
                            'Status: $status',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: isLoading
                                      ? AriseColors.primary
                                      : AriseColors.outline,
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Spacer(),
                  ModelSelector(service: modelService),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isGenerating
                    ? AriseColors.surfaceContainer
                    : AriseColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _isFocused && !isGenerating
                      ? AriseColors.primaryContainer.withValues(alpha: 0.4)
                      : AriseColors.outlineVariant.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: _isFocused && !isGenerating
                    ? [
                        BoxShadow(
                          color: AriseColors.primaryContainer.withValues(
                            alpha: 0.08,
                          ),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: _isVoiceActive
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  // Attachment
                  if (!_isVoiceActive)
                    _ControlButton(
                      icon: Icons.attach_file_rounded,
                      tooltip: 'Attach file',
                      onPressed: () {},
                    ),
                  if (!_isVoiceActive) const SizedBox(width: 2),
                  // Text input
                  if (!_isVoiceActive)
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !isGenerating,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isGenerating
                              ? AriseColors.outline
                              : AriseColors.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: isGenerating
                              ? 'A.R.I.S.E. is typing...'
                              : 'Ask A.R.I.S.E. anything...',
                          hintStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AriseColors.outline.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: isGenerating ? null : (_) => _submit(),
                      ),
                    ),
                  // Microphone and device picker
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: _isVoiceActive
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AriseColors.error.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 16,
                                    spreadRadius: 4,
                                  ),
                                ],
                              )
                            : null,
                        child: _ControlButton(
                          icon: _isVoiceActive
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          tooltip: _isVoiceActive
                              ? 'Stop Voice'
                              : 'Start Voice',
                          iconColor: _isVoiceActive
                              ? AriseColors.error
                              : AriseColors.onSurfaceVariant,
                          onPressed: _toggleVoice,
                        ),
                      ),
                      if (!_isVoiceActive)
                        Builder(
                          builder: (context) {
                            return _ArrowButton(
                              tooltip: 'Select Microphone',
                              onPressed: () =>
                                  _showDevicePicker(context, 'Microphone'),
                            );
                          },
                        ),
                    ],
                  ),
                  if (_isVoiceActive) const SizedBox(width: 8),
                  // Speaker toggle and device picker
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ControlButton(
                        icon: chatService.isSpeakerMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        tooltip: 'Toggle TTS Output',
                        iconColor: chatService.isSpeakerMuted
                            ? AriseColors.error
                            : AriseColors.onSurfaceVariant,
                        onPressed: () {
                          setState(() {
                            chatService.toggleSpeakerMute();
                          });
                        },
                      ),
                      if (!_isVoiceActive)
                        Builder(
                          builder: (context) {
                            return _ArrowButton(
                              tooltip: 'Select Speaker',
                              onPressed: () =>
                                  _showDevicePicker(context, 'Speaker'),
                            );
                          },
                        ),
                    ],
                  ),
                  if (!_isVoiceActive) const SizedBox(width: 4),
                  // Send button
                  if (!_isVoiceActive)
                    _SendButton(
                      enabled: _hasText,
                      onPressed: _hasText ? _submit : null,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          hoverColor: AriseColors.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? AriseColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;

  const _ArrowButton({required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          hoverColor: AriseColors.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: 20,
              color: AriseColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, this.onPressed});

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: enabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AriseColors.primary, AriseColors.primaryContainer],
              )
            : null,
        color: enabled ? null : AriseColors.surfaceContainerHighest,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AriseColors.primaryContainer.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 20,
            color: enabled
                ? AriseColors.onPrimary
                : AriseColors.outline.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
