package com.example.habit_ai_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HabitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_habit).apply {
                val streak = widgetData.getInt("streak", 0)
                val completed = widgetData.getInt("completed_count", 0)
                val total = widgetData.getInt("total_count", 0)
                val percent = widgetData.getInt("percent", 0)

                setTextViewText(R.id.widget_streak_text, "$streak 🔥")
                setTextViewText(R.id.widget_progress_text, "$completed/$total")
                setProgressBar(R.id.widget_progress_bar, 100, percent, false)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
