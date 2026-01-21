import 'package:flutter/material.dart';

class Constants {
  // App Constants
  static const String appName = 'Habit AI Tracker';
  static const int freeHabitLimit = 3; // 🔧 FIXED: Consistent 3-habit limit

  // Category Constants
  static const List<String> habitCategories = [
    'Health & Fitness',
    'Productivity',
    'Learning',
    'Social',
    'Creative',
    'Mindfulness',
    'Finance',
    'Career',
  ];

  // Tag Constants
  static const List<String> habitTags = [
    'Morning',
    'Evening',
    'Work',
    'Health',
    'Fitness',
    'Nutrition',
    'Sleep',
    'Focus',
    'Mindfulness',
    'Learning',
    'Social',
    'Self-care',
    'Finance',
  ];

  // Icon Constants
  static const List<String> habitIcons = [
    'fitness_center',
    'local_drink',
    'book',
    'music_note',
    'brush',
    'self_improvement',
    'savings',
    'work',
    'psychology',
    'nature',
    'restaurant',
    'directions_run',
    'bedtime',
    'phone',
    'eco',
  ];

  // Color Constants
  static const List<Color> habitColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
    Colors.deepOrange,
    Colors.deepPurple,
    Colors.lightGreen,
    Colors.brown,
  ];

  // Quick Templates
  static const List<Map<String, dynamic>> habitTemplates = [
    {
      'name': 'Drink Water',
      'description': 'Drink 8 glasses of water',
      'category': 'Health & Fitness',
      'icon': 'local_drink',
      'colorIndex': 0,
      'goalType': 'weekly',
      'goalTarget': 28,
      'tags': ['Health', 'Morning'],
    },
    {
      'name': 'Read 20 Minutes',
      'description': 'Read daily for 20 minutes',
      'category': 'Learning',
      'icon': 'book',
      'colorIndex': 6,
      'goalType': 'streak',
      'goalTarget': 14,
      'tags': ['Evening', 'Learning'],
    },
    {
      'name': 'Exercise',
      'description': 'Move your body',
      'category': 'Health & Fitness',
      'icon': 'directions_run',
      'colorIndex': 1,
      'goalType': 'weekly',
      'goalTarget': 4,
      'tags': ['Fitness'],
    },
    {
      'name': 'Meditate',
      'description': '5–10 minutes of mindfulness',
      'category': 'Mindfulness',
      'icon': 'self_improvement',
      'colorIndex': 5,
      'goalType': 'streak',
      'goalTarget': 7,
      'tags': ['Mindfulness', 'Morning'],
    },
  ];

  // Animation Constants
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Voice Constants
  static const Duration voiceTimeout = Duration(seconds: 10);
  static const Duration voicePause = Duration(seconds: 3);
  static const double voiceConfidenceThreshold = 0.6;

  // Database Constants
  static const String databaseName = 'habit_tracker.db';
  static const int databaseVersion = 8;

  // Notification Constants
  static const String notificationChannelId = 'habit_reminders';
  static const String notificationChannelName = 'Habit Reminders';

  // 🔧 NEW: Premium Enforcement Messages
  static const String premiumRequiredMessage =
      'Premium subscription required for this feature';
  static const String habitLimitMessage =
      'Free tier allows maximum $freeHabitLimit habits. Upgrade to Premium for unlimited habits.';
  static const String lastFreeHabitMessage =
      'This will be your last free habit. Upgrade to Premium for unlimited habits.';

  // Error Messages
  static const String errorNoInternet = 'No internet connection available';
  static const String errorVoiceNotAvailable =
      'Voice recognition not available';
  static const String errorDatabaseFailed = 'Database operation failed';
  static const String errorAIProcessing = 'AI processing failed';
  static const String errorPremiumRequired = premiumRequiredMessage;

  // Success Messages
  static const String successHabitCreated = 'Habit created successfully';
  static const String successHabitUpdated = 'Habit updated successfully';
  static const String successHabitDeleted = 'Habit deleted successfully';
  static const String successHabitLogged = 'Habit logged successfully';

  // Validation Constants
  static const int maxHabitNameLength = 50;
  static const int maxHabitDescriptionLength = 200;
  static const int maxNoteLength = 100;

  // Premium Features
  static const List<String> premiumFeatures = [
    'Unlimited habits',
    'Advanced AI insights',
    'Export data',
    'Custom themes',
    'Priority support',
    'Detailed analytics',
  ];

  // 🔧 NEW: Premium Feature Keys for validation
  static const String premiumFeatureUnlimitedHabits = 'unlimited_habits';
  static const String premiumFeatureAdvancedInsights = 'advanced_insights';
  static const String premiumFeatureDataExport = 'data_export';
  static const String premiumFeatureCustomThemes = 'custom_themes';
  static const String premiumFeatureDetailedAnalytics = 'detailed_analytics';
  static const String premiumFeaturePatternAnalysis = 'pattern_analysis';
  static const String premiumFeatureAIRecommendations = 'ai_recommendations';
  static const String premiumFeatureDetailedBreakdown = 'detailed_breakdown';
}
