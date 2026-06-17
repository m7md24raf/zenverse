import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zenverse/widgets/ai_chat_bubble/chat_panel.dart';
import 'package:zenverse/widgets/ai_chat_bubble/gemini_chat_service.dart';

/// Full-screen chat route opened from [AiChatBubble].
class ChatFullScreen extends StatelessWidget {
  const ChatFullScreen({
    super.key,
    required this.assistantTitle,
    required this.geminiService,
  });

  final String assistantTitle;
  final GeminiChatService geminiService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.smart_toy_outlined),
            const SizedBox(width: 8),
            Text(assistantTitle),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: ChatPanel(
        geminiService: geminiService,
        assistantTitle: assistantTitle,
        showHeader: false,
      ),
    );
  }
}
