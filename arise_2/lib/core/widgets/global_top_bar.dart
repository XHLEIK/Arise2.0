import 'package:flutter/material.dart';
import '../theme/arise_colors.dart';
import '../services/system_metrics_service.dart';
import '../services/model_service.dart';
import '../services/weather_service.dart';
import 'metric_widget.dart';
import 'model_selector.dart';
import 'weather_clock_widget.dart';

/// Global top system bar across the entire application.
/// Left: A.R.I.S.E. title
/// Center: 6 real-time system metric widgets with sparklines
/// Right: Model selector, weather, clock
class GlobalTopBar extends StatelessWidget {
  const GlobalTopBar({
    super.key,
    required this.metricsService,
    required this.modelService,
    required this.weatherService,
  });

  final SystemMetricsService metricsService;
  final ModelService modelService;
  final WeatherService weatherService;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AriseColors.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: AriseColors.outlineVariant.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // ── Left: Title ──
          _buildTitle(context),
          const SizedBox(width: 32),
          // ── Center: Metrics ──
          Expanded(child: _buildMetrics(context)),
          const SizedBox(width: 16),
          // ── Right: Model + Weather + Clock ──
          _buildRightSection(context),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing dot
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AriseColors.primaryContainer,
            boxShadow: [
              BoxShadow(
                color: AriseColors.primaryContainer.withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'A.R.I.S.E.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AriseColors.onSurface,
            letterSpacing: 3.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMetrics(BuildContext context) {
    return StreamBuilder<SystemMetrics>(
      stream: metricsService.metrics,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final m = snapshot.data!;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(width: 8),
              MetricWidget(
                icon: Icons.memory_rounded,
                label: 'GPU',
                value: m.gpuUsage,
                unit: '%',
                secondaryValue: m.gpuTemp,
                secondaryUnit: '°C',
                history: metricsService.currentGpuHistory,
              ),
              const SizedBox(width: 8),
              MetricWidget(
                icon: Icons.developer_board_rounded,
                label: 'RAM',
                value: m.ramUsage,
                unit: '%',
                history: metricsService.currentRamHistory,
              ),
              const SizedBox(width: 8),
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
          ),
        );
      },
    );
  }

  Widget _buildRightSection(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ModelSelector(service: modelService),
        const SizedBox(width: 10),
        WeatherClockWidget(service: weatherService),
      ],
    );
  }
}
