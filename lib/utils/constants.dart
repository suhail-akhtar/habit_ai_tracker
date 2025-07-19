import 'package:flutter/material.dart';

class Constants {
  // App Constants
  static const String appName = 'AI Voice Habit Tracker';
  static const int freeHabitLimit = 3;

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
  static const int databaseVersion = 1;

  // Notification Constants
  static const String notificationChannelId = 'habit_reminders';
  static const String notificationChannelName = 'Habit Reminders';

  // Error Messages
  static const String errorNoInternet = 'No internet connection available';
  static const String errorVoiceNotAvailable =
      'Voice recognition not available';
  static const String errorDatabaseFailed = 'Database operation failed';
  static const String errorAIProcessing = 'AI processing failed';
  static const String errorPremiumRequired = 'Premium subscription required';

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
}
