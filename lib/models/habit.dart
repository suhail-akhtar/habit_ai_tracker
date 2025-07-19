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
