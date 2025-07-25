import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../models/voice_reminder.dart';
import '../models/notification_settings.dart';
import '../utils/constants.dart';

class VoiceReminderProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  List<VoiceReminder> _reminders = [];
  bool _isLoading = false;
  String? _error;

  List<VoiceReminder> get reminders => _reminders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all voice reminders for the user
  Future<void> loadReminders() async {
    _setLoading(true);
    try {
      _reminders = await _databaseService.getVoiceReminders();
      _clearError();
    } catch (e) {
      _setError('Failed to load voice reminders: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create a voice reminder from voice command
  Future<bool> createVoiceReminder({
    required String message,
    required DateTime reminderTime,
    List<int>? habitIds,
    required bool isPremium,
  }) async {
    try {
      // Check premium limits for free users
      if (!isPremium) {
        final activeReminders = _reminders.where((r) => r.isActive).length;
        if (activeReminders >= Constants.freeReminderLimit) {
          _setError(
            'Free users can only create ${Constants.freeReminderLimit} voice reminders. Upgrade to Premium for unlimited reminders.',
          );
          return false;
        }
      }

      _setLoading(true);

      final reminder = VoiceReminder(
        message: message,
        reminderTime: reminderTime,
        habitIds: habitIds ?? [],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final reminderId = await _databaseService.insertVoiceReminder(reminder);

      if (reminderId != null) {
        final reminderWithId = reminder.copyWith(id: reminderId);
        _reminders.add(reminderWithId);

        // Schedule notification
        await _scheduleReminderNotification(reminderWithId);

        _clearError();
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _setError('Failed to create voice reminder: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing voice reminder
  Future<bool> updateVoiceReminder(VoiceReminder reminder) async {
    try {
      _setLoading(true);

      final updated = reminder.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateVoiceReminder(updated);

      final index = _reminders.indexWhere((r) => r.id == reminder.id);
      if (index != -1) {
        _reminders[index] = updated;

        // Reschedule notification
        await _cancelReminderNotification(reminder.id!);
        await _scheduleReminderNotification(updated);

        _clearError();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to update voice reminder: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a voice reminder
  Future<bool> deleteVoiceReminder(int reminderId) async {
    try {
      _setLoading(true);

      await _databaseService.deleteVoiceReminder(reminderId);
      await _cancelReminderNotification(reminderId);

      _reminders.removeWhere((r) => r.id == reminderId);

      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete voice reminder: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Toggle reminder active status
  Future<bool> toggleReminderStatus(int reminderId) async {
    try {
      final reminder = _reminders.firstWhere((r) => r.id == reminderId);
      final updated = reminder.copyWith(
        isActive: !reminder.isActive,
        updatedAt: DateTime.now(),
      );

      return await updateVoiceReminder(updated);
    } catch (e) {
      _setError('Failed to toggle reminder status: $e');
      return false;
    }
  }

  /// Schedule notification for voice reminder
  Future<void> _scheduleReminderNotification(VoiceReminder reminder) async {
    try {
      final notification = NotificationSettings(
        id:
            reminder.id! +
            10000, // Offset to avoid conflicts with other notifications
        title: 'Voice Reminder',
        message: reminder.message,
        time: TimeOfDay.fromDateTime(reminder.reminderTime),
        type: NotificationType.simple,
        repetition: RepetitionType.oneTime,
        habitIds: reminder.habitIds,
        createdAt: reminder.createdAt,
        updatedAt: reminder.updatedAt,
        nextScheduledTime: reminder.reminderTime,
      );

      await _notificationService.scheduleNotification(notification);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to schedule reminder notification: $e');
      }
    }
  }

  /// Cancel notification for voice reminder
  Future<void> _cancelReminderNotification(int reminderId) async {
    try {
      await _notificationService.cancelNotification(reminderId + 10000);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to cancel reminder notification: $e');
      }
    }
  }

  /// Parse voice input to extract reminder details
  static VoiceReminderData? parseVoiceReminder(String voiceInput) {
    try {
      final input = voiceInput.toLowerCase().trim();

      // Patterns for reminder detection
      final reminderPatterns = [
        RegExp(r'remind me to (.+?) (?:at|on) (.+)'),
        RegExp(r'set (?:a )?reminder (?:to|for) (.+?) (?:at|on) (.+)'),
        RegExp(r'reminder (.+?) (?:at|on) (.+)'),
      ];

      for (final pattern in reminderPatterns) {
        final match = pattern.firstMatch(input);
        if (match != null) {
          final task = match.group(1)?.trim();
          final timeString = match.group(2)?.trim();

          if (task != null && timeString != null) {
            final reminderTime = _parseTimeFromString(timeString);
            if (reminderTime != null) {
              return VoiceReminderData(
                message: task,
                reminderTime: reminderTime,
              );
            }
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing voice reminder: $e');
      }
      return null;
    }
  }

  /// Parse time from natural language string
  static DateTime? _parseTimeFromString(String timeString) {
    try {
      final now = DateTime.now();
      final input = timeString.toLowerCase().trim();

      // Time patterns
      final timePatterns = {
        RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)?'): (Match match) {
          final hour = int.parse(match.group(1)!);
          final minute = int.parse(match.group(2)!);
          final period = match.group(3);

          var finalHour = hour;
          if (period == 'pm' && hour != 12) finalHour += 12;
          if (period == 'am' && hour == 12) finalHour = 0;

          var targetTime = DateTime(
            now.year,
            now.month,
            now.day,
            finalHour,
            minute,
          );
          if (targetTime.isBefore(now)) {
            targetTime = targetTime.add(const Duration(days: 1));
          }
          return targetTime;
        },

        RegExp(r'(\d{1,2})\s*(am|pm)'): (Match match) {
          final hour = int.parse(match.group(1)!);
          final period = match.group(2)!;

          var finalHour = hour;
          if (period == 'pm' && hour != 12) finalHour += 12;
          if (period == 'am' && hour == 12) finalHour = 0;

          var targetTime = DateTime(now.year, now.month, now.day, finalHour, 0);
          if (targetTime.isBefore(now)) {
            targetTime = targetTime.add(const Duration(days: 1));
          }
          return targetTime;
        },
      };

      // Relative time patterns
      final relativePatterns = {
        'in 1 hour': now.add(const Duration(hours: 1)),
        'in 2 hours': now.add(const Duration(hours: 2)),
        'in 30 minutes': now.add(const Duration(minutes: 30)),
        'in an hour': now.add(const Duration(hours: 1)),
        'tomorrow': DateTime(now.year, now.month, now.day + 1, 9, 0),
        'tomorrow morning': DateTime(now.year, now.month, now.day + 1, 9, 0),
        'tomorrow evening': DateTime(now.year, now.month, now.day + 1, 18, 0),
        'tonight': DateTime(now.year, now.month, now.day, 20, 0),
        'this evening': DateTime(now.year, now.month, now.day, 18, 0),
      };

      // Check relative patterns first
      for (final entry in relativePatterns.entries) {
        if (input.contains(entry.key)) {
          return entry.value;
        }
      }

      // Check time patterns
      for (final entry in timePatterns.entries) {
        final match = entry.key.firstMatch(input);
        if (match != null) {
          return entry.value(match);
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing time from string: $e');
      }
      return null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}

/// Data class for parsed voice reminder
class VoiceReminderData {
  final String message;
  final DateTime reminderTime;

  const VoiceReminderData({required this.message, required this.reminderTime});
}
