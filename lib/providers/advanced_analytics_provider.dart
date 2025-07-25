import 'package:flutter/foundation.dart';
import 'dart:math';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../models/analytics_models.dart';
import '../models/habit.dart';

class AdvancedAnalyticsProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final GeminiService _geminiService = GeminiService();

  // Heatmap data
  List<HeatmapData> _heatmapData = [];
  bool _isLoadingHeatmap = false;

  // Predictive insights
  List<PredictiveInsight> _predictiveInsights = [];
  bool _isLoadingInsights = false;

  // Pattern analysis
  List<HabitPattern> _habitPatterns = [];
  bool _isLoadingPatterns = false;

  String? _error;

  // Getters
  List<HeatmapData> get heatmapData => _heatmapData;
  bool get isLoadingHeatmap => _isLoadingHeatmap;

  List<PredictiveInsight> get predictiveInsights => _predictiveInsights;
  bool get isLoadingInsights => _isLoadingInsights;

  List<HabitPattern> get habitPatterns => _habitPatterns;
  bool get isLoadingPatterns => _isLoadingPatterns;

  String? get error => _error;

  bool get isLoading =>
      _isLoadingHeatmap || _isLoadingInsights || _isLoadingPatterns;

  /// Load heatmap data for the specified date range
  Future<void> loadHeatmapData({DateTime? startDate, DateTime? endDate}) async {
    _isLoadingHeatmap = true;
    _clearError();
    notifyListeners();

    try {
      final end = endDate ?? DateTime.now();
      final start = startDate ?? end.subtract(const Duration(days: 365));

      _heatmapData = await _databaseService.getHeatmapData(start, end);

      if (kDebugMode) {
        print('📊 Loaded ${_heatmapData.length} heatmap data points');
      }
    } catch (e) {
      _setError('Failed to load heatmap data: $e');
    } finally {
      _isLoadingHeatmap = false;
      notifyListeners();
    }
  }

  /// Generate predictive insights using AI
  Future<void> generatePredictiveInsights({
    required List<Habit> habits,
    required bool isPremium,
  }) async {
    if (!isPremium) {
      _setError('Predictive analytics is a Premium feature');
      return;
    }

    _isLoadingInsights = true;
    _clearError();
    notifyListeners();

    try {
      // Get recent habit completion data
      final recentData = await _databaseService.getRecentHabitData(
        days: 30,
        habits: habits,
      );

      // Generate insights using AI
      final insights = await _geminiService.generatePredictiveInsights(
        habits: habits,
        recentData: recentData,
        heatmapData: _heatmapData,
      );

      _predictiveInsights = insights;

      if (kDebugMode) {
        print('🔮 Generated ${_predictiveInsights.length} predictive insights');
      }
    } catch (e) {
      _setError('Failed to generate predictive insights: $e');
    } finally {
      _isLoadingInsights = false;
      notifyListeners();
    }
  }

  /// Analyze habit patterns
  Future<void> analyzeHabitPatterns({
    required List<Habit> habits,
    required bool isPremium,
  }) async {
    if (!isPremium) {
      _setError('Pattern analysis is a Premium feature');
      return;
    }

    _isLoadingPatterns = true;
    _clearError();
    notifyListeners();

    try {
      final patterns = <HabitPattern>[];

      for (final habit in habits) {
        // Analyze weekly patterns
        final weeklyPattern = await _analyzeWeeklyPattern(habit);
        if (weeklyPattern != null) patterns.add(weeklyPattern);

        // Analyze daily rhythm patterns
        final dailyPattern = await _analyzeDailyRhythm(habit);
        if (dailyPattern != null) patterns.add(dailyPattern);

        // Analyze streak patterns
        final streakPattern = await _analyzeStreakPattern(habit);
        if (streakPattern != null) patterns.add(streakPattern);
      }

      _habitPatterns = patterns;

      if (kDebugMode) {
        print('🔍 Analyzed ${_habitPatterns.length} habit patterns');
      }
    } catch (e) {
      _setError('Failed to analyze habit patterns: $e');
    } finally {
      _isLoadingPatterns = false;
      notifyListeners();
    }
  }

  /// Analyze weekly completion patterns for a habit
  Future<HabitPattern?> _analyzeWeeklyPattern(Habit habit) async {
    try {
      final weeklyStats = await _databaseService.getWeeklyCompletionStats(
        habit.id!,
      );

      if (weeklyStats.isEmpty) return null;

      // Calculate pattern strength and identify best/worst days
      final sortedDays = weeklyStats.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final bestDay = sortedDays.first;
      final worstDay = sortedDays.last;

      final strength = _calculatePatternStrength(weeklyStats.values.toList());

      if (strength < 0.3) return null; // Pattern not strong enough

      return HabitPattern(
        habitId: habit.id.toString(),
        habitName: habit.name,
        patternType: 'weekly_cycle',
        description:
            'Best on ${_getDayName(bestDay.key)}, challenging on ${_getDayName(worstDay.key)}',
        metrics: {
          'best_day': bestDay.key,
          'best_day_rate': bestDay.value,
          'worst_day': worstDay.key,
          'worst_day_rate': worstDay.value,
        },
        strength: strength,
      );
    } catch (e) {
      if (kDebugMode) print('Error analyzing weekly pattern: $e');
      return null;
    }
  }

  /// Analyze daily rhythm patterns
  Future<HabitPattern?> _analyzeDailyRhythm(Habit habit) async {
    try {
      final hourlyStats = await _databaseService.getHourlyCompletionStats(
        habit.id!,
      );

      if (hourlyStats.isEmpty) return null;

      final sortedHours = hourlyStats.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final bestHour = sortedHours.first;
      final strength = _calculatePatternStrength(hourlyStats.values.toList());

      if (strength < 0.4) return null;

      String timeCategory;
      if (bestHour.key < 6) {
        timeCategory = 'early morning';
      } else if (bestHour.key < 12) {
        timeCategory = 'morning';
      } else if (bestHour.key < 18) {
        timeCategory = 'afternoon';
      } else {
        timeCategory = 'evening';
      }

      return HabitPattern(
        habitId: habit.id.toString(),
        habitName: habit.name,
        patternType: 'daily_rhythm',
        description:
            'Most successful in the $timeCategory (${_formatHour(bestHour.key)})',
        metrics: {
          'best_hour': bestHour.key,
          'best_hour_rate': bestHour.value,
          'time_category': timeCategory,
        },
        strength: strength,
      );
    } catch (e) {
      if (kDebugMode) print('Error analyzing daily rhythm: $e');
      return null;
    }
  }

  /// Analyze streak building patterns
  Future<HabitPattern?> _analyzeStreakPattern(Habit habit) async {
    try {
      final streakData = await _databaseService.getStreakAnalysis(habit.id!);

      if (streakData.isEmpty) return null;

      final averageStreak = streakData['average_streak'] ?? 0.0;
      final longestStreak = streakData['longest_streak'] ?? 0;
      final streakConsistency = streakData['consistency'] ?? 0.0;

      String description;
      String patternType;

      if (streakConsistency > 0.7) {
        patternType = 'streak_building';
        description =
            'Strong streak builder (avg ${averageStreak.toStringAsFixed(1)} days)';
      } else if (streakConsistency < 0.3) {
        patternType = 'decline_risk';
        description = 'Streak maintenance needs attention';
      } else {
        patternType = 'streak_building';
        description = 'Moderate streak consistency';
      }

      return HabitPattern(
        habitId: habit.id.toString(),
        habitName: habit.name,
        patternType: patternType,
        description: description,
        metrics: {
          'average_streak': averageStreak,
          'longest_streak': longestStreak,
          'consistency': streakConsistency,
        },
        strength: streakConsistency,
      );
    } catch (e) {
      if (kDebugMode) print('Error analyzing streak pattern: $e');
      return null;
    }
  }

  /// Calculate pattern strength from a list of values
  double _calculatePatternStrength(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length;
    final standardDeviation = sqrt(variance);

    // Higher variation = stronger pattern (when it matters)
    return (standardDeviation / (mean + 1)).clamp(0.0, 1.0);
  }

  /// Get day name from day number (1 = Monday)
  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  /// Format hour in 12-hour format
  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  /// Get heatmap data for a specific date range
  List<HeatmapData> getHeatmapDataForRange(DateTime start, DateTime end) {
    return _heatmapData.where((data) {
      return data.date.isAfter(start.subtract(const Duration(days: 1))) &&
          data.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get patterns for a specific habit
  List<HabitPattern> getPatternsForHabit(String habitId) {
    return _habitPatterns
        .where((pattern) => pattern.habitId == habitId)
        .toList();
  }

  /// Get insights by type
  List<PredictiveInsight> getInsightsByType(String type) {
    return _predictiveInsights
        .where((insight) => insight.type == type)
        .toList();
  }

  /// Load all advanced analytics data
  Future<void> loadAllAnalytics({
    required List<Habit> habits,
    required bool isPremium,
  }) async {
    await Future.wait([
      loadHeatmapData(),
      if (isPremium) ...[
        generatePredictiveInsights(habits: habits, isPremium: isPremium),
        analyzeHabitPatterns(habits: habits, isPremium: isPremium),
      ],
    ]);
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// Clear all data (useful for testing or user logout)
  void clear() {
    _heatmapData.clear();
    _predictiveInsights.clear();
    _habitPatterns.clear();
    _clearError();
    notifyListeners();
  }
}
