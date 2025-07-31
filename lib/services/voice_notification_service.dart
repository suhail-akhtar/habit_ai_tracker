import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/voice_reminder.dart';
import '../models/notification_settings.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/user_profile_service.dart';
import '../services/gemini_service.dart';

/// Enhanced Voice Notification Service
/// Provides intelligent, context-aware voice notifications and reminders
/// that adapt to user patterns and preferences
class VoiceNotificationService {
  static final VoiceNotificationService _instance =
      VoiceNotificationService._internal();
  factory VoiceNotificationService() => _instance;
  VoiceNotificationService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final UserProfileService _userProfileService = UserProfileService();
  final GeminiService _geminiService = GeminiService();

  /// Create an intelligent voice reminder based on user input
  /// This method analyzes user patterns and creates contextual reminders
  Future<VoiceReminder?> createSmartVoiceReminder({
    required String userInput,
    required List<Habit> userHabits,
    DateTime? preferredTime,
  }) async {
    try {
      // Get user profile for personalization
      final userProfile = await _userProfileService.getUserAIProfile(
        userHabits,
      );

      // Process user input with AI to extract intent and create smart reminder
      final reminderData = await _generateSmartReminder(
        userInput: userInput,
        userHabits: userHabits,
        userProfile: userProfile,
        preferredTime: preferredTime,
      );

      if (reminderData == null) {
        return null;
      }

      // Create the voice reminder
      final voiceReminder = VoiceReminder(
        message: reminderData['message'],
        reminderTime: reminderData['reminderTime'],
        habitIds: reminderData['habitIds'] ?? [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to database
      final id = await _databaseService.insertVoiceReminder(voiceReminder);
      if (id != null) {
        final savedReminder = voiceReminder.copyWith(id: id);

        // Schedule the notification
        await _scheduleVoiceNotification(savedReminder, userProfile);

        return savedReminder;
      }
    } catch (e) {
      print('Error creating smart voice reminder: $e');
    }
    return null;
  }

  /// Generate smart reminder using AI and user context
  Future<Map<String, dynamic>?> _generateSmartReminder({
    required String userInput,
    required List<Habit> userHabits,
    required UserAIProfile userProfile,
    DateTime? preferredTime,
  }) async {
    try {
      final prompt = _buildSmartReminderPrompt(
        userInput: userInput,
        userHabits: userHabits,
        userProfile: userProfile,
        preferredTime: preferredTime,
      );

      // Use generateChatbotResponse as a general content generator
      final response = await _geminiService.generateChatbotResponse(
        'Generate voice reminder: $prompt',
        [],
        [],
      );
      return _parseReminderResponse(response);
    } catch (e) {
      print('Error generating smart reminder: $e');
      // Fallback to simple reminder creation
      return _createFallbackReminder(userInput, userHabits, preferredTime);
    }
  }

  /// Build AI prompt for smart reminder generation
  String _buildSmartReminderPrompt({
    required String userInput,
    required List<Habit> userHabits,
    required UserAIProfile userProfile,
    DateTime? preferredTime,
  }) {
    final currentTime = DateTime.now();
    final timeContext = preferredTime != null
        ? 'User wants reminder at: ${_formatTime(preferredTime)}'
        : 'Current time: ${_formatTime(currentTime)}';

    return '''Create a smart voice reminder based on user input and their profile.

USER INPUT: "$userInput"

USER CONTEXT:
- Active Habits: ${userHabits.map((h) => '"${h.name}" (${h.targetFrequency}/day)').join(', ')}
- Best Completion Time: ${userProfile.patterns.preferredCompletionTimes.join(', ')}
- Activity Level: ${userProfile.completionData.totalCompletions} total completions
- Preferred Methods: ${userProfile.engagement.featureUsage.entries.where((e) => e.value > 0.5).map((e) => e.key).join(', ')}
- Personality: ${userProfile.personality.motivationType} motivation, ${userProfile.personality.preferredCommunication.join('/')} communication
- Stress Level: ${userProfile.personality.riskTolerance}

TIME CONTEXT: $timeContext

Create a reminder that is:
1. Personalized to their communication style and motivation type
2. Contextually relevant to their habits and patterns
3. Clear and actionable
4. Appropriately timed based on their optimal completion patterns

Respond in JSON format:
{
  "message": "Personalized reminder message",
  "reminderTime": "ISO 8601 datetime string",
  "habitIds": [list of relevant habit IDs if any],
  "motivationType": "encouraging|coaching|gentle|direct",
  "contextualTips": "Brief personalized tip based on their patterns"
}''';
  }

  /// Parse AI response for reminder data
  Map<String, dynamic>? _parseReminderResponse(String response) {
    try {
      // Extract JSON from response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;

      if (jsonStart != -1 && jsonEnd > jsonStart) {
        final jsonStr = response.substring(jsonStart, jsonEnd);
        // Parse manually for safety
        return _parseJsonSafely(jsonStr);
      }
    } catch (e) {
      print('Error parsing reminder response: $e');
    }
    return null;
  }

  /// Safe JSON parsing with fallback
  Map<String, dynamic>? _parseJsonSafely(String jsonStr) {
    try {
      // Simple JSON-like parsing for our specific format
      final Map<String, dynamic> result = {};

      // Extract message
      final messageMatch = RegExp(
        r'"message":\s*"([^"]*)"',
      ).firstMatch(jsonStr);
      if (messageMatch != null) {
        result['message'] = messageMatch.group(1);
      }

      // Extract reminderTime
      final timeMatch = RegExp(
        r'"reminderTime":\s*"([^"]*)"',
      ).firstMatch(jsonStr);
      if (timeMatch != null) {
        try {
          result['reminderTime'] = DateTime.parse(timeMatch.group(1)!);
        } catch (e) {
          result['reminderTime'] = DateTime.now().add(const Duration(hours: 1));
        }
      }

      // Extract habitIds
      final habitIdsMatch = RegExp(
        r'"habitIds":\s*\[([^\]]*)\]',
      ).firstMatch(jsonStr);
      if (habitIdsMatch != null) {
        final idsStr = habitIdsMatch.group(1);
        if (idsStr != null && idsStr.isNotEmpty) {
          result['habitIds'] = idsStr
              .split(',')
              .map((s) => int.tryParse(s.trim()))
              .where((id) => id != null)
              .cast<int>()
              .toList();
        }
      }

      return result.isNotEmpty ? result : null;
    } catch (e) {
      print('Error in safe JSON parsing: $e');
      return null;
    }
  }

  /// Create fallback reminder when AI fails
  Map<String, dynamic> _createFallbackReminder(
    String userInput,
    List<Habit> userHabits,
    DateTime? preferredTime,
  ) {
    final lowerInput = userInput.toLowerCase();
    String message;
    DateTime reminderTime;
    List<int> habitIds = [];

    // Determine timing
    if (preferredTime != null) {
      reminderTime = preferredTime;
    } else if (lowerInput.contains('morning')) {
      reminderTime = _getNextTime(8, 0);
    } else if (lowerInput.contains('evening') || lowerInput.contains('night')) {
      reminderTime = _getNextTime(19, 0);
    } else if (lowerInput.contains('lunch') || lowerInput.contains('noon')) {
      reminderTime = _getNextTime(12, 0);
    } else {
      reminderTime = DateTime.now().add(const Duration(hours: 1));
    }

    // Find relevant habits
    for (final habit in userHabits) {
      if (lowerInput.contains(habit.name.toLowerCase())) {
        habitIds.add(habit.id!);
      }
    }

    // Create contextual message
    if (habitIds.isNotEmpty) {
      final habitNames = userHabits
          .where((h) => habitIds.contains(h.id))
          .map((h) => h.name)
          .join(' and ');
      message = "⏰ Time to work on $habitNames! You've got this! 💪";
    } else if (lowerInput.contains('exercise') ||
        lowerInput.contains('workout')) {
      message = "🏃‍♂️ Time to get moving! Your body will thank you later! 💪";
    } else if (lowerInput.contains('water') || lowerInput.contains('drink')) {
      message = "💧 Stay hydrated! Time for some refreshing water! 🥤";
    } else if (lowerInput.contains('meditat') ||
        lowerInput.contains('mindful')) {
      message = "🧘‍♀️ Take a mindful moment. Your mental health matters! ✨";
    } else {
      message = "⏰ Gentle reminder: $userInput 🌟";
    }

    return {
      'message': message,
      'reminderTime': reminderTime,
      'habitIds': habitIds,
    };
  }

  /// Schedule voice notification with enhanced features
  Future<void> _scheduleVoiceNotification(
    VoiceReminder reminder,
    UserAIProfile userProfile,
  ) async {
    try {
      // Determine notification type based on user preferences and time
      final notificationType = _determineNotificationType(
        reminder,
        userProfile,
      );

      final notificationSettings = NotificationSettings(
        id: reminder.id ?? DateTime.now().millisecondsSinceEpoch,
        title: _getContextualTitle(reminder, userProfile),
        message: reminder.message,
        time: TimeOfDay(
          hour: reminder.reminderTime.hour,
          minute: reminder.reminderTime.minute,
        ),
        type: notificationType,
        isEnabled: true,
        habitIds: reminder.habitIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _notificationService.scheduleNotification(notificationSettings);
    } catch (e) {
      print('Error scheduling voice notification: $e');
    }
  }

  /// Determine optimal notification type based on context
  NotificationType _determineNotificationType(
    VoiceReminder reminder,
    UserAIProfile userProfile,
  ) {
    final hour = reminder.reminderTime.hour;
    final isPremium = userProfile.completionData.totalCompletions > 50;

    // Morning and evening get more engaging notifications for active users
    if ((hour >= 6 && hour <= 9) || (hour >= 18 && hour <= 21)) {
      return isPremium ? NotificationType.ringing : NotificationType.simple;
    }

    // Active users get more engaging notifications
    if (isPremium && userProfile.completionData.totalCompletions > 100) {
      return NotificationType.alarm;
    }

    return NotificationType.simple;
  }

  /// Get contextual notification title
  String _getContextualTitle(
    VoiceReminder reminder,
    UserAIProfile userProfile,
  ) {
    final hour = reminder.reminderTime.hour;
    final motivationType = userProfile.personality.motivationType;

    if (motivationType == 'self_driven') {
      if (hour < 12) return "🌅 Rise & Shine!";
      if (hour < 17) return "⚡ Power Hour!";
      return "🌟 Evening Energy!";
    } else if (motivationType == 'needs_support') {
      if (hour < 12) return "🌸 Good Morning";
      if (hour < 17) return "💙 Gentle Reminder";
      return "🌙 Evening Care";
    } else {
      if (hour < 12) return "☀️ Morning Check-in";
      if (hour < 17) return "📋 Habit Time";
      return "🌆 Evening Routine";
    }
  }

  /// Get active voice reminders
  Future<List<VoiceReminder>> getActiveVoiceReminders() async {
    try {
      return await _databaseService.getVoiceReminders();
    } catch (e) {
      print('Error getting active voice reminders: $e');
      return [];
    }
  }

  /// Update voice reminder
  Future<bool> updateVoiceReminder(VoiceReminder reminder) async {
    try {
      await _databaseService.updateVoiceReminder(reminder);
      // Reschedule notification
      final userHabits = await _databaseService.getAllHabits();
      final userProfile = await _userProfileService.getUserAIProfile(
        userHabits,
      );
      await _scheduleVoiceNotification(reminder, userProfile);
      return true;
    } catch (e) {
      print('Error updating voice reminder: $e');
      return false;
    }
  }

  /// Delete voice reminder
  Future<bool> deleteVoiceReminder(int id) async {
    try {
      await _databaseService.deleteVoiceReminder(id);
      // Cancel notification
      await _notificationService.cancelNotification(id);
      return true;
    } catch (e) {
      print('Error deleting voice reminder: $e');
      return false;
    }
  }

  /// Create quick voice reminders for common scenarios
  Future<VoiceReminder?> createQuickReminder({
    required QuickReminderType type,
    required List<Habit> userHabits,
    Duration? delay,
  }) async {
    final reminderTime = DateTime.now().add(
      delay ?? const Duration(minutes: 30),
    );

    String message;

    switch (type) {
      case QuickReminderType.habitCheck:
        message =
            "🏆 Quick habit check! How are you doing with your routines today?";
        break;
      case QuickReminderType.motivationalBoost:
        message =
            "💪 You're doing amazing! Remember, small steps lead to big changes!";
        break;
      case QuickReminderType.hydrationReminder:
        message = "💧 Time for some water! Stay hydrated, stay healthy! 🥤";
        break;
      case QuickReminderType.movementBreak:
        message =
            "🚶‍♀️ Movement break! Stand up, stretch, or take a quick walk! ✨";
        break;
      case QuickReminderType.mindfulnessCheck:
        message = "🧘‍♀️ Take a deep breath. How are you feeling right now? 💙";
        break;
    }

    return createSmartVoiceReminder(
      userInput: message,
      userHabits: userHabits,
      preferredTime: reminderTime,
    );
  }

  /// Helper methods
  DateTime _getNextTime(int hour, int minute) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);

    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    return target;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Quick reminder types for easy creation
enum QuickReminderType {
  habitCheck,
  motivationalBoost,
  hydrationReminder,
  movementBreak,
  mindfulnessCheck,
}
