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

  // 🔧 ENHANCED: Strict premium enforcement
  bool get canCreateMoreHabits {
    if (_isPremium) return true;
    return _habitCount < Constants.freeHabitLimit;
  }

  int get remainingFreeHabits {
    if (_isPremium) return -1; // Unlimited
    final remaining = Constants.freeHabitLimit - _habitCount;
    return remaining > 0 ? remaining : 0;
  }

  // 🔧 NEW: Check if user has reached free limit
  bool get hasReachedFreeLimit =>
      !_isPremium && _habitCount >= Constants.freeHabitLimit;

  // 🔧 NEW: Premium feature validation
  bool canAccessPremiumFeature(String featureName) {
    return _isPremium;
  }

  // 🔧 NEW: Validate habit creation with detailed response
  PremiumValidationResult validateHabitCreation() {
    if (_isPremium) {
      return PremiumValidationResult.success();
    }

    if (_habitCount >= Constants.freeHabitLimit) {
      return PremiumValidationResult.blocked(
        'Free tier allows maximum ${Constants.freeHabitLimit} habits. Upgrade to Premium for unlimited habits.',
      );
    }

    if (_habitCount == Constants.freeHabitLimit - 1) {
      return PremiumValidationResult.warning(
        'This will be your last free habit. Upgrade to Premium for unlimited habits.',
      );
    }

    return PremiumValidationResult.success();
  }

  Future<void> loadUserData() async {
    try {
      // Load subscription status
      final subscriptionSetting = await _databaseService.getSetting(
        'subscription_status',
      );
      _subscriptionStatus = subscriptionSetting?.value ?? 'inactive';
      _isPremium = _subscriptionStatus == 'active';

      // 🔧 ENHANCED: Load actual habit count from database
      await _refreshHabitCount();

      // Load other settings
      await _loadSettings();

      notifyListeners();
    } catch (e) {
      print('Failed to load user data: $e');
    }
  }

  // 🔧 NEW: Refresh habit count from database
  Future<void> _refreshHabitCount() async {
    try {
      final habits = await _databaseService.getActiveHabits();
      _habitCount = habits.length;
    } catch (e) {
      print('Failed to refresh habit count: $e');
      _habitCount = 0;
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

  // 🔧 ENHANCED: Strict habit count management
  Future<void> updateHabitCount(int count) async {
    final oldCount = _habitCount;
    _habitCount = count;

    // 🔧 NEW: Validate count doesn't exceed free limit for non-premium users
    if (!_isPremium && _habitCount > Constants.freeHabitLimit) {
      _habitCount = oldCount; // Revert
      throw Exception(
        'Cannot exceed free tier limit of ${Constants.freeHabitLimit} habits',
      );
    }

    notifyListeners();
  }

  // 🔧 NEW: Increment habit count with validation
  Future<bool> incrementHabitCount() async {
    if (!canCreateMoreHabits) {
      return false;
    }

    _habitCount++;
    notifyListeners();
    return true;
  }

  // 🔧 NEW: Decrement habit count
  Future<void> decrementHabitCount() async {
    if (_habitCount > 0) {
      _habitCount--;
      notifyListeners();
    }
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

// 🔧 NEW: Premium validation result class
class PremiumValidationResult {
  final bool isAllowed;
  final String? message;
  final PremiumValidationType type;

  const PremiumValidationResult._(this.isAllowed, this.message, this.type);

  factory PremiumValidationResult.success() {
    return const PremiumValidationResult._(
      true,
      null,
      PremiumValidationType.success,
    );
  }

  factory PremiumValidationResult.blocked(String message) {
    return PremiumValidationResult._(
      false,
      message,
      PremiumValidationType.blocked,
    );
  }

  factory PremiumValidationResult.warning(String message) {
    return PremiumValidationResult._(
      true,
      message,
      PremiumValidationType.warning,
    );
  }
}

enum PremiumValidationType { success, warning, blocked }
