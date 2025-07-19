import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_habit_tracker/models/habit.dart';
import 'package:flutter/material.dart';

void main() {
  group('Habit Model Tests', () {
    test('Habit creation with required fields', () {
      final habit = Habit(
        name: 'Test Habit',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(habit.name, equals('Test Habit'));
      expect(habit.category, equals('Health'));
      expect(habit.colorCode, equals('#FF0000'));
      expect(habit.iconName, equals('fitness_center'));
      expect(habit.isActive, isTrue);
      expect(habit.targetFrequency, equals(1));
    });

    test('Habit.fromMap creates correct instance', () {
      final map = {
        'id': 1,
        'name': 'Test Habit',
        'description': 'A test habit',
        'category': 'Health',
        'target_frequency': 7,
        'color_code': '#FF0000',
        'icon_name': 'fitness_center',
        'is_active': 1,
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-01T00:00:00.000Z',
      };

      final habit = Habit.fromMap(map);

      expect(habit.id, equals(1));
      expect(habit.name, equals('Test Habit'));
      expect(habit.description, equals('A test habit'));
      expect(habit.category, equals('Health'));
      expect(habit.targetFrequency, equals(7));
      expect(habit.colorCode, equals('#FF0000'));
      expect(habit.iconName, equals('fitness_center'));
      expect(habit.isActive, isTrue);
    });

    test('Habit.toMap creates correct map', () {
      final habit = Habit(
        id: 1,
        name: 'Test Habit',
        description: 'A test habit',
        category: 'Health',
        targetFrequency: 7,
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        isActive: true,
        createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
      );

      final map = habit.toMap();

      expect(map['id'], equals(1));
      expect(map['name'], equals('Test Habit'));
      expect(map['description'], equals('A test habit'));
      expect(map['category'], equals('Health'));
      expect(map['target_frequency'], equals(7));
      expect(map['color_code'], equals('#FF0000'));
      expect(map['icon_name'], equals('fitness_center'));
      expect(map['is_active'], equals(1));
    });

    test('Habit.copyWith creates correct copy', () {
      final original = Habit(
        id: 1,
        name: 'Original',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final copy = original.copyWith(
        name: 'Updated',
        description: 'Updated description',
      );

      expect(copy.id, equals(original.id));
      expect(copy.name, equals('Updated'));
      expect(copy.description, equals('Updated description'));
      expect(copy.category, equals(original.category));
      expect(copy.colorCode, equals(original.colorCode));
    });

    test('Habit.color returns correct Color', () {
      final habit = Habit(
        name: 'Test',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(habit.color, equals(const Color(0xFFFF0000)));
    });

    test('Habit equality works correctly', () {
      final habit1 = Habit(
        id: 1,
        name: 'Test',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final habit2 = Habit(
        id: 1,
        name: 'Test',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final habit3 = Habit(
        id: 2,
        name: 'Different',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(habit1, equals(habit2));
      expect(habit1, isNot(equals(habit3)));
    });
  });
}
