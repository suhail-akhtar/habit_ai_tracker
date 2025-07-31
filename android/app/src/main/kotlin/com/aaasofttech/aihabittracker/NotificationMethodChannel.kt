package com.aaasofttech.aihabittracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class NotificationMethodChannel(private val context: Context) : MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "habit_tracker/notifications"
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scheduleCustomNotification" -> {
                scheduleCustomNotification(call, result)
            }
            "triggerCustomNotification" -> {
                triggerCustomNotificationImmediately(call, result)
            }
            "scheduleSnoozeNotification" -> {
                scheduleSnoozeNotification(call, result)
            }
            "cancelCustomNotification" -> {
                cancelCustomNotification(call, result)
            }
            "cancelAllCustomNotifications" -> {
                cancelAllCustomNotifications(result)
            }
            "requestSystemAlertPermission" -> {
                requestSystemAlertPermission(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun triggerCustomNotificationImmediately(call: MethodCall, result: Result) {
        try {
            val notificationId = call.argument<Int>("notification_id") ?: 0
            val habitName = call.argument<String>("habit_name") ?: "Habit Reminder"
            val habitMessage =
                    call.argument<String>("habit_message") ?: "Time to complete your habit!"
            val habitIds = call.argument<String>("habit_ids") ?: ""
            val type = call.argument<String>("type") ?: "simple"

            // Immediately trigger the notification (for testing)
            triggerCustomNotification(notificationId, habitName, habitMessage, habitIds, type)

            result.success(true)
        } catch (e: Exception) {
            result.error("TRIGGER_ERROR", e.message, null)
        }
    }

    private fun scheduleCustomNotification(call: MethodCall, result: Result) {
        try {
            val notificationId = call.argument<Int>("notification_id") ?: 0
            val habitName = call.argument<String>("habit_name") ?: "Habit Reminder"
            val habitMessage =
                    call.argument<String>("habit_message") ?: "Time to complete your habit!"
            val habitIds = call.argument<String>("habit_ids") ?: ""
            val scheduledTime = call.argument<Long>("scheduled_time") ?: 0L
            val type = call.argument<String>("type") ?: "simple"

            // Schedule the notification using AlarmManager for the specified time
            scheduleNotificationAlarm(
                    notificationId,
                    habitName,
                    habitMessage,
                    habitIds,
                    scheduledTime,
                    type
            )

            result.success(true)
        } catch (e: Exception) {
            result.error("SCHEDULING_ERROR", e.message, null)
        }
    }

    private fun scheduleNotificationAlarm(
            notificationId: Int,
            habitName: String,
            habitMessage: String,
            habitIds: String,
            scheduledTime: Long,
            type: String
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Create intent for the notification receiver
        val intent =
                Intent(context, NotificationReceiver::class.java).apply {
                    putExtra("notification_id", notificationId)
                    putExtra("habit_name", habitName)
                    putExtra("habit_message", habitMessage)
                    putExtra("habit_ids", habitIds)
                    putExtra("type", type)
                    action =
                            when (type) {
                                "alarm" -> "HABIT_ALARM_TRIGGER"
                                "ringing" -> "HABIT_RINGING_TRIGGER"
                                else -> "HABIT_SIMPLE_TRIGGER"
                            }
                }

        val pendingIntent =
                PendingIntent.getBroadcast(
                        context,
                        notificationId,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

        // Schedule the alarm
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        scheduledTime,
                        pendingIntent
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, scheduledTime, pendingIntent)
            }

            println(
                    "✅ Scheduled notification alarm for ID: $notificationId at time: $scheduledTime"
            )
        } catch (e: Exception) {
            println("❌ Failed to schedule alarm: ${e.message}")
        }
    }

    private fun scheduleSnoozeNotification(call: MethodCall, result: Result) {
        try {
            val notificationId = call.argument<Int>("notification_id") ?: 0
            val habitName = call.argument<String>("habit_name") ?: "Habit Reminder"
            val habitMessage =
                    call.argument<String>("habit_message") ?: "Time to complete your habit!"
            val habitIds = call.argument<String>("habit_ids") ?: ""
            val snoozeMinutes = call.argument<Int>("snooze_minutes") ?: 5
            val type = call.argument<String>("type") ?: "alarm"

            // Calculate snooze time (current time + snooze minutes)
            val snoozeTime = System.currentTimeMillis() + (snoozeMinutes * 60 * 1000L)

            // Schedule the snooze alarm
            scheduleNotificationAlarm(
                    notificationId,
                    habitName,
                    habitMessage,
                    habitIds,
                    snoozeTime,
                    type
            )

            println(
                    "✅ Scheduled snooze notification for ID: $notificationId in $snoozeMinutes minutes"
            )
            result.success(true)
        } catch (e: Exception) {
            println("❌ Failed to schedule snooze notification: ${e.message}")
            result.error("SNOOZE_SCHEDULING_ERROR", e.message, null)
        }
    }

    private fun triggerCustomNotification(
            notificationId: Int,
            habitName: String,
            habitMessage: String,
            habitIds: String,
            type: String
    ) {
        val intent =
                when (type) {
                    "alarm" -> Intent(context, AlarmActivity::class.java)
                    "ringing" -> Intent(context, RingingActivity::class.java)
                    else -> return
                }

        println(
                "🔥 Triggering custom notification: $type for ID: $notificationId, Habit: $habitName"
        )
        intent.apply {
            putExtra("notification_id", notificationId)
            putExtra("habit_name", habitName)
            putExtra("habit_message", habitMessage)
            putExtra("habit_ids", habitIds)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        context.startActivity(intent)
    }

    private fun cancelCustomNotification(call: MethodCall, result: Result) {
        try {
            val notificationId = call.argument<Int>("notification_id") ?: 0

            // Cancel the scheduled alarm
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, NotificationReceiver::class.java)
            val pendingIntent =
                    PendingIntent.getBroadcast(
                            context,
                            notificationId,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()

            println("✅ Cancelled notification alarm for ID: $notificationId")
            result.success(true)
        } catch (e: Exception) {
            result.error("CANCELLATION_ERROR", e.message, null)
        }
    }

    private fun cancelAllCustomNotifications(result: Result) {
        try {
            // This is a basic implementation - in a real app you'd keep track of all notification
            // IDs
            // For now, we'll just return success as the main cancellation happens through the
            // regular notification service
            result.success(true)
        } catch (e: Exception) {
            result.error("CANCELLATION_ERROR", e.message, null)
        }
    }
    private fun requestSystemAlertPermission(result: Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(context)) {
                    // Permission already granted
                    result.success(true)
                } else {
                    // Request permission by opening settings
                    val intent =
                            Intent(
                                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                            Uri.parse("package:${context.packageName}")
                                    )
                                    .apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }

                    try {
                        context.startActivity(intent)
                        // Note: We can't know immediately if permission was granted
                        // The app should check again when needed
                        result.success(false) // Indicates permission request was initiated
                    } catch (e: Exception) {
                        result.error(
                                "PERMISSION_REQUEST_FAILED",
                                "Could not open system alert permission settings: ${e.message}",
                                null
                        )
                    }
                }
            } else {
                // No permission needed for older Android versions
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }
}
