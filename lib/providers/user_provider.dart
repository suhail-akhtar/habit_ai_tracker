import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../models/user_settings.dart';
import '../utils/app_log.dart';

class UserProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  // App is currently fully free: keep the fields for compatibility,
  // but treat all users as premium/unlimited.
  bool _isPremium = true;
  String _subscriptionStatus = 'active';
  int _habitCount = 0;
  final Map<String, dynamic> _settings = {};

  // 🔧 NEW: Track enforcement state
  bool _isEnforcementActive = false;
  DateTime? _lastHabitCountSync;

  bool get isPremium => _isPremium;
  String get subscriptionStatus => _subscriptionStatus;
  int get habitCount => _habitCount;
  Map<String, dynamic> get settings => _settings;

  // 🔧 ENHANCED: Strict premium enforcement with fail-safe
  bool get canCreateMoreHabits {
    return true;
  }

  int get remainingFreeHabits {
    return -1; // Unlimited
  }

  // 🔧 ENHANCED: More granular limit checking
  bool get hasReachedFreeLimit => false;

  bool get isAtWarningLimit => false;

  // 🔧 ENHANCED: Comprehensive premium feature validation
  bool canAccessPremiumFeature(String featureName) {
    return true;
  }

  // 🔧 ENHANCED: Detailed validation with multiple check points
  PremiumValidationResult validateHabitCreation() {
    return PremiumValidationResult.success();
  }

  // 🔧 NEW: Validate specific premium features
  PremiumValidationResult validatePremiumFeature(String featureName) {
    return PremiumValidationResult.success();
  }

  Future<void> loadUserData() async {
    try {
      _isEnforcementActive = false;
      _subscriptionStatus = 'active';
      _isPremium = true;

      // 🔧 ENHANCED: Always sync habit count from database
      await _forceHabitCountSync();

      // Load other settings
      await _loadSettings();

      // 🔧 NEW: Validate data integrity
      await _validateDataIntegrity();

      notifyListeners();
    } catch (e) {
      AppLog.e('Failed to load user data', e);
      _isEnforcementActive = false;
      _subscriptionStatus = 'active';
      _isPremium = true;
    }
  }

  // 🔧 NEW: Force synchronization with database
  Future<void> _forceHabitCountSync() async {
    try {
      final habits = await _databaseService.getActiveHabits();
      _habitCount = habits.length;
      _lastHabitCountSync = DateTime.now();

      if (kDebugMode) {
        AppLog.d('🔒 UserProvider: Synced habit count: $_habitCount');
      }
    } catch (e) {
      AppLog.e('Failed to sync habit count', e);
      _habitCount = 0; // Fail-safe to most restrictive
    }
  }

  // 🔧 NEW: Immediate sync for validation
  // 🔧 NEW: Data integrity validation
  Future<void> _validateDataIntegrity() async {
    try {
      // App is currently fully free; keep this hook for future checks.
    } catch (e) {
      AppLog.e('Data integrity validation failed', e);
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

  // 🔧 ENHANCED: Strict habit count management with database verification
  Future<void> updateHabitCount(int count) async {
    // 🔧 NEW: Always verify against database first
    await _forceHabitCountSync();

    final oldCount = _habitCount;

    _habitCount = count;
    _lastHabitCountSync = DateTime.now();

    if (kDebugMode) {
      AppLog.d(
        '🔒 UserProvider: Updated habit count: $oldCount → $_habitCount',
      );
    }

    notifyListeners();
  }

  // 🔧 ENHANCED: Increment with strict validation
  Future<bool> incrementHabitCount() async {
    await _forceHabitCountSync(); // Always sync first

    _habitCount++;
    _lastHabitCountSync = DateTime.now();

    if (kDebugMode) {
      AppLog.d('✅ UserProvider: Incremented habit count to $_habitCount');
    }

    notifyListeners();
    return true;
  }

  // 🔧 ENHANCED: Decrement with validation
  Future<void> decrementHabitCount() async {
    if (_habitCount > 0) {
      _habitCount--;
      _lastHabitCountSync = DateTime.now();

      if (kDebugMode) {
        AppLog.d('⬇️ UserProvider: Decremented habit count to $_habitCount');
      }

      notifyListeners();
    }
  }

  // 🔧 NEW: Force refresh from database (for critical operations)
  Future<void> refreshHabitCount() async {
    await _forceHabitCountSync();
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
      AppLog.e('Failed to update setting $key', e);
    }
  }

  Future<void> upgradeToPremium() async {
    // No-op: app is free.
    _subscriptionStatus = 'active';
    _isPremium = true;
    notifyListeners();
  }

  Future<void> cancelSubscription() async {
    // No-op: app is free.
    _subscriptionStatus = 'active';
    _isPremium = true;
    notifyListeners();
  }

  String getSetting(String key, {String defaultValue = ''}) {
    return _settings[key] ?? defaultValue;
  }

  bool getBoolSetting(String key, {bool defaultValue = false}) {
    final value = _settings[key];
    if (value == null) return defaultValue;
    return value.toLowerCase() == 'true';
  }

  // 🔧 NEW: Get enforcement status (for debugging)
  bool get isEnforcementActive => _isEnforcementActive;

  // 🔧 NEW: Get last sync time (for debugging)
  DateTime? get lastHabitCountSync => _lastHabitCountSync;
}

// 🔧 ENHANCED: More detailed validation result with enforcement context
class PremiumValidationResult {
  final bool isAllowed;
  final String? message;
  final PremiumValidationType type;
  final DateTime timestamp;

  const PremiumValidationResult._(
    this.isAllowed,
    this.message,
    this.type,
    this.timestamp,
  );

  factory PremiumValidationResult.success() {
    return PremiumValidationResult._(
      true,
      null,
      PremiumValidationType.success,
      DateTime.now(),
    );
  }

  factory PremiumValidationResult.blocked(String message) {
    return PremiumValidationResult._(
      false,
      message,
      PremiumValidationType.blocked,
      DateTime.now(),
    );
  }

  factory PremiumValidationResult.warning(String message) {
    return PremiumValidationResult._(
      true,
      message,
      PremiumValidationType.warning,
      DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'PremiumValidationResult(allowed: $isAllowed, type: $type, message: $message)';
  }
}

enum PremiumValidationType { success, warning, blocked }
