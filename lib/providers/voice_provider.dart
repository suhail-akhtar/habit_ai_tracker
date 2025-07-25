import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/platform_speech_service.dart';
import '../services/gemini_service.dart';
import '../models/habit.dart';
import 'habit_provider.dart';

class VoiceProvider with ChangeNotifier {
  final PlatformSpeechService _speechService = PlatformSpeechService();
  final GeminiService _geminiService = GeminiService();

  // State variables
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentWords = '';
  String _status = 'Not initialized';
  double _confidence = 0.0;
  String? _error;
  VoiceCommand? _lastCommand;
  bool _isProcessing = false;

  // Stream subscriptions
  final List<dynamic> _subscriptions = [];

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentWords => _currentWords;
  String get status => _status;
  double get confidence => _confidence;
  String? get error => _error;
  VoiceCommand? get lastCommand => _lastCommand;
  bool get isProcessing => _isProcessing;

  /// Initialize voice provider and speech service
  Future<void> initialize() async {
    try {
      _setStatus('Initializing...');
      _clearError();

      _isInitialized = await _speechService.initialize();

      if (_isInitialized) {
        _setupStreamListeners();
        _setStatus('Ready');

        if (kDebugMode) {
          print('VoiceProvider initialized successfully');
        }
      } else {
        _setError('Failed to initialize voice recognition');
        _setStatus('Failed');
      }
    } catch (e) {
      _setError('Initialization error: $e');
      _setStatus('Failed');
      if (kDebugMode) {
        print('VoiceProvider initialization failed: $e');
      }
    }
    notifyListeners();
  }

  /// Setup stream listeners for speech service
  void _setupStreamListeners() {
    // Words stream
    _subscriptions.add(
      _speechService.wordsStream.listen(
        (words) {
          _currentWords = words;
          notifyListeners();
        },
        onError: (error) {
          if (kDebugMode) print('Words stream error: $error');
        },
      ),
    );

    // Listening state stream
    _subscriptions.add(
      _speechService.listeningStream.listen(
        (listening) {
          _isListening = listening;
          _setStatus(listening ? 'Listening...' : 'Ready');

          // Provide haptic feedback
          if (listening) {
            HapticFeedback.lightImpact();
          } else {
            HapticFeedback.selectionClick();
          }

          notifyListeners();
        },
        onError: (error) {
          if (kDebugMode) print('Listening stream error: $error');
        },
      ),
    );

    // Confidence stream
    _subscriptions.add(
      _speechService.confidenceStream.listen(
        (confidence) {
          _confidence = confidence;
          notifyListeners();
        },
        onError: (error) {
          if (kDebugMode) print('Confidence stream error: $error');
        },
      ),
    );

    // Error stream
    _subscriptions.add(
      _speechService.errorStream.listen(
        (error) {
          // Only show user-facing errors for real problems
          if (error.type == SpeechErrorType.permissionDenied ||
              error.type == SpeechErrorType.initializationFailed ||
              error.type == SpeechErrorType.networkError ||
              error.type == SpeechErrorType.audioError) {
            _setError(error.message);
            _setStatus('Error');
            HapticFeedback.heavyImpact();
          } else {
            // For speech-related errors, just set a gentle status
            _setStatus('No speech detected - try again');
            _clearError();
            HapticFeedback.lightImpact();
          }
        },
        onError: (error) {
          if (kDebugMode) print('Error stream error: $error');
        },
      ),
    );
  }

  /// Start listening for voice input
  Future<void> startListening({Duration? duration, String? locale}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized) {
      _setError('Voice recognition not available');
      return;
    }

    if (_isListening) {
      if (kDebugMode) print('Already listening');
      return;
    }

    try {
      _clearError();
      _setStatus(
        'Preparing microphone...',
      ); // 🔧 IMPROVED: Better status messages
      _currentWords = '';

      // Provide haptic feedback
      HapticFeedback.lightImpact();

      // Show user instruction
      _setStatus('Listening... Speak now');

      final result = await _speechService.startListening(
        listenFor:
            duration ??
            const Duration(seconds: 25), // 🔧 INCREASED: Even longer duration
        localeId: locale,
      );

      if (result != null && result.isNotEmpty && result != "[Listening...]") {
        _currentWords = result;
        _setStatus('Speech captured! Processing...');
        HapticFeedback.mediumImpact();
      } else if (_currentWords.isNotEmpty) {
        // We have some words from partial results
        _setStatus('Processing speech...');
        HapticFeedback.lightImpact();
      } else {
        _setStatus('No clear speech detected. Please try again.');
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      _setError('Failed to start listening: $e');
      HapticFeedback.heavyImpact();
    }
    notifyListeners();
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechService.stopListening();
      HapticFeedback.selectionClick();
      _setStatus('Stopped');
    } catch (e) {
      _setError('Failed to stop listening: $e');
    }
    notifyListeners();
  }

  /// Cancel current listening session
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      await _speechService.cancel();
      _currentWords = '';
      _confidence = 0.0;
      HapticFeedback.lightImpact();
      _setStatus('Cancelled');
    } catch (e) {
      _setError('Failed to cancel listening: $e');
    }
    notifyListeners();
  }

  /// Process voice input with AI
  Future<VoiceCommand?> processVoiceInput(
    String voiceText,
    List<Habit> userHabits,
  ) async {
    if (voiceText.trim().isEmpty) return null;

    try {
      _setProcessing(true);
      _setStatus('Processing with AI...');

      final result = await _geminiService.processVoiceInput(
        voiceText,
        userHabits,
      );

      final command = VoiceCommand.fromMap(result);
      _lastCommand = command;

      _confidence = command.confidence;
      _setStatus('Processed');
      _clearError();

      if (command.confidence < 0.6) {
        _setStatus('Low confidence - please try again');
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }

      return command;
    } catch (e) {
      _setError('Failed to process voice input: $e');
      HapticFeedback.heavyImpact();
      return null;
    } finally {
      _setProcessing(false);
      notifyListeners();
    }
  }

  /// Execute voice command
  Future<bool> executeVoiceCommand(
    VoiceCommand command,
    HabitProvider habitProvider,
  ) async {
    try {
      if (command.habitName == null || command.action == VoiceAction.none) {
        _setError('Invalid command');
        return false;
      }

      // Find the habit by name
      final habit = habitProvider.habits.firstWhere(
        (h) => h.name.toLowerCase() == command.habitName!.toLowerCase(),
        orElse: () => throw Exception('Habit "${command.habitName}" not found'),
      );

      _setStatus('Executing command...');

      switch (command.action) {
        case VoiceAction.completed:
          await habitProvider.logHabitCompletion(
            habit.id!,
            note: command.note,
            inputMethod: 'voice',
          );
          _setStatus('✅ Habit completed successfully');
          HapticFeedback.heavyImpact();
          break;

        case VoiceAction.skipped:
          await habitProvider.logHabitSkip(habit.id!, note: command.note);
          _setStatus('⏭️ Habit skip logged');
          HapticFeedback.mediumImpact();
          break;

        case VoiceAction.reminder:
          // Handle reminder creation - will be implemented in UI layer
          _setStatus('📅 Reminder command detected');
          HapticFeedback.mediumImpact();
          break;

        case VoiceAction.createHabit:
          // Handle habit creation - will be implemented in UI layer
          _setStatus('➕ Create habit command detected');
          HapticFeedback.mediumImpact();
          break;

        case VoiceAction.none:
          _setError('No action specified');
          return false;
      }

      _clearError();
      return true;
    } catch (e) {
      _setError('Failed to execute command: $e');
      HapticFeedback.heavyImpact();
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Get available languages
  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) return [];

    try {
      return await _speechService.getAvailableLanguages();
    } catch (e) {
      _setError('Failed to get languages: $e');
      return [];
    }
  }

  /// Clear current words
  void clearWords() {
    _currentWords = '';
    _confidence = 0.0;
    _lastCommand = null;
    notifyListeners();
  }

  /// Check if speech recognition is supported
  Future<bool> get isSupported async {
    try {
      return await _speechService.hasRecognitionSupport;
    } catch (e) {
      return false;
    }
  }

  // Private helper methods
  void _setStatus(String status) {
    _status = status;
  }

  void _setError(String error) {
    _error = error;
    _status = 'Error: $error';
  }

  void _clearError() {
    _error = null;
  }

  void _setProcessing(bool processing) {
    _isProcessing = processing;
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      try {
        subscription.cancel();
      } catch (e) {
        if (kDebugMode) print('Error canceling subscription: $e');
      }
    }
    _subscriptions.clear();

    // Dispose services
    try {
      _speechService.dispose();
    } catch (e) {
      if (kDebugMode) print('Error disposing services: $e');
    }

    super.dispose();
  }
}

/// Voice command model
class VoiceCommand {
  final String? habitName;
  final VoiceAction action;
  final double confidence;
  final String? note;
  final DateTime timestamp;
  final DateTime? reminderTime;
  final String? reminderMessage;
  final String? newHabitName;
  final String? newHabitCategory;

  const VoiceCommand({
    this.habitName,
    required this.action,
    required this.confidence,
    this.note,
    required this.timestamp,
    this.reminderTime,
    this.reminderMessage,
    this.newHabitName,
    this.newHabitCategory,
  });

  factory VoiceCommand.fromMap(Map<String, dynamic> map) {
    return VoiceCommand(
      habitName: map['habit'],
      action: _parseAction(map['action']),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      note: map['note'],
      timestamp: DateTime.now(),
      reminderTime: map['reminder_time'] != null
          ? DateTime.tryParse(map['reminder_time'])
          : null,
      reminderMessage: map['reminder_message'],
      newHabitName: map['new_habit_name'],
      newHabitCategory: map['new_habit_category'],
    );
  }

  static VoiceAction _parseAction(String? action) {
    switch (action?.toLowerCase()) {
      case 'completed':
        return VoiceAction.completed;
      case 'skipped':
        return VoiceAction.skipped;
      case 'reminder':
      case 'remind':
        return VoiceAction.reminder;
      case 'create':
      case 'add':
        return VoiceAction.createHabit;
      default:
        return VoiceAction.none;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'habitName': habitName,
      'action': action.name,
      'confidence': confidence,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
      'reminderMessage': reminderMessage,
      'newHabitName': newHabitName,
      'newHabitCategory': newHabitCategory,
    };
  }

  @override
  String toString() {
    return 'VoiceCommand(habit: $habitName, action: $action, confidence: $confidence)';
  }
}

/// Voice action enum
enum VoiceAction { completed, skipped, none, reminder, createHabit }
