import 'environment.dart';

class AppConfig {
  static const String appName = 'AI Habit Tracker';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.aaasofttech.aihabittracker';

  // � SECURE: API Configuration using Environment
  static String get geminiApiKey => Environment.geminiApiKey;
  static String get geminiBaseUrl => Environment.baseUrl;
  static const String geminiModel = 'gemini-2.5-flash';

  // API endpoint construction
  static String get geminiEndpoint =>
      '$geminiBaseUrl/$geminiModel:generateContent';

  //Debugging

  static const bool enableApiDebugging = false;
  static Duration apiTimeout = Duration(seconds: 30);

  // Database Configuration
  static const String databaseName = 'habit_tracker.db';
  static const int databaseVersion = 1;

  // Feature Flags
  static const bool enableAnalytics = true;
  static const bool enablePremiumFeatures = true;
  static const bool enableVoiceRecognition = true;
  static const bool enableNotifications = true;

  // Premium Configuration
  static const int freeHabitLimit = 5;
  static const String premiumProductId = 'ai_habit_tracker_premium';

  // Voice Recognition Configuration
  static const Duration voiceListenDuration = Duration(seconds: 10);
  static const Duration voicePauseDuration = Duration(seconds: 3);
  static const String defaultVoiceLanguage = 'en_US';

  // AI Configuration
  static const double aiConfidenceThreshold = 0.6;
  static const int aiInsightCacheDuration = 24; // hours
  static const int maxAiRetries = 3;

  // UI Configuration
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashScreenDuration = Duration(seconds: 2);

  // Notification Configuration
  static const String notificationChannelId = 'habit_reminders';
  static const String notificationChannelName = 'Habit Reminders';
  static const String notificationChannelDescription =
      'Daily habit reminder notifications';

  // Development Configuration
  static const bool isDebugMode = true;
  static const bool enableLogging = true;
}
