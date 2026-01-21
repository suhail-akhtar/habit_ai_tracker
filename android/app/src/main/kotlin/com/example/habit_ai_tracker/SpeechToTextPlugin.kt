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
                package com.ai.habittracker.app

                // Legacy file retained intentionally (deprecated). No classes here.
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