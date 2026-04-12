import 'package:flutter/material.dart';
import '../../../core/theme/arise_colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/services/live_feed_service.dart';

/// Live Event Feed panel — scrollable, auto-populated log entries
/// with left accent lines and fade-in animation.
class LiveFeedPanel extends StatefulWidget {
  const LiveFeedPanel({super.key});

  @override
  State<LiveFeedPanel> createState() => _LiveFeedPanelState();
}

class _LiveFeedPanelState extends State<LiveFeedPanel> {
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
                Icons.terminal_rounded,
                size: 18,
                color: AriseColors.primaryContainer,
              ),
              const SizedBox(width: 10),
              Text(
                'LIVE_EVENT_FEED',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AriseColors.primaryContainer,
                  letterSpacing: 2.0,
                ),
              ),
              const Spacer(),
              // Blinking live dot
              _BlinkingDot(),
            ],
          ),
          const SizedBox(height: 16),
          // Feed entries
          Expanded(
            child: StreamBuilder<List<FeedEntry>>(
              stream: liveFeedService.entries,
              initialData: const [],
              builder: (context, snapshot) {
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'Awaiting System Events...',
                      style: TextStyle(
                        color: AriseColors.outline,
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    return _FeedRow(
                      entry: entries[index],
                      delay: Duration(milliseconds: 100 * index),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedRow extends StatefulWidget {
  const _FeedRow({required this.entry, required this.delay});

  final FeedEntry entry;
  final Duration delay;

  @override
  State<_FeedRow> createState() => _FeedRowState();
}

class _FeedRowState extends State<_FeedRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _FeedType parsedType = _FeedType.info;
    if (widget.entry.type.contains('success')) parsedType = _FeedType.success;
    if (widget.entry.type.contains('security')) parsedType = _FeedType.security;
    if (widget.entry.type.contains('action')) parsedType = _FeedType.action;
    if (widget.entry.type.contains('error')) parsedType = _FeedType.security;

    final color = parsedType.color;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AriseColors.surfaceContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: color.withValues(alpha: 0.6), width: 2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timestamp
            Text(
              widget.entry.time,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AriseColors.outline,
                fontSize: 10,
                letterSpacing: 0.5,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 12),
            // Message
            Expanded(
              child: Text(
                widget.entry.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AriseColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
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

enum _FeedType {
  success,
  security,
  info,
  action;

  Color get color {
    switch (this) {
      case _FeedType.success:
        return AriseColors.primaryContainer;
      case _FeedType.security:
        return AriseColors.secondary;
      case _FeedType.info:
        return AriseColors.onSurfaceVariant;
      case _FeedType.action:
        return AriseColors.tertiary;
    }
  }
}
