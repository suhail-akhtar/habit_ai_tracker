import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../models/ai_insight.dart';

class AnalyticsProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final GeminiService _geminiService = GeminiService();

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
      // Check if we have a cached insight
      final cachedInsight =
          await _databaseService.getAIInsight('user', 'weekly_summary');

      if (cachedInsight != null && !cachedInsight.isExpired) {
        _weeklyInsight = cachedInsight.content;
        return;
      }

      // Generate new insight
      _weeklyInsight = await _geminiService.generateWeeklyInsight(_analytics);

      // Cache the insight
      final insight = AIInsight(
        userId: 'user',
        insightType: 'weekly_summary',
        content: _weeklyInsight!,
        dataHash: _generateDataHash(_analytics),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );

      await _databaseService.saveAIInsight(insight);
    } catch (e) {
      print('Failed to load weekly insight: $e');
      _weeklyInsight =
          'Keep up the great work! Every small step counts towards building lasting habits.';
    }
  }

  String _generateDataHash(Map<String, dynamic> data) {
    // Simple hash generation for caching
    return data.toString().hashCode.toString();
  }

  Future<void> refreshInsight() async {
    _setLoading(true);
    try {
      _weeklyInsight = await _geminiService.generateWeeklyInsight(_analytics);

      // Update cache
      final insight = AIInsight(
        userId: 'user',
        insightType: 'weekly_summary',
        content: _weeklyInsight!,
        dataHash: _generateDataHash(_analytics),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );

      await _databaseService.saveAIInsight(insight);
      _clearError();
    } catch (e) {
      _setError('Failed to refresh insight: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<String> getDailyTip() async {
    return await _geminiService.generateDailyTip();
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
