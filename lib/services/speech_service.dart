import 'dart:async';
import 'package:flutter_speech/flutter_speech.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  final SpeechRecognition _speech = SpeechRecognition();
  bool _isListening = false;
  bool _isAvailable = false;
  String _lastWords = '';

  final StreamController<String> _wordsController =
      StreamController<String>.broadcast();
  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();

  Stream<String> get wordsStream => _wordsController.stream;
  Stream<bool> get listeningStream => _listeningController.stream;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get lastWords => _lastWords;

  Future<bool> initialize() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print('Microphone permission denied');
        return false;
      }

      _isAvailable = await _speech.activate('en_US');

      if (_isAvailable) {
        _speech.setRecognitionResultHandler((String text) {
          _lastWords = text;
          _wordsController.add(_lastWords);
        });

        _speech.setRecognitionStartedHandler(() {
          _isListening = true;
          _listeningController.add(true);
        });

        _speech.setRecognitionCompleteHandler((String text) {
          _isListening = false;
          _listeningController.add(false);
        });
      }

      return _isAvailable;
    } catch (e) {
      print('Error initializing speech recognition: $e');
      return false;
    }
  }

  Future<String?> startListening({
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_isAvailable) {
      print('Speech recognition not available');
      return null;
    }

    if (_isListening) {
      print('Already listening');
      return null;
    }

    final completer = Completer<String?>();

    try {
      _speech.listen();

      Timer(listenFor, () {
        if (!completer.isCompleted) {
          _speech.stop();
          completer.complete(_lastWords.isNotEmpty ? _lastWords : null);
        }
      });

      return await completer.future;
    } catch (e) {
      print('Error starting speech recognition: $e');
      return null;
    }
  }

  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
      _listeningController.add(false);
    }
  }

  Future<List<String>> getAvailableLanguages() async {
    if (!_isAvailable) return [];
    return ['en_US', 'en_GB', 'es_ES', 'fr_FR', 'de_DE'];
  }

  void dispose() {
    _wordsController.close();
    _listeningController.close();
    _speech.stop();
  }
}
