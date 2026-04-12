import 'package:flutter/material.dart';
import '../../../core/theme/arise_colors.dart';

/// Smart prompt suggestion chips displayed near the command input.
class PromptChips extends StatelessWidget {
  const PromptChips({super.key});

  static const List<_ChipData> _chips = [
    _ChipData(icon: Icons.code_rounded, label: 'Open VS Code'),
    _ChipData(icon: Icons.monitor_heart_rounded, label: 'System status'),
    _ChipData(icon: Icons.summarize_rounded, label: 'Summarize file'),
    _ChipData(icon: Icons.search_rounded, label: 'Search web'),
    _ChipData(icon: Icons.slideshow_rounded, label: 'Generate PPT'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: _chips.map((chip) => _PromptChip(data: chip)).toList(),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.data});

  final _ChipData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        hoverColor: AriseColors.primaryContainer.withValues(alpha: 0.08),
        splashColor: AriseColors.primaryContainer.withValues(alpha: 0.12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AriseColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AriseColors.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.icon, size: 14, color: AriseColors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                data.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AriseColors.onSurfaceVariant,
                  letterSpacing: 0.3,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipData {
  const _ChipData({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
