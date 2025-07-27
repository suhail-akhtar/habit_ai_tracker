import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/notification_settings.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/voice_notification_service.dart';
import '../services/user_profile_service.dart';
import '../services/gemini_service.dart';

/// AI Action Service - Enables AI to perform real actions in the app
class AIActionService {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final VoiceNotificationService _voiceService = VoiceNotificationService();
  final UserProfileService _profileService = UserProfileService();
  final GeminiService _geminiService = GeminiService();

  /// Execute AI-detected actions from user messages
  Future<AIActionResult> executeAction({
    required String userMessage,
    required List<Habit> userHabits,
    required BuildContext? context,
  }) async {
    try {
      // Detect action intent from user message
      final actionIntent = _detectActionIntent(userMessage, userHabits);

      if (actionIntent.type == ActionType.none) {
        return AIActionResult(
          success: false,
          message:
              "I can help you with that, but I'll need more specific details.",
          actionType: ActionType.none,
        );
      }

      // Execute the detected action
      switch (actionIntent.type) {
        case ActionType.createHabit:
          return await _createHabit(actionIntent.extractedData, userHabits);

        case ActionType.setupNotification:
          return await _setupNotification(
            actionIntent.extractedData,
            userHabits,
          );

        case ActionType.createReminder:
          return await _createReminder(actionIntent.extractedData, userHabits);

        case ActionType.modifyHabit:
          return await _modifyHabit(actionIntent.extractedData, userHabits);

        case ActionType.checkProgress:
          return await _checkProgress(actionIntent.extractedData, userHabits);

        case ActionType.scheduleActivity:
          return await _scheduleActivity(
            actionIntent.extractedData,
            userHabits,
          );

        case ActionType.none:
          return AIActionResult(
            success: false,
            message: "I'm not sure how to help with that specific request.",
            actionType: ActionType.none,
          );
      }
    } catch (e) {
      if (kDebugMode) {
        print('AI Action Service error: $e');
      }
      return AIActionResult(
        success: false,
        message:
            "I encountered an error while trying to help. Please try again.",
        actionType: ActionType.none,
      );
    }
  }

  /// Detect what action the user wants to perform
  ActionIntent _detectActionIntent(String message, List<Habit> userHabits) {
    final lowerMessage = message.toLowerCase();
    final Map<String, dynamic> extractedData = {};

    // Create Habit Intent
    if (_containsAny(lowerMessage, [
      'create habit',
      'add habit',
      'new habit',
      'start habit',
      'begin habit',
      'suggest habit',
      'habit suggestion',
      'recommend habit',
      'what habit',
      'habit idea',
    ])) {
      extractedData['habitName'] = _extractHabitName(message);
      extractedData['frequency'] = _extractFrequency(message);
      extractedData['category'] = _extractCategory(message);
      extractedData['needsSuggestion'] = _needsHabitSuggestion(message);
      return ActionIntent(ActionType.createHabit, extractedData);
    }

    // Notification Setup Intent
    if (_containsAny(lowerMessage, [
      'remind me',
      'set reminder',
      'notification',
      'alert me',
      'schedule reminder',
    ])) {
      extractedData['title'] = _extractTitle(message);
      extractedData['time'] = _extractTime(message);
      extractedData['message'] = _extractReminderMessage(message);
      extractedData['habitIds'] = _findRelatedHabits(message, userHabits);
      return ActionIntent(ActionType.setupNotification, extractedData);
    }

    // Voice Reminder Intent
    if (_containsAny(lowerMessage, [
      'voice reminder',
      'speak to me',
      'voice alert',
      'say when',
    ])) {
      extractedData['message'] = _extractReminderMessage(message);
      extractedData['time'] = _extractTime(message);
      extractedData['habitIds'] = _findRelatedHabits(message, userHabits);
      return ActionIntent(ActionType.createReminder, extractedData);
    }

    // Modify Habit Intent
    if (_containsAny(lowerMessage, [
      'change habit',
      'modify',
      'update habit',
      'edit habit',
      'adjust',
    ])) {
      extractedData['habitName'] = _findExistingHabit(message, userHabits);
      extractedData['changes'] = _extractChanges(message);
      return ActionIntent(ActionType.modifyHabit, extractedData);
    }

    // Progress Check Intent
    if (_containsAny(lowerMessage, [
      'how am i doing',
      'my progress',
      'check progress',
      'show stats',
      'how many',
    ])) {
      extractedData['timeframe'] = _extractTimeframe(message);
      extractedData['specificHabit'] = _findExistingHabit(message, userHabits);
      return ActionIntent(ActionType.checkProgress, extractedData);
    }

    // Schedule Activity Intent
    if (_containsAny(lowerMessage, [
      'schedule',
      'plan for',
      'book time',
      'set time for',
    ])) {
      extractedData['activity'] = _extractActivity(message);
      extractedData['time'] = _extractTime(message);
      extractedData['date'] = _extractDate(message);
      return ActionIntent(ActionType.scheduleActivity, extractedData);
    }

    return ActionIntent(ActionType.none, {});
  }

  /// Create a new habit based on AI detection
  Future<AIActionResult> _createHabit(
    Map<String, dynamic> data,
    List<Habit> existingHabits,
  ) async {
    try {
      final needsSuggestion = data['needsSuggestion'] as bool? ?? false;

      // If user wants suggestions, provide them
      if (needsSuggestion || (data['habitName'] as String?)?.isEmpty == true) {
        return await _suggestHabits(existingHabits);
      }

      final habitName = data['habitName'] as String? ?? 'New Habit';
      final frequency = data['frequency'] as int? ?? 1;
      final category = data['category'] as String? ?? 'General';

      // Check if habit already exists
      final existingNames = existingHabits
          .map((h) => h.name.toLowerCase())
          .toList();
      if (existingNames.contains(habitName.toLowerCase())) {
        return AIActionResult(
          success: false,
          message:
              "You already have a habit called '$habitName'. Would you like me to suggest a similar but different habit instead?",
          actionType: ActionType.createHabit,
          needsMoreInfo: true,
          followUpQuestion:
              "What specific aspect of '$habitName' would you like to improve or change?",
        );
      }

      final newHabit = Habit(
        name: habitName,
        category: category,
        targetFrequency: frequency,
        colorCode: _getRandomColor(),
        iconName: _getIconForCategory(category),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final habitId = await _databaseService.createHabit(newHabit);

      return AIActionResult(
        success: true,
        message:
            "🎉 Awesome! I've created your '$habitName' habit. You're aiming for $frequency time${frequency > 1 ? 's' : ''} per day. Would you like me to set up reminders for it?",
        actionType: ActionType.createHabit,
        createdHabitId: habitId,
        showToast: true,
        toastMessage: "✅ '$habitName' habit created successfully!",
        followUpQuestion:
            "Would you like me to set up reminder notifications for this habit?",
      );
    } catch (e) {
      return AIActionResult(
        success: false,
        message:
            "I had trouble creating the habit. Can you please try again or provide more details?",
        actionType: ActionType.createHabit,
        needsMoreInfo: true,
        followUpQuestion:
            "What specific habit would you like to create? Please provide the name and how often you'd like to do it.",
      );
    }
  }

  /// Setup notification based on AI detection
  Future<AIActionResult> _setupNotification(
    Map<String, dynamic> data,
    List<Habit> userHabits,
  ) async {
    try {
      final title = data['title'] as String? ?? 'Habit Reminder';
      final message =
          data['message'] as String? ?? 'Time to work on your habits!';
      final timeData = data['time'] as Map<String, dynamic>?;
      final habitIds = data['habitIds'] as List<int>? ?? [];

      if (timeData == null) {
        return AIActionResult(
          success: false,
          message:
              "I need to know when you want to be reminded. Please specify a time like '8 AM', '2:30 PM', or 'in 30 minutes'.",
          actionType: ActionType.setupNotification,
        );
      }

      final hour = timeData['hour'] as int? ?? 9;
      final minute = timeData['minute'] as int? ?? 0;

      final notification = NotificationSettings(
        title: title,
        message: message,
        time: TimeOfDay(hour: hour, minute: minute),
        habitIds: habitIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final notificationId = await _databaseService.createNotificationSetting(
        notification,
      );

      // Schedule the actual notification
      final notificationWithId = notification.copyWith(id: notificationId);
      await _notificationService.scheduleNotification(notificationWithId);

      final timeStr = _formatTime(hour, minute);
      final habitInfo = habitIds.isNotEmpty
          ? " for your ${userHabits.where((h) => habitIds.contains(h.id)).map((h) => h.name).join(' and ')} habit${habitIds.length > 1 ? 's' : ''}"
          : "";

      return AIActionResult(
        success: true,
        message:
            "✅ Perfect! I've set up a reminder$habitInfo at $timeStr. You'll get notified: '$message'",
        actionType: ActionType.setupNotification,
        createdNotificationId: notificationId,
        showToast: true,
        toastMessage: "🔔 Notification scheduled for $timeStr",
        followUpQuestion:
            "Would you like me to set up any other reminders or create additional habits?",
      );
    } catch (e) {
      return AIActionResult(
        success: false,
        message: "Error setting up notification: ${e.toString()}",
        actionType: ActionType.setupNotification,
      );
    }
  }

  /// Create voice reminder
  Future<AIActionResult> _createReminder(
    Map<String, dynamic> data,
    List<Habit> userHabits,
  ) async {
    try {
      final message = data['message'] as String? ?? 'Voice reminder';
      final timeData = data['time'] as Map<String, dynamic>?;

      DateTime reminderTime;
      if (timeData != null) {
        final hour = timeData['hour'] as int? ?? 9;
        final minute = timeData['minute'] as int? ?? 0;
        reminderTime = _getNextTime(hour, minute);
      } else {
        reminderTime = DateTime.now().add(const Duration(hours: 1));
      }

      final voiceReminder = await _voiceService.createSmartVoiceReminder(
        userInput: message,
        userHabits: userHabits,
        preferredTime: reminderTime,
      );

      if (voiceReminder != null) {
        final timeStr = _formatTime(reminderTime.hour, reminderTime.minute);
        return AIActionResult(
          success: true,
          message:
              "🎤 Voice reminder created! I'll speak to you at $timeStr: '${voiceReminder.message}'",
          actionType: ActionType.createReminder,
          createdReminderId: voiceReminder.id,
        );
      } else {
        return AIActionResult(
          success: false,
          message: "I couldn't create the voice reminder. Please try again.",
          actionType: ActionType.createReminder,
        );
      }
    } catch (e) {
      return AIActionResult(
        success: false,
        message: "Error creating voice reminder: ${e.toString()}",
        actionType: ActionType.createReminder,
      );
    }
  }

  /// Modify existing habit
  Future<AIActionResult> _modifyHabit(
    Map<String, dynamic> data,
    List<Habit> userHabits,
  ) async {
    try {
      final habitName = data['habitName'] as String?;
      final changes = data['changes'] as Map<String, dynamic>? ?? {};

      if (habitName == null) {
        return AIActionResult(
          success: false,
          message:
              "Which habit would you like me to modify? Please specify the habit name.",
          actionType: ActionType.modifyHabit,
        );
      }

      final habit = userHabits
          .where((h) => h.name.toLowerCase().contains(habitName.toLowerCase()))
          .firstOrNull;

      if (habit == null) {
        return AIActionResult(
          success: false,
          message:
              "I couldn't find a habit named '$habitName'. Your current habits are: ${userHabits.map((h) => h.name).join(', ')}",
          actionType: ActionType.modifyHabit,
        );
      }

      // Apply changes
      final updatedHabit = habit.copyWith(
        targetFrequency: changes['frequency'] as int? ?? habit.targetFrequency,
        category: changes['category'] as String? ?? habit.category,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateHabit(updatedHabit);

      return AIActionResult(
        success: true,
        message:
            "✅ Updated your '${habit.name}' habit! The changes have been saved.",
        actionType: ActionType.modifyHabit,
        modifiedHabitId: habit.id,
      );
    } catch (e) {
      return AIActionResult(
        success: false,
        message: "Error modifying habit: ${e.toString()}",
        actionType: ActionType.modifyHabit,
      );
    }
  }

  /// Check progress for user
  Future<AIActionResult> _checkProgress(
    Map<String, dynamic> data,
    List<Habit> userHabits,
  ) async {
    try {
      final timeframe = data['timeframe'] as String? ?? 'week';
      final specificHabit = data['specificHabit'] as String?;

      if (userHabits.isEmpty) {
        return AIActionResult(
          success: true,
          message:
              "You haven't created any habits yet! Ready to start your journey? I can help you create your first habit.",
          actionType: ActionType.checkProgress,
        );
      }

      if (specificHabit != null) {
        final habit = userHabits
            .where(
              (h) => h.name.toLowerCase().contains(specificHabit.toLowerCase()),
            )
            .firstOrNull;

        if (habit != null && habit.id != null) {
          final logs = await _databaseService.getHabitLogs(habit.id!);
          final recentLogs = _filterLogsByTimeframe(logs, timeframe);

          return AIActionResult(
            success: true,
            message:
                "📊 ${habit.name}: You've completed it ${recentLogs.length} times this $timeframe! ${_getProgressEncouragement(recentLogs.length, timeframe)}",
            actionType: ActionType.checkProgress,
          );
        }
      }

      // Overall progress
      final progressSummary = await _getOverallProgress(userHabits, timeframe);

      return AIActionResult(
        success: true,
        message: progressSummary,
        actionType: ActionType.checkProgress,
      );
    } catch (e) {
      return AIActionResult(
        success: false,
        message: "Error checking progress: ${e.toString()}",
        actionType: ActionType.checkProgress,
      );
    }
  }

  /// Schedule activity
  Future<AIActionResult> _scheduleActivity(
    Map<String, dynamic> data,
    List<Habit> userHabits,
  ) async {
    try {
      final activity = data['activity'] as String? ?? 'Activity';
      final timeData = data['time'] as Map<String, dynamic>?;

      if (timeData == null) {
        return AIActionResult(
          success: false,
          message:
              "When would you like to schedule '$activity'? Please specify a time.",
          actionType: ActionType.scheduleActivity,
        );
      }

      final hour = timeData['hour'] as int? ?? 9;
      final minute = timeData['minute'] as int? ?? 0;

      // Create a notification for the scheduled activity
      final title = "📅 Scheduled Activity";
      final message = "Time for: $activity";

      final notification = NotificationSettings(
        title: title,
        message: message,
        time: TimeOfDay(hour: hour, minute: minute),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final notificationId = await _databaseService.createNotificationSetting(
        notification,
      );

      final notificationWithId = notification.copyWith(id: notificationId);
      await _notificationService.scheduleNotification(notificationWithId);

      final timeStr = _formatTime(hour, minute);
      return AIActionResult(
        success: true,
        message:
            "📅 Scheduled '$activity' at $timeStr! I'll remind you when it's time.",
        actionType: ActionType.scheduleActivity,
        createdNotificationId: notificationId,
      );
    } catch (e) {
      return AIActionResult(
        success: false,
        message: "Error scheduling activity: ${e.toString()}",
        actionType: ActionType.scheduleActivity,
      );
    }
  }

  /// Suggest habits based on user profile and current habits
  Future<AIActionResult> _suggestHabits(List<Habit> existingHabits) async {
    try {
      final userProfile = await _profileService.getUserAIProfile(
        existingHabits,
      );

      // Generate habit suggestions based on profile
      final prompt =
          """
Based on this user profile, suggest 3-5 specific, actionable habits they should start:

Current habits: ${existingHabits.map((h) => h.name).join(', ')}
Total habits: ${userProfile.totalHabits}
Active habits: ${userProfile.activeHabits}
Completion rate (7 days): ${userProfile.completionData.completionRate7Days}%
Current streak: ${userProfile.completionData.currentStreak} days
Best categories: ${userProfile.completionData.categoryPerformance.entries.map((e) => '${e.key} (${e.value} completions)').join(', ')}

Provide suggestions as a numbered list with:
1. Habit name
2. Brief benefit explanation
3. Recommended frequency

Focus on gaps in their current routine and habits that complement what they already do.
""";

      final suggestions = await _geminiService.generateChatbotResponse(
        prompt,
        existingHabits,
        [],
      );

      return AIActionResult(
        success: true,
        message:
            "🎯 Based on your current habits and goals, here are my personalized recommendations:\n\n$suggestions\n\nWhich of these interests you? Just tell me the name and I'll create it for you!",
        actionType: ActionType.createHabit,
        needsMoreInfo: true,
        followUpQuestion:
            "Which habit would you like me to create for you? Just say the name or describe what you want to work on.",
        suggestions: _extractHabitNames(suggestions),
      );
    } catch (e) {
      return AIActionResult(
        success: true,
        message:
            "Here are some popular habit suggestions based on what successful people do:\n\n"
                "1. **Morning Water** - Drink a glass of water first thing (daily)\n"
                "2. **5-Minute Meditation** - Quick mindfulness practice (daily)\n"
                "3. **Evening Reading** - Read for 15 minutes before bed (daily)\n"
                "4. **Weekly Exercise** - 30-minute workout sessions (3x/week)\n" +
            "5. **Daily Gratitude** - Write 3 things you're grateful for (daily)\n\n" +
            "Which one sounds interesting? I can create it for you right away!",
        actionType: ActionType.createHabit,
        needsMoreInfo: true,
        followUpQuestion: "Which habit would you like to start with?",
        suggestions: [
          "Morning Water",
          "5-Minute Meditation",
          "Evening Reading",
          "Weekly Exercise",
          "Daily Gratitude",
        ],
      );
    }
  }

  /// Check if user needs habit suggestions
  bool _needsHabitSuggestion(String message) {
    return _containsAny(message.toLowerCase(), [
      'suggest',
      'recommend',
      'what habit',
      'habit idea',
      'help me choose',
      'don\'t know',
      'any ideas',
    ]);
  }

  /// Extract habit names from AI response
  List<String> _extractHabitNames(String response) {
    final lines = response.split('\n');
    final habitNames = <String>[];

    for (final line in lines) {
      // Look for numbered lists or bullet points
      final match = RegExp(
        r'^\d+\.\s*\*?\*?(.+?)\*?\*?\s*-',
      ).firstMatch(line.trim());
      if (match != null) {
        habitNames.add(match.group(1)!.trim());
      }
    }

    return habitNames.isNotEmpty
        ? habitNames
        : ["Morning Routine", "Exercise", "Reading", "Meditation"];
  }

  // Helper methods for extraction and parsing
  bool _containsAny(String text, List<String> phrases) {
    return phrases.any((phrase) => text.contains(phrase));
  }

  String _extractHabitName(String message) {
    // Extract habit name from patterns like "create habit drink water" or "add habit: exercise"
    final patterns = [
      RegExp(
        r'(?:create|add|start|begin)\s+habit\s+(.+?)(?:\s+(?:every|daily|twice|once)|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'habit\s*[:]\s*(.+?)(?:\s+(?:every|daily|twice|once)|$)',
        caseSensitive: false,
      ),
      RegExp(r'(?:create|add)\s+(.+?)\s+habit', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }

    return 'New Habit';
  }

  int _extractFrequency(String message) {
    if (message.toLowerCase().contains('twice')) return 2;
    if (message.toLowerCase().contains('three times')) return 3;
    if (message.toLowerCase().contains('once')) return 1;

    final match = RegExp(r'(\d+)\s*times?').firstMatch(message.toLowerCase());
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 1;
    }

    return 1; // Default
  }

  String _extractCategory(String message) {
    final categories = {
      'health': [
        'water',
        'exercise',
        'workout',
        'health',
        'nutrition',
        'vitamin',
      ],
      'wellness': ['meditation', 'mindful', 'relax', 'sleep', 'rest'],
      'productivity': ['read', 'study', 'work', 'focus', 'write'],
      'fitness': ['run', 'walk', 'gym', 'sport', 'stretch'],
    };

    final lowerMessage = message.toLowerCase();
    for (final entry in categories.entries) {
      if (entry.value.any((keyword) => lowerMessage.contains(keyword))) {
        return entry.key;
      }
    }

    return 'General';
  }

  String _extractTitle(String message) {
    final match = RegExp(
      r'title\s*:\s*(.+?)(?:\s|$)',
      caseSensitive: false,
    ).firstMatch(message);
    if (match != null) return match.group(1)!.trim();

    return 'Habit Reminder';
  }

  Map<String, dynamic>? _extractTime(String message) {
    // Extract time patterns like "8 AM", "2:30 PM", "14:30", "in 30 minutes"
    final timePatterns = [
      RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false),
      RegExp(r'(\d{1,2})\s*(AM|PM)', caseSensitive: false),
      RegExp(r'(\d{1,2}):(\d{2})'),
      RegExp(r'at\s+(\d{1,2})'),
    ];

    for (final pattern in timePatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        int hour = int.tryParse(match.group(1)!) ?? 9;
        int minute = match.group(2) != null
            ? int.tryParse(match.group(2)!) ?? 0
            : 0;

        if (match.group(3) != null) {
          final ampm = match.group(3)!.toUpperCase();
          if (ampm == 'PM' && hour < 12) hour += 12;
          if (ampm == 'AM' && hour == 12) hour = 0;
        }

        return {'hour': hour, 'minute': minute};
      }
    }

    // Handle relative times like "in 30 minutes"
    final relativeMatch = RegExp(
      r'in\s+(\d+)\s+minutes?',
      caseSensitive: false,
    ).firstMatch(message);
    if (relativeMatch != null) {
      final minutes = int.tryParse(relativeMatch.group(1)!) ?? 30;
      final targetTime = DateTime.now().add(Duration(minutes: minutes));
      return {'hour': targetTime.hour, 'minute': targetTime.minute};
    }

    return null;
  }

  String _extractReminderMessage(String message) {
    // Try to extract custom message from quotes or after "say" keyword
    final quotedMatch = RegExp(r'"(.+?)"').firstMatch(message);
    if (quotedMatch != null) return quotedMatch.group(1)!;

    final sayMatch = RegExp(
      r'say\s+(.+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (sayMatch != null) return sayMatch.group(1)!;

    return message.length > 50 ? '${message.substring(0, 50)}...' : message;
  }

  List<int> _findRelatedHabits(String message, List<Habit> userHabits) {
    final relatedIds = <int>[];
    final lowerMessage = message.toLowerCase();

    for (final habit in userHabits) {
      if (lowerMessage.contains(habit.name.toLowerCase()) ||
          lowerMessage.contains(habit.category.toLowerCase())) {
        if (habit.id != null) {
          relatedIds.add(habit.id!);
        }
      }
    }

    return relatedIds;
  }

  String? _findExistingHabit(String message, List<Habit> userHabits) {
    final lowerMessage = message.toLowerCase();

    for (final habit in userHabits) {
      if (lowerMessage.contains(habit.name.toLowerCase())) {
        return habit.name;
      }
    }

    return null;
  }

  Map<String, dynamic> _extractChanges(String message) {
    final changes = <String, dynamic>{};

    // Extract frequency changes
    if (message.contains('twice')) changes['frequency'] = 2;
    if (message.contains('three times')) changes['frequency'] = 3;
    if (message.contains('once')) changes['frequency'] = 1;

    final freqMatch = RegExp(r'(\d+)\s*times?').firstMatch(message);
    if (freqMatch != null) {
      changes['frequency'] = int.tryParse(freqMatch.group(1)!) ?? 1;
    }

    return changes;
  }

  String _extractTimeframe(String message) {
    if (message.toLowerCase().contains('today')) return 'today';
    if (message.toLowerCase().contains('week')) return 'week';
    if (message.toLowerCase().contains('month')) return 'month';
    if (message.toLowerCase().contains('year')) return 'year';
    return 'week';
  }

  String _extractActivity(String message) {
    final patterns = [
      RegExp(r'schedule\s+(.+?)(?:\s+at|\s+for|$)', caseSensitive: false),
      RegExp(r'plan\s+(.+?)(?:\s+at|\s+for|$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) return match.group(1)!.trim();
    }

    return 'Activity';
  }

  Map<String, dynamic>? _extractDate(String message) {
    // Simple date extraction - can be enhanced
    if (message.toLowerCase().contains('today')) {
      final today = DateTime.now();
      return {'year': today.year, 'month': today.month, 'day': today.day};
    }

    if (message.toLowerCase().contains('tomorrow')) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return {
        'year': tomorrow.year,
        'month': tomorrow.month,
        'day': tomorrow.day,
      };
    }

    return null;
  }

  // Utility methods
  String _getRandomColor() {
    final colors = [
      '#FF6B6B',
      '#4ECDC4',
      '#45B7D1',
      '#96CEB4',
      '#FFEAA7',
      '#DDA0DD',
    ];
    colors.shuffle();
    return colors.first;
  }

  String _getIconForCategory(String category) {
    final icons = {
      'health': 'favorite',
      'wellness': 'self_improvement',
      'productivity': 'work',
      'fitness': 'fitness_center',
      'general': 'star',
    };
    return icons[category.toLowerCase()] ?? 'star';
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }

  DateTime _getNextTime(int hour, int minute) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);

    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    return target;
  }

  List<dynamic> _filterLogsByTimeframe(List<dynamic> logs, String timeframe) {
    // Simplified filtering for now - returns all logs
    // TODO: Implement proper timeframe filtering based on log.completedAt
    return logs;
  }

  String _getProgressEncouragement(int completions, String timeframe) {
    if (completions == 0) {
      return "No worries, every day is a new opportunity! 🌟";
    }
    if (completions < 3) return "You're getting started! Keep going! 💪";
    if (completions < 7) return "Great progress! You're building momentum! 🚀";
    return "Outstanding! You're crushing it! 🏆";
  }

  Future<String> _getOverallProgress(
    List<Habit> userHabits,
    String timeframe,
  ) async {
    if (userHabits.isEmpty) {
      return "You haven't created any habits yet! Ready to start? I can help you create your first habit.";
    }

    int totalCompletions = 0;
    final activeHabits = userHabits.where((h) => h.isActive).length;

    // This is simplified - in real implementation, would check actual completion logs
    for (final habit in userHabits) {
      if (habit.id != null) {
        // Add logic to count actual completions
        totalCompletions += 3; // Placeholder
      }
    }

    return "📊 This $timeframe: $totalCompletions completions across $activeHabits active habits! ${_getProgressEncouragement(totalCompletions, timeframe)}";
  }
}

/// Action intent detection result
class ActionIntent {
  final ActionType type;
  final Map<String, dynamic> extractedData;

  ActionIntent(this.type, this.extractedData);
}

/// Types of actions AI can perform
enum ActionType {
  none,
  createHabit,
  setupNotification,
  createReminder,
  modifyHabit,
  checkProgress,
  scheduleActivity,
}

/// Result of AI action execution
class AIActionResult {
  final bool success;
  final String message;
  final ActionType actionType;
  final int? createdHabitId;
  final int? createdNotificationId;
  final int? createdReminderId;
  final int? modifiedHabitId;
  final bool needsMoreInfo;
  final String? followUpQuestion;
  final bool showToast;
  final String? toastMessage;
  final List<String>? suggestions;

  AIActionResult({
    required this.success,
    required this.message,
    required this.actionType,
    this.createdHabitId,
    this.createdNotificationId,
    this.createdReminderId,
    this.modifiedHabitId,
    this.needsMoreInfo = false,
    this.followUpQuestion,
    this.showToast = false,
    this.toastMessage,
    this.suggestions,
  });
}
