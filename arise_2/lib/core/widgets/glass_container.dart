import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/arise_colors.dart';

/// A reusable glassmorphism container following the Cinematic Intelligence
/// Framework — backdrop blur, semi-transparent bg, and optional neon glow.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 16,
    this.blurAmount = 16,
    this.backgroundColor,
    this.glowColor,
    this.glowSpread = 0,
    this.glowBlur = 40,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurAmount;
  final Color? backgroundColor;
  final Color? glowColor;
  final double glowSpread;
  final double glowBlur;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                  color: glowColor!,
                  blurRadius: glowBlur,
                  spreadRadius: glowSpread,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor ?? AriseColors.glassBg,
              borderRadius: BorderRadius.circular(borderRadius),
              border:
                  border ??
                  Border.all(color: AriseColors.ghostBorder, width: 1),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
