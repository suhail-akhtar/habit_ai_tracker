class HabitDaySummary {
  final DateTime date;
  final bool isDue;
  final int completedCount;
  final bool isSkipped;
  final bool isTargetMet;

  const HabitDaySummary({
    required this.date,
    required this.isDue,
    required this.completedCount,
    required this.isSkipped,
    required this.isTargetMet,
  });
}

class HabitReport {
  final int habitId;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  final int dueDays;
  final int completedDays;
  final int skippedDays;
  final int missedDays;

  final int totalCompletions;
  final DateTime? lastCompletedAt;

  final int currentStreak;
  final int bestStreak;

  final List<HabitDaySummary> days;

  const HabitReport({
    required this.habitId,
    required this.rangeStart,
    required this.rangeEnd,
    required this.dueDays,
    required this.completedDays,
    required this.skippedDays,
    required this.missedDays,
    required this.totalCompletions,
    required this.lastCompletedAt,
    required this.currentStreak,
    required this.bestStreak,
    required this.days,
  });

  double get completionRate {
    if (dueDays <= 0) return 0;
    return completedDays / dueDays;
  }

  double get adherenceRate {
    if (dueDays <= 0) return 0;
    return (completedDays + skippedDays) / dueDays;
  }
}
