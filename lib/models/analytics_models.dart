import 'package:flutter/material.dart';

/// Model for habit completion heatmap data
class HeatmapData {
  final DateTime date;
  final int completedHabits;
  final int totalHabits;
  final double completionRate;

  const HeatmapData({
    required this.date,
    required this.completedHabits,
    required this.totalHabits,
    required this.completionRate,
  });

  /// Get intensity level for heatmap coloring (0.0 to 1.0)
  double get intensity => totalHabits > 0 ? completionRate / 100 : 0.0;

  /// Get color for heatmap cell based on completion rate
  Color getHeatmapColor(ColorScheme colorScheme) {
    if (totalHabits == 0) {
      return colorScheme.surfaceContainerHighest;
    }

    final baseColor = colorScheme.primary;
    final alpha = (intensity * 255).round().clamp(50, 255);

    return baseColor.withAlpha(alpha);
  }

  factory HeatmapData.fromMap(Map<String, dynamic> map) => HeatmapData(
    date: DateTime.parse(map['date']),
    completedHabits: map['completed_habits'] ?? 0,
    totalHabits: map['total_habits'] ?? 0,
    completionRate: (map['completion_rate'] ?? 0.0).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'completed_habits': completedHabits,
    'total_habits': totalHabits,
    'completion_rate': completionRate,
  };

  /// Get color for heatmap visualization based on completion rate
  Color getColor(Color baseColor) {
    if (totalHabits == 0) {
      return baseColor.withOpacity(0.05); // Very light for no data
    }

    // Clamp intensity between 0.1 and 1.0 for better visibility
    final intensity = (completionRate * 0.9 + 0.1).clamp(0.1, 1.0);
    return Color.lerp(baseColor.withOpacity(0.1), baseColor, intensity) ??
        baseColor;
  }

  @override
  String toString() => 'HeatmapData(date: $date, rate: $completionRate%)';
}

/// Model for predictive analytics insights
class PredictiveInsight {
  final String type;
  final String title;
  final String description;
  final double confidence;
  final Map<String, dynamic> data;
  final DateTime generatedAt;

  const PredictiveInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.confidence,
    this.data = const {},
    required this.generatedAt,
  });

  factory PredictiveInsight.fromMap(Map<String, dynamic> map) =>
      PredictiveInsight(
        type: map['type'],
        title: map['title'],
        description: map['description'],
        confidence: (map['confidence'] ?? 0.0).toDouble(),
        data: Map<String, dynamic>.from(map['data'] ?? {}),
        generatedAt: DateTime.parse(map['generated_at']),
      );

  Map<String, dynamic> toMap() => {
    'type': type,
    'title': title,
    'description': description,
    'confidence': confidence,
    'data': data,
    'generated_at': generatedAt.toIso8601String(),
  };

  /// Get icon for insight type
  IconData get icon {
    switch (type) {
      case 'streak_prediction':
        return Icons.local_fire_department;
      case 'best_time':
        return Icons.access_time;
      case 'habit_retention':
        return Icons.trending_up;
      case 'difficulty_prediction':
        return Icons.psychology;
      case 'pattern_detection':
        return Icons.pattern;
      default:
        return Icons.insights;
    }
  }

  /// Get color for insight based on confidence
  Color getConfidenceColor() {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  @override
  String toString() =>
      'PredictiveInsight(type: $type, confidence: $confidence)';
}

/// Model for habit pattern analysis
class HabitPattern {
  final String habitId;
  final String habitName;
  final String patternType;
  final String description;
  final Map<String, dynamic> metrics;
  final double strength; // 0.0 to 1.0

  const HabitPattern({
    required this.habitId,
    required this.habitName,
    required this.patternType,
    required this.description,
    this.metrics = const {},
    required this.strength,
  });

  factory HabitPattern.fromMap(Map<String, dynamic> map) => HabitPattern(
    habitId: map['habit_id'],
    habitName: map['habit_name'],
    patternType: map['pattern_type'],
    description: map['description'],
    metrics: Map<String, dynamic>.from(map['metrics'] ?? {}),
    strength: (map['strength'] ?? 0.0).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'habit_id': habitId,
    'habit_name': habitName,
    'pattern_type': patternType,
    'description': description,
    'metrics': metrics,
    'strength': strength,
  };

  /// Get icon for pattern type
  IconData get icon {
    switch (patternType) {
      case 'weekly_cycle':
        return Icons.calendar_view_week;
      case 'daily_rhythm':
        return Icons.schedule;
      case 'streak_building':
        return Icons.trending_up;
      case 'decline_risk':
        return Icons.trending_down;
      case 'seasonal':
        return Icons.wb_sunny;
      default:
        return Icons.pattern;
    }
  }

  /// Get color for pattern strength
  Color getStrengthColor() {
    if (strength >= 0.7) return Colors.green;
    if (strength >= 0.4) return Colors.orange;
    return Colors.red;
  }

  @override
  String toString() => 'HabitPattern(habit: $habitName, type: $patternType)';
}
