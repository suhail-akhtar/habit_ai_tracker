import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import 'gemini_service.dart';
import 'database_service.dart';

/// AI-powered goal setting service that provides personalized habit goals
class AIGoalSettingService {
  final GeminiService _geminiService = GeminiService();
  final DatabaseService _databaseService = DatabaseService();

  /// Generate personalized goals based on user habit data
  Future<List<PersonalizedGoal>> generatePersonalizedGoals({
    required List<Habit> habits,
    required List<HabitLog> recentLogs,
    required Map<String, dynamic> analyticsData,
  }) async {
    try {
      if (kDebugMode) {
        print('🎯 AIGoalSettingService: Generating personalized goals...');
      }

      // Analyze user data to create context
      final analysisContext = await _analyzeUserData(
        habits,
        recentLogs,
        analyticsData,
      );

      // Generate AI-powered goal suggestions
      final aiGoals = await _generateAIGoals(analysisContext);

      // Add rule-based goals
      final ruleBasedGoals = _generateRuleBasedGoals(analysisContext);

      // Combine and prioritize goals
      final allGoals = [...aiGoals, ...ruleBasedGoals];

      // Sort by priority and limit to top goals
      allGoals.sort((a, b) => b.priority.compareTo(a.priority));

      if (kDebugMode) {
        print('🎯 AIGoalSettingService: Generated ${allGoals.length} goals');
      }

      return allGoals.take(5).toList(); // Return top 5 goals
    } catch (e) {
      if (kDebugMode) {
        print('🎯 AIGoalSettingService: Error generating goals: $e');
      }
      return _generateFallbackGoals();
    }
  }

  /// Analyze user data to create context for goal generation
  Future<UserAnalysisContext> _analyzeUserData(
    List<Habit> habits,
    List<HabitLog> recentLogs,
    Map<String, dynamic> analyticsData,
  ) async {
    // Calculate completion rates for each habit
    final habitStats = <String, HabitStatistics>{};

    for (final habit in habits) {
      final habitLogs = recentLogs
          .where((log) => log.habitId == habit.id)
          .toList();
      final completionRate = _calculateCompletionRate(
        habitLogs,
        30,
      ); // Last 30 days
      final currentStreak = await _databaseService.getHabitStreak(habit.id!);

      // Get best streak from streak analysis
      final streakAnalysis = await _databaseService.getStreakAnalysis(
        habit.id!,
      );
      final bestStreak = streakAnalysis['longest_streak'] ?? 0;

      habitStats[habit.id.toString()] = HabitStatistics(
        habit: habit,
        completionRate: completionRate,
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        recentLogs: habitLogs.take(7).toList(), // Last 7 days
      );
    }

    return UserAnalysisContext(
      habitStats: habitStats,
      totalHabits: habits.length,
      overallCompletionRate: analyticsData['completionRate'] ?? 0,
      totalDaysActive: analyticsData['totalDaysActive'] ?? 0,
      averageDaily: analyticsData['averageDaily'] ?? 0,
    );
  }

  /// Generate AI-powered goals using Gemini
  Future<List<PersonalizedGoal>> _generateAIGoals(
    UserAnalysisContext context,
  ) async {
    try {
      final prompt = _buildGoalGenerationPrompt(context);
      final response = await _geminiService.generateWeeklyInsight({
        'prompt': prompt,
        'context': context.toMap(),
      });

      // Parse AI response into goals
      return _parseAIGoalsResponse(response, context);
    } catch (e) {
      if (kDebugMode) {
        print('🎯 AIGoalSettingService: AI goal generation failed: $e');
      }
      return [];
    }
  }

  /// Generate rule-based goals
  List<PersonalizedGoal> _generateRuleBasedGoals(UserAnalysisContext context) {
    final goals = <PersonalizedGoal>[];

    // Goal 1: Improve weakest habit
    final weakestHabit = _findWeakestHabit(context);
    if (weakestHabit != null) {
      final currentRate = (weakestHabit.completionRate * 100).round();
      final targetRate = (currentRate + 20).clamp(0, 100);

      goals.add(
        PersonalizedGoal(
          id: 'improve_weakest',
          title: 'Boost ${weakestHabit.habit.name}',
          description:
              'Increase completion rate from $currentRate% to $targetRate% this week',
          targetValue: targetRate.toDouble(),
          currentValue: currentRate.toDouble(),
          unit: '%',
          timeframe: 'This Week',
          category: GoalCategory.improvement,
          priority: 0.8,
          habitId: weakestHabit.habit.id,
          actionSteps: [
            'Set a specific time for ${weakestHabit.habit.name}',
            'Use reminders to stay consistent',
            'Start with smaller, easier versions if needed',
          ],
        ),
      );
    }

    // Goal 2: Extend best streak
    final bestStreakHabit = _findBestStreakHabit(context);
    if (bestStreakHabit != null && bestStreakHabit.currentStreak > 0) {
      final targetStreak = bestStreakHabit.currentStreak + 7;

      goals.add(
        PersonalizedGoal(
          id: 'extend_streak',
          title: 'Extend ${bestStreakHabit.habit.name} Streak',
          description:
              'Reach a $targetStreak-day streak (currently ${bestStreakHabit.currentStreak} days)',
          targetValue: targetStreak.toDouble(),
          currentValue: bestStreakHabit.currentStreak.toDouble(),
          unit: 'days',
          timeframe: 'Next 7 Days',
          category: GoalCategory.consistency,
          priority: 0.7,
          habitId: bestStreakHabit.habit.id,
          actionSteps: [
            'Continue your current routine',
            'Plan for potential obstacles',
            'Celebrate small wins daily',
          ],
        ),
      );
    }

    // Goal 3: Overall completion rate improvement
    if (context.overallCompletionRate < 80) {
      final targetRate = (context.overallCompletionRate + 15).clamp(0, 100);

      goals.add(
        PersonalizedGoal(
          id: 'overall_completion',
          title: 'Improve Overall Consistency',
          description:
              'Reach ${targetRate.round()}% completion rate across all habits',
          targetValue: targetRate.toDouble(),
          currentValue: context.overallCompletionRate.toDouble(),
          unit: '%',
          timeframe: 'This Week',
          category: GoalCategory.consistency,
          priority: 0.6,
          actionSteps: [
            'Focus on your easiest habits first',
            'Create habit stacks (linking habits together)',
            'Track progress daily',
          ],
        ),
      );
    }

    // Goal 4: New habit suggestion
    if (context.totalHabits < 5) {
      goals.add(
        PersonalizedGoal(
          id: 'add_habit',
          title: 'Add a Complementary Habit',
          description:
              'Consider adding a new habit that complements your existing ones',
          targetValue: 1,
          currentValue: 0,
          unit: 'habit',
          timeframe: 'This Week',
          category: GoalCategory.growth,
          priority: 0.5,
          actionSteps: [
            'Choose a habit that takes less than 2 minutes',
            'Link it to an existing habit',
            'Start with just once per week',
          ],
        ),
      );
    }

    return goals;
  }

  /// Calculate completion rate for habit logs
  double _calculateCompletionRate(List<HabitLog> logs, int days) {
    if (logs.isEmpty || days <= 0) return 0.0;

    // All HabitLog entries represent completed habits
    // Calculate based on unique completion days vs target days
    final uniqueDays = logs
        .map(
          (log) => DateTime(
            log.completedAt.year,
            log.completedAt.month,
            log.completedAt.day,
          ),
        )
        .toSet()
        .length;

    return (uniqueDays / days).clamp(0.0, 1.0);
  }

  /// Find the habit with the lowest completion rate
  HabitStatistics? _findWeakestHabit(UserAnalysisContext context) {
    if (context.habitStats.isEmpty) return null;

    return context.habitStats.values.reduce(
      (a, b) => a.completionRate < b.completionRate ? a : b,
    );
  }

  /// Find the habit with the best current streak
  HabitStatistics? _findBestStreakHabit(UserAnalysisContext context) {
    if (context.habitStats.isEmpty) return null;

    return context.habitStats.values.reduce(
      (a, b) => a.currentStreak > b.currentStreak ? a : b,
    );
  }

  /// Build prompt for AI goal generation
  String _buildGoalGenerationPrompt(UserAnalysisContext context) {
    return '''
Analyze this user's habit data and suggest 2-3 personalized, achievable goals for the next week:

User Stats:
- Total habits: ${context.totalHabits}
- Overall completion rate: ${context.overallCompletionRate}%
- Days active: ${context.totalDaysActive}

Habit Performance:
${context.habitStats.entries.map((entry) => '- ${entry.value.habit.name}: ${(entry.value.completionRate * 100).round()}% completion, ${entry.value.currentStreak} day streak').join('\n')}

Generate specific, measurable goals with:
1. Clear target (e.g., "Increase water intake by 20%")
2. Realistic timeframe (this week)
3. Actionable steps

Format as JSON array:
[{"title": "Goal Title", "description": "Specific target", "actionSteps": ["step1", "step2"]}]
''';
  }

  /// Parse AI response into PersonalizedGoal objects
  List<PersonalizedGoal> _parseAIGoalsResponse(
    String response,
    UserAnalysisContext context,
  ) {
    try {
      final jsonResponse = jsonDecode(response);
      final goals = <PersonalizedGoal>[];

      if (jsonResponse is List) {
        for (int i = 0; i < jsonResponse.length && i < 3; i++) {
          final goalData = jsonResponse[i];
          if (goalData is Map<String, dynamic>) {
            goals.add(
              PersonalizedGoal(
                id: 'ai_goal_$i',
                title: goalData['title'] ?? 'AI Suggested Goal',
                description: goalData['description'] ?? '',
                targetValue: 100,
                currentValue: 50,
                unit: '%',
                timeframe: 'This Week',
                category: GoalCategory.aiSuggested,
                priority: 0.9 - (i * 0.1), // Decrease priority for later goals
                actionSteps: List<String>.from(goalData['actionSteps'] ?? []),
              ),
            );
          }
        }
      }

      return goals;
    } catch (e) {
      if (kDebugMode) {
        print('🎯 AIGoalSettingService: Failed to parse AI response: $e');
      }
      return [];
    }
  }

  /// Generate fallback goals when AI fails
  List<PersonalizedGoal> _generateFallbackGoals() {
    return [
      PersonalizedGoal(
        id: 'fallback_consistency',
        title: 'Stay Consistent',
        description: 'Complete at least 80% of your habits this week',
        targetValue: 80,
        currentValue: 60,
        unit: '%',
        timeframe: 'This Week',
        category: GoalCategory.consistency,
        priority: 0.7,
        actionSteps: [
          'Set reminders for each habit',
          'Track progress daily',
          'Celebrate small wins',
        ],
      ),
      PersonalizedGoal(
        id: 'fallback_streak',
        title: 'Build a Streak',
        description: 'Maintain a 7-day streak for your easiest habit',
        targetValue: 7,
        currentValue: 0,
        unit: 'days',
        timeframe: 'Next 7 Days',
        category: GoalCategory.consistency,
        priority: 0.6,
        actionSteps: [
          'Choose your most achievable habit',
          'Do it at the same time each day',
          'Mark it complete immediately',
        ],
      ),
    ];
  }
}

/// Context for analyzing user data
class UserAnalysisContext {
  final Map<String, HabitStatistics> habitStats;
  final int totalHabits;
  final double overallCompletionRate;
  final int totalDaysActive;
  final double averageDaily;

  UserAnalysisContext({
    required this.habitStats,
    required this.totalHabits,
    required this.overallCompletionRate,
    required this.totalDaysActive,
    required this.averageDaily,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalHabits': totalHabits,
      'overallCompletionRate': overallCompletionRate,
      'totalDaysActive': totalDaysActive,
      'averageDaily': averageDaily,
      'habitStats': habitStats.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
    };
  }
}

/// Statistics for a single habit
class HabitStatistics {
  final Habit habit;
  final double completionRate;
  final int currentStreak;
  final int bestStreak;
  final List<HabitLog> recentLogs;

  HabitStatistics({
    required this.habit,
    required this.completionRate,
    required this.currentStreak,
    required this.bestStreak,
    required this.recentLogs,
  });

  Map<String, dynamic> toMap() {
    return {
      'habitName': habit.name,
      'completionRate': completionRate,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'category': habit.category,
    };
  }
}

/// Personalized goal model
class PersonalizedGoal {
  final String id;
  final String title;
  final String description;
  final double targetValue;
  final double currentValue;
  final String unit;
  final String timeframe;
  final GoalCategory category;
  final double priority;
  final int? habitId;
  final List<String> actionSteps;

  PersonalizedGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.timeframe,
    required this.category,
    required this.priority,
    this.habitId,
    this.actionSteps = const [],
  });

  double get progressPercentage {
    if (targetValue == 0) return 0;
    return (currentValue / targetValue * 100).clamp(0, 100);
  }

  bool get isCompleted => currentValue >= targetValue;
}

/// Goal categories
enum GoalCategory { improvement, consistency, growth, aiSuggested }

extension GoalCategoryExtension on GoalCategory {
  String get displayName {
    switch (this) {
      case GoalCategory.improvement:
        return 'Improvement';
      case GoalCategory.consistency:
        return 'Consistency';
      case GoalCategory.growth:
        return 'Growth';
      case GoalCategory.aiSuggested:
        return 'AI Suggested';
    }
  }

  String get icon {
    switch (this) {
      case GoalCategory.improvement:
        return '📈';
      case GoalCategory.consistency:
        return '🎯';
      case GoalCategory.growth:
        return '🌱';
      case GoalCategory.aiSuggested:
        return '🤖';
    }
  }
}
