import 'package:flutter/material.dart';
import '../../../core/theme/arise_colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/chat_service.dart';

/// Right-hand session sidebar — list, create, pin, rename, delete chat sessions.
class SessionsPanel extends StatefulWidget {
  final bool isHidden;
  final VoidCallback onToggle;
  final Future<void> Function(String sessionId)? onSessionSelected;

  const SessionsPanel({
    super.key,
    required this.isHidden,
    required this.onToggle,
    this.onSessionSelected,
  });

  @override
  State<SessionsPanel> createState() => _SessionsPanelState();
}

class _SessionsPanelState extends State<SessionsPanel> {
  @override
  void initState() {
    super.initState();
    sessionService.refreshSessions();
  }

  @override
  void didUpdateWidget(SessionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isHidden && !widget.isHidden) {
      sessionService.refreshSessions();
    }
  }

  Future<void> _createSession() async {
    await chatService.startNewSession();
    if (mounted) setState(() {});
  }

  Future<void> _selectSession(String sessionId) async {
    await sessionService.activateSession(sessionId);
    await widget.onSessionSelected?.call(sessionId);
  }

  Future<void> _togglePin(ChatSessionSummary session) async {
    await sessionService.setPinned(session.sessionId, !session.pinned);
  }

  Future<void> _renameSession(ChatSessionSummary session) async {
    final controller = TextEditingController(text: session.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AriseColors.surfaceContainerHigh,
        title: const Text('Rename session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Session title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      await sessionService.renameSession(session.sessionId, newTitle);
    }
  }

  Future<void> _deleteSession(ChatSessionSummary session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AriseColors.surfaceContainerHigh,
        title: const Text('Delete session?'),
        content: Text('Delete "${session.title}" and all its messages?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AriseColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await sessionService.deleteSession(session.sessionId);
      if (sessionService.activeSessionId != null) {
        await widget.onSessionSelected?.call(sessionService.activeSessionId!);
      } else {
        await _createSession();
      }
    }
  }

  void _showSessionMenu(ChatSessionSummary session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AriseColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(session.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(session.pinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _renameSession(session);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AriseColors.error),
              title: Text('Delete', style: TextStyle(color: AriseColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteSession(session);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      backgroundColor: AriseColors.surfaceContainerLow.withValues(alpha: 0.8),
      padding: EdgeInsets.all(widget.isHidden ? 14 : 10),
      borderRadius: 16,
      blurAmount: 10,
      child: Column(
        crossAxisAlignment:
            widget.isHidden ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                widget.isHidden ? MainAxisAlignment.center : MainAxisAlignment.start,
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
                const SizedBox(width: 8),
                Icon(Icons.forum_outlined, size: 16, color: AriseColors.primaryContainer),
                const SizedBox(width: 8),
                Text(
                  'SESSIONS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AriseColors.primaryContainer,
                        letterSpacing: 2.0,
                        fontSize: 10,
                      ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'New session',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  color: AriseColors.primaryContainer,
                  onPressed: _createSession,
                ),
              ],
            ],
          ),
          if (!widget.isHidden) ...[
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<ChatSessionSummary>>(
                stream: sessionService.sessions,
                initialData: sessionService.currentSessions,
                builder: (context, snapshot) {
                  final sessions = snapshot.data ?? sessionService.currentSessions;
                  if (sessions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'No sessions yet',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AriseColors.outline,
                                ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _createSession,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Start a chat'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isActive = sessionService.activeSessionId == session.sessionId;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _selectSession(session.sessionId),
                          onLongPress: () => _showSessionMenu(session),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AriseColors.primaryContainer.withValues(alpha: 0.12)
                                  : AriseColors.surfaceContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isActive
                                    ? AriseColors.primaryContainer.withValues(alpha: 0.35)
                                    : AriseColors.outlineVariant.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (session.pinned)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.push_pin,
                                      size: 12,
                                      color: AriseColors.secondary.withValues(alpha: 0.8),
                                    ),
                                  ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: isActive
                                                  ? AriseColors.onSurface
                                                  : AriseColors.onSurfaceVariant,
                                              fontWeight:
                                                  isActive ? FontWeight.w600 : FontWeight.w400,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${session.messageCount} messages',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: AriseColors.outline,
                                              fontSize: 9,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  icon: const Icon(Icons.more_vert, size: 16),
                                  color: AriseColors.outline,
                                  onPressed: () => _showSessionMenu(session),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
