package com.example.habit_ai_tracker

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*

class SpeechToTextPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var hasReceivedSpeech = false  // 🔧 NEW: Track if we got any speech

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "habit_tracker/speech")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                initialize(result)
            }
            "startListening" -> {
                val listenDuration = call.argument<Int>("listenDuration") ?: 20
                val localeId = call.argument<String>("localeId") ?: "en_US"
                startListening(listenDuration, localeId, result)
            }
            "stopListening" -> {
                stopListening(result)
            }
            "cancel" -> {
                cancel(result)
            }
            "getAvailableLanguages" -> {
                getAvailableLanguages(result)
            }
            "hasRecognitionSupport" -> {
                hasRecognitionSupport(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initialize(result: Result) {
        try {
            if (SpeechRecognizer.isRecognitionAvailable(context)) {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
                setupRecognitionListener()
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    private fun setupRecognitionListener() {
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                isListening = true
                hasReceivedSpeech = false  // 🔧 RESET: Clear speech flag
                channel.invokeMethod("onListeningStateChanged", true)
            }

            override fun onBeginningOfSpeech() {
                hasReceivedSpeech = true  // 🔧 MARK: We detected speech start
                // Send partial result to show we're detecting speech
                channel.invokeMethod("onSpeechResult", mapOf(
                    "recognizedWords" to "[Listening...]",
                    "confidence" to 0.1
                ))
            }

            override fun onRmsChanged(rmsdB: Float) {
                // RMS value changed - we can use this to show audio levels
            }

            override fun onBufferReceived(buffer: ByteArray?) {
                // Buffer received
            }

            override fun onEndOfSpeech() {
                isListening = false
                channel.invokeMethod("onListeningStateChanged", false)
            }

            override fun onError(error: Int) {
                isListening = false
                channel.invokeMethod("onListeningStateChanged", false)
                
                // 🔧 IMPROVED: Better error handling - only show real errors
                val shouldShowError = when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH -> !hasReceivedSpeech  // Only error if no speech detected
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> !hasReceivedSpeech  // Only error if no speech detected
                    else -> true  // Show other errors normally
                }

                if (shouldShowError) {
                    val errorMessage = when (error) {
                        SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                        SpeechRecognizer.ERROR_CLIENT -> "Client side error"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission required"
                        SpeechRecognizer.ERROR_NETWORK -> "Network error"
                        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                        SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected - please try speaking closer to the microphone"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy - please try again"
                        SpeechRecognizer.ERROR_SERVER -> "Server error"
                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech detected - please try speaking"
                        else -> "Unknown error occurred"
                    }

                    val errorType = when (error) {
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "permission"
                        SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "network"
                        SpeechRecognizer.ERROR_AUDIO -> "audio"
                        else -> "speech"
                    }

                    channel.invokeMethod("onError", mapOf(
                        "errorType" to errorType,
                        "message" to errorMessage
                    ))
                } else {
                    // If we had speech but no match, just end gracefully
                    channel.invokeMethod("onSpeechResult", mapOf(
                        "recognizedWords" to "",
                        "confidence" to 0.0
                    ))
                }
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val confidenceScores = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
                
                if (!matches.isNullOrEmpty()) {
                    val recognizedText = matches[0]
                    val confidence = confidenceScores?.get(0)?.toDouble() ?: 0.8
                    
                    channel.invokeMethod("onSpeechResult", mapOf(
                        "recognizedWords" to recognizedText,
                        "confidence" to confidence
                    ))
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty() && matches[0].isNotEmpty()) {
                    hasReceivedSpeech = true  // 🔧 MARK: We have partial speech
                    channel.invokeMethod("onSpeechResult", mapOf(
                        "recognizedWords" to matches[0],
                        "confidence" to 0.5
                    ))
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {
                // Event occurred
            }
        })
    }

    private fun startListening(listenDuration: Int, localeId: String, result: Result) {
        try {
            if (isListening) {
                result.error("ALREADY_LISTENING", "Speech recognition is already active", null)
                return
            }

            hasReceivedSpeech = false  // 🔧 RESET: Clear speech detection flag

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId.replace("_", "-"))
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                
                // 🔧 OPTIMIZED: More forgiving timeout settings
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 15000L)  // 15 seconds of silence
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 8000L)  // 8 seconds for partial
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 300L)  // 300ms minimum
                
                // 🔧 NEW: Additional parameters for better recognition
                putExtra("android.speech.extra.DICTATION_MODE", true)
                putExtra("android.speech.extra.GET_AUDIO_FORMAT", "audio/AMR")
                putExtra("android.speech.extra.GET_AUDIO", true)
                
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)  // Get multiple results
            }

            speechRecognizer?.startListening(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("START_LISTENING_ERROR", e.message, null)
        }
    }

    private fun stopListening(result: Result) {
        try {
            speechRecognizer?.stopListening()
            isListening = false
            result.success(null)
        } catch (e: Exception) {
            result.error("STOP_LISTENING_ERROR", e.message, null)
        }
    }

    private fun cancel(result: Result) {
        try {
            speechRecognizer?.cancel()
            isListening = false
            hasReceivedSpeech = false  // 🔧 RESET: Clear flags
            result.success(null)
        } catch (e: Exception) {
            result.error("CANCEL_ERROR", e.message, null)
        }
    }

    private fun getAvailableLanguages(result: Result) {
        val languages = listOf(
            "en_US", "en_GB", "es_ES", "fr_FR", "de_DE", "it_IT", 
            "ja_JP", "ko_KR", "zh_CN", "pt_BR", "ru_RU"
        )
        result.success(languages)
    }

    private fun hasRecognitionSupport(result: Result) {
        val isAvailable = SpeechRecognizer.isRecognitionAvailable(context)
        result.success(isAvailable)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        speechRecognizer?.destroy()
    }
}