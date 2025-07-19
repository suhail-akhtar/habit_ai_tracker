class AppConfig {
  static const String appName = 'AI Voice Habit Tracker';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String geminiApiKey = 'AIzaSyCYEdW8B5WhT15w6Xb8pSOeXhtJwiQJBoc';
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // Database Configuration
  static const String databaseName = 'habit_tracker.db';
  static const int databaseVersion = 1;

  // Feature Flags
  static const bool enableAnalytics = true;
  static const bool enablePremiumFeatures = true;
  static const bool enableVoiceRecognition = true;
  static const bool enableNotifications = true;

  // Premium Configuration
  static const int freeHabitLimit = 3;
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
