import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 🔔 Needed for background handler type
import 'package:timezone/data/latest.dart' as tz;
import 'providers/habit_provider.dart';
import 'providers/voice_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/user_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/voice_input_screen.dart';
import 'screens/habit_setup_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
// import 'services/database_service.dart'; // removed unused
// import 'models/habit_log.dart'; // removed unused
import 'utils/theme.dart';
import 'config/app_config.dart';

// 🔔 BACKGROUND HANDLER MOVED TO MAIN.DART
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  // 🔧 CRITICAL: Initialize Flutter binding for background isolate
  WidgetsFlutterBinding.ensureInitialized();
  print('🔔 Background notification tap: ${notificationResponse.payload}');
  // Action buttons have been removed. Taps are handled in DashboardScreen via payload stream.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones(); // Ensure timezones needed for notifications

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
        ChangeNotifierProvider(create: (_) => VoiceProvider()),
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
              '/voice': (context) => const VoiceInputScreen(),
              '/habit-setup': (context) => const HabitSetupScreen(),
              '/analytics': (context) => const AnalyticsScreen(),
              '/settings': (context) => const SettingsScreen(),
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

  final List<Widget> _screens = const [
    DashboardScreen(),
    VoiceInputScreen(),
    HabitSetupScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 🔧 ENHANCED: Better initialization order for premium validation
      final userProvider = context.read<UserProvider>();
      final habitProvider = context.read<HabitProvider>();
      final voiceProvider = context.read<VoiceProvider>();
      final analyticsProvider = context.read<AnalyticsProvider>();

      // Load user data first to get premium status
      await userProvider.loadUserData();

      // Then load habits and update habit count in user provider
      await habitProvider.loadHabits();
      await userProvider.updateHabitCount(habitProvider.habitCount);

      // Initialize other providers
      await voiceProvider.initialize();
      await analyticsProvider.loadAnalytics();
    } catch (e) {
      print('App initialization error: $e');
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
            icon: Icon(Icons.mic_outlined),
            selectedIcon: Icon(Icons.mic),
            label: 'Voice',
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
