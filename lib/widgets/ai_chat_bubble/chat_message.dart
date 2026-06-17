/// A single turn in the AI chat conversation.
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// `user` or `ai` (mapped to Gemini `model` role when sending).
  final String role;
  final String text;
  final DateTime timestamp;

  bool get isUser => role == 'user';
  bool get isAi => role == 'ai';

  ChatMessage copyWith({String? role, String? text, DateTime? timestamp}) {
    return ChatMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
