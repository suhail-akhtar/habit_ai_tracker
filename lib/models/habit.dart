import 'package:flutter/material.dart';

class Habit {
  final int? id;
  final String name;
  final String? description;
  final String category;
  final int targetFrequency;
  final String colorCode;
  final String iconName;
  final bool isActive;
  final bool hasFreeze; // ❄️ NEW: Streak freeze capability

  // 📅 NEW: Schedule semantics
  // If a weekday is not included, it's treated as a rest day (doesn't break streak).
  // 1=Mon ... 7=Sun
  final List<int> scheduleDaysOfWeek;
  // Optional explicit start date; days before start do not break streak.
  final DateTime? startDate;
  
  // 🕒 NEW: Flexible Scheduling
  final String frequencyType; // 'daily', 'interval'
  final int? intervalMinutes;
  final String? windowStartTime; // "HH:MM"
  final String? windowEndTime; // "HH:MM"
  
  // 🔔 NEW: Reminder Settings integrated
  final bool isReminderEnabled;
  final String? reminderTime; // "HH:MM" for daily simple

  // 🎯 Goals & Targets
  // goalType: 'streak' | 'weekly' | 'total'
  final String goalType;
  final int? goalTarget;

  // 🏷️ Tags
  final List<String> tags;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  Habit({
    this.id,
    required this.name,
    this.description,
    required this.category,
    this.targetFrequency = 1,
    required this.colorCode,
    required this.iconName,
    this.isActive = true,
    this.hasFreeze = false,
    this.scheduleDaysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.startDate,
    this.frequencyType = 'daily',
    this.intervalMinutes,
    this.windowStartTime,
    this.windowEndTime,
    this.isReminderEnabled = false,
    this.reminderTime,
    this.goalType = 'streak',
    this.goalTarget,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'target_frequency': targetFrequency,
        'color_code': colorCode,
        'icon_name': iconName,
        'is_active': isActive ? 1 : 0,
        'has_freeze': hasFreeze ? 1 : 0,
      'schedule_days_of_week': scheduleDaysOfWeek.join(','),
      'start_date': startDate?.toIso8601String(),
        'frequency_type': frequencyType,
        'interval_minutes': intervalMinutes,
        'window_start_time': windowStartTime,
        'window_end_time': windowEndTime,
        'is_reminder_enabled': isReminderEnabled ? 1 : 0,
        'reminder_time': reminderTime,
        'goal_type': goalType,
        'goal_target': goalTarget,
        'tags': tags.join(','),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Habit.fromMap(Map<String, dynamic> map) => Habit(
        id: map['id'],
        name: map['name'],
        description: map['description'],
        category: map['category'],
        targetFrequency: map['target_frequency'] ?? 1,
        colorCode: map['color_code'],
        iconName: map['icon_name'],
        isActive: (map['is_active'] ?? 1) == 1,
        hasFreeze: (map['has_freeze'] ?? 0) == 1,
      scheduleDaysOfWeek: ((map['schedule_days_of_week'] as String?) ?? '1,2,3,4,5,6,7')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList(),
      startDate: (map['start_date'] as String?) != null &&
          (map['start_date'] as String).isNotEmpty
        ? DateTime.tryParse(map['start_date'] as String)
        : null,
        frequencyType: map['frequency_type'] ?? 'daily',
        intervalMinutes: map['interval_minutes'],
        windowStartTime: map['window_start_time'],
        windowEndTime: map['window_end_time'],
        isReminderEnabled: (map['is_reminder_enabled'] ?? 0) == 1,
        reminderTime: map['reminder_time'],
        goalType: (map['goal_type'] as String?) ?? 'streak',
        goalTarget: map['goal_target'] as int?,
        tags: ((map['tags'] as String?) ?? '')
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim())
            .toList(),
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
      );

  Habit copyWith({
    int? id,
    String? name,
    String? description,
    String? category,
    int? targetFrequency,
    String? colorCode,
    String? iconName,
    bool? isActive,
    bool? hasFreeze,
    List<int>? scheduleDaysOfWeek,
    DateTime? startDate,
    String? frequencyType,
    int? intervalMinutes,
    String? windowStartTime,
    String? windowEndTime,
    bool? isReminderEnabled,
    String? reminderTime,
    String? goalType,
    int? goalTarget,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Habit(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        targetFrequency: targetFrequency ?? this.targetFrequency,
        colorCode: colorCode ?? this.colorCode,
        iconName: iconName ?? this.iconName,
        isActive: isActive ?? this.isActive,
        hasFreeze: hasFreeze ?? this.hasFreeze,
        scheduleDaysOfWeek: scheduleDaysOfWeek ?? this.scheduleDaysOfWeek,
        startDate: startDate ?? this.startDate,
        frequencyType: frequencyType ?? this.frequencyType,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        windowStartTime: windowStartTime ?? this.windowStartTime,
        windowEndTime: windowEndTime ?? this.windowEndTime,
        isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
        reminderTime: reminderTime ?? this.reminderTime,
        goalType: goalType ?? this.goalType,
        goalTarget: goalTarget ?? this.goalTarget,
        tags: tags ?? this.tags,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Color get color => Color(int.parse(colorCode.replaceFirst('#', '0xFF')));

  @override
  String toString() => 'Habit(id: $id, name: $name, category: $category)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Habit &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
