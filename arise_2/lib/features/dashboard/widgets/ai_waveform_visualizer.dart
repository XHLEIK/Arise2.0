import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/arise_colors.dart';

/// Enum representing the AI's current voice pipeline state.
enum WaveState { idle, listening, speaking }

/// A responsive, animated voice waveform visualizer replacing the central orb.
/// Built utilizing CustomPainter for optimal 60fps repaints minimizing widget tree thrashing.
class AiWaveformVisualizer extends StatefulWidget {
  final WaveState state;
  final double manualAmplitude;
  final double height;

  const AiWaveformVisualizer({
    super.key,
    this.state = WaveState.idle,
    this.manualAmplitude = 0.0,
    this.height = 80.0,
  });

  @override
  State<AiWaveformVisualizer> createState() => _AiWaveformVisualizerState();
}

class _AiWaveformVisualizerState extends State<AiWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void didUpdateWidget(AiWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      if (widget.state == WaveState.speaking) {
        _controller.duration = const Duration(milliseconds: 800);
        _controller.repeat();
      } else if (widget.state == WaveState.listening) {
        _controller.duration = const Duration(milliseconds: 1200);
        _controller.repeat();
      } else {
        _controller.duration = const Duration(seconds: 2);
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size(double.infinity, widget.height),
              painter: _WaveformPainter(
                progress: _controller.value,
                state: widget.state,
                manualAmplitude: widget.manualAmplitude,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final WaveState state;
  final double manualAmplitude;

  _WaveformPainter({
    required this.progress,
    required this.state,
    required this.manualAmplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int barCount = 40;
    final double barWidth = 4.0;

    // Ensure spacing calculates nicely across any screen width
    final double totalBarWidth = barCount * barWidth;
    double spacing = (size.width - totalBarWidth) / (barCount - 1);
    if (spacing < 2.0) spacing = 2.0;

    // Center layout by recalculating exact drawing width
    final double actualWidth = totalBarWidth + (spacing * (barCount - 1));
    final double startX = (size.width - actualWidth) / 2.0;
    final double centerY = size.height / 2;

    final Paint glowPaint = Paint()
      ..color = AriseColors.primaryContainer.withValues(alpha: 0.15)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth + 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    final Paint barPaint = Paint()
      ..shader = LinearGradient(
        colors: [AriseColors.primary, AriseColors.primaryContainer],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final double baseAmp = _getBaseAmplitude();

    for (int i = 0; i < barCount; i++) {
      double normalizedIndex = i / (barCount - 1);

      // Foundational rolling wave spanning the block
      double angle = (normalizedIndex * pi * 4) + (progress * pi * 2);

      // Inject trigonometric entropy into height mappings
      double heightOffset = sin(angle) * baseAmp;
      double variation = sin(i * 1.5) * baseAmp * 0.5;

      // Assemble final bar raw height scalar
      double activeHeight =
          (baseAmp + heightOffset + variation).abs() * size.height / 2;

      // Apply a gaussian curve multiplier so edges are extremely quiet and center surges
      double centerWeight = 1.0 - (normalizedIndex - 0.5).abs() * 1.8;
      activeHeight *= centerWeight.clamp(0.1, 1.0);

      // Mix incoming manual STT/TTS mic noise floor into the calculation natively
      activeHeight += (manualAmplitude * size.height / 2 * centerWeight);

      // Enforce rendering clip clamps ensuring a flat line when idle and never clipping the box bound
      activeHeight = activeHeight.clamp(2.0, size.height / 2.2);

      final double x = startX + (i * (barWidth + spacing));
      final Offset p1 = Offset(x, centerY - activeHeight);
      final Offset p2 = Offset(x, centerY + activeHeight);

      // Dual-pass rendering for glass/neon bloom effect
      if (activeHeight > 4.0) canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, barPaint);
    }
  }

  double _getBaseAmplitude() {
    switch (state) {
      case WaveState.idle:
        return 0.15;
      case WaveState.listening:
        return 0.35;
      case WaveState.speaking:
        return 0.65;
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.state != state ||
        oldDelegate.manualAmplitude != manualAmplitude;
  }
}
