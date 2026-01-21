package com.ai.habittracker.app

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
			speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
			result.success(true)
		} catch (e: Exception) {
			result.error("INIT_ERROR", e.message, null)
		}
	}

	private fun startListening(listenDuration: Int, localeId: String, result: Result) {
		if (!SpeechRecognizer.isRecognitionAvailable(context)) {
			result.error("NOT_AVAILABLE", "Speech recognition not available", null)
			return
		}

		if (ActivityCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
			!= PackageManager.PERMISSION_GRANTED
		) {
			result.error("PERMISSION", "Record audio permission not granted", null)
			return
		}

		if (speechRecognizer == null) {
			speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
		}

		hasReceivedSpeech = false
		isListening = true

		speechRecognizer?.setRecognitionListener(object : RecognitionListener {
			override fun onReadyForSpeech(params: Bundle?) {
				channel.invokeMethod("onListeningStateChanged", true)
			}

			override fun onBeginningOfSpeech() {}

			override fun onRmsChanged(rmsdB: Float) {}

			override fun onBufferReceived(buffer: ByteArray?) {}

			override fun onEndOfSpeech() {}

			override fun onError(error: Int) {
				isListening = false
				channel.invokeMethod("onListeningStateChanged", false)

				if (!hasReceivedSpeech && error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
					channel.invokeMethod("onError", "timeout")
					return
				}

				channel.invokeMethod("onError", error.toString())
			}

			override fun onResults(results: Bundle?) {
				isListening = false
				channel.invokeMethod("onListeningStateChanged", false)
				hasReceivedSpeech = true

				val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
				val confidenceScores = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
				val text = matches?.firstOrNull() ?: ""
				val confidence = confidenceScores?.firstOrNull() ?: 0f

				channel.invokeMethod(
					"onSpeechResult",
					mapOf(
						"recognizedWords" to text,
						"confidence" to confidence
					)
				)
			}

			override fun onPartialResults(partialResults: Bundle?) {
				val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
				val text = matches?.firstOrNull() ?: ""
				channel.invokeMethod("onSpeechResult", mapOf("recognizedWords" to text, "confidence" to 0.0))
			}

			override fun onEvent(eventType: Int, params: Bundle?) {}
		})

		val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
		intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
		intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId)
		intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
		intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, listenDuration * 1000)
		intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1000)
		intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 500)

		speechRecognizer?.startListening(intent)
		result.success(true)
	}

	private fun stopListening(result: Result) {
		if (!isListening) {
			result.success(true)
			return
		}
		speechRecognizer?.stopListening()
		isListening = false
		result.success(true)
	}

	private fun cancel(result: Result) {
		speechRecognizer?.cancel()
		isListening = false
		result.success(true)
	}

	private fun getAvailableLanguages(result: Result) {
		val locales = Locale.getAvailableLocales()
		val languages = locales.map { it.toLanguageTag() }.distinct()
		result.success(languages)
	}

	private fun hasRecognitionSupport(result: Result) {
		result.success(SpeechRecognizer.isRecognitionAvailable(context))
	}

	override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
		channel.setMethodCallHandler(null)
		speechRecognizer?.destroy()
		speechRecognizer = null
	}
}
