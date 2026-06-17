import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolves the Gemini API key from `.env` (preferred) or `--dart-define`.
class GeminiConfig {
  GeminiConfig._();

  /// Loaded from [dotenv] after `await dotenv.load(fileName: '.env')` in [main].
  static String get apiKey {
    final fromDotEnv = dotenv.env['GEMINI_API_KEY'];
    if (fromDotEnv != null && fromDotEnv.trim().isNotEmpty) {
      return fromDotEnv.trim().replaceAll(RegExp(r'\s+'), '');
    }
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) {
      return fromDefine.trim().replaceAll(RegExp(r'\s+'), '');
    }
    return '';
  }

  static bool get hasApiKey => apiKey.isNotEmpty;
}
