import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../models/analytics_models.dart';
import '../config/app_config.dart';

class GeminiService {
  static final http.Client _httpClient = http.Client();
  int _retryCount = 0;

  Future<Map<String, dynamic>> processVoiceInput(
    String voiceText,
    List<Habit> userHabits,
  ) async {
    if (voiceText.trim().isEmpty) {
      return _createErrorResponse('Empty voice input');
    }

    try {
      if (kDebugMode) {
        print('🤖 GeminiService: 🎯 Processing voice input: "$voiceText"');
        print(
          '🤖 GeminiService: 📝 Available habits: ${userHabits.map((h) => h.name).join(', ')}',
        );
      }

      final prompt = _buildVoicePrompt(voiceText, userHabits);
      final response = await _callGeminiAPI(prompt);
      final result = _parseVoiceResponse(response);

      if (kDebugMode) {
        print('🤖 GeminiService: ✅ AI processing successful: $result');
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('🤖 GeminiService: ❌ AI processing failed: $e');
      }
      return _fallbackProcessing(voiceText, userHabits);
    }
  }

  Future<String> generateWeeklyInsight(
    Map<String, dynamic> analyticsData,
  ) async {
    try {
      final prompt = _buildInsightPrompt(analyticsData);
      final response = await _callGeminiAPI(prompt);
      return response.trim();
    } catch (e) {
      if (kDebugMode) {
        print('🤖 GeminiService: ❌ Insight generation failed: $e');
      }
      return _generateFallbackInsight(analyticsData);
    }
  }

  /// Generate chatbot response for user conversation
  Future<String> generateChatbotResponse(
    String userMessage,
    List<Habit> userHabits,
    List<Map<String, String>> conversationHistory,
  ) async {
    try {
      if (kDebugMode) {
        print(
          '🤖 GeminiService: 💬 Generating chatbot response for: "$userMessage"',
        );
      }

      final prompt = _buildChatbotPrompt(
        userMessage,
        userHabits,
        conversationHistory,
      );
      final response = await _callGeminiAPI(prompt);

      if (kDebugMode) {
        print('🤖 GeminiService: ✅ Chatbot response generated successfully');
      }

      return response.trim();
    } catch (e) {
      if (kDebugMode) {
        print('🤖 GeminiService: ❌ Chatbot response failed: $e');
      }
      return _generateFallbackChatResponse(userMessage, userHabits);
    }
  }

  Future<String> _callGeminiAPI(String prompt) async {
    _retryCount = 0;

    while (_retryCount < AppConfig.maxAiRetries) {
      try {
        final requestBody = _buildRequestBody(prompt);

        if (kDebugMode) {
          print(
            '🤖 GeminiService: 🌐 Making API request (attempt ${_retryCount + 1}/${AppConfig.maxAiRetries})',
          );
          print(
            '🤖 GeminiService: 📤 Request URL: ${AppConfig.geminiEndpoint}',
          );
        }

        final response = await _httpClient
            .post(
              Uri.parse(AppConfig.geminiEndpoint),
              headers: _buildHeaders(),
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 15));

        if (kDebugMode) {
          print('🤖 GeminiService: 📥 Response Status: ${response.statusCode}');
          print('🤖 GeminiService: 📥 Response Body: ${response.body}');
        }

        if (response.statusCode == 200) {
          return _extractContentFromResponse(response.body);
        } else {
          throw HttpException(
            'API Error ${response.statusCode}: ${response.body}',
            uri: Uri.parse(AppConfig.geminiEndpoint),
          );
        }
      } catch (e) {
        _retryCount++;
        if (kDebugMode) {
          print('🤖 GeminiService: ⚠️ Attempt $_retryCount failed: $e');
        }

        if (_retryCount >= AppConfig.maxAiRetries) {
          throw Exception(
            'API call failed after ${AppConfig.maxAiRetries} attempts: $e',
          );
        }

        // Simple backoff
        await Future.delayed(Duration(milliseconds: 1000 * _retryCount));
      }
    }

    throw Exception('API call failed after all retry attempts');
  }

  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'x-goog-api-key': AppConfig.geminiApiKey,
    };
  }

  // 🔧 FIXED: Updated request body with proper token allocation and safety settings
  Map<String, dynamic> _buildRequestBody(String prompt) {
    return {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'topK': 40,
        'topP': 0.95,
        "thinkingConfig": {"thinkingBudget": 0},
        'maxOutputTokens': 512, // 🔧 INCREASED: More tokens for response
        'responseMimeType': 'text/plain',
      },
      // 🔧 REMOVED: Safety settings that might interfere with response
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_NONE',
        },
      ],
    };
  }

  // 🔧 ENHANCED: Better response extraction handling all possible structures
  String _extractContentFromResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody);

      if (kDebugMode) {
        print('🤖 GeminiService: 🔍 Full response: ${jsonEncode(data)}');
      }

      // Check if response was blocked or truncated
      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        final candidate = data['candidates'][0];
        final finishReason = candidate['finishReason'];

        if (kDebugMode) {
          print('🤖 GeminiService: 📋 Finish reason: $finishReason');
        }

        // Handle different finish reasons
        if (finishReason == 'SAFETY') {
          throw Exception('Response blocked by safety filters');
        }

        if (finishReason == 'MAX_TOKENS') {
          if (kDebugMode) {
            print('🤖 GeminiService: ⚠️ Response truncated due to token limit');
          }
          // Continue processing even if truncated - might still have useful content
        }

        // Try multiple extraction strategies
        String? content;

        // Strategy 1: Standard content.parts[0].text
        if (candidate['content']?['parts'] != null &&
            candidate['content']['parts'].isNotEmpty &&
            candidate['content']['parts'][0]['text'] != null) {
          content = candidate['content']['parts'][0]['text'];
        }
        // Strategy 2: Direct content.text (alternative structure)
        else if (candidate['content']?['text'] != null) {
          content = candidate['content']['text'];
        }
        // Strategy 3: Check if content field has a direct string value
        else if (candidate['content'] is String) {
          content = candidate['content'];
        }
        // Strategy 4: Look for text field at candidate level
        else if (candidate['text'] != null) {
          content = candidate['text'];
        }
        // Strategy 5: Check for any field with "text" in the name
        else {
          for (final key in candidate.keys) {
            if (key.toLowerCase().contains('text') &&
                candidate[key] is String) {
              content = candidate[key];
              break;
            }
          }
        }

        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString().trim();
        }

        // If we still don't have content, log the structure and throw
        if (kDebugMode) {
          print('🤖 GeminiService: 🚨 Content extraction failed');
          print(
            '🤖 GeminiService: 📊 Candidate structure: ${jsonEncode(candidate)}',
          );
        }
      }

      // Last resort: check for any text-like field in the entire response
      final responseStr = jsonEncode(data);
      final textMatch = RegExp(
        r'"text"\s*:\s*"([^"]*)"',
      ).firstMatch(responseStr);
      if (textMatch != null) {
        final extractedText = textMatch.group(1);
        if (extractedText != null && extractedText.trim().isNotEmpty) {
          return extractedText.trim();
        }
      }

      throw Exception(
        'No valid content found in response - Full response: ${jsonEncode(data)}',
      );
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Invalid JSON response: $responseBody');
      }
      rethrow;
    }
  }

  // 🔧 OPTIMIZED: Shorter, more focused prompt to avoid token limits
  String _buildVoicePrompt(String voiceText, List<Habit> habits) {
    final habitNames = habits.map((h) => h.name).toList();

    return '''Voice: "$voiceText"
Habits: ${habitNames.join(', ')}

JSON only:
{"habit": "exact name or null", "action": "completed/skipped/none", "confidence": 0.8, "note": null}

Rules:
- completed: done, finished, did
- skipped: missed, didn't, forgot
- exact habit name from list''';
  }

  Map<String, dynamic> _parseVoiceResponse(String response) {
    try {
      // Handle potential truncation - find the JSON part
      String cleanResponse = response
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      // If response was truncated, try to complete the JSON
      if (!cleanResponse.endsWith('}')) {
        // Find the last complete field
        final lastCommaIndex = cleanResponse.lastIndexOf(',');
        final lastQuoteIndex = cleanResponse.lastIndexOf('"');

        if (lastCommaIndex > lastQuoteIndex) {
          // Remove incomplete field and close JSON
          cleanResponse = '${cleanResponse.substring(0, lastCommaIndex)}}';
        } else if (lastQuoteIndex > 0) {
          // Add closing quote and brace
          cleanResponse = '$cleanResponse"}';
        } else {
          // Try to find any JSON-like structure
          final jsonMatch = RegExp(r'\{[^}]*\}').firstMatch(cleanResponse);
          if (jsonMatch != null) {
            cleanResponse = jsonMatch.group(0)!;
          }
        }
      }

      if (kDebugMode) {
        print('🤖 GeminiService: 🧹 Cleaned response: $cleanResponse');
      }

      final parsed = jsonDecode(cleanResponse);

      return {
        'habit': parsed['habit'],
        'action': parsed['action'] ?? 'none',
        'confidence': (parsed['confidence'] ?? 0.0).toDouble().clamp(0.0, 1.0),
        'note': parsed['note'],
      };
    } catch (e) {
      if (kDebugMode) {
        print('🤖 GeminiService: ❌ Failed to parse AI response: $e');
        print('🤖 GeminiService: 📝 Raw response: $response');
      }
      return _createErrorResponse('Failed to parse AI response');
    }
  }

  Map<String, dynamic> _fallbackProcessing(
    String voiceText,
    List<Habit> userHabits,
  ) {
    if (kDebugMode) {
      print('🤖 GeminiService: 🔄 Using fallback processing for: "$voiceText"');
    }

    final lowerText = voiceText.toLowerCase();
    Habit? bestMatch;
    double bestScore = 0.0;

    // Find best matching habit with improved algorithm
    for (final habit in userHabits) {
      final score = _calculateHabitMatchScore(
        lowerText,
        habit.name.toLowerCase(),
      );
      if (score > bestScore && score > 0.2) {
        // Lower threshold for better matching
        bestScore = score;
        bestMatch = habit;
      }
    }

    if (bestMatch == null) {
      return _createErrorResponse('No matching habit found');
    }

    // Determine action with improved detection
    String action = 'none';
    double actionConfidence = 0.5;

    if (_containsCompletionWords(lowerText)) {
      action = 'completed';
      actionConfidence = 0.8;
    } else if (_containsSkipWords(lowerText)) {
      action = 'skipped';
      actionConfidence = 0.7;
    }

    final finalConfidence = (bestScore * actionConfidence).clamp(0.0, 1.0);

    final result = {
      'habit': bestMatch.name,
      'action': action,
      'confidence': finalConfidence,
      'note': 'Processed with fallback algorithm',
    };

    if (kDebugMode) {
      print('🤖 GeminiService: 🎯 Fallback result: $result');
    }
    return result;
  }

  // 🔧 IMPROVED: Better habit matching algorithm
  double _calculateHabitMatchScore(String input, String habitName) {
    final inputWords = input.split(' ').where((w) => w.length > 2).toList();
    final habitWords = habitName.split(' ').where((w) => w.length > 2).toList();

    if (habitWords.isEmpty) return 0.0;

    int exactMatches = 0;
    int partialMatches = 0;

    for (final habitWord in habitWords) {
      bool foundPartial = false;

      for (final inputWord in inputWords) {
        if (inputWord == habitWord) {
          exactMatches++;
          break;
        } else if (inputWord.contains(habitWord) ||
            habitWord.contains(inputWord)) {
          if (!foundPartial) {
            partialMatches++;
            foundPartial = true;
          }
        }
      }
    }

    // Weight exact matches more heavily
    final score =
        (exactMatches * 1.0 + partialMatches * 0.6) / habitWords.length;
    return score.clamp(0.0, 1.0);
  }

  bool _containsCompletionWords(String text) {
    const words = [
      'completed',
      'done',
      'finished',
      'did',
      'accomplished',
      'complete',
    ];
    return words.any((word) => text.contains(word));
  }

  bool _containsSkipWords(String text) {
    const words = [
      'skipped',
      'missed',
      'didn\'t',
      'not',
      'forgot',
      'skip',
      'miss',
    ];
    return words.any((word) => text.contains(word));
  }

  // 🔧 OPTIMIZED: Shorter insight prompt
  String _buildInsightPrompt(Map<String, dynamic> analyticsData) {
    return '''Stats: ${analyticsData['totalHabits'] ?? 0} habits, ${analyticsData['recentLogs'] ?? 0} completed, ${analyticsData['bestStreak'] ?? 0} best streak, ${analyticsData['completionRate'] ?? 0}% rate.

Write motivational insight (max 40 words):''';
  }

  /// Build chatbot prompt for conversation
  String _buildChatbotPrompt(
    String userMessage,
    List<Habit> userHabits,
    List<Map<String, String>> conversationHistory,
  ) {
    final habitNames = userHabits.map((h) => h.name).toList();
    final contextInfo = habitNames.isNotEmpty
        ? 'User habits: ${habitNames.join(', ')}'
        : 'User has no habits yet';

    // Build conversation context
    String conversationContext = '';
    if (conversationHistory.isNotEmpty) {
      final recentHistory = conversationHistory
          .take(4)
          .toList(); // Last 4 messages
      for (final msg in recentHistory) {
        conversationContext += '${msg['role']}: ${msg['message']}\n';
      }
    }

    return '''You are a helpful habit coach and wellness assistant. Focus ONLY on:
- Habit formation and tracking
- Health and wellness advice
- Motivation and goal setting
- Exercise, nutrition, sleep, mindfulness
- Productivity and self-improvement

$contextInfo

${conversationContext.isNotEmpty ? 'Recent conversation:\n$conversationContext\n' : ''}User: $userMessage

Rules:
- ONLY answer questions about habits, health, wellness, and self-improvement
- If asked about unrelated topics, politely redirect to habits/wellness
- Keep responses helpful, motivational, and under 100 words
- Be personal and supportive
- Suggest specific, actionable advice

Response:''';
  }

  /// Generate fallback chatbot response
  String _generateFallbackChatResponse(
    String userMessage,
    List<Habit> userHabits,
  ) {
    final lowerMessage = userMessage.toLowerCase();

    // Check for common topics and provide relevant responses
    if (lowerMessage.contains('habit') || lowerMessage.contains('routine')) {
      return 'Building habits takes time and consistency. Start small with just one habit and focus on doing it daily for 21 days. What habit would you like to work on?';
    } else if (lowerMessage.contains('motivation') ||
        lowerMessage.contains('give up')) {
      return 'Remember why you started! Every small step counts toward your bigger goals. Even if you miss a day, you can always start fresh tomorrow. What\'s one small thing you can do today?';
    } else if (lowerMessage.contains('goal') ||
        lowerMessage.contains('target')) {
      return 'Great goals are specific and achievable! Instead of "exercise more," try "walk 10 minutes daily." What specific goal would you like to set?';
    } else if (lowerMessage.contains('stress') ||
        lowerMessage.contains('anxiety')) {
      return 'Stress management is crucial for habit success. Try deep breathing, short walks, or 5-minute meditation. Building calm routines helps everything else fall into place.';
    } else if (lowerMessage.contains('sleep') ||
        lowerMessage.contains('tired')) {
      return 'Good sleep is the foundation of all habits! Try a consistent bedtime routine: no screens 1 hour before bed, dim lights, and the same sleep schedule daily.';
    } else {
      return 'I\'m here to help with habits, wellness, and healthy living! Feel free to ask about building routines, staying motivated, or reaching your health goals. What would you like to work on?';
    }
  }

  String _generateFallbackInsight(Map<String, dynamic> analyticsData) {
    final completionRate = analyticsData['completionRate'] as int? ?? 0;
    final bestStreak = analyticsData['bestStreak'] as int? ?? 0;

    if (completionRate >= 80) {
      return "Outstanding $completionRate% completion! Your $bestStreak-day streak shows incredible consistency. Keep momentum by focusing on your easiest habit tomorrow.";
    } else if (completionRate >= 60) {
      return "Great $completionRate% progress! Your $bestStreak-day streak demonstrates commitment. Pick one habit to prioritize this week for even better results.";
    } else if (completionRate >= 40) {
      return "Building momentum at $completionRate%! Every step counts. Focus on one simple habit today to boost your confidence and streak.";
    } else {
      return "Starting strong with $completionRate%! Choose your easiest habit and commit to it for just 3 days. Small wins create lasting change.";
    }
  }

  /// Generate predictive insights using AI analysis
  Future<List<PredictiveInsight>> generatePredictiveInsights({
    required List<Habit> habits,
    required Map<String, dynamic> recentData,
    required List<HeatmapData> heatmapData,
  }) async {
    try {
      final insights = <PredictiveInsight>[];

      // Analyze each habit for predictive insights
      for (final habit in habits) {
        final habitInsights = await _analyzeHabitForInsights(
          habit,
          recentData,
          heatmapData,
        );
        insights.addAll(habitInsights);
      }

      // Add general behavioral insights
      final behavioralInsights = await _generateBehavioralInsights(
        habits,
        heatmapData,
      );
      insights.addAll(behavioralInsights);

      // Sort by confidence and return top insights
      insights.sort((a, b) => b.confidence.compareTo(a.confidence));
      return insights.take(10).toList(); // Return top 10 insights
    } catch (e) {
      if (kDebugMode) print('Error generating predictive insights: $e');
      return _generateFallbackInsights(habits);
    }
  }

  /// Analyze a specific habit for insights
  Future<List<PredictiveInsight>> _analyzeHabitForInsights(
    Habit habit,
    Map<String, dynamic> recentData,
    List<HeatmapData> heatmapData,
  ) async {
    final insights = <PredictiveInsight>[];

    // Find habit data in recent data
    final habitDataList =
        recentData['habits'] as List<Map<String, dynamic>>? ?? [];
    final habitData = habitDataList.firstWhere(
      (data) => data['id'] == habit.id,
      orElse: () => <String, dynamic>{},
    );

    final completions = habitData['completions'] as int? ?? 0;
    final uniqueDays = habitData['unique_days'] as int? ?? 0;
    final periodDays = recentData['period_days'] as int? ?? 30;

    final completionRate = periodDays > 0 ? completions / periodDays : 0.0;

    // Risk analysis
    if (completionRate < 0.3) {
      insights.add(
        PredictiveInsight(
          type: 'risk_warning',
          title: 'Habit at Risk',
          description:
              '${habit.name} completion is low (${(completionRate * 100).toInt()}%). Consider adjusting your approach.',
          confidence: 0.85,
          data: {
            'actionRecommendation':
                'Reduce frequency or break into smaller steps',
            'habitId': habit.id.toString(),
            'completionRate': completionRate,
          },
          generatedAt: DateTime.now(),
        ),
      );
    }

    // Success prediction
    if (completionRate > 0.7 && uniqueDays >= 7) {
      insights.add(
        PredictiveInsight(
          type: 'success_prediction',
          title: 'Strong Momentum',
          description:
              '${habit.name} shows excellent consistency. High chance of long-term success.',
          confidence: 0.9,
          data: {
            'actionRecommendation':
                'Consider adding a related habit to build on this success',
            'habitId': habit.id.toString(),
            'completionRate': completionRate,
            'uniqueDays': uniqueDays,
          },
          generatedAt: DateTime.now(),
        ),
      );
    }

    // Trend analysis
    if (heatmapData.length >= 14) {
      final recentHeatmap = heatmapData.take(7).toList();
      final previousHeatmap = heatmapData.skip(7).take(7).toList();

      final recentAvg = recentHeatmap.isNotEmpty
          ? recentHeatmap.map((d) => d.completionRate).reduce((a, b) => a + b) /
                recentHeatmap.length
          : 0.0;
      final previousAvg = previousHeatmap.isNotEmpty
          ? previousHeatmap
                    .map((d) => d.completionRate)
                    .reduce((a, b) => a + b) /
                previousHeatmap.length
          : 0.0;

      if (recentAvg > previousAvg + 0.2) {
        insights.add(
          PredictiveInsight(
            type: 'trend_positive',
            title: 'Improving Trend',
            description:
                'Your recent performance is trending upward. Keep the momentum!',
            confidence: 0.75,
            data: {
              'actionRecommendation':
                  'Stay consistent with your current approach',
              'habitId': habit.id.toString(),
              'recentAvg': recentAvg,
              'previousAvg': previousAvg,
            },
            generatedAt: DateTime.now(),
          ),
        );
      } else if (recentAvg < previousAvg - 0.2) {
        insights.add(
          PredictiveInsight(
            type: 'trend_negative',
            title: 'Declining Trend',
            description:
                'Performance has dipped recently. Time to reassess your strategy.',
            confidence: 0.8,
            data: {
              'actionRecommendation':
                  'Review what changed and adjust your routine',
              'habitId': habit.id.toString(),
              'recentAvg': recentAvg,
              'previousAvg': previousAvg,
            },
            generatedAt: DateTime.now(),
          ),
        );
      }
    }

    return insights;
  }

  /// Generate behavioral insights
  Future<List<PredictiveInsight>> _generateBehavioralInsights(
    List<Habit> habits,
    List<HeatmapData> heatmapData,
  ) async {
    final insights = <PredictiveInsight>[];

    if (heatmapData.isEmpty) return insights;

    // Analyze overall patterns
    final averageCompletion =
        heatmapData.map((d) => d.completionRate).reduce((a, b) => a + b) /
        heatmapData.length;

    // Weekend vs weekday analysis
    final weekendData = heatmapData
        .where(
          (d) =>
              d.date.weekday == DateTime.saturday ||
              d.date.weekday == DateTime.sunday,
        )
        .toList();
    final weekdayData = heatmapData
        .where(
          (d) =>
              d.date.weekday != DateTime.saturday &&
              d.date.weekday != DateTime.sunday,
        )
        .toList();

    if (weekendData.isNotEmpty && weekdayData.isNotEmpty) {
      final weekendAvg =
          weekendData.map((d) => d.completionRate).reduce((a, b) => a + b) /
          weekendData.length;
      final weekdayAvg =
          weekdayData.map((d) => d.completionRate).reduce((a, b) => a + b) /
          weekdayData.length;

      if (weekdayAvg > weekendAvg + 0.2) {
        insights.add(
          PredictiveInsight(
            type: 'behavioral_pattern',
            title: 'Weekend Challenge',
            description:
                'You perform better on weekdays. Weekends need more structure.',
            confidence: 0.7,
            data: {
              'actionRecommendation':
                  'Set specific weekend habit times or reminders',
              'weekdayAvg': weekdayAvg,
              'weekendAvg': weekendAvg,
            },
            generatedAt: DateTime.now(),
          ),
        );
      } else if (weekendAvg > weekdayAvg + 0.2) {
        insights.add(
          PredictiveInsight(
            type: 'behavioral_pattern',
            title: 'Weekday Struggle',
            description:
                'Weekends are your strong days. Weekdays need attention.',
            confidence: 0.7,
            data: {
              'actionRecommendation':
                  'Simplify weekday habits or add morning routines',
              'weekdayAvg': weekdayAvg,
              'weekendAvg': weekendAvg,
            },
            generatedAt: DateTime.now(),
          ),
        );
      }
    }

    // Overall performance insight
    if (averageCompletion > 0.8) {
      insights.add(
        PredictiveInsight(
          type: 'performance_excellent',
          title: 'Exceptional Performance',
          description:
              'You\'re maintaining ${(averageCompletion * 100).toInt()}% completion rate. Excellent consistency!',
          confidence: 0.95,
          data: {
            'actionRecommendation': 'Consider adding a challenging new habit',
            'averageCompletion': averageCompletion,
          },
          generatedAt: DateTime.now(),
        ),
      );
    } else if (averageCompletion < 0.4) {
      insights.add(
        PredictiveInsight(
          type: 'performance_needs_attention',
          title: 'Focus Needed',
          description:
              'Overall completion is at ${(averageCompletion * 100).toInt()}%. Time to reassess your habit load.',
          confidence: 0.9,
          data: {
            'actionRecommendation':
                'Reduce to 1-2 core habits and build from there',
            'averageCompletion': averageCompletion,
          },
          generatedAt: DateTime.now(),
        ),
      );
    }

    return insights;
  }

  /// Generate fallback insights when AI fails
  List<PredictiveInsight> _generateFallbackInsights(List<Habit> habits) {
    return [
      PredictiveInsight(
        type: 'general_motivation',
        title: 'Keep Building',
        description:
            'Consistency is key to habit formation. Every day is a new opportunity.',
        confidence: 0.5,
        data: {
          'actionRecommendation':
              'Focus on one habit at a time for best results',
        },
        generatedAt: DateTime.now(),
      ),
      PredictiveInsight(
        type: 'general_tip',
        title: 'Start Small',
        description: 'Small, consistent actions lead to big changes over time.',
        confidence: 0.5,
        data: {
          'actionRecommendation':
              'Make your habits so small they\'re hard to fail',
        },
        generatedAt: DateTime.now(),
      ),
    ];
  }

  Map<String, dynamic> _createErrorResponse(String message) {
    return {
      'habit': null,
      'action': 'none',
      'confidence': 0.0,
      'note': message,
    };
  }

  void dispose() {
    _httpClient.close();
  }
}
