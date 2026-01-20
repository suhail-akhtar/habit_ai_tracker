import 'package:flutter/material.dart';

class HabitTemplate {
  final String id;
  final String name;
  final String category;
  final String iconName;
  final Color color;
  final int targetFrequency;

  const HabitTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.iconName,
    required this.color,
    this.targetFrequency = 1,
  });

  static const List<HabitTemplate> defaults = [
    HabitTemplate(
      id: 'water',
      name: 'Drink water',
      category: 'Health',
      iconName: 'water_drop',
      color: Color(0xFF2196F3),
    ),
    HabitTemplate(
      id: 'walk',
      name: 'Walk 10 minutes',
      category: 'Health',
      iconName: 'directions_walk',
      color: Color(0xFF4CAF50),
    ),
    HabitTemplate(
      id: 'read',
      name: 'Read 10 pages',
      category: 'Growth',
      iconName: 'menu_book',
      color: Color(0xFF673AB7),
    ),
    HabitTemplate(
      id: 'journal',
      name: 'Journal',
      category: 'Mindfulness',
      iconName: 'edit_note',
      color: Color(0xFFFF9800),
    ),
    HabitTemplate(
      id: 'meditate',
      name: 'Meditate',
      category: 'Mindfulness',
      iconName: 'self_improvement',
      color: Color(0xFF009688),
    ),
    HabitTemplate(
      id: 'stretch',
      name: 'Stretch',
      category: 'Health',
      iconName: 'accessibility_new',
      color: Color(0xFFE91E63),
    ),
  ];
}
