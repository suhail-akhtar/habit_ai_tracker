# Habit AI Tracker - Native Android Migration Specification

## 1. Project Overview
*   **App Name**: Habit AI Tracker
*   **Platform**: Android Native
*   **Language**: Kotlin
*   **UI Framework**: Jetpack Compose (Material Design 3)
*   **Architecture**: MVVM + Clean Architecture with Repository Pattern
*   **Dependency Injection**: Hilt (Dagger)
*   **Goal**: Re-create the complete Flutter "Habit AI Tracker" application as a native Android app to solve background reliability issues and leverage native APIs for Voice and AI integration.

## 2. Core Features & UX

### 2.1. Dashboard (`DashboardScreen`)
*   **Greeting**: "Good Morning/Afternoon/Evening" + Motivational Subtext.
*   **Bento Grid**: A summary grid showing:
    *   **Focus**: Current active habit or "Next up".
    *   **Streak**: Current active streak count.
    *   **Tip**: Daily AI-generated motivational tip.
    *   **Progress**: Circular indicator of day's completion (e.g., 3/5 habits).
*   **Habit List**:
    *   Vertical scrolling list of active habits for *today*.
    *   **Habit Card**:
        *   Displays: Title, Description (optional), Icon, Progress (0/1 or X/N).
        *   **Actions**:
            *   **Tap**: Toggle completion (mark done) or open details. (Behavior varies based on `targetFrequency`).
            *   **Long Press**: Context menu (Edit, Delete, Stats).
        *   **Visuals**: Custom color coding per habit.

### 2.2. Voice Input (`VoiceInputScreen`)
*   **UI**:
    *   Full-screen or large modal overlay.
    *   **Visualizer**: Animated waveform/bars reacting to microphone input amplitude.
    *   **Live Transcription**: Real-time text display of what the user is saying ("I drank 2 glasses of water...").
    *   **Status**: "Listening...", "Processing...", "Success".
*   **Functionality**:
    *   Uses native `SpeechRecognizer` for offline-capable, low-latency transcription.
    *   **Auto-Process**: Option to automatically send to AI after silence is detected.
    *   **Magical AI Parsing**: The transcribed text is sent to Gemini AI to infer actions.
        *   *User says*: "I went for a run and drank water."
        *   *App actions*: Marks "Running" as complete, increments "Water" by 1.

### 2.3. Habit Creation/Edit (`HabitSetupScreen`)
*   **Fields**:
    *   **Name**: Text input.
    *   **Description**: Optional text.
    *   **Category**: Dropdown/Chip selection (Health, Productivity, Mindfulness, etc.).
    *   **Icon**: Grid selection of MDI icons.
    *   **Color**: Color picker.
*   **Scheduling (Flexible)**:
    *   **Frequency**: "X times per [Day/Week/Month]".
    *   **Details**: Interval minutes (e.g., "Every 60 mins"), Specific Window (Start Time - End Time).
*   **Notifications**:
    *   **Enable/Disable**.
    *   **Time**: TimePicker.
    *   **Type**: Simple, Ringing (Persistent), Alarm (Full Screen).

### 2.4. Analytics (`AnalyticsScreen`)
*   **Heatmap**: GitHub-style contribution graph (green squares) showing activity over the last 3-6 months.
*   **Completion Rate**: Monthly/Weekly Charts (Bar/Line).
*   **Streaks**: Display longest and current streaks.
*   **Insights**: AI-generated weekly summary based on performance.
*   **Habit Specific**: Drill-down view for a single habit's history.

### 2.5. Settings
*   **Theme**: Light/Dark/System.
*   **Notifications**: Global toggle, "Fix Permissions" wizard (for Xiaomi/Samsung autostart).
*   **Data**: Export/Import (JSON), Clear Data.

---

## 3. Data Architecture (Room Database)

### 3.1. Entity: `Habit`
```kotlin
@Entity(tableName = "habits")
data class Habit(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val description: String?,
    val category: String, // e.g., 'Health'
    val iconName: String, // e.g., 'water_drop' - map to R.drawable or Vector
    val colorCode: Long, // 0xFF2196F3
    
    // Scheduling
    val frequencyType: String, // 'daily', 'weekly', 'interval'
    val targetFrequency: Int, // e.g., 3 (times per day)
    val intervalMinutes: Int?, // For periodic reminders
    val windowStartTime: String?, // "09:00"
    val windowEndTime: String?, // "21:00"

    // Notifications
    val isReminderEnabled: Boolean,
    val reminderTime: String?, // "08:00"
    val notificationType: String, // 'simple', 'ringing', 'alarm'
    
    // Status
    val isActive: Boolean = true,
    val isArchived: Boolean = false,
    
    val createdAt: Long = System.currentTimeMillis()
)
```

### 3.2. Entity: `HabitLog`
```kotlin
@Entity(
    tableName = "habit_logs",
    indices = [Index(value = ["habitId"])]
)
data class HabitLog(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val habitId: Long,
    val timestamp: Long, // Exact time of completion
    val dateKey: String, // "YYYY-MM-DD" for fast querying of daily stats
    val value: Int = 1, // Usually 1, but could be "500" for "500ml water"
    val status: String, // 'completed', 'skipped'
    val source: String, // 'manual', 'voice', 'notification'
    val note: String? // "Logged via voice: 'drank water'"
)
```

### 3.3. Entity: `UserSettings`
*   Key-Value store (or use DataStore Preferences) for:
    *   `theme_mode`
    *   `is_premium`
    *   `user_name`
    *   `last_app_open`

---

## 4. Technical Implementation Details

### 4.1. The AI Engine (Gemini)
*   **Repository**: `GeminiRepository`
*   **Input**: Natural Language String + List of Active Habits (Names + IDs).
*   **Prompt Engineering**:
    > "You are a habit tracking assistant. The user says: '$input'. Available habits: ${habitsJson}. Return a JSON array of actions: [{habit_id: 1, action: 'complete', count: 1}]. If no match, return suggestions."
*   **Response Handling**:
    *   Parse JSON response.
    *   Execute database transactions to insert `HabitLog`s.
    *   Return feedback to UI: "Marked Water and Running as done."

### 4.2. Notification System (The "Robust" Design)
*   **Dependencies**:
    *   `androidx.work:work-runtime-ktx` (WorkManager) ? NO. Use **AlarmManager** for exact timing.
    *   `android.permission.SCHEDULE_EXACT_ALARM`.
    *   `android.permission.USE_FULL_SCREEN_INTENT`.
*   **Components**:
    1.  `AlarmScheduler`: Wrapper around `AlarmManager`.
    2.  `NotificationReceiver` (BroadcastReceiver):
        *   Triggered by AlarmManager.
        *   Builds the Notification.
        *   Handles "Ringing" sound looping (MediaPlayer or Notification sound).
    3.  `ActionReceiver` (BroadcastReceiver):
        *   Handles "Mark Done" / "Skip" button taps from the notification tray purely in background.
    4.  `FullScreenAlarmActivity`:
        *   A transparent or full-screen Activity that launches if `notificationType == 'alarm'`.
        *   Shows the "Did you do it?" dialog over the lock screen.

### 4.3. Navigation Graph
*   `NavHost` -> `MainScaffold` -> `BottomNavigation`
    *   Route: `dashboard`
    *   Route: `analytics`
    *   Route: `settings`
*   Modals/Full Screens:
    *   `voice_input` (Dialog or Full Screen)
    *   `habit_detail/{habitId}`
    *   `habit_setup?habitId={id}`

---

## 5. Migration Steps for AI Agent

1.  **Project Setup**:
    *   Create new Android Project (Compose, Material3).
    *   Add libs: Room, Hilt, Retrofit, Navigation, Accompanist (Permissions).

2.  **Domain & Data**:
    *   Create `Habit` and `HabitLog` data classes.
    *   Implement `HabitDao` and `AppDatabase`.
    *   Create `HabitRepository`.

3.  **UI Construction**:
    *   Build `HabitCard` composable.
    *   Build `DashboardScreen` with `LazyColumn`.
    *   Implement `VoiceInputScreen` using `SpeechRecognizer`.

4.  **Logic & Services**:
    *   Port `GeminiService.dart` logic to `GeminiRepository.kt` (using Retrofit).
    *   Implement the `AlarmScheduler` logic.

5.  **Refinement**:
    *   Add the "Heatmap" custom view (Canvas or Grid).
    *   Polish animations (Lottie or Compose Animation).

## 6. Prompting Guide (for Generating Code)

When asking an AI to generate the native code, use these specific prompts contexts:

*   **For UI**: "Create a Jetpack Compose screen for the Dashboard. It should use a LazyColumn. The items are 'HabitCards'. Use Material3 styling. The top section is a 'BentoGrid'."
*   **For Notifications**: "Create an Android BroadcastReceiver named `NotificationReceiver`. It should handle an Intent from AlarmManager. It needs to acquire a WakeLock, build a NotificationCompat with high priority, and play a sound. Handle the 'Ringing' type by using a looped sound."
*   **For AI**: "Create a Retrofit service for Google Gemini. The input is a prompt string. The output is a JSON structure mapping voice commands to habit IDs."
