import 'package:flutter/material.dart';

enum NotificationType { simple, ringing, alarm }

enum RepetitionType { oneTime, daily, weekly, monthly }

class NotificationSettings {
  final int? id;
  final String title;
  final String message;
  final TimeOfDay time;
  final List<int> daysOfWeek; // 1-7, 1=Monday
  final NotificationType type;
  final RepetitionType repetition;
  final bool isEnabled;
  final List<int> habitIds; // Associated habits
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? nextScheduledTime;

  const NotificationSettings({
    this.id,
    required this.title,
    required this.message,
    required this.time,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7], // Default: all days
    this.type = NotificationType.simple,
    this.repetition = RepetitionType.daily,
    this.isEnabled = true,
    this.habitIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.nextScheduledTime,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'message': message,
    'time_hour': time.hour,
    'time_minute': time.minute,
    'days_of_week': daysOfWeek.join(','),
    'type': type.name,
    'repetition': repetition.name,
    'is_enabled': isEnabled ? 1 : 0,
    'habit_ids': habitIds.join(','),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'next_scheduled_time': nextScheduledTime?.toIso8601String(),
  };

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    final daysOfWeekStr = map['days_of_week'] as String? ?? '';
    final habitIdsStr = map['habit_ids'] as String? ?? '';

    return NotificationSettings(
      id: map['id'],
      title: map['title'],
      message: map['message'],
      time: TimeOfDay(hour: map['time_hour'], minute: map['time_minute']),
      daysOfWeek: daysOfWeekStr.isEmpty
          ? []
          : daysOfWeekStr.split(',').map(int.parse).toList(),
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.simple,
      ),
      repetition: RepetitionType.values.firstWhere(
        (e) => e.name == map['repetition'],
        orElse: () => RepetitionType.daily,
      ),
      isEnabled: (map['is_enabled'] ?? 1) == 1,
      habitIds: habitIdsStr.isEmpty
          ? []
          : habitIdsStr.split(',').map(int.parse).toList(),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      nextScheduledTime: map['next_scheduled_time'] != null
          ? DateTime.parse(map['next_scheduled_time'])
          : null,
    );
  }

  NotificationSettings copyWith({
    int? id,
    String? title,
    String? message,
    TimeOfDay? time,
    List<int>? daysOfWeek,
    NotificationType? type,
    RepetitionType? repetition,
    bool? isEnabled,
    List<int>? habitIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? nextScheduledTime,
  }) => NotificationSettings(
    id: id ?? this.id,
    title: title ?? this.title,
    message: message ?? this.message,
    time: time ?? this.time,
    daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    type: type ?? this.type,
    repetition: repetition ?? this.repetition,
    isEnabled: isEnabled ?? this.isEnabled,
    habitIds: habitIds ?? this.habitIds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    nextScheduledTime: nextScheduledTime ?? this.nextScheduledTime,
  );

  String get timeString =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String get typeDisplayName {
    switch (type) {
      case NotificationType.simple:
        return 'Simple';
      case NotificationType.ringing:
        return 'Ringing';
      case NotificationType.alarm:
        return 'Alarm';
    }
  }

  String get repetitionDisplayName {
    switch (repetition) {
      case RepetitionType.oneTime:
        return 'One Time';
      case RepetitionType.daily:
        return 'Daily';
      case RepetitionType.weekly:
        return 'Weekly';
      case RepetitionType.monthly:
        return 'Monthly';
    }
  }

  String get daysDisplayName {
    if (daysOfWeek.length == 7) return 'Every day';
    if (daysOfWeek.length == 5 &&
        daysOfWeek.every((day) => day >= 1 && day <= 5)) {
      return 'Weekdays';
    }
    if (daysOfWeek.length == 2 &&
        daysOfWeek.contains(6) &&
        daysOfWeek.contains(7)) {
      return 'Weekends';
    }

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return daysOfWeek.map((day) => dayNames[day - 1]).join(', ');
  }

  bool get hasHabits => habitIds.isNotEmpty;

  @override
  String toString() =>
      'NotificationSettings(id: $id, title: $title, time: $timeString)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSettings &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
