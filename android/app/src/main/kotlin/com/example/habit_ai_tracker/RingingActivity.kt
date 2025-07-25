package com.example.habit_ai_tracker

import android.app.Activity
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
import android.view.animation.Animation
import android.view.animation.ScaleAnimation
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.TextView

class RingingActivity : Activity() {
    
    private var wakeLock: PowerManager.WakeLock? = null
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var isRinging = true
    
    // UI Components
    private lateinit var habitIconView: ImageView
    private lateinit var habitNameText: TextView
    private lateinit var habitMessageText: TextView
    private lateinit var answerButton: ImageButton
    private lateinit var declineButton: ImageButton
    
    // Ringing data
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
        
        setupCallScreenActivity()
        setContentView(R.layout.activity_ringing)
        
        initializeViews()
        setupButtons()
        acquireWakeLock()
        startRinging()
        startPulseAnimation()
    }
    
    private fun setupCallScreenActivity() {
        // Setup call-like full-screen experience
        window.addFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
        
        // Call-like UI (less aggressive than alarm)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_FULLSCREEN
    }
    
    private fun initializeViews() {
        habitIconView = findViewById(R.id.ringing_habit_icon)
        habitNameText = findViewById(R.id.ringing_habit_name)
        habitMessageText = findViewById(R.id.ringing_habit_message)
        answerButton = findViewById(R.id.ringing_answer)
        declineButton = findViewById(R.id.ringing_decline)
        
        // Set habit information
        habitNameText.text = habitName
        habitMessageText.text = habitMessage
        
        // Set habit icon (default for now, could be customized)
        //habitIconView.setImageResource(R.drawable.ic_launcher_foreground)
    }
    
    private fun setupButtons() {
        answerButton.setOnClickListener {
            answerCall()
        }
        
        declineButton.setOnClickListener {
            declineCall()
        }
    }
    
    private fun startPulseAnimation() {
        val scaleAnimation = ScaleAnimation(
            1.0f, 1.2f, 1.0f, 1.2f,
            Animation.RELATIVE_TO_SELF, 0.5f,
            Animation.RELATIVE_TO_SELF, 0.5f
        ).apply {
            duration = 1000
            repeatMode = Animation.REVERSE
            repeatCount = Animation.INFINITE
        }
        
        habitIconView.startAnimation(scaleAnimation)
    }
    
    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or 
            PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "HabitTracker:RingingWakeLock"
        )
        wakeLock?.acquire(2 * 60 * 1000L) // 2 minutes max for ringing
    }
    
    private fun startRinging() {
        startRingtone()
        startCallVibration()
    }
    
    private fun startRingtone() {
        try {
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            
            mediaPlayer = MediaPlayer().apply {
                setDataSource(this@RingingActivity, ringtoneUri)
                isLooping = true
                setAudioStreamType(AudioManager.STREAM_RING)
                prepare()
                start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun startCallVibration() {
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        
        // Call-like vibration pattern (gentler than alarm)
        val pattern = longArrayOf(0, 1000, 1000, 1000, 1000)
        
        if (vibrator?.hasVibrator() == true) {
            vibrator?.vibrate(pattern, 0) // Repeat indefinitely
        }
    }
    
    private fun answerCall() {
        isRinging = false
        stopRinging()
        
        print("called");

        // Send result back to Flutter app to mark linked habits as completed
        sendResultToFlutter("call_answered", mapOf(
            "action" to "call_answered",
            "habit_ids" to habitIds,
            "notification_id" to notificationId
        ))
        
        finish()
    }
    
    private fun declineCall() {
        isRinging = false
        stopRinging()
        
        // Send result back to Flutter app to mark linked habits as skipped
        sendResultToFlutter("call_declined", mapOf(
            "action" to "call_declined",
            "habit_ids" to habitIds,
            "notification_id" to notificationId
        ))
        
        finish()
    }
    
    private fun sendResultToFlutter(action: String, data: Map<String, Any>) {
        try {
            // Broadcast intent that MainActivity can listen for
            val broadcastIntent = Intent("com.example.habit_ai_tracker.RINGING_ACTION").apply {
                putExtra("ringing_action", action)
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
            println("✅ Sent ringing action broadcast: $action")
        } catch (e: Exception) {
            println("❌ Failed to send broadcast to Flutter: ${e.message}")
        }
    }
    
    private fun stopRinging() {
        mediaPlayer?.let {
            if (it.isPlaying) {
                it.stop()
            }
            it.release()
        }
        mediaPlayer = null
        
        vibrator?.cancel()
        vibrator = null
        
        habitIconView.clearAnimation()
    }
    
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Allow back button for ringing (less aggressive than alarm)
        super.onBackPressed()
        declineCall()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopRinging()
        wakeLock?.release()
    }
    
    override fun onPause() {
        super.onPause()
        // Continue ringing in background briefly
        // Auto-dismiss after 30 seconds if not answered
        if (isRinging) {
            habitIconView.postDelayed({
                if (isRinging && !isFinishing) {
                    declineCall()
                }
            }, 30000) // 30 seconds timeout
        }
    }
}