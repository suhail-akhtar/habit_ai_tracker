import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../models/habit.dart';

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
      // Initialize timezone data
      tz.initializeTimeZones();

      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
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

      // Request permissions
      await requestPermissions();

      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ NotificationService initialization failed: $e');
      _isInitialized = false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      // Request notification permission
      final permission = await Permission.notification.request();
      _hasPermission = permission == PermissionStatus.granted;

      if (!_hasPermission) {
        print('❌ Notification permission denied');
        return false;
      }

      // For Android 13+ (API level 33+), also request POST_NOTIFICATIONS
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

  Future<void> scheduleHabitReminder(
    int habitId,
    String habitName,
    TimeOfDay time, {
    bool enabled = true,
  }) async {
    if (!_isInitialized || !_hasPermission) {
      print(
        '❌ Cannot schedule notification: init=$_isInitialized, permission=$_hasPermission',
      );
      return;
    }

    try {
      if (!enabled) {
        await cancelHabitReminder(habitId);
        return;
      }

      // Calculate next notification time
      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      );

      // Create notification details
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'habit_reminders',
            'Habit Reminders',
            channelDescription: 'Daily habit reminder notifications',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
            sound: RawResourceAndroidNotificationSound('notification'),
            enableVibration: true,
            playSound: true,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'notification.wav',
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Schedule the notification
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        habitId, // Use habit ID as notification ID
        'Habit Reminder: $habitName',
        'Time to complete your habit! 🎯',
        scheduledTZ,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        payload: 'habit_reminder:$habitId',
      );

      print('✅ Scheduled notification for $habitName at ${time.format}');
    } catch (e) {
      print('❌ Failed to schedule notification: $e');
    }
  }

  Future<void> scheduleDailyReminder(TimeOfDay time, List<Habit> habits) async {
    if (!_isInitialized || !_hasPermission || habits.isEmpty) {
      print('❌ Cannot schedule daily reminder');
      return;
    }

    try {
      // Cancel existing daily reminder
      await _flutterLocalNotificationsPlugin.cancel(
        999,
      ); // Use 999 for daily reminder

      // Calculate next notification time
      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      );

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'daily_reminders',
            'Daily Reminders',
            channelDescription: 'Daily habit check-in notifications',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      final habitCount = habits.length;
      final habitNames = habits.take(3).map((h) => h.name).join(', ');

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        999, // Daily reminder ID
        'Daily Habit Check-in 📝',
        habitCount <= 3
            ? 'Time to check your habits: $habitNames'
            : 'Time to check your $habitCount habits: $habitNames and more',
        scheduledTZ,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_reminder',
      );

      print('✅ Scheduled daily reminder at ${time.format}');
    } catch (e) {
      print('❌ Failed to schedule daily reminder: $e');
    }
  }

  Future<void> cancelHabitReminder(int habitId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(habitId);
      print('✅ Cancelled notification for habit $habitId');
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

  Future<void> showStreakAchievement(String habitName, int streakDays) async {
    if (!_isInitialized || !_hasPermission) return;

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'achievements',
            'Achievements',
            channelDescription: 'Habit streak achievements',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: false,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
            color: Colors.orange,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🎉 $streakDays Day Streak!',
        'Amazing! You\'ve completed "$habitName" for $streakDays days in a row!',
        platformChannelSpecifics,
        payload: 'achievement:$habitName:$streakDays',
      );

      print('✅ Showed streak achievement for $habitName: $streakDays days');
    } catch (e) {
      print('❌ Failed to show achievement notification: $e');
    }
  }

  Future<void> showWeeklyInsight(String insight) async {
    if (!_isInitialized || !_hasPermission) return;

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'insights',
            'Weekly Insights',
            channelDescription: 'AI-powered weekly habit insights',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            showWhen: false,
            icon: '@mipmap/ic_launcher',
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: false,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        888, // Weekly insight ID
        '💡 Weekly Insight',
        insight,
        platformChannelSpecifics,
        payload: 'weekly_insight',
      );

      print('✅ Showed weekly insight notification');
    } catch (e) {
      print('❌ Failed to show insight notification: $e');
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

    // Handle different notification types
    if (payload != null) {
      if (payload.startsWith('habit_reminder:')) {
        final habitId = int.tryParse(payload.split(':')[1]);
        print('📱 Opening habit reminder for ID: $habitId');
        // Navigate to specific habit or dashboard
      } else if (payload == 'daily_reminder') {
        print('📱 Opening daily reminder - navigate to dashboard');
        // Navigate to dashboard
      } else if (payload.startsWith('achievement:')) {
        print('📱 Opening achievement notification');
        // Navigate to analytics or show achievement details
      }
    }
  }

  // Helper method to format time for display
  String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Helper method to parse time from string
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
