import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TextToSpeechService {
  static const String _ttsEnabledKey = 'tts_enabled';
  static const String _speechRateKey = 'speech_rate';
  static const String _speechPitchKey = 'speech_pitch';
  static const String _speechVolumeKey = 'speech_volume';

  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isEnabled = false;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  double _volume = 0.8;

  // Singleton pattern
  static final TextToSpeechService _instance = TextToSpeechService._internal();
  factory TextToSpeechService() => _instance;
  TextToSpeechService._internal();

  /// Initialize the TTS service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();
      await _loadSettings();
      await _configureTts();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  /// Load TTS settings from shared preferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_ttsEnabledKey) ?? false;
      _speechRate = prefs.getDouble(_speechRateKey) ?? 0.5;
      _pitch = prefs.getDouble(_speechPitchKey) ?? 1.0;
      _volume = prefs.getDouble(_speechVolumeKey) ?? 0.8;
    } catch (e) {
      print('Error loading TTS settings: $e');
    }
  }

  /// Configure TTS settings
  Future<void> _configureTts() async {
    if (_flutterTts == null) return;

    try {
      await _flutterTts!.setLanguage("en-US");
      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setPitch(_pitch);
      await _flutterTts!.setVolume(_volume);

      // Set up completion handler
      _flutterTts!.setCompletionHandler(() {
        print('TTS completed');
      });

      // Set up error handler
      _flutterTts!.setErrorHandler((msg) {
        print('TTS Error: $msg');
      });
    } catch (e) {
      print('Error configuring TTS: $e');
    }
  }

  /// Speak the given text
  Future<void> speak(String text) async {
    if (!_isInitialized || !_isEnabled || _flutterTts == null) return;

    try {
      // Clean up text for better speech
      String cleanedText = _cleanTextForSpeech(text);

      // Stop any current speech
      await stop();

      // Speak the text
      await _flutterTts!.speak(cleanedText);
    } catch (e) {
      print('Error speaking text: $e');
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    if (_flutterTts == null) return;

    try {
      await _flutterTts!.stop();
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }

  /// Pause current speech
  Future<void> pause() async {
    if (_flutterTts == null) return;

    try {
      await _flutterTts!.pause();
    } catch (e) {
      print('Error pausing TTS: $e');
    }
  }

  /// Clean text for better speech synthesis
  String _cleanTextForSpeech(String text) {
    // Remove markdown formatting
    String cleaned = text
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // Bold
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // Italic
        .replaceAll(RegExp(r'__(.*?)__'), r'$1') // Underline
        .replaceAll(RegExp(r'`(.*?)`'), r'$1') // Code
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1') // Links
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // Headers
        .replaceAll(RegExp(r'^\s*[-*+]\s*', multiLine: true), '') // Lists
        .replaceAll(
          RegExp(r'^\s*\d+\.\s*', multiLine: true),
          '',
        ) // Numbered lists
        .replaceAll(RegExp(r'\n+'), ' ') // Multiple newlines
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces
        .trim();

    // Replace common abbreviations for better pronunciation
    cleaned = cleaned
        .replaceAll('AI', 'A I')
        .replaceAll('TTS', 'text to speech')
        .replaceAll('API', 'A P I')
        .replaceAll('URL', 'U R L')
        .replaceAll('SMS', 'S M S')
        .replaceAll('GPS', 'G P S');

    return cleaned;
  }

  /// Enable or disable TTS
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_ttsEnabledKey, enabled);
    } catch (e) {
      print('Error saving TTS enabled setting: $e');
    }
  }

  /// Set speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);

    try {
      if (_flutterTts != null) {
        await _flutterTts!.setSpeechRate(_speechRate);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_speechRateKey, _speechRate);
    } catch (e) {
      print('Error setting speech rate: $e');
    }
  }

  /// Set speech pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);

    try {
      if (_flutterTts != null) {
        await _flutterTts!.setPitch(_pitch);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_speechPitchKey, _pitch);
    } catch (e) {
      print('Error setting pitch: $e');
    }
  }

  /// Set speech volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);

    try {
      if (_flutterTts != null) {
        await _flutterTts!.setVolume(_volume);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_speechVolumeKey, _volume);
    } catch (e) {
      print('Error setting volume: $e');
    }
  }

  /// Get available voices
  Future<List<dynamic>> getVoices() async {
    if (_flutterTts == null) return [];

    try {
      return await _flutterTts!.getVoices ?? [];
    } catch (e) {
      print('Error getting voices: $e');
      return [];
    }
  }

  /// Set voice by name
  Future<void> setVoice(Map<String, String> voice) async {
    if (_flutterTts == null) return;

    try {
      await _flutterTts!.setVoice(voice);
    } catch (e) {
      print('Error setting voice: $e');
    }
  }

  /// Get available languages
  Future<List<dynamic>> getLanguages() async {
    if (_flutterTts == null) return [];

    try {
      return await _flutterTts!.getLanguages ?? [];
    } catch (e) {
      print('Error getting languages: $e');
      return [];
    }
  }

  /// Set language
  Future<void> setLanguage(String language) async {
    if (_flutterTts == null) return;

    try {
      await _flutterTts!.setLanguage(language);
    } catch (e) {
      print('Error setting language: $e');
    }
  }

  /// Check if TTS is available
  Future<bool> isAvailable() async {
    if (_flutterTts == null) return false;

    try {
      final languages = await getLanguages();
      return languages.isNotEmpty;
    } catch (e) {
      print('Error checking TTS availability: $e');
      return false;
    }
  }

  /// Check if currently speaking
  Future<bool> isSpeaking() async {
    if (_flutterTts == null) return false;

    try {
      // Note: This is a placeholder implementation
      // The actual TTS speaking status would need platform-specific implementation
      return false;
    } catch (e) {
      return false;
    }
  }

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  double get volume => _volume;

  /// Dispose resources
  Future<void> dispose() async {
    if (_flutterTts != null) {
      await stop();
      _flutterTts = null;
    }
    _isInitialized = false;
  }
}
