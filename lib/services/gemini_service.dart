import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/habit.dart';
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
      bool foundExact = false;
      bool foundPartial = false;

      for (final inputWord in inputWords) {
        if (inputWord == habitWord) {
          exactMatches++;
          foundExact = true;
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
