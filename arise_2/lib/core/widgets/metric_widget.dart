import 'package:flutter/material.dart';
import '../theme/arise_colors.dart';

/// A compact metric card with icon, value, label, mini progress bar,
/// and sparkline mini-graph. Color-coded by threshold.
class MetricWidget extends StatelessWidget {
  const MetricWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.secondaryValue,
    this.secondaryUnit,
    this.history = const [],
    this.maxValue = 100,
    this.warningThreshold = 70,
    this.criticalThreshold = 90,
  });

  final IconData icon;
  final String label;
  final double value;
  final String unit;
  final double? secondaryValue;
  final String? secondaryUnit;
  final List<double> history;
  final double maxValue;
  final double warningThreshold;
  final double criticalThreshold;

  Color get _valueColor {
    if (value >= criticalThreshold) return const Color(0xFFFF5252);
    if (value >= warningThreshold) return const Color(0xFFFFAB40);
    return AriseColors.primaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AriseColors.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _valueColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + value
          Row(
            children: [
              Icon(icon, size: 12, color: _valueColor.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AriseColors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 9,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                secondaryValue != null
                    ? '${value.toInt()}$unit | ${secondaryValue!.toInt()}${secondaryUnit!}'
                    : '${value.toInt()}$unit',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _valueColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Sparkline mini-graph
          if (history.length > 2)
            SizedBox(
              height: 16,
              child: CustomPaint(
                size: const Size(double.infinity, 16),
                painter: _SparklinePainter(
                  values: history,
                  maxValue: maxValue,
                  color: _valueColor,
                ),
              ),
            ),
          if (history.length <= 2)
            // Fallback: mini progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (value / maxValue).clamp(0, 1),
                minHeight: 3,
                backgroundColor: AriseColors.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _valueColor.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Draws a sparkline mini-graph from historical values.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.maxValue,
    required this.color,
  });

  final List<double> values;
  final double maxValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (values.length - 1).clamp(1, values.length);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y =
          size.height -
          (values[i] / maxValue * size.height).clamp(0, size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Fill gradient
    fillPath.lineTo((values.length - 1) * stepX, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Current value dot
    if (values.isNotEmpty) {
      final lastX = (values.length - 1) * stepX;
      final lastY =
          size.height -
          (values.last / maxValue * size.height).clamp(0, size.height);

      canvas.drawCircle(Offset(lastX, lastY), 2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) => true;
}
