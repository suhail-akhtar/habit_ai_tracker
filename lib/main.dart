import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 🔔 Needed for background handler type
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'providers/habit_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/user_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/habit_setup_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'screens/alarm_screen.dart';
import 'services/notification_service.dart';
import 'services/database_service.dart';
import 'models/habit.dart';
import 'models/habit_log.dart';
// import 'services/database_service.dart'; // removed unused
// import 'models/habit_log.dart'; // removed unused
import 'utils/theme.dart';
import 'utils/app_log.dart';
import 'config/app_config.dart';

// 🔔 BACKGROUND HANDLER MOVED TO MAIN.DART
@pragma('vm:entry-point')
void notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  // 🔧 CRITICAL: Initialize Flutter binding for background isolate
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure plugins can be used from this background isolate.
  // This is required for DB writes via sqflite.
  try {
    ui.DartPluginRegistrant.ensureInitialized();
  } catch (_) {
    // No-op: some Flutter versions may not require this.
  }

  final actionId = notificationResponse.actionId;
  final payload = notificationResponse.payload;
  AppLog.d(
    '🔔 Background notification response: actionId=$actionId payload=$payload',
  );

  // We only handle action buttons here. Taps are handled by UI flow.
  if (actionId != 'accept' &&
      actionId != 'reject' &&
      actionId != 'dismiss' &&
      actionId != 'snooze') {
    return;
  }
  if (payload == null || payload.isEmpty) return;

  // Payload formats:
  // - new: custom_notification:{type}:{notificationId}:{habitIdsCsv}
  // - old: custom_notification:{notificationId}:{habitId}
  int? notificationSettingId;
  final habitIds = <int>[];
  String? typeStr;
  if (payload.startsWith('custom_notification:')) {
    final parts = payload.split(':');
    if (parts.length >= 4) {
      // new format
      typeStr = parts[1];
      notificationSettingId = int.tryParse(parts[2]);
      final habitIdsCsv = parts[3];
      for (final raw in habitIdsCsv.split(',')) {
        final id = int.tryParse(raw.trim());
        if (id != null) habitIds.add(id);
      }
    } else if (parts.length >= 3) {
      // old format (best-effort)
      notificationSettingId = int.tryParse(parts[1]);
      final habitId = int.tryParse(parts[2]);
      if (habitId != null) habitIds.add(habitId);
    }
  }

  if (habitIds.isEmpty) return;
  notificationSettingId ??= habitIds.first;

  // Alarm snooze must work even if the app is killed.
  if (actionId == 'snooze') {
    if (typeStr != 'alarm') return;

    try {
      // Init timezone and local notifications in this isolate.
      tz_data.initializeTimeZones();

      final plugin = FlutterLocalNotificationsPlugin();
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await plugin.initialize(initSettings);

      final habit = await DatabaseService().getHabit(habitIds.first);
      final habitName = habit?.name ?? 'Habit';
      final title = '$habitName Alarm';
      const snoozeDelay = Duration(minutes: 10);
      final body = 'Snoozed for ${snoozeDelay.inMinutes} minutes';
      final when = tz.TZDateTime.now(tz.local).add(snoozeDelay);

      final androidDetails = AndroidNotificationDetails(
        'alarm_reminders_v2',
        'Alarm Reminders',
        channelDescription: 'Full-screen alarm-style reminders',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        ongoing: true,
        autoCancel: false,
        additionalFlags: Int32List.fromList([4]),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'snooze',
            'Snooze',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'dismiss',
            'Dismiss',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'accept',
            'Accept',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      final snoozedId = DateTime.now().millisecondsSinceEpoch.remainder(
        1000000000,
      );

      await plugin.zonedSchedule(
        snoozedId,
        title,
        body,
        when,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: payload,
      );
    } catch (e) {
      AppLog.e('❌ Snooze scheduling failed', e);
    }
    return;
  }

  final db = DatabaseService();
  try {
    final status = actionId == 'accept' ? 'completed' : 'skipped';
    final note = actionId == 'accept'
        ? (typeStr == 'alarm'
              ? 'Completed via alarm notification action'
              : 'Completed via notification action')
        : (typeStr == 'alarm'
              ? 'Skipped via alarm notification action'
              : 'Skipped via notification action');

    for (final habitId in habitIds) {
      final log = HabitLog(
        habitId: habitId,
        completedAt: DateTime.now(),
        note: note,
        inputMethod: 'notification_action',
        status: status,
      );
      await db.logHabit(log);
    }
    AppLog.d(
      '✅ Background log saved for habitIds=${habitIds.join(",")} status=$status',
    );
  } catch (e) {
    AppLog.e('❌ Background log failed', e);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones(); // Ensure timezones needed for notifications

  // Initialize services with background handler
  await NotificationService().initialize(notificationTapBackground);

  runApp(const AIVoiceHabitTrackerApp());
}

class AIVoiceHabitTrackerApp extends StatelessWidget {
  const AIVoiceHabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HabitProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          return MaterialApp(
            title: AppConfig.appName,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _getThemeMode(userProvider.getSetting('theme_mode')),
            home: const MainNavigationScreen(),
            routes: {
              '/dashboard': (context) => const DashboardScreen(),
              '/habit-setup': (context) => const HabitSetupScreen(),
              '/analytics': (context) => const AnalyticsScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/incoming-call': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                final habitId = args is int ? args : null;
                if (habitId == null) {
                  return const MainNavigationScreen();
                }
                return IncomingCallScreen(habitId: habitId);
              },
              '/alarm': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                final habitId = args is int ? args : null;
                if (habitId == null) {
                  return const MainNavigationScreen();
                }
                return AlarmScreen(
                  notificationSettingId: habitId,
                  habitIds: [habitId],
                );
              },
            },
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const MainNavigationScreen(),
              );
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  ThemeMode _getThemeMode(String themeModeString) {
    switch (themeModeString.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  StreamSubscription<String?>? _notificationSubscription;
  String? _lastHandledPayload;
  DateTime? _lastHandledAt;

  final List<Widget> _screens = const [
    DashboardScreen(),
    HabitSetupScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _startNotificationRouting();
    _initializeApp();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _startNotificationRouting() {
    _notificationSubscription = NotificationService().payloadStream.listen(
      _handleNotificationPayload,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Best-effort: request runtime permissions once UI is ready.
      await NotificationService().requestPermissions();
      await _checkInitialNotification();
    });
  }

  Future<void> _checkInitialNotification() async {
    final payload = await NotificationService().getInitialPayload();
    if (payload != null) {
      _handleNotificationPayload(payload);
    }
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null) return;

    // Guard against duplicate delivery (e.g., initial payload + stream)
    final now = DateTime.now();
    if (_lastHandledPayload == payload &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!).inSeconds < 2) {
      return;
    }
    _lastHandledPayload = payload;
    _lastHandledAt = now;

    if (!payload.startsWith('custom_notification:')) return;

    final parts = payload.split(':');

    // Supported payload formats:
    // - new: custom_notification:{type}:{notificationId}:{habitIdsCsv}
    // - old: custom_notification:{notificationId}:{habitId}
    final String? typeStr = parts.length >= 4 ? parts[1] : null;
    final int? notificationSettingId = parts.length >= 4
      ? int.tryParse(parts[2])
      : (parts.length >= 3 ? int.tryParse(parts[1]) : null);

    final String habitIdsCsv = parts.length >= 4
      ? parts[3]
      : (parts.length >= 3 ? parts[2] : '');

    final habitIds = <int>[];
    for (final raw in habitIdsCsv.split(',')) {
      final id = int.tryParse(raw.trim());
      if (id != null) habitIds.add(id);
    }

    if (habitIds.isEmpty) return;
    final habitId = habitIds.first;

    if (typeStr == 'ringing' || typeStr == 'alarm') {
      if (typeStr == 'ringing') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(habitId: habitId),
            fullscreenDialog: true,
          ),
        );
        return;
      }

      if (typeStr == 'alarm') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlarmScreen(
              notificationSettingId: notificationSettingId ?? habitId,
              habitIds: habitIds,
            ),
            fullscreenDialog: true,
          ),
        );
        return;
      }
    }

    _showHabitActionDialog(habitId);
  }

  void _showHabitActionDialog(int habitId) {
    final habitProvider = context.read<HabitProvider>();
    if (habitProvider.habits.isEmpty) {
      Future.delayed(
        const Duration(seconds: 1),
        () => _showHabitActionDialog(habitId),
      );
      return;
    }

    Habit? habit;
    for (final h in habitProvider.habits) {
      if (h.id == habitId) {
        habit = h;
        break;
      }
    }
    if (habit == null) return;

    final Habit selectedHabit = habit;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Did you do it?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mark "${selectedHabit.name}" as complete?'),
            if (selectedHabit.description != null &&
                selectedHabit.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  selectedHabit.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        actions: [
          if (selectedHabit.targetFrequency > 1) ...[
            TextButton(
              onPressed: () {
                context.read<HabitProvider>().logHabitSkip(
                  habitId,
                  note: 'Skipped session via notification',
                );
                Navigator.pop(context);
              },
              child: const Text('Skip Session'),
            ),
            TextButton(
              onPressed: () {
                context.read<HabitProvider>().logHabitSkip(
                  habitId,
                  note: 'Skipped via notification',
                );
                Navigator.pop(context);
              },
              child: const Text('Skip'),
            ),
          ] else
            TextButton(
              onPressed: () {
                context.read<HabitProvider>().logHabitSkip(habitId);
                Navigator.pop(context);
              },
              child: const Text('Skip'),
            ),
          FilledButton(
            onPressed: () {
              context.read<HabitProvider>().logHabitCompletion(
                habitId,
                inputMethod: 'notification',
              );
              Navigator.pop(context);
            },
            child: const Text('Yes, Complete!'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeApp() async {
    try {
      // 🔧 ENHANCED: Better initialization order for premium validation
      final userProvider = context.read<UserProvider>();
      final habitProvider = context.read<HabitProvider>();
      final analyticsProvider = context.read<AnalyticsProvider>();

      // Load user data first to get premium status
      await userProvider.loadUserData();

      // Then load habits and update habit count in user provider
      await habitProvider.loadHabits();
      await userProvider.updateHabitCount(habitProvider.habitCount);

      // Initialize other providers
      await analyticsProvider.loadAnalytics();
    } catch (e) {
      AppLog.e('App initialization error', e);
      // Continue with app even if some providers fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_outlined),
            selectedIcon: Icon(Icons.add),
            label: 'Add Habit',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
