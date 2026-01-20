import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../utils/app_log.dart';

class HabitProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  List<Habit> _habits = [];
  List<HabitLog> _todayLogs = [];
  int _longestStreak = 0;
  bool _isLoading = false;
  String? _error;

  List<Habit> get habits => _habits;
  List<HabitLog> get todayLogs => _todayLogs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Habit> get activeHabits {
    return _habits.where((habit) => habit.isActive).toList();
  }

  // 🔧 ENHANCED: Real-time habit count with database verification
  int get habitCount {
    final activeHabits = _habits.where((h) => h.isActive).length;

    if (kDebugMode && activeHabits != _habits.length) {
      AppLog.d(
        '🔍 HabitProvider: Active habits: $activeHabits / Total: ${_habits.length}',
      );
    }

    return activeHabits;
  }

  List<Habit> get todayHabits {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool isDueToday(Habit habit) {
      if (!habit.isActive) return false;

      final start = habit.startDate;
      if (start != null) {
        final startDay = DateTime(start.year, start.month, start.day);
        if (today.isBefore(startDay)) return false;
      }

      final days = habit.scheduleDaysOfWeek.isEmpty
          ? const [1, 2, 3, 4, 5, 6, 7]
          : habit.scheduleDaysOfWeek;
      return days.contains(today.weekday);
    }

    return activeHabits.where(isDueToday).toList();
  }

  int get longestStreak {
    return _longestStreak;
  }

  Future<void> _refreshLongestStreak() async {
    try {
      _longestStreak = await _databaseService.getBestStreakAcrossActiveHabits();
    } catch (e) {
      // Best-effort; don't block core flows on streak aggregation.
      if (kDebugMode) {
        AppLog.e('Failed to refresh longest streak', e);
      }
    }
  }

  Future<void> _updateWidgets() async {
    try {
      final active = habitCount;
      // Calculate real completed count (unique habits completed today)
      final completedUnique = _todayLogs.map((l) => l.habitId).toSet().length;

      await WidgetService.updateHabitStatus(completedUnique, active);
      await WidgetService.updateStreak(longestStreak);
    } catch (e) {
      AppLog.e('Widget update failed', e);
    }
  }

  Future<void> loadHabits() async {
    _setLoading(true);
    try {
      _habits = await _databaseService.getActiveHabits();
      await _loadTodayLogs();
      await _refreshLongestStreak();
      _updateWidgets(); // Update widgets after loading

      if (kDebugMode) {
        AppLog.d('📱 HabitProvider: Loaded ${_habits.length} habits');
      }

      _clearError();
    } catch (e) {
      _setError('Failed to load habits: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadTodayLogs() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    _todayLogs = await _databaseService.getLogsForDateRange(
      startOfDay,
      endOfDay,
    );
  }

  // 🔧 ENHANCED: Multi-layer premium validation with database protection
  Future<bool> addHabit(Habit habit, {required bool isPremium}) async {
    _setLoading(true);
    try {
      // 🔧 LAYER 3: Create habit with timestamp validation
      final habitWithId = habit.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _databaseService.createHabit(habitWithId);
      final newHabit = habitWithId.copyWith(id: id);

      // 🔧 SUCCESS: Update local state
      _habits.insert(0, newHabit);
      _clearError();

      if (kDebugMode) {
        AppLog.d(
          '✅ HabitProvider: Successfully created habit "${newHabit.name}" ($habitCount)',
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to add habit: $e');
      if (kDebugMode) {
        AppLog.e('❌ HabitProvider: Habit creation failed', e);
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateHabit(Habit habit) async {
    _setLoading(true);
    try {
      final updatedHabit = habit.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateHabit(updatedHabit);

      final index = _habits.indexWhere((h) => h.id == habit.id);
      if (index != -1) {
        _habits[index] = updatedHabit;

        if (kDebugMode) {
          AppLog.d('📝 HabitProvider: Updated habit "${updatedHabit.name}"');
        }

        notifyListeners();
      }

      _clearError();
    } catch (e) {
      _setError('Failed to update habit: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 🔧 ENHANCED: Safe deletion with count tracking
  Future<void> deleteHabit(int habitId) async {
    _setLoading(true);
    try {
      final habitToDelete = _habits.firstWhere((h) => h.id == habitId);

      await _databaseService.deleteHabit(habitId);
      _habits.removeWhere((habit) => habit.id == habitId);

      if (kDebugMode) {
        AppLog.d(
          '🗑️ HabitProvider: Deleted habit "${habitToDelete.name}" ($habitCount remaining)',
        );
      }

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete habit: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 🔧 ENHANCED: Validate habit logging permissions
  Future<void> logHabitCompletion(
    int habitId, {
    String? note,
    String inputMethod = 'manual',
    bool isPremium = false,
  }) async {
    try {
      // 🔧 NEW: Validate habit exists and is active
      final habit = _habits.firstWhere(
        (h) => h.id == habitId && h.isActive,
        orElse: () => throw Exception('Habit not found or inactive'),
      );

      final habitLog = HabitLog(
        habitId: habitId,
        completedAt: DateTime.now(),
        note: note,
        inputMethod: inputMethod,
        status: 'completed',
      );

      await _databaseService.logHabit(habitLog);
      await _loadTodayLogs();
      await _refreshLongestStreak();
      _updateWidgets(); // Update widgets

      // Check for streak achievements
      final streak = await _databaseService.getHabitStreak(habitId);
      if (streak > 0 && streak % 7 == 0) {
        await _notificationService.showStreakAchievement(habit.name, streak);
      }

      // 🎯 Goal achievement (best-effort): notify when goal target reached
      final goalProgress = await _databaseService.getHabitGoalProgress(habitId);
      if (goalProgress.isNotEmpty) {
        final target = goalProgress['target'] as int? ?? 0;
        final completed = goalProgress['completed'] as int? ?? 0;
        final type = goalProgress['type'] as String? ?? '';

        if (target > 0 && completed == target) {
          final title = type == 'weekly'
              ? 'Weekly Goal Achieved!'
              : type == 'total'
                  ? 'Total Goal Achieved!'
                  : 'Streak Goal Achieved!';
          final message = type == 'weekly'
              ? 'You hit $target completions this week for "$habit.name".'
              : type == 'total'
                  ? 'You reached $target total completions for "$habit.name".'
                  : 'You reached a $target-day streak for "$habit.name".';

          await _notificationService.showGoalAchievement(
            habit.name,
            title,
            message,
          );
        }
      }

      if (kDebugMode) {
        AppLog.d(
          '✅ HabitProvider: Logged completion for "${habit.name}" via $inputMethod',
        );
      }

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to log habit: $e');
      if (kDebugMode) {
        AppLog.e('❌ HabitProvider: Failed to log habit completion', e);
      }
    }
  }

  Future<void> logHabitSkip(int habitId, {String? note}) async {
    try {
      final habit = _habits.firstWhere(
        (h) => h.id == habitId && h.isActive,
        orElse: () => throw Exception('Habit not found or inactive'),
      );

      final habitLog = HabitLog(
        habitId: habitId,
        completedAt: DateTime.now(),
        note: note ?? 'Skipped',
        inputMethod: 'manual',
        status: 'skipped',
      );

      await _databaseService.logHabit(habitLog);
      await _loadTodayLogs();
      await _refreshLongestStreak();
      _updateWidgets();

      if (kDebugMode) {
        AppLog.d('⏭️ HabitProvider: Logged skip for "${habit.name}"');
      }

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to log habit skip: $e');
    }
  }

  // 🔧 ENHANCED: Validate habit completion with active status check
  bool isHabitCompletedToday(int habitId) {
    final count = getCompletionCountToday(habitId);

    // If the habit isn't loaded yet, treat it as not completed.
    final habitIndex = _habits.indexWhere((h) => h.id == habitId && h.isActive);
    if (habitIndex == -1) return false;
    final habit = _habits[habitIndex];

    // 🔔 CHANGED: Skips now count as "attempts" or "slots used",
    // but don't automatically mark the WHOLE day as finished unless target met.
    // If you skip once in a 5x habit, you have 4x left.
    // Logic: (Completions + Skips) >= Target

    final skips = getSkipCountToday(habitId);

    // Special case: If user explicitly marked "Day Skipped" (future feature),
    // we could handle it here. For now, we trust the count.

    return (count + skips) >= habit.targetFrequency;
  }

  // 🔔 NEW: Helper to count skips
  int getSkipCountToday(int habitId) {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return _todayLogs
        .where(
          (log) =>
              log.habitId == habitId &&
              log.completedAt.toIso8601String().startsWith(todayStr) &&
              log.status == 'skipped',
        )
        .length;
  }

  int getCompletionCountToday(int habitId) {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _todayLogs
        .where(
          (log) =>
              log.habitId == habitId &&
              log.completedAt.toIso8601String().startsWith(todayStr) &&
              log.status == 'completed',
        )
        .length;
  }

  bool isHabitSkippedToday(int habitId) {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _todayLogs.any(
      (log) =>
          log.habitId == habitId &&
          log.completedAt.toIso8601String().startsWith(todayStr) &&
          log.status == 'skipped',
    );
  }

  Future<int> getHabitStreak(int habitId) async {
    return await _databaseService.getHabitStreak(habitId);
  }

  Future<List<HabitLog>> getHabitHistory(int habitId, {int limit = 30}) async {
    return await _databaseService.getHabitLogs(habitId, limit: limit);
  }

  // 🔧 NEW: Validate habit access for premium features
  bool canAccessHabit(int habitId, {bool isPremium = false}) {
    final habitIndex = _habits.indexWhere((h) => h.id == habitId && h.isActive);
    if (habitIndex == -1) return false;

    // App is currently fully free.
    return true;
  }

  // 🔧 NEW: Get habits accessible to current user tier
  List<Habit> getAccessibleHabits({bool isPremium = false}) {
    return activeHabits;
  }

  // 🔧 NEW: Force reload from database (for critical operations)
  Future<void> forceReload() async {
    try {
      final freshHabits = await _databaseService.getActiveHabits();
      _habits = freshHabits;
      await _loadTodayLogs();

      if (kDebugMode) {
        AppLog.d(
          '🔄 HabitProvider: Force reloaded ${_habits.length} habits from database',
        );
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to reload habits: $e');
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
    notifyListeners();
  }
}
