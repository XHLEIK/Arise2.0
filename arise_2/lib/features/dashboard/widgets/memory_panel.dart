import '../../../core/services/live_feed_service.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/arise_colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/ai_pulse.dart';
import '../../../core/services/system_metrics_service.dart';
import '../../../core/widgets/metric_widget.dart';

/// System Matrix panel — displaying critical system stats in real-time.
class MemoryPanel extends StatelessWidget {
  final bool isHidden;
  final VoidCallback onToggle;
  final SystemMetricsService metricsService;
  const MemoryPanel({
    super.key,
    required this.metricsService,
    required this.isHidden,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      backgroundColor: AriseColors.surfaceContainerLow.withValues(alpha: 0.8),
      padding: EdgeInsets.all(isHidden ? 14 : 10),
      borderRadius: 16,
      blurAmount: 10,
      child: Column(
        crossAxisAlignment: isHidden ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // HUD header
          Row(
            mainAxisAlignment: isHidden ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isHidden
                      ? Icons.keyboard_arrow_left_rounded
                      : Icons.keyboard_arrow_right_rounded,
                ),
                color: AriseColors.onSurfaceVariant,
                iconSize: 20,
                onPressed: onToggle,
              ),
              if (!isHidden) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.memory_rounded,
                  size: 14,
                  color: AriseColors.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'SYSTEM_MATRIX',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AriseColors.secondary,
                    letterSpacing: 2.0,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                _BlinkingDot(),
              ],
            ],
          ),

          // Memory sectors with live system metrics rebuilt using GridView/Wrap
          if (!isHidden) const SizedBox(height: 8),
          if (!isHidden)
            StreamBuilder<SystemMetrics>(
              stream: metricsService.metrics,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final m = snapshot.data!;
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.8,
                  children: [
                    MetricWidget(
                      icon: Icons.speed_rounded,
                      label: 'CPU',
                      value: m.cpuUsage,
                      unit: '%',
                      secondaryValue: m.cpuTemp,
                      secondaryUnit: '°C',
                      history: metricsService.currentCpuHistory,
                    ),
                    MetricWidget(
                      icon: Icons.memory_rounded,
                      label: 'GPU',
                      value: m.gpuUsage,
                      unit: '%',
                      secondaryValue: m.gpuTemp,
                      secondaryUnit: '°C',
                      history: metricsService.currentGpuHistory,
                    ),
                    MetricWidget(
                      icon: Icons.developer_board_rounded,
                      label: 'RAM',
                      value: m.ramUsage,
                      unit: '%',
                      history: metricsService.currentRamHistory,
                    ),
                    MetricWidget(
                      icon: Icons.storage_rounded,
                      label: 'DISK',
                      value: m.storageUsage,
                      unit: '%',
                      history: metricsService.currentStorageHistory,
                      warningThreshold: 85,
                      criticalThreshold: 95,
                    ),
                  ],
                );
              },
            ),

          if (!isHidden) const SizedBox(height: 10),

          // Status area with live event
          if (!isHidden)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AriseColors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const AiPulse(size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SYSTEM_MATRIX',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AriseColors.primaryContainer,
                                letterSpacing: 1.2,
                                fontSize: 9,
                              ),
                        ),
                        const SizedBox(height: 2),
                        StreamBuilder<List<FeedEntry>>(
                          stream: liveFeedService.entries,
                          initialData: const [],
                          builder: (context, snapshot) {
                            final entries = snapshot.data ?? [];
                            String msg = entries.isEmpty
                                ? 'Awaiting System Events...'
                                : entries.first.message;
                            return Text(
                              msg,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AriseColors.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  _HeartbeatDots(),
                ],
              ),
            ),
        ],
      ),
    );
  }
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

/// Blinking "LIVE" indicator dot.
class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
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
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(
                  0xFF4CAF50,
                ).withValues(alpha: 0.5 + _controller.value * 0.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF4CAF50,
                    ).withValues(alpha: _controller.value * 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'LIVE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF4CAF50),
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }
}
