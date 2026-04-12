import 'package:flutter/material.dart';
import '../../../core/theme/arise_colors.dart';
import '../../../core/widgets/glass_container.dart';

/// The Active Automations panel — HUD-style label header with
/// an icon chip and count badge.
class AutomationPanel extends StatelessWidget {
  const AutomationPanel({super.key});

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
                Icons.bolt_rounded,
                size: 18,
                color: AriseColors.primaryContainer,
              ),
              const SizedBox(width: 10),
              Text(
                'ACTIVE_AUTOMATIONS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AriseColors.primaryContainer,
                  letterSpacing: 2.0,
                ),
              ),
              const Spacer(),
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AriseColors.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AriseColors.primaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AriseColors.primaryContainer,
                        boxShadow: [
                          BoxShadow(
                            color: AriseColors.primaryContainer.withValues(
                              alpha: 0.6,
                            ),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '3 RUNNING',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AriseColors.primaryContainer,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Automation items
          _AutomationItem(
            name: 'Neural Path Optimizer',
            status: 'Active',
            progress: 0.78,
            icon: Icons.psychology_rounded,
          ),
          const SizedBox(height: 12),
          _AutomationItem(
            name: 'Memory Defragmentation',
            status: 'Queued',
            progress: 0.45,
            icon: Icons.auto_fix_high_rounded,
            color: AriseColors.secondary,
          ),
          const SizedBox(height: 12),
          _AutomationItem(
            name: 'Kernel Watchdog',
            status: 'Monitoring',
            progress: 1.0,
            icon: Icons.visibility_rounded,
            color: AriseColors.tertiary,
          ),
        ],
      ),
    );
  }
}

class _AutomationItem extends StatelessWidget {
  const _AutomationItem({
    required this.name,
    required this.status,
    required this.progress,
    required this.icon,
    this.color,
  });

  final String name;
  final String status;
  final double progress;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AriseColors.primaryContainer;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AriseColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AriseColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AriseColors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(c),
            ),
          ),
        ],
      ),
    );
  }
}
