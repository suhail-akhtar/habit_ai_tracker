import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../models/habit.dart';

/// AI-powered habit assistant service for advanced features
class AIHabitAssistantService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Generate personalized habit suggestions based on user goals
  Future<List<HabitSuggestion>> generateHabitSuggestions({
    required String userGoal,
    required List<Habit> existingHabits,
    required String userLevel, // beginner, intermediate, advanced
  }) async {
    try {
      final prompt = _buildHabitSuggestionPrompt(
        userGoal,
        existingHabits,
        userLevel,
      );
      final response = await _callGeminiAPI(prompt);
      return _parseHabitSuggestions(response);
    } catch (e) {
      print('Error generating habit suggestions: $e');
      return _getFallbackSuggestions(userGoal);
    }
  }

  /// Generate personalized habit streak motivation
  Future<String> generateStreakMotivation({
    required Habit habit,
    required int currentStreak,
    required int longestStreak,
  }) async {
    try {
      final prompt =
          '''
      Generate a personalized, encouraging message for a user with:
      - Habit: ${habit.name}
      - Current streak: $currentStreak days
      - Longest streak: $longestStreak days
      
      Make it motivating, personal, and under 100 words. Include an emoji.
      ''';

      return await _callGeminiAPI(prompt);
    } catch (e) {
      return _getFallbackMotivation(currentStreak);
    }
  }

  /// Analyze habit completion patterns and provide insights
  Future<HabitInsight> analyzeHabitPattern({
    required Habit habit,
    required List<DateTime> completionDates,
    required int totalDays,
  }) async {
    try {
      final completionRate = (completionDates.length / totalDays * 100).round();
      final weekdayPattern = _analyzeWeekdayPattern(completionDates);

      final prompt =
          '''
      Analyze this habit completion pattern:
      - Habit: ${habit.name}
      - Completion rate: $completionRate%
      - Total days tracked: $totalDays
      - Weekday pattern: $weekdayPattern
      
      Provide actionable insights and suggestions for improvement in JSON format:
      {
        "insight": "main insight about the pattern",
        "suggestions": ["suggestion1", "suggestion2"],
        "strengths": ["strength1", "strength2"],
        "areas_for_improvement": ["area1", "area2"]
      }
      ''';

      final response = await _callGeminiAPI(prompt);
      return _parseHabitInsight(response);
    } catch (e) {
      return HabitInsight.fallback(habit.name);
    }
  }

  /// Generate smart habit stacking suggestions
  Future<List<HabitStackSuggestion>> generateHabitStacks({
    required List<Habit> userHabits,
    required String newHabitCategory,
  }) async {
    try {
      final existingHabitsText = userHabits
          .map((h) => '${h.name} (${h.category})')
          .join(', ');

      final prompt =
          '''
      The user wants to add a new $newHabitCategory habit. 
      Their existing habits: $existingHabitsText
      
      Suggest 3 habit stack combinations where the new habit can be paired with existing ones.
      Format: JSON array with objects containing "anchor_habit", "new_habit", "trigger", "benefit"
      ''';

      final response = await _callGeminiAPI(prompt);
      return _parseHabitStacks(response);
    } catch (e) {
      return _getFallbackStacks(newHabitCategory);
    }
  }

  /// Generate weekly habit challenges
  Future<WeeklyChallenge> generateWeeklyChallenge({
    required List<Habit> userHabits,
    required String focusArea,
  }) async {
    try {
      final prompt =
          '''
      Create a personalized weekly challenge for a user focused on: $focusArea
      Their current habits: ${userHabits.map((h) => h.name).join(', ')}
      
      Generate a challenge that:
      1. Builds on existing habits
      2. Is achievable but slightly challenging
      3. Has clear daily actions
      4. Includes a reward/celebration
      
      Format as JSON with: title, description, daily_actions[], reward, difficulty_level
      ''';

      final response = await _callGeminiAPI(prompt);
      return _parseWeeklyChallenge(response);
    } catch (e) {
      return WeeklyChallenge.fallback(focusArea);
    }
  }

  /// Smart notification messages based on time and context
  Future<String> generateSmartNotification({
    required Habit habit,
    required TimeOfDay timeOfDay,
    required String weather,
    required int missedDays,
  }) async {
    try {
      final timeContext = _getTimeContext(timeOfDay);

      final prompt =
          '''
      Generate a smart, contextual notification for:
      - Habit: ${habit.name}
      - Time: $timeContext
      - Weather: $weather
      - Missed days: $missedDays
      
      Make it personal, motivating, and under 50 words. Consider the time and weather context.
      ''';

      return await _callGeminiAPI(prompt);
    } catch (e) {
      return 'Time for ${habit.name}! You\'ve got this! 💪';
    }
  }

  // Private helper methods
  Future<String> _callGeminiAPI(String prompt) async {
    final url = Uri.parse(
      '$_baseUrl/gemini-1.5-flash-latest:generateContent?key=${Environment.geminiApiKey}',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw Exception('API call failed: ${response.statusCode}');
    }
  }

  String _buildHabitSuggestionPrompt(
    String userGoal,
    List<Habit> existingHabits,
    String userLevel,
  ) {
    final existingHabitsText = existingHabits.isEmpty
        ? 'No existing habits'
        : existingHabits.map((h) => h.name).join(', ');

    return '''
    Generate 5 specific, actionable habit suggestions for someone who wants to: $userGoal
    
    User level: $userLevel
    Existing habits: $existingHabitsText
    
    For each suggestion, provide:
    1. Habit name (specific and actionable)
    2. Category (Health, Productivity, Learning, Mindfulness, Exercise, Other)
    3. Difficulty (Easy, Medium, Hard)
    4. Estimated time commitment
    5. Why it helps achieve the goal
    
    Make suggestions that complement existing habits and are appropriate for the user level.
    Format as JSON array.
    ''';
  }

  List<HabitSuggestion> _parseHabitSuggestions(String response) {
    try {
      // Extract JSON from response if it's wrapped in markdown
      final jsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(response);
      if (jsonMatch != null) {
        final jsonArray = jsonDecode(jsonMatch.group(0)!);
        return (jsonArray as List)
            .map((item) => HabitSuggestion.fromJson(item))
            .toList();
      }
    } catch (e) {
      print('Error parsing habit suggestions: $e');
    }
    return [];
  }

  List<HabitSuggestion> _getFallbackSuggestions(String userGoal) {
    // Provide smart fallbacks based on common goals
    if (userGoal.toLowerCase().contains('health') ||
        userGoal.toLowerCase().contains('fitness')) {
      return [
        HabitSuggestion(
          name: 'Morning Walk',
          category: 'Exercise',
          difficulty: 'Easy',
          timeCommitment: '15 minutes',
          benefit: 'Boosts energy and metabolism',
        ),
        HabitSuggestion(
          name: 'Drink Water',
          category: 'Health',
          difficulty: 'Easy',
          timeCommitment: '2 minutes',
          benefit: 'Improves hydration and focus',
        ),
      ];
    }
    return [
      HabitSuggestion(
        name: 'Daily Planning',
        category: 'Productivity',
        difficulty: 'Easy',
        timeCommitment: '10 minutes',
        benefit: 'Increases daily focus and achievement',
      ),
    ];
  }

  String _getFallbackMotivation(int currentStreak) {
    if (currentStreak == 0) {
      return "Fresh start, fresh possibilities! Today is day one of your next streak. 🌱";
    } else if (currentStreak < 7) {
      return "You're building momentum! $currentStreak days strong and counting. Keep the fire burning! 🔥";
    } else {
      return "Incredible dedication! $currentStreak days of consistent action. You're unstoppable! ⚡";
    }
  }

  Map<String, int> _analyzeWeekdayPattern(List<DateTime> completionDates) {
    final weekdayCounts = <String, int>{};
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    for (final date in completionDates) {
      final weekday = weekdays[date.weekday - 1];
      weekdayCounts[weekday] = (weekdayCounts[weekday] ?? 0) + 1;
    }

    return weekdayCounts;
  }

  HabitInsight _parseHabitInsight(String response) {
    try {
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(response);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!);
        return HabitInsight.fromJson(json);
      }
    } catch (e) {
      print('Error parsing habit insight: $e');
    }
    return HabitInsight.fallback('your habit');
  }

  List<HabitStackSuggestion> _parseHabitStacks(String response) {
    // Implementation for parsing habit stack suggestions
    return [];
  }

  List<HabitStackSuggestion> _getFallbackStacks(String category) {
    // Fallback habit stacking suggestions
    return [];
  }

  WeeklyChallenge _parseWeeklyChallenge(String response) {
    try {
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(response);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!);
        return WeeklyChallenge.fromJson(json);
      }
    } catch (e) {
      print('Error parsing weekly challenge: $e');
    }
    return WeeklyChallenge.fallback('general improvement');
  }

  String _getTimeContext(TimeOfDay timeOfDay) {
    final hour = timeOfDay.hour;
    if (hour < 6) return 'early morning';
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    if (hour < 21) return 'evening';
    return 'night';
  }
}

// Data classes for AI responses
class HabitSuggestion {
  final String name;
  final String category;
  final String difficulty;
  final String timeCommitment;
  final String benefit;

  HabitSuggestion({
    required this.name,
    required this.category,
    required this.difficulty,
    required this.timeCommitment,
    required this.benefit,
  });

  factory HabitSuggestion.fromJson(Map<String, dynamic> json) {
    return HabitSuggestion(
      name: json['name'] ?? '',
      category: json['category'] ?? 'Other',
      difficulty: json['difficulty'] ?? 'Medium',
      timeCommitment: json['time_commitment'] ?? '10 minutes',
      benefit: json['benefit'] ?? 'Helps achieve your goals',
    );
  }
}

class HabitInsight {
  final String insight;
  final List<String> suggestions;
  final List<String> strengths;
  final List<String> areasForImprovement;

  HabitInsight({
    required this.insight,
    required this.suggestions,
    required this.strengths,
    required this.areasForImprovement,
  });

  factory HabitInsight.fromJson(Map<String, dynamic> json) {
    return HabitInsight(
      insight: json['insight'] ?? '',
      suggestions: List<String>.from(json['suggestions'] ?? []),
      strengths: List<String>.from(json['strengths'] ?? []),
      areasForImprovement: List<String>.from(
        json['areas_for_improvement'] ?? [],
      ),
    );
  }

  factory HabitInsight.fallback(String habitName) {
    return HabitInsight(
      insight: 'Your $habitName habit shows potential for growth!',
      suggestions: [
        'Try setting a specific time each day',
        'Track your progress visually',
      ],
      strengths: [
        'You\'ve started tracking',
        'You\'re committed to improvement',
      ],
      areasForImprovement: ['Consistency', 'Setting specific triggers'],
    );
  }
}

class HabitStackSuggestion {
  final String anchorHabit;
  final String newHabit;
  final String trigger;
  final String benefit;

  HabitStackSuggestion({
    required this.anchorHabit,
    required this.newHabit,
    required this.trigger,
    required this.benefit,
  });
}

class WeeklyChallenge {
  final String title;
  final String description;
  final List<String> dailyActions;
  final String reward;
  final String difficultyLevel;

  WeeklyChallenge({
    required this.title,
    required this.description,
    required this.dailyActions,
    required this.reward,
    required this.difficultyLevel,
  });

  factory WeeklyChallenge.fromJson(Map<String, dynamic> json) {
    return WeeklyChallenge(
      title: json['title'] ?? 'Weekly Challenge',
      description:
          json['description'] ?? 'Complete daily actions to build momentum',
      dailyActions: List<String>.from(json['daily_actions'] ?? []),
      reward: json['reward'] ?? 'Celebrate your progress!',
      difficultyLevel: json['difficulty_level'] ?? 'Medium',
    );
  }

  factory WeeklyChallenge.fallback(String focusArea) {
    return WeeklyChallenge(
      title: 'Focus on $focusArea',
      description: 'A week of intentional progress in $focusArea',
      dailyActions: [
        'Take one small action toward $focusArea',
        'Reflect on your progress',
      ],
      reward: 'Treat yourself to something you enjoy!',
      difficultyLevel: 'Medium',
    );
  }
}
