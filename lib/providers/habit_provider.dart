import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class HabitProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  List<Habit> _habits = [];
  List<HabitLog> _todayLogs = [];
  bool _isLoading = false;
  String? _error;

  List<Habit> get habits => _habits;
  List<HabitLog> get todayLogs => _todayLogs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Habit> get todayHabits {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _habits.where((habit) {
      final completedToday = _todayLogs.any((log) =>
          log.habitId == habit.id &&
          log.completedAt.toIso8601String().startsWith(todayStr));
      return habit.isActive;
    }).toList();
  }

  int get longestStreak {
    // Calculate longest streak across all habits
    int maxStreak = 0;
    // This would be implemented with proper database queries
    return maxStreak;
  }

  Future<void> loadHabits() async {
    _setLoading(true);
    try {
      _habits = await _databaseService.getActiveHabits();
      await _loadTodayLogs();
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

    _todayLogs =
        await _databaseService.getLogsForDateRange(startOfDay, endOfDay);
  }

  Future<void> addHabit(Habit habit) async {
    _setLoading(true);
    try {
      final habitWithId = habit.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _databaseService.createHabit(habitWithId);
      final newHabit = habitWithId.copyWith(id: id);

      _habits.insert(0, newHabit);
      _clearError();

      notifyListeners();
    } catch (e) {
      _setError('Failed to add habit: $e');
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
        notifyListeners();
      }

      _clearError();
    } catch (e) {
      _setError('Failed to update habit: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteHabit(int habitId) async {
    _setLoading(true);
    try {
      await _databaseService.deleteHabit(habitId);
      _habits.removeWhere((habit) => habit.id == habitId);
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete habit: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logHabitCompletion(int habitId,
      {String? note, String inputMethod = 'manual'}) async {
    try {
      final habitLog = HabitLog(
        habitId: habitId,
        completedAt: DateTime.now(),
        note: note,
        inputMethod: inputMethod,
      );

      await _databaseService.logHabit(habitLog);
      await _loadTodayLogs();

      // Check for streak achievements
      final streak = await _databaseService.getHabitStreak(habitId);
      if (streak > 0 && streak % 7 == 0) {
        final habit = _habits.firstWhere((h) => h.id == habitId);
        await _notificationService.showStreakAchievement(habit.name, streak);
      }

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to log habit: $e');
    }
  }

  Future<void> logHabitSkip(int habitId, {String? note}) async {
    try {
      final habitLog = HabitLog(
        habitId: habitId,
        completedAt: DateTime.now(),
        note: note ?? 'Skipped',
        inputMethod: 'skip',
      );

      await _databaseService.logHabit(habitLog);
      await _loadTodayLogs();

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to log habit skip: $e');
    }
  }

  bool isHabitCompletedToday(int habitId) {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _todayLogs.any((log) =>
        log.habitId == habitId &&
        log.completedAt.toIso8601String().startsWith(todayStr) &&
        log.inputMethod != 'skip');
  }

  Future<int> getHabitStreak(int habitId) async {
    return await _databaseService.getHabitStreak(habitId);
  }

  Future<List<HabitLog>> getHabitHistory(int habitId, {int limit = 30}) async {
    return await _databaseService.getHabitLogs(habitId, limit: limit);
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
