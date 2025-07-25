package com.example.habit_ai_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var notificationMethodChannel: MethodChannel
    private lateinit var alarmActionReceiver: BroadcastReceiver
    private lateinit var ringingActionReceiver: BroadcastReceiver

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(SpeechToTextPlugin())

        // Register the notification method channel
        notificationMethodChannel =
                MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        "habit_tracker/notifications"
                )
        notificationMethodChannel.setMethodCallHandler(NotificationMethodChannel(this))

        // Set up broadcast receivers
        setupBroadcastReceivers()
    }

    private fun setupBroadcastReceivers() {

        println("🔥 MainActivity: Setting up broadcast receivers")

        // Alarm action receiver
        alarmActionReceiver =
                object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        println("🔥 MainActivity: Alarm broadcast received!")
                        intent?.let { handleAlarmResult(it) }
                    }
                }

        // Ringing action receiver
        ringingActionReceiver =
                object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        println("🔥 MainActivity: Ringing broadcast received!")
                        intent?.let { handleRingingResult(it) }
                    }
                }

        // Register receivers with RECEIVER_NOT_EXPORTED flag for Android 13+ (API 33+)
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            registerReceiver(
                    alarmActionReceiver,
                    IntentFilter("com.example.habit_ai_tracker.ALARM_ACTION"),
                    Context.RECEIVER_NOT_EXPORTED
            )
            registerReceiver(
                    ringingActionReceiver,
                    IntentFilter("com.example.habit_ai_tracker.RINGING_ACTION"),
                    Context.RECEIVER_NOT_EXPORTED
            )
        } else {
            registerReceiver(
                    alarmActionReceiver,
                    IntentFilter("com.example.habit_ai_tracker.ALARM_ACTION")
            )
            registerReceiver(
                    ringingActionReceiver,
                    IntentFilter("com.example.habit_ai_tracker.RINGING_ACTION")
            )
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(alarmActionReceiver)
            unregisterReceiver(ringingActionReceiver)
        } catch (e: Exception) {
            // Receivers may not be registered
        }
    }

    private fun handleAlarmResult(data: Intent) {
        println("🔥 MainActivity: handleAlarmResult called")
        val action = data.getStringExtra("alarm_action") ?: return
        val habitIds = data.getStringExtra("habit_ids") ?: ""
        val notificationId = data.getIntExtra("notification_id", 0)

        println(
                "🔥 MainActivity: action=$action, habitIds=$habitIds, notificationId=$notificationId"
        )

        val resultData =
                mapOf(
                        "action" to action,
                        "habit_ids" to habitIds,
                        "notification_id" to notificationId
                )

        when (action) {
            "alarm_dismissed" -> {
                println("🔥 MainActivity: Calling onAlarmDismissed method channel")
                notificationMethodChannel.invokeMethod("onAlarmDismissed", resultData)
            }
            "alarm_snoozed" -> {
                val snoozeMinutes = data.getIntExtra("snooze_minutes", 5)
                val snoozeData = resultData + ("snooze_minutes" to snoozeMinutes)
                println("🔥 MainActivity: Calling onAlarmSnoozed method channel")
                notificationMethodChannel.invokeMethod("onAlarmSnoozed", snoozeData)
            }
        }
    }

    private fun handleRingingResult(data: Intent) {
        println("🔥 MainActivity: handleRingingResult called")
        val action = data.getStringExtra("ringing_action") ?: return
        val habitIds = data.getStringExtra("habit_ids") ?: ""
        val notificationId = data.getIntExtra("notification_id", 0)

        println(
                "🔥 MainActivity: action=$action, habitIds=$habitIds, notificationId=$notificationId"
        )

        val resultData =
                mapOf(
                        "action" to action,
                        "habit_ids" to habitIds,
                        "notification_id" to notificationId
                )

        when (action) {
            "call_answered" -> {
                println("🔥 MainActivity: Calling onCallAnswered method channel")
                notificationMethodChannel.invokeMethod("onCallAnswered", resultData)
            }
            "call_declined" -> {
                println("🔥 MainActivity: Calling onCallDeclined method channel")
                notificationMethodChannel.invokeMethod("onCallDeclined", resultData)
            }
        }
    }
}
