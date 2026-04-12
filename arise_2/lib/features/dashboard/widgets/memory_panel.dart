import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/arise_colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/ai_pulse.dart';

/// Memory Sectors panel — circular progress indicators, status lines,
/// and the AI pulse breathing animation.
class MemoryPanel extends StatelessWidget {
  const MemoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      backgroundColor: AriseColors.surfaceContainerLow.withValues(alpha: 0.8),
      padding: const EdgeInsets.all(24),
      borderRadius: 16,
      blurAmount: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HUD header
          Row(
            children: [
              Icon(
                Icons.memory_rounded,
                size: 18,
                color: AriseColors.secondary,
              ),
              const SizedBox(width: 10),
              Text(
                'MEMORY_SECTORS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AriseColors.secondary,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Memory rings row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MemoryRing(
                label: 'SHORT-TERM',
                value: 0.62,
                color: AriseColors.primaryContainer,
                sizeLabel: '1.2 GB',
              ),
              _MemoryRing(
                label: 'SEMANTIC',
                value: 0.84,
                color: AriseColors.secondary,
                sizeLabel: '3.4 GB',
              ),
              _MemoryRing(
                label: 'STRUCTURED',
                value: 0.35,
                color: AriseColors.tertiary,
                sizeLabel: '840 MB',
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Status area with AI pulse
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AriseColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const AiPulse(size: 38),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRIMARY_CORE_ONLINE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AriseColors.primaryContainer,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Executing Task...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AriseColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Heartbeat indicator
                _HeartbeatDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated circular progress ring with center label.
class _MemoryRing extends StatefulWidget {
  const _MemoryRing({
    required this.label,
    required this.value,
    required this.color,
    required this.sizeLabel,
  });

  final String label;
  final double value;
  final Color color;
  final String sizeLabel;

  @override
  State<_MemoryRing> createState() => _MemoryRingState();
}

class _MemoryRingState extends State<_MemoryRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: _progressAnimation.value,
                  color: widget.color,
                  trackColor: AriseColors.surfaceContainerHighest,
                ),
                child: Center(
                  child: Text(
                    '${(_progressAnimation.value * 100).toInt()}%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: widget.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AriseColors.onSurfaceVariant,
            fontSize: 9,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.sizeLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: widget.color.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 5.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );

    // Glow arc
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = strokeWidth + 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Three dots that pulse sequentially for a heartbeat effect.
class _HeartbeatDots extends StatefulWidget {
  @override
  State<_HeartbeatDots> createState() => _HeartbeatDotsState();
}

class _HeartbeatDotsState extends State<_HeartbeatDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animValue = ((_controller.value - delay) % 1.0).clamp(
              0.0,
              1.0,
            );
            final opacity = (sin(animValue * pi)).clamp(0.2, 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AriseColors.primaryContainer.withValues(
                    alpha: opacity,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
