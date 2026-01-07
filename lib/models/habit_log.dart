class HabitLog {
  final int? id;
  final int habitId;
  final DateTime completedAt;
  final String? note;
  final String inputMethod;
  final int? moodRating;
  final String status;

  HabitLog({
    this.id,
    required this.habitId,
    required this.completedAt,
    this.note,
    required this.inputMethod,
    this.moodRating,
    this.status = 'completed',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'habit_id': habitId,
        'completed_at': completedAt.toIso8601String(),
        'note': note,
        'input_method': inputMethod,
        'mood_rating': moodRating,
        'status': status,
      };

  factory HabitLog.fromMap(Map<String, dynamic> map) => HabitLog(
        id: map['id'],
        habitId: map['habit_id'],
        completedAt: DateTime.parse(map['completed_at']),
        note: map['note'],
        inputMethod: map['input_method'],
        moodRating: map['mood_rating'],
        status: map['status'] ?? 'completed',
      );

  HabitLog copyWith({
    int? id,
    int? habitId,
    DateTime? completedAt,
    String? note,
    String? inputMethod,
    int? moodRating,
    String? status,
  }) =>
      HabitLog(
        id: id ?? this.id,
        habitId: habitId ?? this.habitId,
        completedAt: completedAt ?? this.completedAt,
        note: note ?? this.note,
        inputMethod: inputMethod ?? this.inputMethod,
        moodRating: moodRating ?? this.moodRating,
        status: status ?? this.status,
      );

  @override
  String toString() =>
      'HabitLog(id: $id, habitId: $habitId, completedAt: $completedAt)';
}
