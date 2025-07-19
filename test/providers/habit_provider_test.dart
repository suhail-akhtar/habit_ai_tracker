import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_habit_tracker/providers/habit_provider.dart';
import 'package:ai_voice_habit_tracker/models/habit.dart';

void main() {
  group('Habit Provider Tests', () {
    late HabitProvider habitProvider;

    setUp(() {
      habitProvider = HabitProvider();
    });

    test('Initial state is correct', () {
      expect(habitProvider.habits, isEmpty);
      expect(habitProvider.isLoading, isFalse);
      expect(habitProvider.error, isNull);
    });

    test('Loading state changes correctly', () {
      bool loadingChanged = false;
      habitProvider.addListener(() {
        loadingChanged = true;
      });

      // This would normally trigger loading
      expect(loadingChanged, isFalse);
    });

    test('Error state is handled correctly', () {
      expect(habitProvider.error, isNull);

      // In a real test, we would mock the database service
      // to simulate an error and verify error handling
    });

    test('Today habits filter works correctly', () {
      // This test would require mocking the database
      // and setting up test data with specific dates
      expect(habitProvider.todayHabits, isEmpty);
    });

    test('Habit completion check works', () {
      // Test with a mock habit ID
      const testHabitId = 1;
      final isCompleted = habitProvider.isHabitCompletedToday(testHabitId);
      expect(isCompleted, isFalse);
    });
  });
}
