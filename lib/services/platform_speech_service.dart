import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PlatformSpeechService {
  static const MethodChannel _channel = MethodChannel('habit_tracker/speech');
  static final PlatformSpeechService _instance =
      PlatformSpeechService._internal();
  factory PlatformSpeechService() => _instance;
  PlatformSpeechService._internal();

  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';
  double _confidenceLevel = 0.0;

  // Stream controllers for reactive updates
  final StreamController<String> _wordsController =
      StreamController<String>.broadcast();
  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();
  final StreamController<double> _confidenceController =
      StreamController<double>.broadcast();
  final StreamController<SpeechError> _errorController =
      StreamController<SpeechError>.broadcast();

  // Public streams
  Stream<String> get wordsStream => _wordsController.stream;
  Stream<bool> get listeningStream => _listeningController.stream;
  Stream<double> get confidenceStream => _confidenceController.stream;
  Stream<SpeechError> get errorStream => _errorController.stream;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  double get confidenceLevel => _confidenceLevel;

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      // Check and request permissions
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        _emitError(
          SpeechError(
            type: SpeechErrorType.permissionDenied,
            message: 'Microphone permission denied',
          ),
        );
        return false;
      }

      // Setup method call handler
      _channel.setMethodCallHandler(_handleMethodCall);

      // Initialize platform-specific speech recognition
      final result = await _channel.invokeMethod<bool>('initialize') ?? false;

      _isInitialized = result;

      if (_isInitialized) {
        if (kDebugMode) {
          print('Platform speech service initialized successfully');
        }
      } else {
        _emitError(
          SpeechError(
            type: SpeechErrorType.initializationFailed,
            message: 'Failed to initialize speech recognition',
          ),
        );
      }

      return _isInitialized;
    } catch (e) {
      _emitError(
        SpeechError(
          type: SpeechErrorType.unknown,
          message: 'Initialization error: $e',
        ),
      );
      return false;
    }
  }

  /// Handle method calls from platform
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSpeechResult':
        final Map<String, dynamic> result = Map<String, dynamic>.from(
          call.arguments,
        );
        _lastWords = result['recognizedWords'] ?? '';
        _confidenceLevel = (result['confidence'] ?? 0.0).toDouble();

        _wordsController.add(_lastWords);
        _confidenceController.add(_confidenceLevel);
        break;

      case 'onListeningStateChanged':
        _isListening = call.arguments as bool;
        _listeningController.add(_isListening);
        break;

      case 'onError':
        final Map<String, dynamic> error = Map<String, dynamic>.from(
          call.arguments,
        );
        _emitError(
          SpeechError(
            type: _parseErrorType(error['errorType'] ?? 'unknown'),
            message: error['message'] ?? 'Unknown error',
          ),
        );
        break;
    }
  }

  /// Start listening for speech input
  Future<String?> startListening({
    Duration listenFor = const Duration(seconds: 10),
    String? localeId,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    if (_isListening) {
      if (kDebugMode) print('Already listening');
      return null;
    }

    try {
      final result = await _channel.invokeMethod<String>('startListening', {
        'listenDuration': listenFor.inSeconds,
        'localeId': localeId ?? 'en_US',
      });

      return result;
    } catch (e) {
      _emitError(
        SpeechError(
          type: SpeechErrorType.listeningFailed,
          message: 'Failed to start listening: $e',
        ),
      );
      return null;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _channel.invokeMethod('stopListening');
    } catch (e) {
      _emitError(
        SpeechError(
          type: SpeechErrorType.unknown,
          message: 'Error stopping speech recognition: $e',
        ),
      );
    }
  }

  /// Cancel current listening session
  Future<void> cancel() async {
    if (!_isListening) return;

    try {
      await _channel.invokeMethod('cancel');
      _lastWords = '';
      _confidenceLevel = 0.0;
      _wordsController.add('');
      _confidenceController.add(0.0);
    } catch (e) {
      _emitError(
        SpeechError(
          type: SpeechErrorType.unknown,
          message: 'Error canceling speech recognition: $e',
        ),
      );
    }
  }

  /// Get available languages
  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) return [];

    try {
      final result = await _channel.invokeListMethod<String>(
        'getAvailableLanguages',
      );
      return result ?? [];
    } catch (e) {
      _emitError(
        SpeechError(
          type: SpeechErrorType.unknown,
          message: 'Error getting available languages: $e',
        ),
      );
      return [];
    }
  }

  /// Request microphone permission
  Future<bool> _requestMicrophonePermission() async {
    try {
      var status = await Permission.microphone.status;

      if (status.isDenied) {
        status = await Permission.microphone.request();
      }

      return status.isGranted;
    } catch (e) {
      _emitError(
        SpeechError(
          type: SpeechErrorType.permissionDenied,
          message: 'Permission request failed: $e',
        ),
      );
      return false;
    }
  }

  /// Parse error types
  SpeechErrorType _parseErrorType(String errorType) {
    switch (errorType.toLowerCase()) {
      case 'permission':
        return SpeechErrorType.permissionDenied;
      case 'network':
        return SpeechErrorType.networkError;
      case 'audio':
        return SpeechErrorType.audioError;
      case 'initialization':
        return SpeechErrorType.initializationFailed;
      case 'listening':
        return SpeechErrorType.listeningFailed;
      default:
        return SpeechErrorType.unknown;
    }
  }

  /// Emit error to stream
  void _emitError(SpeechError error) {
    _errorController.add(error);
    if (kDebugMode) {
      print('Platform Speech Service Error: ${error.message}');
    }
  }

  /// Check if device has speech recognition capability
  Future<bool> get hasRecognitionSupport async {
    if (!_isInitialized) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasRecognitionSupport');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Dispose of resources
  void dispose() {
    _wordsController.close();
    _listeningController.close();
    _confidenceController.close();
    _errorController.close();
  }
}

/// Speech service error class
class SpeechError {
  final SpeechErrorType type;
  final String message;
  final bool permanent;

  const SpeechError({
    required this.type,
    required this.message,
    this.permanent = false,
  });

  @override
  String toString() => 'SpeechError(type: $type, message: $message)';
}

/// Speech error types
enum SpeechErrorType {
  permissionDenied,
  initializationFailed,
  listeningFailed,
  networkError,
  audioError,
  unknown,
}
