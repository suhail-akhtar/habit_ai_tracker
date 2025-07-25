package com.example.habit_ai_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("NotificationReceiver", "Received intent: ${intent.action}")
        
        when (intent.action) {
            "HABIT_ALARM_TRIGGER" -> {
                handleAlarmTrigger(context, intent)
            }
            "HABIT_RINGING_TRIGGER" -> {
                handleRingingTrigger(context, intent)
            }
            else -> {
                Log.w("NotificationReceiver", "Unknown action: ${intent.action}")
            }
        }
    }
    
    private fun handleAlarmTrigger(context: Context, intent: Intent) {
        Log.d("NotificationReceiver", "Handling alarm trigger")
        
        val alarmIntent = Intent(context, AlarmActivity::class.java).apply {
            // Pass through all the notification data
            putExtra("habit_name", intent.getStringExtra("habit_name"))
            putExtra("habit_message", intent.getStringExtra("habit_message"))
            putExtra("notification_id", intent.getIntExtra("notification_id", 0))
            putExtra("habit_ids", intent.getStringExtra("habit_ids"))
            
            // Required flags for launching activity from broadcast receiver
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            
            // Ensure it shows over lock screen
            addFlags(Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT)
        }
        
        try {
            context.startActivity(alarmIntent)
            Log.d("NotificationReceiver", "Successfully started AlarmActivity")
        } catch (e: Exception) {
            Log.e("NotificationReceiver", "Failed to start AlarmActivity", e)
        }
    }
    
    private fun handleRingingTrigger(context: Context, intent: Intent) {
        Log.d("NotificationReceiver", "Handling ringing trigger")
        
        val ringingIntent = Intent(context, RingingActivity::class.java).apply {
            // Pass through all the notification data
            putExtra("habit_name", intent.getStringExtra("habit_name"))
            putExtra("habit_message", intent.getStringExtra("habit_message"))
            putExtra("notification_id", intent.getIntExtra("notification_id", 0))
            putExtra("habit_ids", intent.getStringExtra("habit_ids"))
            
            // Required flags for launching activity from broadcast receiver
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            
            // Ensure it shows over lock screen
            addFlags(Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT)
        }
        
        try {
            context.startActivity(ringingIntent)
            Log.d("NotificationReceiver", "Successfully started RingingActivity")
        } catch (e: Exception) {
            Log.e("NotificationReceiver", "Failed to start RingingActivity", e)
        }
    }
}