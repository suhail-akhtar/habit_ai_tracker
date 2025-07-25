class VoiceReminder {
  final int? id;
  final String message;
  final DateTime reminderTime;
  final List<int> habitIds;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VoiceReminder({
    this.id,
    required this.message,
    required this.reminderTime,
    this.habitIds = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'message': message,
    'reminder_time': reminderTime.toIso8601String(),
    'habit_ids': habitIds.join(','),
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory VoiceReminder.fromMap(Map<String, dynamic> map) => VoiceReminder(
    id: map['id'],
    message: map['message'],
    reminderTime: DateTime.parse(map['reminder_time']),
    habitIds: map['habit_ids'] != null && map['habit_ids'].isNotEmpty
        ? map['habit_ids']
              .toString()
              .split(',')
              .map<int>((e) => int.parse(e))
              .toList()
        : [],
    isActive: (map['is_active'] ?? 1) == 1,
    createdAt: DateTime.parse(map['created_at']),
    updatedAt: DateTime.parse(map['updated_at']),
  );

  VoiceReminder copyWith({
    int? id,
    String? message,
    DateTime? reminderTime,
    List<int>? habitIds,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => VoiceReminder(
    id: id ?? this.id,
    message: message ?? this.message,
    reminderTime: reminderTime ?? this.reminderTime,
    habitIds: habitIds ?? this.habitIds,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  String toString() =>
      'VoiceReminder(id: $id, message: $message, time: $reminderTime)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceReminder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
