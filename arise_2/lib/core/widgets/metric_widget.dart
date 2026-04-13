import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A compact futuristic metric card with icon, value, label, mini progress bar,
/// and sparkline mini-graph. Color-coded per metric.
class MetricWidget extends StatefulWidget {
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

  @override
  State<MetricWidget> createState() => _MetricWidgetState();
}

class _MetricWidgetState extends State<MetricWidget> {
  bool _isHovered = false;

  Color get _valueColor {
    // Specific fixed colors based on prompt
    final String l = widget.label.toUpperCase();
    if (l == 'CPU') return const Color(0xFF00E5FF); // Cyan
    if (l == 'GPU') return const Color(0xFF9D4EDD); // Purple
    if (l == 'RAM') return const Color(0xFFF59E0B); // Amber
    if (l == 'DISK') return const Color(0xFF14B8A6); // Teal
    // Fallback
    return const Color(0xFF00E5FF);
  }

  @override
  Widget build(BuildContext context) {
    final color = _valueColor;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xBF141823), // rgba(20, 24, 35, 0.75)
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered 
                ? color.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Metric Name + Status Dot
            Row(
              children: [
                Icon(widget.icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  widget.label.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                // Micro glowing status indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Center: Large value number
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${widget.value.toInt()}',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  widget.unit,
                  style: GoogleFonts.inter(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Secondary Info
            if (widget.secondaryValue != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '${widget.secondaryValue!.toInt()}${widget.secondaryUnit}',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 9,
                  ),
                ),
              )
            else
              const SizedBox(height: 10), // Placeholder to keep heights consistent
            
            const Spacer(),

            // Bottom: Animated Live Graph
            SizedBox(
              height: 10,
              width: double.infinity,
              child: widget.history.length > 1
                  ? CustomPaint(
                      painter: _FuturisticSparklinePainter(
                        values: widget.history,
                        maxValue: widget.maxValue,
                        color: color,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (widget.value / widget.maxValue).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Futuristic Sparkline with neon glow
class _FuturisticSparklinePainter extends CustomPainter {
  _FuturisticSparklinePainter({
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
      final y = size.height - (values[i] / maxValue * size.height).clamp(0, size.height);

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
        colors: [
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Glowing Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1); // Soft glow

    canvas.drawPath(path, linePaint);

    // Current value dot
    if (values.isNotEmpty) {
      final lastX = (values.length - 1) * stepX;
      final lastY = size.height - (values.last / maxValue * size.height).clamp(0, size.height);

      canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(lastX, lastY), 5, Paint()..color = color.withValues(alpha: 0.5));
    }
  }

  @override
  bool shouldRepaint(_FuturisticSparklinePainter oldDelegate) => true;
}
