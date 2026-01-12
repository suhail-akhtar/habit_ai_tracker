import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_habit_tracker/main.dart';
import 'package:ai_voice_habit_tracker/screens/analytics_screen.dart';

void main() {
  group('Main App Widget Tests', () {
    testWidgets('App starts and displays navigation',
        (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const AIVoiceHabitTrackerApp());

      // Wait for the app to initialize
      await tester.pumpAndSettle();

      // Verify that the navigation bar is present
      expect(find.byType(NavigationBar), findsOneWidget);

      // Verify navigation destinations
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Add Habit'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Navigation works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const AIVoiceHabitTrackerApp());

      await tester.pumpAndSettle();

      // Tap on Analytics tab
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();

      // Verify Analytics screen is displayed
      expect(find.byType(AnalyticsScreen), findsOneWidget);
    });

    testWidgets('Dashboard displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const AIVoiceHabitTrackerApp());

      await tester.pumpAndSettle();

      // Verify dashboard elements
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
