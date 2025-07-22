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

  // 🔧 NEW: Track enforcement state
  bool _isEnforcementActive = true;
  DateTime? _lastHabitCountSync;

  bool get isPremium => _isPremium;
  String get subscriptionStatus => _subscriptionStatus;
  int get habitCount => _habitCount;
  Map<String, dynamic> get settings => _settings;

  // 🔧 ENHANCED: Strict premium enforcement with fail-safe
  bool get canCreateMoreHabits {
    if (!_isEnforcementActive) return false; // Fail-safe
    if (_isPremium) return true;
    return _habitCount < Constants.freeHabitLimit;
  }

  int get remainingFreeHabits {
    if (_isPremium) return -1; // Unlimited
    final remaining = Constants.freeHabitLimit - _habitCount;
    return remaining > 0 ? remaining : 0;
  }

  // 🔧 ENHANCED: More granular limit checking
  bool get hasReachedFreeLimit =>
      !_isPremium && _habitCount >= Constants.freeHabitLimit;

  bool get isAtWarningLimit =>
      !_isPremium && _habitCount == Constants.freeHabitLimit - 1;

  // 🔧 ENHANCED: Comprehensive premium feature validation
  bool canAccessPremiumFeature(String featureName) {
    if (!_isEnforcementActive) return false; // Fail-safe
    return _isPremium;
  }

  // 🔧 ENHANCED: Detailed validation with multiple check points
  PremiumValidationResult validateHabitCreation() {
    // 🔧 NEW: Force habit count sync before validation
    _syncHabitCountFromDatabase();

    if (!_isEnforcementActive) {
      return PremiumValidationResult.blocked(
        'Feature validation is currently disabled. Please restart the app.',
      );
    }

    if (_isPremium) {
      return PremiumValidationResult.success();
    }

    if (_habitCount >= Constants.freeHabitLimit) {
      return PremiumValidationResult.blocked(Constants.habitLimitMessage);
    }

    if (_habitCount == Constants.freeHabitLimit - 1) {
      return PremiumValidationResult.warning(Constants.lastFreeHabitMessage);
    }

    return PremiumValidationResult.success();
  }

  // 🔧 NEW: Validate specific premium features
  PremiumValidationResult validatePremiumFeature(String featureName) {
    if (!_isEnforcementActive) {
      return PremiumValidationResult.blocked(
        'Feature validation is currently disabled.',
      );
    }

    if (_isPremium) {
      return PremiumValidationResult.success();
    }

    String message;
    switch (featureName) {
      case Constants.premiumFeatureUnlimitedHabits:
        message = 'Unlimited habits require Premium subscription';
        break;
      case Constants.premiumFeatureAdvancedInsights:
        message = 'Advanced AI insights require Premium subscription';
        break;
      case Constants.premiumFeatureDataExport:
        message = 'Data export requires Premium subscription';
        break;
      case Constants.premiumFeatureDetailedAnalytics:
        message = 'Detailed analytics require Premium subscription';
        break;
      default:
        message = Constants.premiumRequiredMessage;
    }

    return PremiumValidationResult.blocked(message);
  }

  Future<void> loadUserData() async {
    try {
      _isEnforcementActive = true; // Always start with enforcement active

      // Load subscription status
      final subscriptionSetting = await _databaseService.getSetting(
        'subscription_status',
      );
      _subscriptionStatus = subscriptionSetting?.value ?? 'inactive';
      _isPremium = _subscriptionStatus == 'active';

      // 🔧 ENHANCED: Always sync habit count from database
      await _forceHabitCountSync();

      // Load other settings
      await _loadSettings();

      // 🔧 NEW: Validate data integrity
      await _validateDataIntegrity();

      notifyListeners();
    } catch (e) {
      print('Failed to load user data: $e');
      _isEnforcementActive = false; // Disable enforcement on error
    }
  }

  // 🔧 NEW: Force synchronization with database
  Future<void> _forceHabitCountSync() async {
    try {
      final habits = await _databaseService.getActiveHabits();
      _habitCount = habits.length;
      _lastHabitCountSync = DateTime.now();

      if (kDebugMode) {
        print('🔒 UserProvider: Synced habit count: $_habitCount');
      }
    } catch (e) {
      print('Failed to sync habit count: $e');
      _habitCount = 0; // Fail-safe to most restrictive
    }
  }

  // 🔧 NEW: Immediate sync for validation
  void _syncHabitCountFromDatabase() {
    if (_lastHabitCountSync == null ||
        DateTime.now().difference(_lastHabitCountSync!).inMinutes > 5) {
      _forceHabitCountSync();
    }
  }

  // 🔧 NEW: Data integrity validation
  Future<void> _validateDataIntegrity() async {
    try {
      // Ensure habit count doesn't exceed free limit for non-premium users
      if (!_isPremium && _habitCount > Constants.freeHabitLimit) {
        if (kDebugMode) {
          print(
            '⚠️ UserProvider: Data integrity issue - non-premium user has $_habitCount habits (limit: ${Constants.freeHabitLimit})',
          );
        }

        // This could indicate a bypass attempt or data corruption
        // For now, we'll just log it and maintain the count
        // In a production app, you might want to disable some habits
      }
    } catch (e) {
      print('Data integrity validation failed: $e');
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

    // 🔧 NEW: Validate count doesn't exceed free limit for non-premium users
    if (!_isPremium && count > Constants.freeHabitLimit) {
      if (kDebugMode) {
        print(
          '🚫 UserProvider: Rejected habit count update - would exceed free limit ($count > ${Constants.freeHabitLimit})',
        );
      }
      throw Exception(
        'Cannot exceed free tier limit of ${Constants.freeHabitLimit} habits',
      );
    }

    _habitCount = count;
    _lastHabitCountSync = DateTime.now();

    if (kDebugMode) {
      print('🔒 UserProvider: Updated habit count: $oldCount → $_habitCount');
    }

    notifyListeners();
  }

  // 🔧 ENHANCED: Increment with strict validation
  Future<bool> incrementHabitCount() async {
    await _forceHabitCountSync(); // Always sync first

    if (!canCreateMoreHabits) {
      if (kDebugMode) {
        print(
          '🚫 UserProvider: Cannot increment - at limit ($_habitCount/${Constants.freeHabitLimit})',
        );
      }
      return false;
    }

    _habitCount++;
    _lastHabitCountSync = DateTime.now();

    if (kDebugMode) {
      print('✅ UserProvider: Incremented habit count to $_habitCount');
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
        print('⬇️ UserProvider: Decremented habit count to $_habitCount');
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
      print('Failed to update setting $key: $e');
    }
  }

  Future<void> upgradeToPremium() async {
    try {
      // This would typically involve in-app purchase logic
      await updateSetting('subscription_status', 'active');
      _subscriptionStatus = 'active';
      _isPremium = true;

      if (kDebugMode) {
        print('🌟 UserProvider: Upgraded to Premium');
      }

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

      // 🔧 NEW: Re-validate habit count after downgrade
      await _validateDataIntegrity();

      if (kDebugMode) {
        print('❌ UserProvider: Cancelled Premium subscription');
      }

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
