import 'package:flutter/material.dart';
import '../../../core/theme/arise_colors.dart';
import '../../../core/services/chat_service.dart';

/// A compact scrollable chat transcript panel.
/// Shows user and AI messages in a futuristic assistant transcript style.
class ChatTimeline extends StatefulWidget {
  const ChatTimeline({super.key});

  @override
  State<ChatTimeline> createState() => _ChatTimelineState();
}

class _ChatTimelineState extends State<ChatTimeline> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: const [0.0, 0.08, 0.92, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: StreamBuilder<List<ChatMessage>>(
        stream: chatService.messages,
        initialData: const [],
        builder: (context, snapshot) {
          final messages = snapshot.data ?? [];
          if (messages.isEmpty) {
            return const Center(
              child: Text(
                'Awaiting input...',
                style: TextStyle(color: AriseColors.outline, fontSize: 12),
              ),
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          });

          return ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return _ChatBubble(message: messages[index]);
            },
          );
        },
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(isUser),
          if (!isUser) const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AriseColors.surfaceContainerHigh
                    : AriseColors.surfaceContainerLow,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
                border: Border.all(
                  color: isUser
                      ? AriseColors.outlineVariant.withValues(alpha: 0.2)
                      : AriseColors.primaryContainer.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isUser
                          ? AriseColors.onSurface
                          : AriseColors.tertiary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.time,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AriseColors.outline.withValues(alpha: 0.5),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 10),
          if (isUser) _buildAvatar(isUser),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser
            ? AriseColors.surfaceContainerHighest
            : AriseColors.primaryContainer.withValues(alpha: 0.15),
        border: Border.all(
          color: isUser
              ? AriseColors.outlineVariant.withValues(alpha: 0.3)
              : AriseColors.primaryContainer.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
        size: 14,
        color: isUser
            ? AriseColors.onSurfaceVariant
            : AriseColors.primaryContainer,
      ),
    );
  }
}
