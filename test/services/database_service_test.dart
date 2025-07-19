import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_voice_habit_tracker/services/database_service.dart';
import 'package:ai_voice_habit_tracker/models/habit.dart';
import 'package:ai_voice_habit_tracker/models/habit_log.dart';

void main() {
  group('Database Service Tests', () {
    late DatabaseService databaseService;

    setUpAll(() {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      databaseService = DatabaseService();
    });

    tearDown(() async {
      await databaseService.close();
    });

    test('Database initializes correctly', () async {
      final db = await databaseService.database;
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('Create and retrieve habit', () async {
      final habit = Habit(
        name: 'Test Habit',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await databaseService.createHabit(habit);
      expect(id, isPositive);

      final retrievedHabit = await databaseService.getHabit(id);
      expect(retrievedHabit, isNotNull);
      expect(retrievedHabit!.name, equals('Test Habit'));
      expect(retrievedHabit.category, equals('Health'));
    });

    test('Update habit', () async {
      final habit = Habit(
        name: 'Original Name',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await databaseService.createHabit(habit);
      final updatedHabit = habit.copyWith(
        id: id,
        name: 'Updated Name',
        updatedAt: DateTime.now(),
      );

      await databaseService.updateHabit(updatedHabit);
      final retrievedHabit = await databaseService.getHabit(id);

      expect(retrievedHabit!.name, equals('Updated Name'));
    });

    test('Delete habit', () async {
      final habit = Habit(
        name: 'Test Habit',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await databaseService.createHabit(habit);
      await databaseService.deleteHabit(id);
      final retrievedHabit = await databaseService.getHabit(id);

      expect(retrievedHabit, isNull);
    });

    test('Log habit completion', () async {
      final habit = Habit(
        name: 'Test Habit',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final habitId = await databaseService.createHabit(habit);
      final habitLog = HabitLog(
        habitId: habitId,
        completedAt: DateTime.now(),
        inputMethod: 'manual',
        note: 'Test completion',
      );

      final logId = await databaseService.logHabit(habitLog);
      expect(logId, isPositive);

      final logs = await databaseService.getHabitLogs(habitId);
      expect(logs.length, equals(1));
      expect(logs.first.note, equals('Test completion'));
    });

    test('Get active habits only', () async {
      final activeHabit = Habit(
        name: 'Active Habit',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final inactiveHabit = Habit(
        name: 'Inactive Habit',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        isActive: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await databaseService.createHabit(activeHabit);
      await databaseService.createHabit(inactiveHabit);

      final activeHabits = await databaseService.getActiveHabits();
      expect(activeHabits.length, equals(1));
      expect(activeHabits.first.name, equals('Active Habit'));
    });

    test('Get analytics data', () async {
      final habit = Habit(
        name: 'Test Habit',
        category: 'Health',
        colorCode: '#FF0000',
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final habitId = await databaseService.createHabit(habit);

      // Log some completions
      for (int i = 0; i < 3; i++) {
        final log = HabitLog(
          habitId: habitId,
          completedAt: DateTime.now(),
          inputMethod: 'manual',
        );
        await databaseService.logHabit(log);
      }

      final analytics = await databaseService.getAnalytics();
      expect(analytics['totalHabits'], equals(1));
      expect(analytics['totalLogs'], equals(3));
    });
  });
}
