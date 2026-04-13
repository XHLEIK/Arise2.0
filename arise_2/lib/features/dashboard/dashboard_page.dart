import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/arise_colors.dart';
import '../../core/services/live_feed_service.dart';
import '../../core/services/chat_service.dart';
import 'widgets/ai_waveform_visualizer.dart';
import 'widgets/chat_timeline.dart';
import 'widgets/command_input_bar.dart';
import 'widgets/prompt_chips.dart';
import 'widgets/memory_panel.dart';
import 'widgets/live_feed_panel.dart';

import '../../core/services/system_metrics_service.dart';

/// Jarvis-style AI Command Center dashboard.
/// The top bar is now global (in AppShell), so this page only has:
/// Center: Orb + status + chat + chips + input
/// Right: Memory sectors + live event feed
class DashboardPage extends StatefulWidget {
  final SystemMetricsService metricsService;
  
  const DashboardPage({super.key, required this.metricsService});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isAgentLogHidden = false;
  bool _isSessionsHidden = false;
  WaveState _waveState = WaveState.idle;
  double _currentAmplitude = 0.0;
  bool _isThinking = false;
  bool _isVoiceActive = false;

  StreamSubscription? _ampSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _transcriptSub;

  bool _hasGreeted = false;

  @override
  void initState() {
    super.initState();

    liveFeedService.modelStatus.listen((status) {
      if (mounted && status == 'Ready ✓' && !_hasGreeted) {
        _hasGreeted = true;
        chatService.generateGreeting();
      }
    });

    _ampSub = liveFeedService.amplitudeStream.listen((amp) {
      if (mounted) setState(() => _currentAmplitude = amp);
    });

    _stateSub = liveFeedService.voiceStateStream.listen((stateStr) {
      if (mounted) {
        setState(() {
          if (stateStr == 'VOICE_MODE_OFF') {
            _waveState = WaveState.idle;
            _isVoiceActive = false;
          } else if (stateStr == 'VOICE_MODE_ON') {
            _waveState = WaveState.idle;
            _isVoiceActive = true;
          } else if (stateStr == 'LISTENING') {
            _waveState = WaveState.idle;
            _isThinking = false;
            _isVoiceActive = true;
          } else if (stateStr == 'USER_SPEAKING' ||
              stateStr == 'SPEECH_DETECTED') {
            _waveState = WaveState.listening;
            _isThinking = false;
            _isVoiceActive = true;
          } else if (stateStr == 'USER_STOPPED_SPEAKING' ||
              stateStr == 'AI_THINKING') {
            _waveState = WaveState.idle;
            _isThinking = true;
          } else if (stateStr == 'TTS_START') {
            _waveState = WaveState.speaking;
            _isThinking = false;
          } else if (stateStr == 'TTS_END') {
            _waveState = WaveState.idle;
          }
        });
      }
    });

    _transcriptSub = liveFeedService.transcriptStream.listen((text) {
      chatService.sendMessage(text);
    });
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _stateSub?.cancel();
    _transcriptSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rightPanelsHidden = _isAgentLogHidden && _isSessionsHidden;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Center Column (Flexible) ──
          Expanded(flex: rightPanelsHidden ? 85 : 65, child: _buildCenterColumn(context)),
          const SizedBox(width: 20),
          // ── Right Column (Flexible handling) ──
          _buildRightColumn(),
        ],
      ),
    );
  }

  Widget _buildCenterColumn(BuildContext context) {
    return Column(
      children: [
        // ── AI Voice Waveform ──
        SizedBox(
          height: 140,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _cycleState,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: AiWaveformVisualizer(
                      state: _waveState,
                      manualAmplitude: _currentAmplitude,
                      height: 60,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _stateLabel,
                    key: ValueKey(_waveState),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _stateColor.withValues(alpha: 0.8),
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Chat Timeline ──
        const Expanded(flex: 6, child: ChatTimeline()),
        const SizedBox(height: 12),
        // ── Prompt Chips ──
        const PromptChips(),
        const SizedBox(height: 14),
        // ── Command Input ──
        const CommandInputBar(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          width: _isAgentLogHidden ? 60 : MediaQuery.of(context).size.width * 0.30,
          child: MemoryPanel(
            metricsService: widget.metricsService,
            isHidden: _isAgentLogHidden,
            onToggle: () => setState(() => _isAgentLogHidden = !_isAgentLogHidden),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          flex: _isSessionsHidden ? 0 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            width: _isSessionsHidden ? 60 : MediaQuery.of(context).size.width * 0.30,
            constraints: _isSessionsHidden ? const BoxConstraints(minHeight: 60) : null,
            child: LiveFeedPanel(
              isHidden: _isSessionsHidden,
              onToggle: () => setState(() => _isSessionsHidden = !_isSessionsHidden),
            ),
          ),
        ),
      ],
    );
  }

  void _cycleState() {
    setState(() {
      final values = WaveState.values;
      _waveState = values[(_waveState.index + 1) % values.length];
    });
  }

  String get _stateLabel {
    if (_isThinking) return 'PROCESSING...';
    switch (_waveState) {
      case WaveState.idle:
        return _isVoiceActive ? 'LISTENING...' : 'SYSTEMS ONLINE';
      case WaveState.listening:
        return 'RECEIVING...';
      case WaveState.speaking:
        return 'SPEAKING...';
    }
  }

  Color get _stateColor {
    if (_isThinking) return AriseColors.outline;
    switch (_waveState) {
      case WaveState.idle:
        return _isVoiceActive
            ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
            : AriseColors.primaryContainer;
      case WaveState.listening:
        return const Color(0xFF00E5FF);
      case WaveState.speaking:
        return AriseColors.primaryContainer;
    }
  }
}
