/// Environment configuration for different build modes
class Environment {
  static const String _geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '', // Fallback for development
  );

  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// Get Gemini API key based on environment
  static String get geminiApiKey {
    // In production, this should come from secure environment variables
    // For now, using the provided key but this should be moved to CI/CD secrets
    return _geminiApiKey;
  }

  /// Check if running in production
  static bool get isProduction => _environment == 'production';

  /// Check if running in debug mode
  static bool get isDebug => _environment == 'development';

  /// App configuration based on environment
  static String get baseUrl {
    switch (_environment) {
      case 'production':
        return 'https://generativelanguage.googleapis.com/v1beta/models';
      case 'staging':
        return 'https://generativelanguage.googleapis.com/v1beta/models';
      default:
        return 'https://generativelanguage.googleapis.com/v1beta/models';
    }
  }
}
