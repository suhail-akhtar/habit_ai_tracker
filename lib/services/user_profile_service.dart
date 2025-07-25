import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../services/database_service.dart';

/// Comprehensive user profile and analytics service for AI personalization
class UserProfileService {
  final DatabaseService _databaseService = DatabaseService();

  /// Get comprehensive user analytics for AI context
  Future<UserAIProfile> getUserAIProfile(List<Habit> habits) async {
    try {
      final now = DateTime.now();
      final last7Days = now.subtract(const Duration(days: 7));
      final last30Days = now.subtract(const Duration(days: 30));

      // Get habit completion data
      final completionData = await _getHabitCompletionAnalytics(habits);

      // Analyze user patterns
      final patterns = await _analyzeUserPatterns(habits, last30Days);

      // Get engagement metrics
      final engagement = await _getEngagementMetrics(last30Days);

      // Determine user personality traits
      final personality = _analyzePersonalityTraits(completionData, patterns);

      // Get current struggles and strengths
      final insights = _generateUserInsights(completionData, patterns);

      return UserAIProfile(
        totalHabits: habits.length,
        activeHabits: habits.where((h) => h.isActive).length,
        completionData: completionData,
        patterns: patterns,
        engagement: engagement,
        personality: personality,
        insights: insights,
        lastUpdated: now,
      );
    } catch (e) {
      if (kDebugMode) {
        print('🤖 UserProfileService: ❌ Failed to generate AI profile: $e');
      }
      return _getFallbackProfile(habits);
    }
  }

  /// Get detailed habit completion analytics
  Future<HabitCompletionData> _getHabitCompletionAnalytics(
    List<Habit> habits,
  ) async {
    final now = DateTime.now();
    final last7Days = now.subtract(const Duration(days: 7));
    final last30Days = now.subtract(const Duration(days: 30));

    int totalCompletions7Days = 0;
    int totalCompletions30Days = 0;
    int totalPossible7Days = 0;
    int totalPossible30Days = 0;
    int currentStreak = 0;
    int bestStreak = 0;
    Map<String, int> categoryPerformance = {};
    List<HabitPerformance> habitPerformances = [];

    for (final habit in habits) {
      if (habit.id == null) continue; // Skip habits without ID

      // Get habit logs for analysis
      final logs = await _databaseService.getHabitLogs(habit.id!);

      // Calculate streaks
      final habitStreak = _calculateCurrentStreak(logs);
      final habitBestStreak = _calculateBestStreak(logs);

      currentStreak += habitStreak;
      bestStreak = bestStreak > habitBestStreak ? bestStreak : habitBestStreak;

      // Calculate completions in time periods (HabitLog uses completedAt DateTime)
      final completions7 = logs
          .where((log) => log.completedAt.isAfter(last7Days))
          .length;
      final completions30 = logs
          .where((log) => log.completedAt.isAfter(last30Days))
          .length;

      totalCompletions7Days += completions7;
      totalCompletions30Days += completions30;
      totalPossible7Days += 7; // Assuming daily habits
      totalPossible30Days += 30;

      // Category performance
      final category = habit.category;
      categoryPerformance[category] =
          (categoryPerformance[category] ?? 0) + completions30;

      // Individual habit performance
      habitPerformances.add(
        HabitPerformance(
          habitId: habit.id!,
          habitName: habit.name,
          category: category,
          completionRate7Days: completions7 / 7.0,
          completionRate30Days: completions30 / 30.0,
          currentStreak: habitStreak,
          bestStreak: habitBestStreak,
          difficulty: _assessHabitDifficulty(logs),
          consistency: _calculateConsistency(logs),
        ),
      );
    }

    return HabitCompletionData(
      completionRate7Days: totalPossible7Days > 0
          ? totalCompletions7Days / totalPossible7Days
          : 0.0,
      completionRate30Days: totalPossible30Days > 0
          ? totalCompletions30Days / totalPossible30Days
          : 0.0,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      categoryPerformance: categoryPerformance,
      habitPerformances: habitPerformances,
      totalCompletions: totalCompletions30Days,
    );
  }

  /// Analyze user behavioral patterns
  Future<UserPatterns> _analyzeUserPatterns(
    List<Habit> habits,
    DateTime since,
  ) async {
    Map<int, double> weekdayPerformance = {};
    Map<int, double> hourlyPerformance = {};
    List<String> strugglingAreas = [];
    List<String> strongAreas = [];
    double motivation = 0.7; // Default

    // Analyze completion patterns by day of week and time
    for (final habit in habits) {
      if (habit.id == null) continue;

      final logs = await _databaseService.getHabitLogs(habit.id!);
      final recentLogs = logs
          .where((log) => log.completedAt.isAfter(since))
          .toList();

      for (final log in recentLogs) {
        final weekday = log.completedAt.weekday;
        final hour = log.completedAt.hour;

        // Since HabitLog exists, it means the habit was completed
        weekdayPerformance[weekday] =
            (weekdayPerformance[weekday] ?? 0.0) + 1.0;
        hourlyPerformance[hour] = (hourlyPerformance[hour] ?? 0.0) + 1.0;
      }
    }

    // Normalize performance data
    final totalCompletions = weekdayPerformance.values.fold(
      0.0,
      (a, b) => a + b,
    );
    if (totalCompletions > 0) {
      weekdayPerformance.updateAll((key, value) => value / totalCompletions);
      hourlyPerformance.updateAll((key, value) => value / totalCompletions);
    }

    // Determine struggling and strong areas
    final categoryPerformance = <String, double>{};
    for (final habit in habits) {
      if (habit.id == null) continue;

      final category = habit.category;
      final logs = await _databaseService.getHabitLogs(habit.id!);
      final recentLogs = logs
          .where((log) => log.completedAt.isAfter(since))
          .toList();
      final completionRate = recentLogs.length / 30.0; // Rough estimation

      categoryPerformance[category] =
          (categoryPerformance[category] ?? 0.0) + completionRate;
    }

    categoryPerformance.forEach((category, rate) {
      if (rate < 0.4) {
        strugglingAreas.add(category);
      } else if (rate > 0.7) {
        strongAreas.add(category);
      }
    });

    // Calculate motivation level based on recent performance
    final recentRate = categoryPerformance.values.isEmpty
        ? 0.5
        : categoryPerformance.values.reduce((a, b) => a + b) /
              categoryPerformance.length;
    motivation = recentRate.clamp(0.0, 1.0);

    return UserPatterns(
      weekdayPerformance: weekdayPerformance,
      hourlyPerformance: hourlyPerformance,
      strugglingAreas: strugglingAreas,
      strongAreas: strongAreas,
      preferredCompletionTimes: _getPreferredTimes(hourlyPerformance),
      motivationLevel: motivation,
    );
  }

  /// Get user engagement metrics
  Future<EngagementMetrics> _getEngagementMetrics(DateTime since) async {
    // This would integrate with app usage analytics
    // For now, we'll create a basic implementation
    return EngagementMetrics(
      dailyOpenCount: 3.5, // Average opens per day
      sessionDuration: const Duration(minutes: 8),
      voiceCommandUsage: 12, // Times used in last 30 days
      notificationResponseRate: 0.75,
      featureUsage: {
        'voice_input': 0.8,
        'manual_logging': 0.6,
        'analytics': 0.3,
        'ai_chat': 0.4,
      },
    );
  }

  /// Analyze personality traits based on behavior
  PersonalityTraits _analyzePersonalityTraits(
    HabitCompletionData completion,
    UserPatterns patterns,
  ) {
    // Determine personality based on behavior patterns
    String motivationType = 'balanced';
    if (patterns.motivationLevel > 0.8) {
      motivationType = 'self_driven';
    } else if (patterns.motivationLevel < 0.4) {
      motivationType = 'needs_support';
    }

    String consistency = 'moderate';
    final avgConsistency = completion.habitPerformances.isEmpty
        ? 0.5
        : completion.habitPerformances
                  .map((h) => h.consistency)
                  .reduce((a, b) => a + b) /
              completion.habitPerformances.length;

    if (avgConsistency > 0.7) {
      consistency = 'high';
    } else if (avgConsistency < 0.3) {
      consistency = 'low';
    }

    String responseToReminders = 'good';
    // This could be enhanced with actual notification response data

    List<String> preferredCommunication = [];
    if (patterns.motivationLevel > 0.6) {
      preferredCommunication.addAll(['encouraging', 'goal_oriented']);
    } else {
      preferredCommunication.addAll(['supportive', 'gentle']);
    }

    return PersonalityTraits(
      motivationType: motivationType,
      consistency: consistency,
      responseToReminders: responseToReminders,
      preferredCommunication: preferredCommunication,
      riskTolerance: completion.bestStreak > 7 ? 'high' : 'low',
      socialNeed: patterns.strugglingAreas.length > 2 ? 'high' : 'low',
    );
  }

  /// Generate actionable user insights
  UserInsights _generateUserInsights(
    HabitCompletionData completion,
    UserPatterns patterns,
  ) {
    List<String> currentStruggles = [];
    List<String> strengths = [];
    List<String> recommendations = [];
    String riskLevel = 'low';

    // Identify struggles
    if (completion.completionRate7Days < 0.3) {
      currentStruggles.add('Low completion rate this week');
      riskLevel = 'high';
    }

    if (patterns.strugglingAreas.isNotEmpty) {
      currentStruggles.add(
        'Struggling with ${patterns.strugglingAreas.join(", ")}',
      );
    }

    if (completion.currentStreak == 0) {
      currentStruggles.add('No active streaks');
      riskLevel = riskLevel == 'high' ? 'high' : 'medium';
    }

    // Identify strengths
    if (completion.completionRate30Days > 0.7) {
      strengths.add('Strong monthly performance');
    }

    if (patterns.strongAreas.isNotEmpty) {
      strengths.add('Excelling in ${patterns.strongAreas.join(", ")}');
    }

    if (completion.bestStreak > 7) {
      strengths.add('Capable of maintaining long streaks');
    }

    // Generate recommendations
    if (completion.completionRate7Days < completion.completionRate30Days) {
      recommendations.add(
        'Recent dip detected - refocus on your easiest habit',
      );
    }

    if (patterns.strugglingAreas.length > patterns.strongAreas.length) {
      recommendations.add(
        'Consider reducing habit load to focus on consistency',
      );
    }

    if (patterns.preferredCompletionTimes.isNotEmpty) {
      final bestTime = patterns.preferredCompletionTimes.first;
      recommendations.add(
        'Schedule more habits around $bestTime for better success',
      );
    }

    return UserInsights(
      currentStruggles: currentStruggles,
      strengths: strengths,
      recommendations: recommendations,
      riskLevel: riskLevel,
      nextMilestone: _getNextMilestone(completion),
      motivationBooster: _getMotivationBooster(patterns, completion),
    );
  }

  /// Helper methods
  int _calculateCurrentStreak(List<HabitLog> logs) {
    // Implementation for calculating current streak
    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final dayLog = logs
          .where(
            (log) =>
                log.completedAt.year == date.year &&
                log.completedAt.month == date.month &&
                log.completedAt.day == date.day,
          )
          .firstOrNull;

      if (dayLog != null) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _calculateBestStreak(List<HabitLog> logs) {
    // Implementation for calculating best streak
    int bestStreak = 0;
    int currentStreak = 0;

    final sortedLogs = logs.toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    DateTime? lastDate;
    for (final log in sortedLogs) {
      final logDate = DateTime(
        log.completedAt.year,
        log.completedAt.month,
        log.completedAt.day,
      );

      if (lastDate == null || logDate.difference(lastDate).inDays == 1) {
        currentStreak++;
        bestStreak = bestStreak > currentStreak ? bestStreak : currentStreak;
      } else if (logDate.difference(lastDate).inDays > 1) {
        currentStreak = 1;
      }
      lastDate = logDate;
    }
    return bestStreak;
  }

  String _assessHabitDifficulty(List<HabitLog> logs) {
    // Based on completion frequency - more logs means easier habit
    final logsPerWeek = logs.length / 4.0; // Rough calculation

    if (logsPerWeek > 5) return 'easy';
    if (logsPerWeek > 3) return 'moderate';
    if (logsPerWeek > 1) return 'challenging';
    return 'difficult';
  }

  double _calculateConsistency(List<HabitLog> logs) {
    if (logs.length < 7) return 0.5;

    // Calculate consistency based on how evenly distributed the logs are
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final recentLogs = logs
        .where((log) => log.completedAt.isAfter(last30Days))
        .length;

    return (recentLogs / 30.0).clamp(0.0, 1.0);
  }

  List<String> _getPreferredTimes(Map<int, double> hourlyPerformance) {
    final sortedHours = hourlyPerformance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedHours.take(3).map((entry) {
      final hour = entry.key;
      if (hour < 6) return 'early morning';
      if (hour < 12) return 'morning';
      if (hour < 18) return 'afternoon';
      return 'evening';
    }).toList();
  }

  String _getNextMilestone(HabitCompletionData completion) {
    if (completion.bestStreak < 7) return '7-day streak';
    if (completion.bestStreak < 21) return '21-day streak';
    if (completion.bestStreak < 30) return '30-day streak';
    if (completion.bestStreak < 66) return '66-day habit formation';
    return '100-day mastery';
  }

  String _getMotivationBooster(
    UserPatterns patterns,
    HabitCompletionData completion,
  ) {
    if (patterns.motivationLevel > 0.8) {
      return 'You\'re crushing it! Your consistency is inspiring.';
    } else if (patterns.motivationLevel > 0.6) {
      return 'Steady progress beats perfection. You\'re building something lasting.';
    } else {
      return 'Every small step matters. Tomorrow is a fresh start.';
    }
  }

  UserAIProfile _getFallbackProfile(List<Habit> habits) {
    return UserAIProfile(
      totalHabits: habits.length,
      activeHabits: habits.where((h) => h.isActive).length,
      completionData: HabitCompletionData(
        completionRate7Days: 0.5,
        completionRate30Days: 0.5,
        currentStreak: 0,
        bestStreak: 0,
        categoryPerformance: {},
        habitPerformances: [],
        totalCompletions: 0,
      ),
      patterns: UserPatterns(
        weekdayPerformance: {},
        hourlyPerformance: {},
        strugglingAreas: [],
        strongAreas: [],
        preferredCompletionTimes: [],
        motivationLevel: 0.5,
      ),
      engagement: EngagementMetrics(
        dailyOpenCount: 1.0,
        sessionDuration: const Duration(minutes: 5),
        voiceCommandUsage: 0,
        notificationResponseRate: 0.5,
        featureUsage: {},
      ),
      personality: PersonalityTraits(
        motivationType: 'balanced',
        consistency: 'moderate',
        responseToReminders: 'good',
        preferredCommunication: ['encouraging'],
        riskTolerance: 'medium',
        socialNeed: 'medium',
      ),
      insights: UserInsights(
        currentStruggles: ['Getting started'],
        strengths: ['Taking the first step'],
        recommendations: ['Start with one simple habit'],
        riskLevel: 'low',
        nextMilestone: '7-day streak',
        motivationBooster: 'Every journey begins with a single step!',
      ),
      lastUpdated: DateTime.now(),
    );
  }
}

/// User AI Profile Model
class UserAIProfile {
  final int totalHabits;
  final int activeHabits;
  final HabitCompletionData completionData;
  final UserPatterns patterns;
  final EngagementMetrics engagement;
  final PersonalityTraits personality;
  final UserInsights insights;
  final DateTime lastUpdated;

  UserAIProfile({
    required this.totalHabits,
    required this.activeHabits,
    required this.completionData,
    required this.patterns,
    required this.engagement,
    required this.personality,
    required this.insights,
    required this.lastUpdated,
  });
}

/// Habit Completion Data
class HabitCompletionData {
  final double completionRate7Days;
  final double completionRate30Days;
  final int currentStreak;
  final int bestStreak;
  final Map<String, int> categoryPerformance;
  final List<HabitPerformance> habitPerformances;
  final int totalCompletions;

  HabitCompletionData({
    required this.completionRate7Days,
    required this.completionRate30Days,
    required this.currentStreak,
    required this.bestStreak,
    required this.categoryPerformance,
    required this.habitPerformances,
    required this.totalCompletions,
  });
}

/// Individual Habit Performance
class HabitPerformance {
  final int habitId;
  final String habitName;
  final String category;
  final double completionRate7Days;
  final double completionRate30Days;
  final int currentStreak;
  final int bestStreak;
  final String difficulty;
  final double consistency;

  HabitPerformance({
    required this.habitId,
    required this.habitName,
    required this.category,
    required this.completionRate7Days,
    required this.completionRate30Days,
    required this.currentStreak,
    required this.bestStreak,
    required this.difficulty,
    required this.consistency,
  });
}

/// User Behavioral Patterns
class UserPatterns {
  final Map<int, double> weekdayPerformance;
  final Map<int, double> hourlyPerformance;
  final List<String> strugglingAreas;
  final List<String> strongAreas;
  final List<String> preferredCompletionTimes;
  final double motivationLevel;

  UserPatterns({
    required this.weekdayPerformance,
    required this.hourlyPerformance,
    required this.strugglingAreas,
    required this.strongAreas,
    required this.preferredCompletionTimes,
    required this.motivationLevel,
  });
}

/// Engagement Metrics
class EngagementMetrics {
  final double dailyOpenCount;
  final Duration sessionDuration;
  final int voiceCommandUsage;
  final double notificationResponseRate;
  final Map<String, double> featureUsage;

  EngagementMetrics({
    required this.dailyOpenCount,
    required this.sessionDuration,
    required this.voiceCommandUsage,
    required this.notificationResponseRate,
    required this.featureUsage,
  });
}

/// Personality Traits
class PersonalityTraits {
  final String motivationType;
  final String consistency;
  final String responseToReminders;
  final List<String> preferredCommunication;
  final String riskTolerance;
  final String socialNeed;

  PersonalityTraits({
    required this.motivationType,
    required this.consistency,
    required this.responseToReminders,
    required this.preferredCommunication,
    required this.riskTolerance,
    required this.socialNeed,
  });
}

/// User Insights
class UserInsights {
  final List<String> currentStruggles;
  final List<String> strengths;
  final List<String> recommendations;
  final String riskLevel;
  final String nextMilestone;
  final String motivationBooster;

  UserInsights({
    required this.currentStruggles,
    required this.strengths,
    required this.recommendations,
    required this.riskLevel,
    required this.nextMilestone,
    required this.motivationBooster,
  });
}
