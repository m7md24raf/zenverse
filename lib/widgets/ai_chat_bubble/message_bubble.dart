import 'package:flutter/material.dart';
import 'package:zenverse/widgets/ai_chat_bubble/chat_message.dart';
import 'package:zenverse/widgets/ai_chat_bubble/typing_indicator.dart';

/// Renders one chat line — user (right / primary) or AI (left / surface).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.showTyping = false,
  });

  final ChatMessage message;
  final bool showTyping;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = message.isUser;

    final bg = isUser ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = isUser ? scheme.onPrimary : scheme.onSurface;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 18),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: DecoratedBox(
              decoration: BoxDecoration(color: bg, borderRadius: radius),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: showTyping
                    ? const TypingIndicator()
                    : Text(message.text, style: theme.textTheme.bodyMedium?.copyWith(color: fg, height: 1.35)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
