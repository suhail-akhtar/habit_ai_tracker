import 'package:flutter/foundation.dart';
import '../services/speech_service.dart';
import '../services/gemini_service.dart';
import '../models/habit.dart';
import 'habit_provider.dart';

class VoiceProvider with ChangeNotifier {
  final SpeechService _speechService = SpeechService();
  final GeminiService _geminiService = GeminiService();

  bool _isInitialized = false;
  bool _isListening = false;
  String _currentWords = '';
  String _status = 'Not initialized';
  double _confidence = 0.0;
  String? _error;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentWords => _currentWords;
  String get status => _status;
  double get confidence => _confidence;
  String? get error => _error;

  Future<void> initialize() async {
    try {
      _isInitialized = await _speechService.initialize();
      _status = _isInitialized ? 'Ready' : 'Failed to initialize';

      // Listen to speech service streams
      _speechService.wordsStream.listen((words) {
        _currentWords = words;
        notifyListeners();
      });

      _speechService.listeningStream.listen((listening) {
        _isListening = listening;
        _status = listening ? 'Listening...' : 'Ready';
        notifyListeners();
      });

      _clearError();
    } catch (e) {
      _setError('Failed to initialize voice recognition: $e');
    }
    notifyListeners();
  }

  Future<void> startListening() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized) {
      _setError('Voice recognition not available');
      return;
    }

    try {
      _clearError();
      _status = 'Starting...';
      notifyListeners();

      final result = await _speechService.startListening();

      if (result != null && result.isNotEmpty) {
        _currentWords = result;
        _status = 'Processing...';
        notifyListeners();
      } else {
        _status = 'No speech detected';
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to start listening: $e');
    }
  }

  void stopListening() {
    _speechService.stopListening();
    _status = 'Stopped';
    notifyListeners();
  }

  Future<Map<String, dynamic>> processVoiceInput(
    String voiceText,
    List<Habit> userHabits,
  ) async {
    try {
      _status = 'Processing with AI...';
      notifyListeners();

      final result =
          await _geminiService.processVoiceInput(voiceText, userHabits);

      _confidence = result['confidence'] ?? 0.0;
      _status = 'Processed';
      _clearError();

      notifyListeners();
      return result;
    } catch (e) {
      _setError('Failed to process voice input: $e');
      return {
        'habit': null,
        'action': 'none',
        'confidence': 0.0,
        'note': null,
      };
    }
  }

  Future<void> executeVoiceCommand(
    Map<String, dynamic> command,
    HabitProvider habitProvider,
  ) async {
    try {
      final habitName = command['habit'] as String?;
      final action = command['action'] as String?;
      final note = command['note'] as String?;

      if (habitName == null || action == null || action == 'none') {
        _setError('Could not understand the command');
        return;
      }

      // Find the habit by name
      final habit = habitProvider.habits.firstWhere(
        (h) => h.name.toLowerCase() == habitName.toLowerCase(),
        orElse: () => throw Exception('Habit not found'),
      );

      if (action == 'completed') {
        await habitProvider.logHabitCompletion(
          habit.id!,
          note: note,
          inputMethod: 'voice',
        );
        _status = 'Habit logged successfully';
      } else if (action == 'skipped') {
        await habitProvider.logHabitSkip(
          habit.id!,
          note: note,
        );
        _status = 'Habit skip logged';
      }

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to execute voice command: $e');
    }
  }

  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) return [];
    return await _speechService.getAvailableLanguages();
  }

  void _setError(String error) {
    _error = error;
    _status = 'Error: $error';
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _speechService.dispose();
    super.dispose();
  }
}
