import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:zenverse/widgets/ai_chat_bubble/chat_message.dart';

/// Calls Google Gemini [generateContent] with full conversation history.
class GeminiChatService {
  GeminiChatService({
    required this.apiKey,
    this.model = defaultModel,
    http.Client? client,
  }) : _cleanKey = _sanitizeApiKey(apiKey),
       _client = client ?? http.Client();

  static const defaultModel = 'gemini-flash-latest';

  final String apiKey;
  final String model;
  final String _cleanKey;
  final http.Client _client;

  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  static String _sanitizeApiKey(String key) => key.trim().replaceAll(RegExp(r'\s+'), '');

  /// Sends [history] plus optional system hint; returns assistant text or throws [GeminiChatException].
  Future<String> sendMessage(List<ChatMessage> history) async {
    if (_cleanKey.isEmpty) {
      throw const GeminiChatException(
        'Gemini API key is missing. Add GEMINI_API_KEY to the project .env file (see .env.example).',
      );
    }

    if (history.isEmpty) {
      throw const GeminiChatException('No messages to send.');
    }

    final contents = history.map((m) {
      return {
        'role': m.isUser ? 'user' : 'model',
        'parts': [
          {'text': m.text},
        ],
      };
    }).toList();

    final uri = Uri.parse('$_baseUrl/models/$model:generateContent?key=$_cleanKey');

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'contents': contents}),
          )
          .timeout(const Duration(seconds: 45));
    } on http.ClientException catch (e) {
      throw GeminiChatException(
        'No internet connection or network error. Check your connection and try again.',
        cause: e,
      );
    } catch (e) {
      throw GeminiChatException(
        'Could not reach the AI service. Please try again in a moment.',
        cause: e,
      );
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print('Gemini response status: ${response.statusCode}');
      // ignore: avoid_print
      print('Gemini response body: ${response.body}');
    }

    if (response.statusCode == 429) {
      throw const GeminiChatException('Too many requests. Wait a moment and try again.');
    }

    if (response.statusCode != 200) {
      throw GeminiChatException(_friendlyHttpError(response.statusCode, response.body));
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        final block = json['promptFeedback']?['blockReason'];
        if (block != null) {
          throw GeminiChatException('The request was blocked ($block). Try rephrasing your message.');
        }
        throw const GeminiChatException('The AI returned an empty response. Please try again.');
      }
      final parts = candidates.first['content']?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw const GeminiChatException('The AI returned an empty response. Please try again.');
      }
      final text = parts.first['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw const GeminiChatException('The AI returned an empty response. Please try again.');
      }
      return text.trim();
    } catch (e) {
      if (e is GeminiChatException) rethrow;
      throw GeminiChatException('Could not read the AI response.', cause: e);
    }
  }

  String _friendlyHttpError(int status, String body) {
    String? apiMessage;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      apiMessage = json['error']?['message'] as String?;
    } catch (_) {}

    return switch (status) {
      400 => apiMessage ?? 'Invalid request. Please try a shorter message.',
      401 || 403 => 'Invalid API key. Check your GEMINI_API_KEY configuration.',
      429 => 'Too many requests. Wait a moment and try again.',
      500 || 503 => 'The AI service is temporarily unavailable. Try again soon.',
      _ => apiMessage ?? 'Something went wrong (HTTP $status). Please try again.',
    };
  }

  void dispose() => _client.close();
}

class GeminiChatException implements Exception {
  const GeminiChatException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
