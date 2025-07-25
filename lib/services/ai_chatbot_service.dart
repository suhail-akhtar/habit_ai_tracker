import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../utils/constants.dart';
import 'gemini_service.dart';
import 'user_profile_service.dart';

/// AI-powered chatbot service for habit coaching and FAQ support
class AIChatbotService {
  final GeminiService _geminiService = GeminiService();
  final UserProfileService _profileService = UserProfileService();

  // Track daily usage
  static DateTime? _lastResetDate;
  static int _dailyMessageCount = 0;

  /// Send a message to the AI chatbot
  Future<ChatbotResponse> sendMessage({
    required String message,
    required bool isPremiumUser,
    required List<Habit> userHabits,
    List<ChatMessage> conversationHistory = const [],
  }) async {
    try {
      // Check usage limits
      final usageCheck = _checkUsageLimits(isPremiumUser);
      if (!usageCheck.canSendMessage) {
        return ChatbotResponse(
          message: usageCheck.errorMessage!,
          isError: true,
          remainingMessages: usageCheck.remainingMessages,
          messageType: ChatMessageType.system,
        );
      }

      // Sanitize user input
      final sanitizedMessage = _sanitizeMessage(message);
      if (sanitizedMessage.isEmpty) {
        return ChatbotResponse(
          message:
              "I couldn't understand your message. Please try again with a clear question.",
          isError: true,
          remainingMessages: usageCheck.remainingMessages,
          messageType: ChatMessageType.error,
        );
      }

      // Increment usage count
      _incrementUsageCount();

      // Generate AI response
      final aiResponse = await _generateAIResponse(
        sanitizedMessage,
        userHabits,
        conversationHistory,
        isPremiumUser,
      );

      return ChatbotResponse(
        message: aiResponse.message,
        isError: false,
        remainingMessages: _getRemainingMessages(isPremiumUser),
        messageType: aiResponse.messageType,
        suggestions: aiResponse.suggestions,
        habitRecommendations: aiResponse.habitRecommendations,
      );
    } catch (e) {
      if (kDebugMode) {
        print('🤖 AIChatbotService: ❌ Send message failed: $e');
      }

      return ChatbotResponse(
        message: "I'm having trouble right now. Please try again in a moment.",
        isError: true,
        remainingMessages: _getRemainingMessages(isPremiumUser),
        messageType: ChatMessageType.error,
      );
    }
  }

  /// Get FAQ answers
  Future<ChatbotResponse> getFAQAnswer(
    String question,
    bool isPremiumUser,
  ) async {
    final faqAnswer = _matchFAQPattern(question);

    if (faqAnswer != null) {
      return ChatbotResponse(
        message: faqAnswer,
        isError: false,
        remainingMessages: _getRemainingMessages(isPremiumUser),
        messageType: ChatMessageType.faq,
      );
    }

    // If no FAQ match, treat as regular chat
    return sendMessage(
      message: question,
      isPremiumUser: isPremiumUser,
      userHabits: [],
      conversationHistory: [],
    );
  }

  /// Check current usage limits
  UsageLimitResult checkUsageLimits(bool isPremiumUser) {
    return _checkUsageLimits(isPremiumUser);
  }

  /// Reset daily usage count (called automatically)
  void _resetDailyUsage() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (_lastResetDate == null || _lastResetDate!.isBefore(todayDate)) {
      _lastResetDate = todayDate;
      _dailyMessageCount = 0;

      if (kDebugMode) {
        print('🤖 AIChatbotService: Daily usage reset');
      }
    }
  }

  /// Check if user can send message
  UsageLimitResult _checkUsageLimits(bool isPremiumUser) {
    _resetDailyUsage();

    final limit = isPremiumUser
        ? Constants.premiumChatbotMessages
        : Constants.freeChatbotMessages;

    final remaining = limit - _dailyMessageCount;

    if (remaining <= 0) {
      final errorMessage = isPremiumUser
          ? "You've reached your daily limit of $limit messages. Try again tomorrow!"
          : "You've used all $limit free messages today. Upgrade to Premium for up to ${Constants.premiumChatbotMessages} messages daily!";

      return UsageLimitResult(
        canSendMessage: false,
        remainingMessages: 0,
        errorMessage: errorMessage,
      );
    }

    return UsageLimitResult(canSendMessage: true, remainingMessages: remaining);
  }

  /// Increment usage count
  void _incrementUsageCount() {
    _dailyMessageCount++;
  }

  /// Get remaining messages for user
  int _getRemainingMessages(bool isPremiumUser) {
    _resetDailyUsage();

    final limit = isPremiumUser
        ? Constants.premiumChatbotMessages
        : Constants.freeChatbotMessages;

    return (limit - _dailyMessageCount).clamp(0, limit);
  }

  /// Sanitize user message
  String _sanitizeMessage(String message) {
    // Remove HTML and potentially dangerous content
    String sanitized = message.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove excessive whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Limit length
    if (sanitized.length > 500) {
      sanitized = sanitized.substring(0, 500);
    }

    return sanitized;
  }

  /// Generate AI response using Gemini
  Future<AIChatResponse> _generateAIResponse(
    String message,
    List<Habit> userHabits,
    List<ChatMessage> conversationHistory,
    bool isPremiumUser,
  ) async {
    try {
      // Get user profile for context
      final userProfile = await _profileService.getUserAIProfile(userHabits);

      // Convert conversation history to the format expected by GeminiService
      final history = conversationHistory
          .map(
            (msg) => {
              'role': msg.isUser ? 'user' : 'assistant',
              'message': msg.content,
            },
          )
          .toList();

      // Enhanced prompt with user context
      final contextualPrompt = _buildContextualPrompt(
        message,
        userProfile,
        userHabits,
      );
      final response = await _geminiService.generateChatbotResponse(
        contextualPrompt,
        userHabits,
        history,
      );

      return _parseAIResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('🤖 AIChatbotService: ❌ AI response failed: $e');
      }

      return _generateFallbackResponse(message, userHabits);
    }
  }

  /// Build contextual prompt with user profile information
  String _buildContextualPrompt(
    String userMessage,
    UserAIProfile profile,
    List<Habit> habits,
  ) {
    final contextBuilder = StringBuffer();

    // Add user context
    contextBuilder.writeln('USER CONTEXT:');
    contextBuilder.writeln(
      '- Has ${profile.totalHabits} habits (${profile.activeHabits} active)',
    );
    contextBuilder.writeln(
      '- 7-day completion rate: ${(profile.completionData.completionRate7Days * 100).toInt()}%',
    );
    contextBuilder.writeln(
      '- 30-day completion rate: ${(profile.completionData.completionRate30Days * 100).toInt()}%',
    );
    contextBuilder.writeln(
      '- Current streak: ${profile.completionData.currentStreak} days',
    );
    contextBuilder.writeln(
      '- Best streak: ${profile.completionData.bestStreak} days',
    );
    contextBuilder.writeln(
      '- Motivation level: ${(profile.patterns.motivationLevel * 100).toInt()}%',
    );

    if (profile.patterns.strongAreas.isNotEmpty) {
      contextBuilder.writeln(
        '- Strong areas: ${profile.patterns.strongAreas.join(", ")}',
      );
    }

    if (profile.patterns.strugglingAreas.isNotEmpty) {
      contextBuilder.writeln(
        '- Struggling with: ${profile.patterns.strugglingAreas.join(", ")}',
      );
    }

    if (profile.insights.currentStruggles.isNotEmpty) {
      contextBuilder.writeln(
        '- Current challenges: ${profile.insights.currentStruggles.join(", ")}',
      );
    }

    contextBuilder.writeln(
      '- Next milestone: ${profile.insights.nextMilestone}',
    );
    contextBuilder.writeln(
      '- Personality: ${profile.personality.motivationType}, ${profile.personality.consistency} consistency',
    );

    // Add specific habits context
    if (habits.isNotEmpty) {
      contextBuilder.writeln('\nCURRENT HABITS:');
      for (final habit in habits.take(5)) {
        // Limit to avoid token overload
        final performance = profile.completionData.habitPerformances
            .where((p) => p.habitId == habit.id)
            .firstOrNull;

        if (performance != null) {
          contextBuilder.writeln(
            '- ${habit.name} (${habit.category}): ${(performance.completionRate30Days * 100).toInt()}% completion, ${performance.currentStreak} day streak',
          );
        } else {
          contextBuilder.writeln(
            '- ${habit.name} (${habit.category}): New habit',
          );
        }
      }
    }

    // Add recommendations context
    if (profile.insights.recommendations.isNotEmpty) {
      contextBuilder.writeln('\nCURRENT RECOMMENDATIONS:');
      for (final rec in profile.insights.recommendations.take(3)) {
        contextBuilder.writeln('- $rec');
      }
    }

    contextBuilder.writeln('\nUSER MESSAGE: $userMessage');
    contextBuilder.writeln(
      '\nRespond as a knowledgeable, supportive habit coach who knows this user well. Be specific, personal, and reference their actual progress when relevant. Keep response under 150 words.',
    );

    return contextBuilder.toString();
  }

  /// Parse AI response
  AIChatResponse _parseAIResponse(String response) {
    // Determine message type based on content
    ChatMessageType messageType = ChatMessageType.general;

    final lowerResponse = response.toLowerCase();
    if (lowerResponse.contains('goal') || lowerResponse.contains('target')) {
      messageType = ChatMessageType.coaching;
    } else if (lowerResponse.contains('try') ||
        lowerResponse.contains('suggest')) {
      messageType = ChatMessageType.advice;
    } else if (lowerResponse.contains('help') ||
        lowerResponse.contains('how to')) {
      messageType = ChatMessageType.featureHelp;
    }

    // Extract suggestions (simple pattern matching)
    final suggestions = <String>[];
    if (response.contains('try')) {
      suggestions.add('Tell me more about this habit');
      suggestions.add('How can I stay motivated?');
    }

    return AIChatResponse(
      message: response,
      messageType: messageType,
      suggestions: suggestions,
    );
  }

  /// Generate fallback response when AI fails
  AIChatResponse _generateFallbackResponse(
    String message,
    List<Habit> userHabits,
  ) {
    final lowerMessage = message.toLowerCase();

    String responseText;
    ChatMessageType messageType = ChatMessageType.general;

    // Context-aware responses based on user's habits
    if (lowerMessage.contains('progress') ||
        lowerMessage.contains('status') ||
        lowerMessage.contains('how am i doing') ||
        lowerMessage.contains('current')) {
      if (userHabits.isEmpty) {
        responseText =
            'You haven\'t created any habits yet! Start with one simple habit like "drink 1 glass of water" or "walk for 5 minutes." What habit would you like to begin with?';
        messageType = ChatMessageType.coaching;
      } else {
        responseText =
            'You have ${userHabits.length} habit${userHabits.length > 1 ? 's' : ''} in progress! ${userHabits.map((h) => h.name).take(3).join(", ")}${userHabits.length > 3 ? " and more" : ""}. Keep building your routine one day at a time!';
        messageType = ChatMessageType.coaching;
      }
    } else if (lowerMessage.contains('habit') ||
        lowerMessage.contains('routine')) {
      responseText =
          'Building habits takes time and consistency. Start small with just one habit and focus on doing it daily for 21 days. What habit would you like to work on?';
      messageType = ChatMessageType.coaching;
    } else if (lowerMessage.contains('motivation') ||
        lowerMessage.contains('give up')) {
      if (userHabits.isNotEmpty) {
        responseText =
            'Remember why you started with ${userHabits.first.name}! Every small step counts toward your bigger goals. Even if you miss a day, you can always start fresh tomorrow.';
      } else {
        responseText =
            'Remember why you wanted to build better habits! Every small step counts toward your bigger goals. Starting is the hardest part - you\'ve got this!';
      }
      messageType = ChatMessageType.coaching;
    } else if (lowerMessage.contains('goal') ||
        lowerMessage.contains('target')) {
      responseText =
          'Great goals are specific and achievable! Instead of "exercise more," try "walk 10 minutes daily." What specific goal would you like to set?';
      messageType = ChatMessageType.advice;
    } else if (lowerMessage.contains('streak') ||
        lowerMessage.contains('consistency')) {
      responseText =
          'Streaks are motivating, but don\'t let a broken streak discourage you! The key is getting back on track quickly. Focus on consistency over perfection.';
      messageType = ChatMessageType.advice;
    } else if (lowerMessage.contains('stress') ||
        lowerMessage.contains('anxiety')) {
      responseText =
          'Stress management is crucial for habit success. Try deep breathing, short walks, or 5-minute meditation. Building calm routines helps everything else fall into place.';
      messageType = ChatMessageType.advice;
    } else if (lowerMessage.contains('sleep') ||
        lowerMessage.contains('tired')) {
      responseText =
          'Good sleep is the foundation of all habits! Try a consistent bedtime routine: no screens 1 hour before bed, dim lights, and the same sleep schedule daily.';
      messageType = ChatMessageType.advice;
    } else {
      final habitCount = userHabits.length;
      if (habitCount == 0) {
        responseText =
            'I\'m here to help you start your habit journey! Let\'s begin with one simple habit. What healthy routine would you like to build?';
      } else if (habitCount < 3) {
        responseText =
            'Great start with your ${habitCount == 1 ? 'habit' : 'habits'}! I\'m here to help you stay consistent and motivated. What would you like to know?';
      } else {
        responseText =
            'Impressive - you\'re tracking $habitCount habits! I\'m here to help you optimize your routine and stay motivated. What can I help with?';
      }
      messageType = ChatMessageType.featureHelp;
    }

    final habitCount = userHabits.length;
    final suggestions = habitCount == 0
        ? [
            'How do I start my first habit?',
            'What are the best beginner habits?',
          ]
        : [
            'How\'s my progress?',
            'Tips for staying motivated?',
            'How to improve consistency?',
          ];

    return AIChatResponse(
      message: responseText,
      messageType: messageType,
      suggestions: suggestions,
    );
  }

  /// Match FAQ patterns
  String? _matchFAQPattern(String question) {
    final lowerQuestion = question.toLowerCase();

    // FAQ patterns and responses
    final faqPatterns = {
      'how to add habit':
          'To add a new habit: Go to "Add Habit" tab → Enter habit name → Choose frequency → Set reminders → Save. Start with simple, specific habits like "drink 1 glass of water" rather than vague ones like "be healthier".',

      'streak':
          'Streaks track consecutive days of completing a habit. Don\'t worry if you break a streak - just start again! The key is consistency over perfection. Even a 3-day streak is better than none.',

      'motivation':
          'Staying motivated: 1) Start ridiculously small, 2) Stack habits with existing routines, 3) Celebrate small wins, 4) Track progress visually, 5) Find an accountability partner. Remember: motivation gets you started, habit keeps you going.',

      'best habits':
          'Great starter habits: Morning water (1 glass), 5-minute walk, 2-minute meditation, reading 1 page, making your bed, writing 3 gratitude items. Pick ONE that feels almost too easy to fail.',

      'how long habits':
          'Habit formation takes 18-254 days (average 66 days) depending on complexity. Simple habits like drinking water: ~30 days. Complex habits like exercising: ~3-6 months. Focus on consistency, not speed.',

      'missed day':
          'Missing one day won\'t ruin your progress! Research shows missing occasionally doesn\'t hurt habit formation. Just get back on track the next day. Two days in a row is when it gets harder, so prioritize bouncing back quickly.',
    };

    // Find matching pattern
    for (final entry in faqPatterns.entries) {
      if (lowerQuestion.contains(entry.key.split(' ').first) ||
          entry.key.split(' ').any((word) => lowerQuestion.contains(word))) {
        return entry.value;
      }
    }

    return null;
  }

  /// Dispose resources
  void dispose() {
    _geminiService.dispose();
  }
}

/// Usage limit check result
class UsageLimitResult {
  final bool canSendMessage;
  final int remainingMessages;
  final String? errorMessage;

  UsageLimitResult({
    required this.canSendMessage,
    required this.remainingMessages,
    this.errorMessage,
  });
}

/// Chatbot response model
class ChatbotResponse {
  final String message;
  final bool isError;
  final int? remainingMessages;
  final ChatMessageType messageType;
  final List<String> suggestions;
  final List<String> habitRecommendations;

  ChatbotResponse({
    required this.message,
    required this.isError,
    this.remainingMessages,
    required this.messageType,
    this.suggestions = const [],
    this.habitRecommendations = const [],
  });
}

/// AI chat response (internal)
class AIChatResponse {
  final String message;
  final ChatMessageType messageType;
  final List<String> suggestions;
  final List<String> habitRecommendations;

  AIChatResponse({
    required this.message,
    required this.messageType,
    this.suggestions = const [],
    this.habitRecommendations = const [],
  });
}

/// Chat message model
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final ChatMessageType messageType;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.messageType = ChatMessageType.general,
  });
}

/// Message types
enum ChatMessageType {
  general,
  coaching,
  advice,
  featureHelp,
  error,
  system,
  faq,
}

extension ChatMessageTypeExtension on ChatMessageType {
  String get displayName {
    switch (this) {
      case ChatMessageType.general:
        return 'General';
      case ChatMessageType.coaching:
        return 'Coaching';
      case ChatMessageType.advice:
        return 'Advice';
      case ChatMessageType.featureHelp:
        return 'Help';
      case ChatMessageType.error:
        return 'Error';
      case ChatMessageType.system:
        return 'System';
      case ChatMessageType.faq:
        return 'FAQ';
    }
  }

  String get icon {
    switch (this) {
      case ChatMessageType.general:
        return '💬';
      case ChatMessageType.coaching:
        return '🎯';
      case ChatMessageType.advice:
        return '💡';
      case ChatMessageType.featureHelp:
        return '❓';
      case ChatMessageType.error:
        return '❌';
      case ChatMessageType.system:
        return '⚙️';
      case ChatMessageType.faq:
        return '📚';
    }
  }
}
