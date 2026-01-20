import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../utils/app_log.dart';

enum AnalyticsRange { week, month, year }

class AnalyticsProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  Map<String, dynamic> _analytics = {};
  Map<DateTime, int> _heatmapData = {};
  List<Map<String, dynamic>> _progressSeries = const [];
  Map<String, dynamic> _rangeSummary = {};
  AnalyticsRange _range = AnalyticsRange.week;
  String? _weeklyInsight;
  String _bestTimeLabel = '—';
  String _bestDayLabel = '—';
  String _leastActiveDayLabel = '—';
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get analytics => _analytics;
  Map<DateTime, int> get heatmapData => _heatmapData;
  List<Map<String, dynamic>> get progressSeries => _progressSeries;
  Map<String, dynamic> get rangeSummary => _rangeSummary;
  AnalyticsRange get range => _range;
  String? get weeklyInsight => _weeklyInsight;
  String get bestTimeLabel => _bestTimeLabel;
  String get bestDayLabel => _bestDayLabel;
  String get leastActiveDayLabel => _leastActiveDayLabel;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAnalytics() async {
    _setLoading(true);
    try {
      _analytics = await _databaseService.getAnalytics();
      _heatmapData = await _databaseService.getHeatmapData();
      await _loadRangeData();
      await _loadPatternInsights();
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

  Future<void> setRange(AnalyticsRange range) async {
    if (_range == range) return;
    _range = range;
    await _loadRangeData();
    notifyListeners();
  }

  Future<void> _loadRangeData() async {
    _progressSeries = await _databaseService.getProgressSeries(
      range: _range.name,
    );
    _rangeSummary = await _databaseService.getRangeSummary(
      range: _range.name,
    );
  }

  Future<void> _loadPatternInsights() async {
    final hourCounts = await _databaseService.getCompletionsByHour(days: 30);
    final weekdayCounts =
        await _databaseService.getCompletionsByWeekday(days: 30);

    _bestTimeLabel = _formatBestHour(hourCounts);
    _bestDayLabel = _formatBestWeekday(weekdayCounts, preferMax: true);
    _leastActiveDayLabel = _formatBestWeekday(weekdayCounts, preferMax: false);
  }

  String _formatBestHour(Map<int, int> hourCounts) {
    if (hourCounts.isEmpty) return '—';
    final best = hourCounts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    final start = best.key;
    final end = (best.key + 1) % 24;
    return '${_formatHour(start)}–${_formatHour(end)}';
  }

  String _formatBestWeekday(
    Map<int, int> weekdayCounts, {
    required bool preferMax,
  }) {
    if (weekdayCounts.isEmpty) return '—';
    final entry = weekdayCounts.entries.reduce(
      (a, b) => preferMax
          ? (a.value >= b.value ? a : b)
          : (a.value <= b.value ? a : b),
    );
    return _weekdayLabel(entry.key);
  }

  String _weekdayLabel(int weekday) {
    const labels = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    if (weekday < 1 || weekday > 7) return '—';
    return labels[weekday - 1];
  }

  String _formatHour(int hour) {
    final normalized = hour % 24;
    final period = normalized >= 12 ? 'PM' : 'AM';
    final display = normalized == 0
        ? 12
        : normalized > 12
            ? normalized - 12
            : normalized;
    return '$display $period';
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

  Future<Map<String, dynamic>> getHabitAnalytics(int habitId) async {
    return await _databaseService.getHabitAnalytics(habitId);
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
