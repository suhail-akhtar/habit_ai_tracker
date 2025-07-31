package com.aaasofttech.aihabittracker

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Bundle
import android.os.PowerManager
import android.os.Vibrator
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.*

class AlarmActivity : Activity() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var isAlarmActive = true

    // UI Components
    private lateinit var timeText: TextView
    private lateinit var habitText: TextView
    private lateinit var messageText: TextView
    private lateinit var dismissButton: Button
    private lateinit var snoozeButton: Button

    // Alarm data
    private var habitName: String = ""
    private var habitMessage: String = ""
    private var habitIds: String = ""
    private var notificationId: Int = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Extract data from intent
        habitName = intent.getStringExtra("habit_name") ?: "Habit Reminder"
        habitMessage = intent.getStringExtra("habit_message") ?: "Time to complete your habit!"
        habitIds = intent.getStringExtra("habit_ids") ?: ""
        notificationId = intent.getIntExtra("notification_id", 0)

        setupFullScreenActivity()
        setContentView(R.layout.activity_alarm)

        initializeViews()
        setupButtons()
        acquireWakeLock()
        startAlarm()
        updateTimeDisplay()
    }

    private fun setupFullScreenActivity() {
        // Make activity full-screen and show over lock screen
        window.addFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        // Hide system UI for true full-screen experience
        window.decorView.systemUiVisibility =
                (View.SYSTEM_UI_FLAG_FULLSCREEN or
                        View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
    }

    private fun initializeViews() {
        timeText = findViewById(R.id.alarm_time)
        habitText = findViewById(R.id.alarm_habit_name)
        messageText = findViewById(R.id.alarm_message)
        dismissButton = findViewById(R.id.alarm_dismiss)
        snoozeButton = findViewById(R.id.alarm_snooze)

        // Set habit information
        habitText.text = habitName
        messageText.text = habitMessage
    }

    private fun setupButtons() {
        dismissButton.setOnClickListener { dismissAlarm() }

        snoozeButton.setOnClickListener { snoozeAlarm() }
    }

    private fun updateTimeDisplay() {
        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
        timeText.text = timeFormat.format(Date())

        // Update every second if alarm is still active
        if (isAlarmActive) {
            timeText.postDelayed({ updateTimeDisplay() }, 1000)
        }
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock =
                powerManager.newWakeLock(
                        PowerManager.FULL_WAKE_LOCK or
                                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                                PowerManager.ON_AFTER_RELEASE,
                        "HabitTracker:AlarmWakeLock"
                )
        wakeLock?.acquire(10 * 60 * 1000L) // 10 minutes max
    }

    private fun startAlarm() {
        startAlarmSound()
        startVibration()
    }

    private fun startAlarmSound() {
        try {
            val alarmUri =
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            mediaPlayer =
                    MediaPlayer().apply {
                        setDataSource(this@AlarmActivity, alarmUri)
                        isLooping = true
                        setAudioStreamType(AudioManager.STREAM_ALARM)
                        prepare()
                        start()
                    }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startVibration() {
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

        // Vibration pattern: wait, vibrate, wait, vibrate, etc.
        val pattern = longArrayOf(0, 1000, 1000, 1000, 1000, 1000)

        if (vibrator?.hasVibrator() == true) {
            vibrator?.vibrate(pattern, 0) // Repeat indefinitely
        }
    }

    private fun dismissAlarm() {
        isAlarmActive = false
        stopAlarm()

        // Send result back to Flutter app to mark habit as completed
        sendResultToFlutter(
                "alarm_dismissed",
                mapOf(
                        "action" to "alarm_dismissed",
                        "habit_ids" to habitIds,
                        "notification_id" to notificationId
                )
        )

        finish()
    }

    private fun snoozeAlarm() {
        isAlarmActive = false
        stopAlarm()

        // Show snooze time picker dialog
        showSnoozeTimeDialog()
    }

    private fun showSnoozeTimeDialog() {
        val snoozeOptions = arrayOf("5 minutes", "10 minutes", "15 minutes", "30 minutes", "Custom")
        val snoozeMinutes = arrayOf(5, 10, 15, 30, -1) // -1 for custom

        AlertDialog.Builder(this)
                .setTitle("Snooze for how long?")
                .setItems(snoozeOptions) { _, which ->
                    if (which == snoozeOptions.size - 1) {
                        // Custom option selected
                        showCustomSnoozeDialog()
                    } else {
                        // Predefined option selected
                        scheduleSnooze(snoozeMinutes[which])
                    }
                }
                .setNegativeButton("Cancel") { _, _ ->
                    // User cancelled snooze, restart alarm
                    isAlarmActive = true
                    startAlarm()
                }
                .setCancelable(false)
                .show()
    }

    private fun showCustomSnoozeDialog() {
        val editText =
                EditText(this).apply {
                    hint = "Enter minutes (minimum 5)"
                    inputType = android.text.InputType.TYPE_CLASS_NUMBER
                }

        AlertDialog.Builder(this)
                .setTitle("Custom Snooze Time")
                .setMessage("Enter snooze time in minutes:")
                .setView(editText)
                .setPositiveButton("OK") { _, _ ->
                    val input = editText.text.toString()
                    val minutes = input.toIntOrNull() ?: 5
                    val snoozeTime = if (minutes < 5) 5 else minutes // Minimum 5 minutes
                    scheduleSnooze(snoozeTime)
                }
                .setNegativeButton("Cancel") { _, _ ->
                    showSnoozeTimeDialog() // Go back to main snooze dialog
                }
                .setCancelable(false)
                .show()
    }

    private fun scheduleSnooze(minutes: Int) {
        // Send snooze request to Flutter app
        sendResultToFlutter(
                "alarm_snoozed",
                mapOf(
                        "action" to "alarm_snoozed",
                        "snooze_minutes" to minutes,
                        "habit_ids" to habitIds,
                        "notification_id" to notificationId
                )
        )

        finish()
    }

    private fun sendResultToFlutter(action: String, data: Map<String, Any>) {
        try {
            // Broadcast intent that MainActivity can listen for
            val broadcastIntent =
                    Intent("com.aaasofttech.aihabittracker.ALARM_ACTION").apply {
                        putExtra("alarm_action", action)
                        putExtra("habit_ids", habitIds)
                        putExtra("notification_id", notificationId)
                        data.forEach { (key, value) ->
                            when (value) {
                                is String -> putExtra(key, value)
                                is Int -> putExtra(key, value)
                                is Boolean -> putExtra(key, value)
                            }
                        }
                    }
            sendBroadcast(broadcastIntent)
            println("✅ Sent alarm action broadcast: $action")
        } catch (e: Exception) {
            println("❌ Failed to send broadcast to Flutter: ${e.message}")
        }
    }

    private fun stopAlarm() {
        mediaPlayer?.let {
            if (it.isPlaying) {
                it.stop()
            }
            it.release()
        }
        mediaPlayer = null

        vibrator?.cancel()
        vibrator = null
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Prevent dismissing alarm with back button
        // User must use dismiss button
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarm()
        wakeLock?.release()
    }

    override fun onPause() {
        super.onPause()
        // Keep alarm active even when paused
        // Don't call stopAlarm() here
    }
}
