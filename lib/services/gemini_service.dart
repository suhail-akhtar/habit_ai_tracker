import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/habit.dart';
import '../config/app_config.dart';

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  Future<Map<String, dynamic>> processVoiceInput(
    String voiceText,
    List<Habit> userHabits,
  ) async {
    final prompt = _buildVoicePrompt(voiceText, userHabits);

    try {
      final response = await _callGeminiAPI(prompt);
      return _parseVoiceResponse(response);
    } catch (e) {
      print('Gemini API error: $e');
      return _fallbackProcessing(voiceText, userHabits);
    }
  }

  Future<String> generateWeeklyInsight(
      Map<String, dynamic> analyticsData) async {
    final prompt = _buildInsightPrompt(analyticsData);

    try {
      final response = await _callGeminiAPI(prompt);
      return response.trim();
    } catch (e) {
      print('Gemini insight generation error: $e');
      return _generateFallbackInsight(analyticsData);
    }
  }

  Future<List<String>> generateHabitSuggestions(String category) async {
    final prompt = '''
Generate 5 specific, actionable habit suggestions for the "$category" category.
Return only a JSON array of strings, no additional text.
Examples: ["Drink 8 glasses of water", "Take 10,000 steps", "Read for 30 minutes"]
''';

    try {
      final response = await _callGeminiAPI(prompt);
      final parsed = jsonDecode(response);
      if (parsed is List) {
        return parsed.cast<String>();
      }
    } catch (e) {
      print('Gemini suggestion generation error: $e');
    }

    return _getFallbackSuggestions(category);
  }

  String _buildVoicePrompt(String voiceText, List<Habit> habits) {
    final habitNames = habits.map((h) => h.name).join(', ');

    return '''
Analyze this voice input: "$voiceText"

User's habits: $habitNames

Return ONLY a JSON response with this exact format:
{
  "habit": "exact habit name from list or null",
  "action": "completed/skipped/none", 
  "confidence": 0.8,
  "note": "any additional context or null"
}

Rules:
- Match the closest habit name from the list
- If no clear match, return null for habit
- Action should be "completed" for positive words, "skipped" for negative, "none" if unclear
- Confidence should be 0.0-1.0
- Note should capture any mood or context mentioned
''';
  }

  String _buildInsightPrompt(Map<String, dynamic> analyticsData) {
    return '''
Based on this habit tracking data, provide a motivational weekly insight in exactly 50 words or less:

- Total habits: ${analyticsData['totalHabits']}
- Habits completed this week: ${analyticsData['recentLogs']}
- Best streak: ${analyticsData['bestStreak']} days
- Completion rate: ${analyticsData['completionRate']}%

Focus on encouragement and one specific actionable next step. Be personal and motivating.
''';
  }

  Future<String> _callGeminiAPI(String prompt) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': AppConfig.geminiApiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 200,
          'topP': 0.8,
          'topK': 10,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (content != null) {
        return content.toString().trim();
      }
    }

    throw Exception(
        'Failed to get response from Gemini API: ${response.statusCode}');
  }

  Map<String, dynamic> _parseVoiceResponse(String response) {
    try {
      // Clean the response to extract JSON
      final cleanResponse =
          response.replaceAll(RegExp(r'```json|```'), '').trim();
      final parsed = jsonDecode(cleanResponse);

      return {
        'habit': parsed['habit'],
        'action': parsed['action'] ?? 'none',
        'confidence': (parsed['confidence'] ?? 0.0).toDouble(),
        'note': parsed['note'],
      };
    } catch (e) {
      print('Error parsing Gemini response: $e');
      return {
        'habit': null,
        'action': 'none',
        'confidence': 0.0,
        'note': null,
      };
    }
  }

  Map<String, dynamic> _fallbackProcessing(
      String voiceText, List<Habit> userHabits) {
    final lowerText = voiceText.toLowerCase();

    // Simple keyword matching
    for (final habit in userHabits) {
      final habitWords = habit.name.toLowerCase().split(' ');
      final matchCount =
          habitWords.where((word) => lowerText.contains(word)).length;

      if (matchCount > 0) {
        String action = 'none';
        double confidence = matchCount / habitWords.length;

        if (lowerText.contains('completed') ||
            lowerText.contains('done') ||
            lowerText.contains('finished') ||
            lowerText.contains('did')) {
          action = 'completed';
          confidence = (confidence * 0.8).clamp(0.0, 1.0);
        } else if (lowerText.contains('skipped') ||
            lowerText.contains('missed') ||
            lowerText.contains('didn\'t') ||
            lowerText.contains('not')) {
          action = 'skipped';
          confidence = (confidence * 0.7).clamp(0.0, 1.0);
        }

        return {
          'habit': habit.name,
          'action': action,
          'confidence': confidence,
          'note': null,
        };
      }
    }

    return {
      'habit': null,
      'action': 'none',
      'confidence': 0.0,
      'note': null,
    };
  }

  String _generateFallbackInsight(Map<String, dynamic> analyticsData) {
    final completionRate = analyticsData['completionRate'] as int;
    final bestStreak = analyticsData['bestStreak'] as int;

    if (completionRate >= 80) {
      return "Amazing work! You're crushing your habits with a $completionRate% completion rate. Keep this momentum going and try adding one new habit to challenge yourself.";
    } else if (completionRate >= 60) {
      return "Great progress! You're completing $completionRate% of your habits. Your best streak is $bestStreak days - let's beat that record this week!";
    } else if (completionRate >= 40) {
      return "You're building momentum with a $completionRate% completion rate. Focus on consistency over perfection - even small steps count toward lasting change.";
    } else {
      return "Every journey starts with a single step. Your $completionRate% completion rate shows you're trying. Pick one habit to focus on this week and build from there.";
    }
  }

  List<String> _getFallbackSuggestions(String category) {
    final suggestions = {
      'health': [
        'Drink 8 glasses of water daily',
        'Take 10,000 steps',
        'Sleep 8 hours per night',
        'Eat 5 servings of fruits and vegetables',
        'Exercise for 30 minutes'
      ],
      'productivity': [
        'Write in a journal for 10 minutes',
        'Read for 30 minutes',
        'Plan tomorrow before bed',
        'Do a 5-minute meditation',
        'Organize workspace daily'
      ],
      'learning': [
        'Study a new language for 15 minutes',
        'Watch educational videos',
        'Take online course lessons',
        'Practice a musical instrument',
        'Learn one new fact daily'
      ],
      'social': [
        'Call a friend or family member',
        'Send a thoughtful message',
        'Practice gratitude',
        'Volunteer for a cause',
        'Join a community group'
      ],
      'creative': [
        'Write in a creative journal',
        'Draw or sketch for 20 minutes',
        'Take photos of interesting subjects',
        'Try a new recipe',
        'Listen to new music genres'
      ],
    };

    return suggestions[category.toLowerCase()] ?? suggestions['health']!;
  }
}
