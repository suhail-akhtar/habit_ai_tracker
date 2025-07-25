import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../models/habit.dart';
import '../models/notification_settings.dart';
import '../providers/habit_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 🔔 NEW: Method channel for custom Android activities
  static const MethodChannel _methodChannel = MethodChannel(
    'habit_tracker/notifications',
  );

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

      // 🔔 NEW: Set up method channel handlers for alarm/ringing results
      _methodChannel.setMethodCallHandler(_handleMethodCall);

      _isInitialized = true;
      await requestPermissions();

      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ NotificationService initialization failed: $e');
      _isInitialized = false;
    }
  }

  // Handle method calls from Android activities
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('=== METHOD CALL RECEIVED ===');
    print('Method: ${call.method}');
    print('Arguments: ${call.arguments}');

    if (call.arguments is Map) {
      final args = call.arguments as Map;
      print('Argument keys: ${args.keys.toList()}');
      if (args.containsKey('action')) {
        print('Action value: "${args['action']}"');
      }
      if (args.containsKey('habit_ids')) {
        print('Habit IDs: "${args['habit_ids']}"');
      }
    }
    print('============================');

    try {
      switch (call.method) {
        case 'onAlarmDismissed':
          final arguments = call.arguments as Map<dynamic, dynamic>;
          print('Processing onAlarmDismissed...');
          await handleAlarmAction(
            action: arguments['action'] ?? 'alarm_dismissed',
            habitIds: arguments['habit_ids'] ?? '',
            notificationId: arguments['notification_id'] ?? 0,
          );
          break;

        case 'onAlarmSnoozed':
          final arguments = call.arguments as Map<dynamic, dynamic>;
          print('Processing onAlarmSnoozed...');
          await handleAlarmAction(
            action: arguments['action'] ?? 'alarm_snoozed',
            habitIds: arguments['habit_ids'] ?? '',
            notificationId: arguments['notification_id'] ?? 0,
            snoozeMinutes: arguments['snooze_minutes'] ?? 5,
          );
          break;

        case 'onCallAnswered':
          final arguments = call.arguments as Map<dynamic, dynamic>;
          print('Processing onCallAnswered...');
          await handleRingingAction(
            action: arguments['action'] ?? 'call_answered',
            habitIds: arguments['habit_ids'] ?? '',
            notificationId: arguments['notification_id'] ?? 0,
          );
          break;

        case 'onCallDeclined':
          final arguments = call.arguments as Map<dynamic, dynamic>;
          print('Processing onCallDeclined...');
          await handleRingingAction(
            action: arguments['action'] ?? 'call_declined',
            habitIds: arguments['habit_ids'] ?? '',
            notificationId: arguments['notification_id'] ?? 0,
          );
          break;

        default:
          print('Unknown method call: ${call.method}');
      }
    } catch (e) {
      print('Error handling method call ${call.method}: $e');
      print('Stack trace: $e');
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

      // 🔔 NEW: Request system alert window permission for alarms/ringing
      if (_hasPermission) {
        await _requestSystemAlertPermission();
      }

      print('✅ Notification permissions: $_hasPermission');
      return _hasPermission;
    } catch (e) {
      print('❌ Permission request failed: $e');
      _hasPermission = false;
      return false;
    }
  }

  // 🔔 NEW: Request system alert window permission for full-screen activities
  Future<void> _requestSystemAlertPermission() async {
    try {
      await _methodChannel.invokeMethod('requestSystemAlertPermission');
    } catch (e) {
      print('❌ System alert permission request failed: $e');
    }
  }

  // 🔔 ENHANCED: Schedule notification with custom activity support
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

      // 🔔 NEW: Handle custom activities for alarm/ringing
      if (settings.type == NotificationType.alarm ||
          settings.type == NotificationType.ringing) {
        return await _scheduleCustomNotification(settings, associatedHabits);
      } else {
        return await _scheduleRegularNotification(settings, associatedHabits);
      }
    } catch (e) {
      print('❌ Failed to schedule notification: $e');
      return false;
    }
  }

  // Schedule custom notification (alarm/ringing with Android activities)
  Future<bool> _scheduleCustomNotification(
    NotificationSettings settings,
    List<Habit>? associatedHabits,
  ) async {
    try {
      final scheduledTimes = _calculateScheduledTimes(settings);
      bool allScheduled = true;

      for (int i = 0; i < scheduledTimes.length; i++) {
        final scheduledTime = scheduledTimes[i];
        final notificationId = (settings.id ?? 0) * 1000 + i;

        final habitIdsStr = settings.habitIds.join(',');
        final notificationData = {
          'notification_id': notificationId,
          'habit_name': _buildTitle(settings, associatedHabits),
          'habit_message': _buildMessage(settings, associatedHabits),
          'habit_ids': habitIdsStr,
          'scheduled_time': scheduledTime.millisecondsSinceEpoch,
          'type': settings.type.name,
        };

        try {
          final result = await _methodChannel.invokeMethod(
            'scheduleCustomNotification',
            notificationData,
          );

          if (result == true) {
            print(
              'Scheduled ${settings.type.name} notification #$notificationId',
            );
          } else {
            print('Failed to schedule notification #$notificationId');
            allScheduled = false;
          }
        } catch (e) {
          print('Failed to schedule notification #$notificationId: $e');
          allScheduled = false;
        }
      }

      return allScheduled;
    } catch (e) {
      print('Failed to schedule custom notifications: $e');
      return false;
    }
  }

  // 🔔 EXISTING: Regular notification scheduling (simple type)
  Future<bool> _scheduleRegularNotification(
    NotificationSettings settings,
    List<Habit>? associatedHabits,
  ) async {
    try {
      final notificationDetails = _buildNotificationDetails(settings);
      final scheduledTimes = _calculateScheduledTimes(settings);

      bool allScheduled = true;
      for (int i = 0; i < scheduledTimes.length; i++) {
        final scheduledTime = scheduledTimes[i];
        final notificationId = (settings.id ?? 0) * 1000 + i;

        try {
          await _flutterLocalNotificationsPlugin.zonedSchedule(
            notificationId,
            _buildTitle(settings, associatedHabits),
            _buildMessage(settings, associatedHabits),
            scheduledTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: _getMatchComponents(settings),
            payload:
                'simple_notification:${settings.id}:${settings.habitIds.join(",")}',
          );

          print(
            '✅ Scheduled regular notification #$notificationId for ${scheduledTime.toString()}',
          );
        } catch (e) {
          print(
            '❌ Failed to schedule regular notification #$notificationId: $e',
          );
          allScheduled = false;
        }
      }

      return allScheduled;
    } catch (e) {
      print('❌ Failed to schedule regular notifications: $e');
      return false;
    }
  }

  NotificationDetails _buildNotificationDetails(NotificationSettings settings) {
    // Only used for simple notifications now
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'simple_reminders',
          'Simple Reminders',
          channelDescription: 'Simple habit reminder notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(android: androidDetails, iOS: iOSDetails);
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

        final finalDate = scheduledDate.isBefore(now)
            ? scheduledDate.add(const Duration(days: 1))
            : scheduledDate;

        times.add(tz.TZDateTime.from(finalDate, tz.local));
        break;

      case RepetitionType.daily:
        for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
          final testDate = now.add(Duration(days: dayOffset));
          final weekday = testDate.weekday;

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
              break;
            }
          }
        }
        break;

      case RepetitionType.weekly:
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

  // 🔔 ENHANCED: Cancel specific notification (both regular and custom)
  Future<void> cancelNotification(int notificationId) async {
    try {
      // Cancel regular notifications
      for (int i = 0; i < 10; i++) {
        await _flutterLocalNotificationsPlugin.cancel(
          notificationId * 1000 + i,
        );
      }

      // 🔔 NEW: Cancel custom notifications via method channel
      try {
        await _methodChannel.invokeMethod('cancelCustomNotification', {
          'notification_id': notificationId,
        });
      } catch (e) {
        print('❌ Failed to cancel custom notification: $e');
      }

      print('✅ Cancelled notification group $notificationId');
    } catch (e) {
      print('❌ Failed to cancel notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();

      // 🔔 NEW: Cancel all custom notifications
      try {
        await _methodChannel.invokeMethod('cancelAllCustomNotifications');
      } catch (e) {
        print('❌ Failed to cancel custom notifications: $e');
      }

      print('✅ Cancelled all notifications');
    } catch (e) {
      print('❌ Failed to cancel all notifications: $e');
    }
  }

  // 🔔 NEW: Test notification immediately (for testing UI)
  Future<bool> testNotification(NotificationSettings settings) async {
    if (!_isInitialized || !_hasPermission) {
      print(
        '❌ Cannot test notification: init=$_isInitialized, permission=$_hasPermission',
      );
      return false;
    }

    try {
      // For custom notification types (alarm/ringing), trigger immediately
      if (settings.type == NotificationType.alarm ||
          settings.type == NotificationType.ringing) {
        final notificationData = {
          'notification_id': settings.id ?? 999999,
          'habit_name': settings.title,
          'habit_message': settings.message,
          'habit_ids': settings.habitIds.join(','),
          'type': settings.type.name,
        };

        final result = await _methodChannel.invokeMethod(
          'triggerCustomNotification',
          notificationData,
        );

        print('✅ Triggered test ${settings.type.name} notification');
        return result == true;
      } else {
        // For simple notifications, use regular notification system
        final notificationDetails = _buildNotificationDetails(settings);

        await _flutterLocalNotificationsPlugin.show(
          settings.id ?? 999999,
          settings.title,
          settings.message,
          notificationDetails,
        );

        print('✅ Triggered test simple notification');
        return true;
      }
    } catch (e) {
      print('❌ Failed to test notification: $e');
      return false;
    }
  }

  // 🔔 NEW: Handle alarm snooze functionality
  Future<bool> scheduleSnoozeNotification({
    required int notificationId,
    required String habitName,
    required String habitMessage,
    required String habitIds,
    required int snoozeMinutes,
    required NotificationType type,
  }) async {
    try {
      final snoozeData = {
        'notification_id': notificationId,
        'habit_name': habitName,
        'habit_message': habitMessage,
        'habit_ids': habitIds,
        'snooze_minutes': snoozeMinutes,
        'type': type.name,
      };

      final result = await _methodChannel.invokeMethod(
        'scheduleSnoozeNotification',
        snoozeData,
      );

      print('✅ Scheduled snooze notification for $snoozeMinutes minutes');
      return result == true;
    } catch (e) {
      print('❌ Failed to schedule snooze notification: $e');
      return false;
    }
  }

  // Handle habit completion from alarm/ringing actions
  Future<void> handleAlarmAction({
    required String action,
    required String habitIds,
    required int notificationId,
    int? snoozeMinutes,
  }) async {
    print('handleAlarmAction: $action, habitIds: $habitIds');

    try {
      final habitIdList = habitIds
          .split(',')
          .where((id) => id.isNotEmpty)
          .map((id) => int.tryParse(id))
          .where((id) => id != null)
          .cast<int>()
          .toList();

      if (action == 'alarm_dismissed') {
        await _markHabitsCompleted(habitIdList);
      } else if (action == 'alarm_snoozed' && snoozeMinutes != null) {
        await scheduleSnoozeNotification(
          notificationId: notificationId,
          habitName: 'Habit Reminder',
          habitMessage: 'Time to complete your habits!',
          habitIds: habitIds,
          snoozeMinutes: snoozeMinutes,
          type: NotificationType.alarm,
        );
      }
    } catch (e) {
      print('Failed to handle alarm action: $e');
    }
  }

  // Handle ringing call actions
  Future<void> handleRingingAction({
    required String action,
    required String habitIds,
    required int notificationId,
  }) async {
    print('handleRingingAction: $action, habitIds: $habitIds');

    try {
      final habitIdList = habitIds
          .split(',')
          .where((id) => id.isNotEmpty)
          .map((id) => int.tryParse(id))
          .where((id) => id != null)
          .cast<int>()
          .toList();

      if (action == 'call_answered') {
        await _markHabitsCompleted(habitIdList);
      } else if (action == 'call_declined') {
        await _markHabitsSkipped(habitIdList);
      }
    } catch (e) {
      print('Failed to handle ringing action: $e');
    }
  }

  // Mark habits as completed
  Future<void> _markHabitsCompleted(List<int> habitIds) async {
    try {
      print('Completing habits: $habitIds');
      final habitProvider = HabitProvider();

      for (final habitId in habitIds) {
        await habitProvider.logHabitCompletion(
          habitId,
          note: 'Completed via notification action',
          inputMethod: 'notification',
        );
      }
      print('Successfully marked ${habitIds.length} habits as completed');
    } catch (e) {
      print('Failed to mark habits as completed: $e');
    }
  }

  // Mark habits as skipped
  Future<void> _markHabitsSkipped(List<int> habitIds) async {
    try {
      print('Skipping habits: $habitIds');
      final habitProvider = HabitProvider();

      for (final habitId in habitIds) {
        await habitProvider.logHabitSkip(
          habitId,
          note: 'Skipped via notification action',
        );
      }
      print('Successfully marked ${habitIds.length} habits as skipped');
    } catch (e) {
      print('Failed to mark habits as skipped: $e');
    }
  }

  // Legacy support: Keep existing methods for compatibility
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
