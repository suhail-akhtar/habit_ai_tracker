import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../utils/app_log.dart';

class AnalyticsProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  Map<String, dynamic> _analytics = {};
  Map<DateTime, int> _heatmapData = {};
  String? _weeklyInsight;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get analytics => _analytics;
  Map<DateTime, int> get heatmapData => _heatmapData;
  String? get weeklyInsight => _weeklyInsight;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAnalytics() async {
    _setLoading(true);
    try {
      _analytics = await _databaseService.getAnalytics();
      _heatmapData = await _databaseService.getHeatmapData();
      await _loadWeeklyInsight();
      _clearError();
    } catch (e) {
      _setError('Failed to load analytics: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadWeeklyInsight() async {
    try {
      // App is currently AI-free: provide a local, deterministic insight.
      final totalCompletions = (_analytics['totalCompletions'] as int?) ?? 0;
      final totalHabits = (_analytics['totalHabits'] as int?) ?? 0;

      if (totalHabits == 0) {
        _weeklyInsight =
            'Create your first habit to start building momentum this week.';
        return;
      }

      if (totalCompletions == 0) {
        _weeklyInsight =
            'A fresh start week. Try completing one habit today to get a streak going.';
        return;
      }

      _weeklyInsight =
          'Nice work — you have $totalCompletions completions across $totalHabits habits. Keep it consistent and build on small wins.';
    } catch (e) {
      AppLog.e('Failed to load weekly insight', e);
      _weeklyInsight =
          'Keep up the great work! Every small step counts towards building lasting habits.';
    }
  }

  Future<void> refreshInsight() async {
    _setLoading(true);
    try {
      await _loadWeeklyInsight();
      _clearError();
    } catch (e) {
      _setError('Failed to refresh insight: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<String> getDailyTip() async {
    const tips = <String>[
      'Start small: aim for consistency, not intensity.',
      'Attach your habit to an existing routine to make it stick.',
      'If you miss a day, restart immediately — no guilt, just action.',
      'Make it easy: reduce friction and prepare in advance.',
      'Track progress daily; what gets measured gets improved.',
    ];
    final index = DateTime.now().day % tips.length;
    return tips[index];
  }

  Map<String, dynamic> getHabitAnalytics(int habitId) {
    // This would return detailed analytics for a specific habit
    // Including streak, completion rate, patterns, etc.
    return {
      'streak': 0,
      'completionRate': 0.0,
      'totalLogs': 0,
      'averagePerWeek': 0.0,
    };
  }

  List<Map<String, dynamic>> getWeeklyProgress() {
    // Return weekly progress data for charts
    return List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      return {
        'date': date,
        'completedHabits': 0, // This would be calculated from actual data
        'totalHabits': 0,
      };
    });
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
