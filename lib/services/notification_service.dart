import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../models/habit.dart';
import '../models/notification_settings.dart';
import '../utils/constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _hasPermission = false;

  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;

  Future<void> initialize() async {
    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      await requestPermissions();

      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ NotificationService initialization failed: $e');
      _isInitialized = false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final permission = await Permission.notification.request();
      _hasPermission = permission == PermissionStatus.granted;

      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        _hasPermission = status == PermissionStatus.granted;
      }

      print('✅ Notification permissions: $_hasPermission');
      return _hasPermission;
    } catch (e) {
      print('❌ Permission request failed: $e');
      _hasPermission = false;
      return false;
    }
  }

  // 🔔 ENHANCED: Schedule custom notification with full feature support
  Future<bool> scheduleNotification(
    NotificationSettings settings, {
    List<Habit>? associatedHabits,
  }) async {
    if (!_isInitialized || !_hasPermission) {
      print(
        '❌ Cannot schedule notification: init=$_isInitialized, permission=$_hasPermission',
      );
      return false;
    }

    try {
      // Cancel existing notification with same ID
      if (settings.id != null) {
        await _flutterLocalNotificationsPlugin.cancel(settings.id!);
      }

      if (!settings.isEnabled) {
        print('ℹ️ Notification disabled, skipping schedule');
        return true;
      }

      final notificationDetails = _buildNotificationDetails(settings);
      final scheduledTimes = _calculateScheduledTimes(settings);

      bool allScheduled = true;
      for (int i = 0; i < scheduledTimes.length; i++) {
        final scheduledTime = scheduledTimes[i];
        final notificationId =
            (settings.id ?? 0) * 1000 + i; // Unique ID per instance

        try {
          await _flutterLocalNotificationsPlugin.zonedSchedule(
            notificationId,
            _buildTitle(settings, associatedHabits),
            _buildMessage(settings, associatedHabits),
            scheduledTime,
            notificationDetails,
            androidScheduleMode: settings.type == NotificationType.alarm
                ? AndroidScheduleMode.alarmClock
                : AndroidScheduleMode.exactAllowWhileIdle,

            matchDateTimeComponents: _getMatchComponents(settings),
            payload:
                'custom_notification:${settings.id}:${settings.habitIds.join(",")}',
          );

          print(
            '✅ Scheduled notification #$notificationId for ${scheduledTime.toString()}',
          );
        } catch (e) {
          print('❌ Failed to schedule notification #$notificationId: $e');
          allScheduled = false;
        }
      }

      return allScheduled;
    } catch (e) {
      print('❌ Failed to schedule notification: $e');
      return false;
    }
  }

  NotificationDetails _buildNotificationDetails(NotificationSettings settings) {
    AndroidNotificationDetails androidDetails;

    switch (settings.type) {
      case NotificationType.simple:
        androidDetails = const AndroidNotificationDetails(
          'simple_reminders',
          'Simple Reminders',
          channelDescription: 'Simple habit reminder notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );
        break;

      case NotificationType.ringing:
        androidDetails = AndroidNotificationDetails(
          'ringing_reminders',
          'Ringing Reminders',
          channelDescription: 'Persistent ringing habit reminders',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
          category: AndroidNotificationCategory.call,
          ongoing: true, // Makes it persistent like a call
          autoCancel: false, // User must manually dismiss
          timeoutAfter: 30000, // Auto-dismiss after 30 seconds
        );
        break;
      case NotificationType.alarm:
        androidDetails = AndroidNotificationDetails(
          'alarm_reminders',
          'Alarm Reminders',
          channelDescription: 'Full-screen alarm-style reminders',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          vibrationPattern: Int64List.fromList([
            0,
            500,
            200,
            500,
            200,
            500,
            200,
            500,
          ]),
          fullScreenIntent: true, // Shows full-screen like alarm
          category: AndroidNotificationCategory.alarm,
          ongoing: true, // Persistent
          autoCancel: false, // Must be manually dismissed
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'dismiss',
              'Dismiss',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'snooze',
              'Snooze 5min',
              showsUserInterface: false,
            ),
          ],
        );
        break;
    }

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(android: androidDetails, iOS: iOSDetails);
  }

  List<tz.TZDateTime> _calculateScheduledTimes(NotificationSettings settings) {
    final now = DateTime.now();
    final times = <tz.TZDateTime>[];

    switch (settings.repetition) {
      case RepetitionType.oneTime:
        final scheduledDate = DateTime(
          now.year,
          now.month,
          now.day,
          settings.time.hour,
          settings.time.minute,
        );

        // If time has passed today, schedule for tomorrow
        final finalDate = scheduledDate.isBefore(now)
            ? scheduledDate.add(const Duration(days: 1))
            : scheduledDate;

        times.add(tz.TZDateTime.from(finalDate, tz.local));
        break;

      case RepetitionType.daily:
        // Schedule for next occurrence for each selected day
        for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
          final testDate = now.add(Duration(days: dayOffset));
          final weekday = testDate.weekday; // 1=Monday, 7=Sunday

          if (settings.daysOfWeek.contains(weekday)) {
            final scheduledDate = DateTime(
              testDate.year,
              testDate.month,
              testDate.day,
              settings.time.hour,
              settings.time.minute,
            );

            if (scheduledDate.isAfter(now)) {
              times.add(tz.TZDateTime.from(scheduledDate, tz.local));
              break; // Only need next occurrence for daily
            }
          }
        }
        break;

      case RepetitionType.weekly:
        // Schedule for next week
        final nextWeek = now.add(const Duration(days: 7));
        final scheduledDate = DateTime(
          nextWeek.year,
          nextWeek.month,
          nextWeek.day,
          settings.time.hour,
          settings.time.minute,
        );
        times.add(tz.TZDateTime.from(scheduledDate, tz.local));
        break;

      case RepetitionType.monthly:
        // Schedule for next month
        final nextMonth = DateTime(now.year, now.month + 1, now.day);
        final scheduledDate = DateTime(
          nextMonth.year,
          nextMonth.month,
          nextMonth.day,
          settings.time.hour,
          settings.time.minute,
        );
        times.add(tz.TZDateTime.from(scheduledDate, tz.local));
        break;
    }

    return times;
  }

  DateTimeComponents? _getMatchComponents(NotificationSettings settings) {
    switch (settings.repetition) {
      case RepetitionType.daily:
        return DateTimeComponents.time;
      case RepetitionType.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case RepetitionType.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
      case RepetitionType.oneTime:
        return null;
    }
  }

  String _buildTitle(NotificationSettings settings, List<Habit>? habits) {
    if (settings.title.isNotEmpty) return settings.title;

    if (habits != null && habits.isNotEmpty) {
      if (habits.length == 1) {
        return '${habits.first.name} Reminder';
      } else {
        return 'Habit Reminder (${habits.length} habits)';
      }
    }

    return 'Habit Reminder';
  }

  String _buildMessage(NotificationSettings settings, List<Habit>? habits) {
    if (settings.message.isNotEmpty) return settings.message;

    if (habits != null && habits.isNotEmpty) {
      if (habits.length == 1) {
        return 'Time to complete: ${habits.first.name}';
      } else {
        final habitNames = habits.take(2).map((h) => h.name).join(', ');
        final remaining = habits.length - 2;
        return remaining > 0
            ? 'Time to complete: $habitNames and $remaining more'
            : 'Time to complete: $habitNames';
      }
    }

    return 'Time to check your habits! 🎯';
  }

  // 🔔 ENHANCED: Cancel specific notification
  Future<void> cancelNotification(int notificationId) async {
    try {
      // Cancel all instances of this notification (base ID + variants)
      for (int i = 0; i < 10; i++) {
        await _flutterLocalNotificationsPlugin.cancel(
          notificationId * 1000 + i,
        );
      }
      print('✅ Cancelled notification group $notificationId');
    } catch (e) {
      print('❌ Failed to cancel notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      print('✅ Cancelled all notifications');
    } catch (e) {
      print('❌ Failed to cancel all notifications: $e');
    }
  }

  // 🔔 LEGACY SUPPORT: Keep existing methods for compatibility
  Future<void> scheduleHabitReminder(
    int habitId,
    String habitName,
    TimeOfDay time, {
    bool enabled = true,
  }) async {
    if (!enabled) {
      await cancelNotification(habitId);
      return;
    }

    final settings = NotificationSettings(
      id: habitId,
      title: 'Habit Reminder',
      message: 'Time to complete: $habitName',
      time: time,
      type: NotificationType.simple,
      repetition: RepetitionType.daily,
      isEnabled: true,
      habitIds: [habitId],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await scheduleNotification(settings);
  }

  Future<void> showStreakAchievement(String habitName, int streakDays) async {
    if (!_isInitialized || !_hasPermission) return;

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'achievements',
            'Achievements',
            channelDescription: 'Habit streak achievements',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: false,
            enableVibration: true,
            playSound: true,
            color: Colors.orange,
          );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🎉 $streakDays Day Streak!',
        'Amazing! You\'ve completed "$habitName" for $streakDays days in a row!',
        details,
        payload: 'achievement:$habitName:$streakDays',
      );

      print('✅ Showed streak achievement for $habitName: $streakDays days');
    } catch (e) {
      print('❌ Failed to show achievement notification: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
    } catch (e) {
      print('❌ Failed to get pending notifications: $e');
      return [];
    }
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    print('🔔 Notification tapped with payload: $payload');

    if (payload != null) {
      if (payload.startsWith('custom_notification:')) {
        final parts = payload.split(':');
        if (parts.length >= 2) {
          final notificationId = int.tryParse(parts[1]);
          print('📱 Opening custom notification $notificationId');
          // Navigate to dashboard or specific habit
        }
      } else if (payload.startsWith('habit_reminder:')) {
        final habitId = int.tryParse(payload.split(':')[1]);
        print('📱 Opening habit reminder for ID: $habitId');
      } else if (payload.startsWith('achievement:')) {
        print('📱 Opening achievement notification');
      }
    }
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay? parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      print('❌ Failed to parse time: $timeString');
    }
    return null;
  }
}
