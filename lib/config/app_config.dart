class AppConfig {
    static const String appName = 'Habit Tracker';
  static const String appVersion = '1.0.0';

    // Debugging

  static const bool enableApiDebugging = false;
  static Duration apiTimeout = Duration(seconds: 30);

  // Database Configuration
  static const String databaseName = 'habit_tracker.db';
  static const int databaseVersion = 1;

    // Feature Flags
    static const bool enableAnalytics = true;
    static const bool enableNotifications = true;

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
