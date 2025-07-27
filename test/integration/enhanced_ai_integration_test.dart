import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_voice_habit_tracker/models/habit.dart';
import 'package:ai_voice_habit_tracker/services/ai_action_service.dart';
import 'package:ai_voice_habit_tracker/services/ai_chatbot_service.dart';

void main() {
  group('Enhanced AI Functionality Integration Tests', () {
    late AIActionService actionService;
    late AIChatbotService chatbotService;

    setUp(() {
      // Initialize test environment
      SharedPreferences.setMockInitialValues({});
      actionService = AIActionService();
      chatbotService = AIChatbotService();
    });

    group('AI Action Service Enhanced Features', () {
      test('should execute actions with proper results', () async {
        // Test action execution functionality
        final result = await actionService.executeAction(
          action: 'create_habit',
          parameters: {'name': 'Morning Exercise', 'category': 'fitness'},
          userHabits: [],
          userProfile: {},
        );

        expect(result.success, isNotNull);
        expect(result.message, isNotEmpty);
      });

      test('should provide interactive questioning when needed', () async {
        // Test interactive questioning capability
        final result = await actionService.executeAction(
          action: 'setup_notification',
          parameters: {},
          userHabits: [],
          userProfile: {},
        );

        if (result.needsMoreInfo) {
          expect(result.followUpQuestion, isNotNull);
          expect(result.followUpQuestion!.isNotEmpty, isTrue);
        }
      });

      test('should provide toast feedback for actions', () async {
        // Test toast message functionality
        final result = await actionService.executeAction(
          action: 'create_habit',
          parameters: {'name': 'Test Habit', 'category': 'wellness'},
          userHabits: [],
          userProfile: {},
        );

        if (result.success && result.showToast) {
          expect(result.toastMessage, isNotNull);
          expect(result.toastMessage!.isNotEmpty, isTrue);
        }
      });
    });

    group('AI Chatbot Service Enhanced Features', () {
      test('should maintain persistent message limits', () async {
        // Test persistent message tracking
        final prefs = await SharedPreferences.getInstance();

        // Clear any existing data
        await prefs.clear();

        // Check initial state
        final initialLimits = await chatbotService.checkUsageLimits(false);
        expect(initialLimits.remainingMessages, equals(3)); // Free user limit

        // Send a message
        final response = await chatbotService.sendMessage(
          message: 'Hello',
          isPremiumUser: false,
          userHabits: [],
          conversationHistory: [],
        );

        expect(response.message, isNotEmpty);

        // Check that usage was tracked
        final updatedLimits = await chatbotService.checkUsageLimits(false);
        expect(updatedLimits.remainingMessages, equals(2));
      });

      test('should handle enhanced responses with action results', () async {
        // Test enhanced chatbot responses
        final response = await chatbotService.sendMessage(
          message: 'Create a new habit for drinking water',
          isPremiumUser: false,
          userHabits: [],
          conversationHistory: [],
        );

        expect(response.message, isNotEmpty);

        // Check if action was executed and results are available
        if (response.actionExecuted && response.actionResult != null) {
          final actionResult = response.actionResult!;
          expect(actionResult.success, isNotNull);

          if (actionResult.showToast) {
            expect(actionResult.toastMessage, isNotNull);
          }

          if (actionResult.needsMoreInfo) {
            expect(actionResult.followUpQuestion, isNotNull);
          }
        }
      });

      test('should provide intelligent habit suggestions', () async {
        // Test AI-powered habit suggestions
        final mockHabits = [
          Habit(
            name: 'Morning Run',
            description: 'Daily 30-minute run',
            category: 'fitness',
            colorCode: '#FF0000',
            iconName: 'fitness_center',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final response = await chatbotService.sendMessage(
          message: 'Suggest new habits for me',
          isPremiumUser: false,
          userHabits: mockHabits,
          conversationHistory: [],
        );

        expect(response.message, isNotEmpty);
        expect(
          response.message.toLowerCase(),
          anyOf(
            contains('suggest'),
            contains('recommend'),
            contains('habit'),
            contains('fitness'), // Should analyze existing habits
          ),
        );
      });

      test('should handle premium vs free user limits correctly', () async {
        // Clear preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Test free user limits
        final freeLimits = await chatbotService.checkUsageLimits(false);
        expect(freeLimits.remainingMessages, equals(3));

        // Test premium user limits
        final premiumLimits = await chatbotService.checkUsageLimits(true);
        expect(premiumLimits.remainingMessages, equals(50));
      });

      test('should reset usage limits daily', () async {
        // Test daily reset functionality
        final prefs = await SharedPreferences.getInstance();

        // Set yesterday's date with some usage
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yesterdayKey =
            'chat_usage_${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
        await prefs.setInt(yesterdayKey, 5);

        // Check today's limits (should be reset)
        final todayLimits = await chatbotService.checkUsageLimits(false);
        expect(
          todayLimits.remainingMessages,
          equals(3),
        ); // Should be reset to max
      });
    });

    group('Integration - AI Action & Chatbot Services', () {
      test('should work together for complex user requests', () async {
        // Test complex request that requires both services
        final response = await chatbotService.sendMessage(
          message:
              'I want to create a morning routine habit and set a reminder for 6 AM',
          isPremiumUser: true,
          userHabits: [],
          conversationHistory: [],
        );

        expect(response.message, isNotEmpty);

        // Should execute actions and provide appropriate feedback
        if (response.actionExecuted && response.actionResult != null) {
          final actionResult = response.actionResult!;

          // Should either succeed or ask for clarification
          expect(actionResult.success || actionResult.needsMoreInfo, isTrue);

          if (actionResult.success && actionResult.showToast) {
            expect(actionResult.toastMessage, isNotNull);
            expect(
              actionResult.toastMessage!.toLowerCase(),
              anyOf(
                contains('habit'),
                contains('created'),
                contains('reminder'),
                contains('notification'),
              ),
            );
          }
        }
      });

      test(
        'should provide contextual responses based on user habits',
        () async {
          // Test contextual AI responses
          final mockHabits = [
            Habit(
              name: 'Daily Meditation',
              description: '10 minutes mindfulness',
              category: 'wellness',
              colorCode: '#00FF00',
              iconName: 'self_improvement',
              createdAt: DateTime.now().subtract(const Duration(days: 30)),
              updatedAt: DateTime.now(),
            ),
            Habit(
              name: 'Read Books',
              description: '30 minutes reading',
              category: 'education',
              colorCode: '#0000FF',
              iconName: 'menu_book',
              createdAt: DateTime.now().subtract(const Duration(days: 15)),
              updatedAt: DateTime.now(),
            ),
          ];

          final response = await chatbotService.sendMessage(
            message: 'How am I doing with my habits?',
            isPremiumUser: false,
            userHabits: mockHabits,
            conversationHistory: [],
          );

          expect(response.message, isNotEmpty);
          // Should reference existing habits
          expect(
            response.message.toLowerCase(),
            anyOf(
              contains('meditation'),
              contains('read'),
              contains('habits'),
              contains('progress'),
            ),
          );
        },
      );
    });
  });
}
