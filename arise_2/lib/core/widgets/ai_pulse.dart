import 'package:flutter/material.dart';
import '../theme/arise_colors.dart';

/// A breathing circular glow that indicates AI processing.
/// Uses the secondary (violet) palette with a smooth pulsing animation.
class AiPulse extends StatefulWidget {
  const AiPulse({
    super.key,
    this.size = 48,
    this.color,
    this.minOpacity = 0.3,
    this.maxOpacity = 0.8,
    this.duration = const Duration(milliseconds: 2000),
  });

  final double size;
  final Color? color;
  final double minOpacity;
  final double maxOpacity;
  final Duration duration;

  @override
  State<AiPulse> createState() => _AiPulseState();
}

class _AiPulseState extends State<AiPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AriseColors.aiPulse;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: _opacityAnimation.value),
                  color.withValues(alpha: _opacityAnimation.value * 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: _opacityAnimation.value * 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: widget.size * 0.35,
                height: widget.size * 0.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(
                    alpha: _opacityAnimation.value * 1.2 > 1.0
                        ? 1.0
                        : _opacityAnimation.value * 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
