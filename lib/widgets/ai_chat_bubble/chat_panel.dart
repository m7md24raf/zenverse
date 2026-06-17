import 'package:flutter/material.dart';
import 'package:zenverse/widgets/ai_chat_bubble/chat_message.dart';
import 'package:zenverse/widgets/ai_chat_bubble/gemini_chat_service.dart';
import 'package:zenverse/widgets/ai_chat_bubble/message_bubble.dart';

/// Full chat UI: scrollable messages, input field, send button, typing state.
class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.geminiService,
    this.assistantTitle = 'Zen AI',
    this.showHeader = true,
  });

  final GeminiChatService geminiService;
  final String assistantTitle;
  final bool showHeader;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Local welcome only — never sent to Gemini.
    _messages.add(
      ChatMessage(
        role: 'ai',
        text:
            "Hi! I'm ${widget.assistantTitle}. Ask me anything about focus, productivity, or your Zenverse journey.",
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Conversation turns for the API — excludes the hardcoded welcome shown before any user message.
  List<ChatMessage> _apiHistory() {
    final firstUser = _messages.indexWhere((m) => m.isUser);
    if (firstUser < 0) return const [];
    return _messages.sublist(firstUser);
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    final text = _input.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
      _messages.add(ChatMessage(role: 'user', text: text));
    });
    _input.clear();
    _scrollToBottom();

    try {
      final historyForApi = _apiHistory();
      final reply = await widget.geminiService.sendMessage(historyForApi);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'ai', text: reply));
      });
    } on GeminiChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'ai', text: e.message));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'ai',
            text: 'Something unexpected happened. Please try again.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: scheme.surface,
      borderRadius: widget.showHeader
          ? const BorderRadius.vertical(top: Radius.circular(20))
          : BorderRadius.zero,
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (widget.showHeader) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy_outlined, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.assistantTitle,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ],
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isSending && index == _messages.length) {
                    return MessageBubble(
                      message: ChatMessage(role: 'ai', text: ''),
                      showTyping: true,
                    );
                  }
                  return MessageBubble(message: _messages[index]);
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_isSending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _isSending ? null : (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ask Zen AI…',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSending ? null : _sendMessage,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: const Icon(Icons.send_rounded, size: 22),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
