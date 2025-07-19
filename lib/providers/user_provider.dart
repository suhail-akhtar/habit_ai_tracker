import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../models/user_settings.dart';
import '../utils/constants.dart';

class UserProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  bool _isPremium = false;
  String _subscriptionStatus = 'inactive';
  int _habitCount = 0;
  final Map<String, dynamic> _settings = {};

  bool get isPremium => _isPremium;
  String get subscriptionStatus => _subscriptionStatus;
  int get habitCount => _habitCount;
  Map<String, dynamic> get settings => _settings;

  bool get canCreateMoreHabits =>
      _isPremium || _habitCount < Constants.freeHabitLimit;
  int get remainingFreeHabits => Constants.freeHabitLimit - _habitCount;

  Future<void> loadUserData() async {
    try {
      // Load subscription status
      final subscriptionSetting =
          await _databaseService.getSetting('subscription_status');
      _subscriptionStatus = subscriptionSetting?.value ?? 'inactive';
      _isPremium = _subscriptionStatus == 'active';

      // Load other settings
      await _loadSettings();

      notifyListeners();
    } catch (e) {
      print('Failed to load user data: $e');
    }
  }

  Future<void> _loadSettings() async {
    final settingKeys = [
      'theme_mode',
      'notification_enabled',
      'reminder_time',
      'voice_language',
      'analytics_enabled',
    ];

    for (final key in settingKeys) {
      final setting = await _databaseService.getSetting(key);
      if (setting != null) {
        _settings[key] = setting.value;
      }
    }
  }

  Future<void> updateHabitCount(int count) async {
    _habitCount = count;
    notifyListeners();
  }

  Future<void> updateSetting(String key, String value) async {
    try {
      final setting = UserSettings(
        key: key,
        value: value,
        updatedAt: DateTime.now(),
      );

      await _databaseService.saveSetting(setting);
      _settings[key] = value;

      notifyListeners();
    } catch (e) {
      print('Failed to update setting $key: $e');
    }
  }

  Future<void> upgradeToPremium() async {
    try {
      // This would typically involve in-app purchase logic
      await updateSetting('subscription_status', 'active');
      _subscriptionStatus = 'active';
      _isPremium = true;

      notifyListeners();
    } catch (e) {
      print('Failed to upgrade to premium: $e');
    }
  }

  Future<void> cancelSubscription() async {
    try {
      await updateSetting('subscription_status', 'inactive');
      _subscriptionStatus = 'inactive';
      _isPremium = false;

      notifyListeners();
    } catch (e) {
      print('Failed to cancel subscription: $e');
    }
  }

  String getSetting(String key, {String defaultValue = ''}) {
    return _settings[key] ?? defaultValue;
  }

  bool getBoolSetting(String key, {bool defaultValue = false}) {
    final value = _settings[key];
    if (value == null) return defaultValue;
    return value.toLowerCase() == 'true';
  }
}
