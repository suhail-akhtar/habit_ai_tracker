# Habit AI Tracker - Android Native Technical Design Document

## 1. Executive Summary
This document outlines the technical architecture and specifications for porting the "Habit AI Tracker" application from Flutter to **Native Android (Kotlin)**. The primary motivation is to overcome limitations in background execution reliability, precise notification scheduling, and system-level integrations (specifically handling "App Killed" states) which have proven challenging in the cross-platform environment.

## 2. Technology Stack

*   **Language**: Kotlin (100% compliant with modern Android standards).
*   **UI Framework**: Jetpack Compose (Material Design 3).
*   **Architecture**: MVVM (Model-View-ViewModel) with Clean Architecture principles.
*   **Database**: Room (SQLite Abstraction).
*   **Networking**: Retrofit + OkHttp (for Gemini AI & Analytics).
*   **Dependency Injection**: Hilt (Dagger).
*   **Async/Concurrency**: Kotlin Coroutines & Flow.
*   **Testing**: JUnit, Espresso, Mockk.

## 3. Core Architecture modules

### 3.1. Application Layer (UI)
*   **Activity**: Single Activity Architecture (`MainActivity`).
*   **Navigation**: Jetpack Navigation Compose.
*   **Screens**:
    *   `DashboardScreen`: Bento Grid layout, Streaks, Daily Summary.
    *   `HabitDetailScreen`: Charts, History, Edit.
    *   `VoiceInputScreen`: Floating active listening UI.
    *   `NotificationSettingsScreen`: Granular control over alarms/ringing.

### 3.2. Domain Layer (Business Logic)
*   **UseCases**: Encapsulate single actions (e.g., `LogHabitCompletionUseCase`, `ScheduleHabitAlarmUseCase`).
*   **Repository Interfaces**: Abstractions for data access.

### 3.3. Data Layer
*   **LocalDataSource**: Room DAO for `Habit`, `HabitLog`, `UserSettings`.
*   **RemoteDataSource**: API calls to Gemini AI.
*   **Preferences**: DataStore (Proto or Preferences) for lightweight settings.

---

## 4. Critical Systems Design (The "Fixes")

The following sections detail how the native implementation addresses the specific pain points encountered in Flutter.

### 4.1. The Robust Notification System
**Problem**: Notifications not firing when the app is swiped away (killed).
**Native Solution**: `BroadcastReceiver` + `AlarmManager` (System Level).

#### Implementation Details:
1.  **NotificationReceiver (`BroadcastReceiver`)**:
    *   Registered in `AndroidManifest.xml`.
    *   **Crucial**: Does *not* require the UI to be running. The Android OS instantiates this class directly when the alarm fires.
    *   Logic:
        *   Receives Intent.
        *   Acquires `WakeLock` (ensure CPU stays on).
        *   Constructs `NotificationCompat.Builder`.
        *   Posts notification to `NotificationManager`.
        *   Releases `WakeLock`.

2.  **Scheduling (`AlarmManager`)**:
    *   Use `AlarmManager.setExactAndAllowWhileIdle()`: Guarantees execution even in "Doze" mode.
    *   Use `AlarmClockInfo` for the "Alarm" notification type (triggers full-screen intent).

3.  **Boot Persistence (`BootReceiver`)**:
    *   Listen for `android.intent.action.BOOT_COMPLETED`.
    *   Reschedule all active alarms upon phone restart (Alarms are cleared by OS on reboot).

4.  **Full Screen Intent (The "Alarm" UI)**:
    *   Define a special `AlarmActivity` in Manifest with `android:showOnLockScreen="true"`.
    *   When the Alarm fires, the `Intent` includes `setFullScreenIntent(pendingIntent)`.
    *   This bypasses the lock screen to show the "Did you do it?" dialog immediately, just like the stock Clock app.

### 4.2. Actionable Notifications
**Problem**: Buttons not triggering or context lost in background isolates.
**Native Solution**: `PendingIntent`.

*   **Mark Complete**: creates a `PendingIntent` pointing to `HabitActionReceiver`.
*   **Skip**: creates a `PendingIntent` pointing to `HabitActionReceiver`.
*   The `HabitActionReceiver` runs purely in the background (no UI needed) to update the Room Database.

### 4.3. Foreground Services (Ringing/Ongoing)
*   For "Ringing" reminders that must persist until dismissed:
*   Start a `ForegroundService` with type `capability="shortService"` or `media`.
*   This places a permanent notification in the tray that cannot be swiped away until the user interacts.

---

## 5. Data Model Schema (Room)

### 5.1. Entity: `habits`
| Column | Type | Notes |
| :--- | :--- | :--- |
| `id` | LONG (PK) | Auto-generate |
| `title` | TEXT | |
| `description` | TEXT | |
| `frequency_type` | TEXT | 'daily', 'interval', 'specific_days' |
| `target_count` | INT | e.g., 3 times/day |
| `sound_uri` | TEXT | Custom ringtone path |
| `is_archived` | BOOLEAN | Soft delete |

### 5.2. Entity: `habit_logs`
| Column | Type | Notes |
| :--- | :--- | :--- |
| `id` | LONG (PK) | |
| `habit_id` | LONG (FK) | Indexes for speed |
| `timestamp` | LONG | Epoch millis |
| `status` | STRING | 'completed', 'skipped', 'failed' |
| `source` | STRING | 'manual', 'voice', 'notification' |

---

## 6. AI & Voice Integration

### 6.1. Speech Recognition
*   Use `SpeechRecognizer` (Android SDK) directly.
*   **Benefit**: Zero latency vs network calls for basic transcription.
*   **Offline Support**: Works offline on Pixel and modern devices.

### 6.2. Gemini AI Processing
*   The recognized text is sent to a `GeminiRepository`.
*   **Prompt Engineering**: Native string resources file for easy prompt management.
*   **Response Parsing**: Use Kotlin Serialization (Json) to map AI response directly to `Habit` objects.

---

## 7. Migration Roadmap

### Phase 1: Foundation
1.  Setup Android Studio Project (Gradle KTS).
2.  Implement Room Database & DAOs.
3.  Create Base Repositories.

### Phase 2: Core Features
1.  Implement `DashboardScreen` (Compose).
2.  Implement `HabitService` (Logic for Creating/Editing).

### Phase 3: The Notification Engine (Priority)
1.  Implement `AlarmManager` wrapper.
2.  Create `NotificationReceiver` and `BootReceiver`.
3.  Test "Force Stop" and "Reboot" scenarios thoroughly.

### Phase 4: AI & Polish
1.  Integrate Voice Input.
2.  Add Charts/Analytics.
3.  Optimize release build (ProGuard/R8).

## 8. Specific "Vendor Killer" Handling
To address Xiaomi/Samsung killing background apps:
*   **Intent Logic**: Add a helper `AutoStartPermissionHelper`.
*   It detects the manufacturer (`Build.MANUFACTURER`).
*   It constructs a specific `Intent` to open the "Autostart" or "Battery Optimization" settings page for that specific phone.
*   Show a dialog: *"To ensure alarms ring, please allow Autostart for Habit AI."*

---

## 9. Code Structure Example (Kotlin)

```kotlin
// NotificationReceiver.kt
class NotificationReceiver : BroadcastReceiver() {
    @Inject lateinit var repository: HabitRepository // Hilt Injection works here!

    override fun onReceive(context: Context, intent: Intent) {
        val type = intent.getStringExtra("TYPE")
        val habitId = intent.getLongExtra("HABIT_ID", -1)
        
        // GoToAsync() implies we might do DB work
        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val habit = repository.getHabit(habitId)
                NotificationHelper.showNotification(context, habit)
            } finally {
                pendingResult.finish()
            }
        }
    }
}
```

```kotlin
// AlarmScheduler.kt
fun scheduleExactAlarm(context: Context, timeInMillis: Long, pendingIntent: PendingIntent) {
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    
    // The "Doze" buster
    alarmManager.setExactAndAllowWhileIdle(
        AlarmManager.RTC_WAKEUP,
        timeInMillis,
        pendingIntent
    )
}
```
