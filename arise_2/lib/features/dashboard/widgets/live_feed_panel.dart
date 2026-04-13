import 'package:flutter/material.dart';
import '../../../core/theme/arise_colors.dart';
import '../../../core/widgets/glass_container.dart';

/// Live Event Feed panel — scrollable, auto-populated log entries
/// with left accent lines and fade-in animation.
class LiveFeedPanel extends StatefulWidget {
  final bool isHidden;
  final VoidCallback onToggle;
  const LiveFeedPanel({
    super.key,
    required this.isHidden,
    required this.onToggle,
  });

  @override
  State<LiveFeedPanel> createState() => _LiveFeedPanelState();
}

class _LiveFeedPanelState extends State<LiveFeedPanel> {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      backgroundColor: AriseColors.surfaceContainerLow.withValues(alpha: 0.8),
      padding: EdgeInsets.all(widget.isHidden ? 14 : 10),
      borderRadius: 16,
      blurAmount: 10,
      child: Column(
        crossAxisAlignment: widget.isHidden ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // HUD header
          Row(
            mainAxisAlignment: widget.isHidden ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  widget.isHidden
                      ? Icons.keyboard_arrow_left_rounded
                      : Icons.keyboard_arrow_right_rounded,
                ),
                color: AriseColors.onSurfaceVariant,
                iconSize: 20,
                onPressed: widget.onToggle,
              ),
              if (!widget.isHidden) ...[
                const SizedBox(width: 10),
                Icon(
                  Icons.terminal_rounded,
                  size: 18,
                  color: AriseColors.primaryContainer,
                ),
                const SizedBox(width: 10),
                Text(
                  'ACTIVE_SESSIONS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AriseColors.primaryContainer,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ],
          ),
          if (!widget.isHidden) const SizedBox(height: 16),
          // Feed entries
          if (!widget.isHidden)
            const Expanded(
              child: Center(
                child: Text(
                  'No active sessions.',
                  style: TextStyle(
                    color: AriseColors.outline,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
