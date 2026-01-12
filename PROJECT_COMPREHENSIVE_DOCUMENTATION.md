# AI Voice Habit Tracker — Comprehensive Project Documentation

## 1) Executive Summary
This repository contains a Flutter (Material 3) habit-tracking application with:

- A 5-tab main navigation: **Dashboard**, **Voice**, **Add Habit**, **Analytics**, **Settings**.
- **Local-first storage** using **SQLite (sqflite)** for habits, habit logs, cached AI insights, user settings, and notification settings.
- **Voice capture** implemented via a custom platform channel (`MethodChannel`) with an Android implementation (`SpeechToTextPlugin.kt`).
- **AI features** powered by **Google Gemini** (HTTP API), used for:
  - parsing voice commands into structured “actions”
  - generating daily tips
  - generating/caching weekly insights
- **Reminders** via `flutter_local_notifications` + timezone scheduling.
- **Home screen widget** updates via `home_widget`.
- A simple **Premium gating** system (via `UserProvider`) that limits the free tier (notably habit creation count and some analytics details).

This document explains the architecture, every screen/page, and the major features end-to-end.

---

## 2) Tech Stack & Key Dependencies
From `pubspec.yaml`:

- **Flutter / Dart**: Flutter app, Dart SDK ^3.8.1
- **State management**: `provider`
- **Persistence**: `sqflite`, `path`
- **Networking**: `http`, `dio` (HTTP used for Gemini in current code)
- **Voice permissions**: `permission_handler`
- **Notifications**: `flutter_local_notifications`, `timezone`
- **UI / Visualization**:
  - `fl_chart` (charts)
  - `flutter_heatmap_calendar` (activity heatmap)
  - `flutter_staggered_grid_view` (dashboard bento layout)
  - `percent_indicator` (circular progress)
  - `animations`, `flutter_animate` (motion)
  - `google_fonts`
- **Local settings**: `shared_preferences` (used e.g. for Voice screen auto-process toggle)
- **Home widget**: `home_widget`
- **Premium / monetization**: `in_app_purchase` is included (current implementation is largely simulated via settings)

---

## 3) Repository Layout (Flutter)
Primary app code is under `lib/`:

- `lib/main.dart` — app entry, service initialization, providers, routes, main tab navigation.
- `lib/screens/` — UI pages/screens.
- `lib/providers/` — app state and business logic (Provider pattern).
- `lib/services/` — integrations (SQLite wrapper, notifications, AI, voice platform channel, widgets).
- `lib/models/` — data models for DB and app state.
- `lib/utils/` — theme + helpers + constants.
- `lib/widgets/` — reusable UI components.

Android-specific voice recognition lives in:

- `android/app/src/main/kotlin/.../SpeechToTextPlugin.kt`

---

## 4) App Bootstrap & Navigation
### 4.1 Entry point
`main.dart` does:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `tz.initializeTimeZones()`
3. `NotificationService().initialize(notificationTapBackground)`
4. `runApp(AIVoiceHabitTrackerApp())`

A background notification tap handler is registered:

- `notificationTapBackground(NotificationResponse notificationResponse)`

This handler only logs; interactive handling is intended to be done via payload processing in the UI.

### 4.2 Providers (global state)
`AIVoiceHabitTrackerApp` wraps the app in a `MultiProvider`:

- `HabitProvider` — habits, logs, logging, streak calculation calls, widget updates.
- `VoiceProvider` — speech capture state + AI parsing + command execution.
- `AnalyticsProvider` — reads analytics from DB + caches/generates weekly insight.
- `UserProvider` — premium gating + user settings (theme mode, etc).

### 4.3 Routes and main tabs
`MaterialApp.routes` defines named routes:

- `/dashboard` → DashboardScreen
- `/voice` → VoiceInputScreen
- `/habit-setup` → HabitSetupScreen
- `/analytics` → AnalyticsScreen
- `/settings` → SettingsScreen

The main UX uses a bottom `NavigationBar` within `MainNavigationScreen` and an `IndexedStack` to keep tab state alive:

- index 0: Dashboard
- index 1: Voice
- index 2: Add Habit
- index 3: Analytics
- index 4: Settings

### 4.4 Initialization order
`MainNavigationScreen._initializeApp()` loads providers in this order:

1. `userProvider.loadUserData()` (premium status / settings)
2. `habitProvider.loadHabits()`
3. `userProvider.updateHabitCount(habitProvider.habitCount)`
4. `voiceProvider.initialize()`
5. `analyticsProvider.loadAnalytics()`

This ordering is chosen to ensure premium state is known before habit-limit enforcement.

---

## 5) Design System & Visual Language
### 5.1 Theme
`lib/utils/theme.dart` defines `AppTheme`:

- Material 3 themes: `lightTheme` and `darkTheme`.
- Uses Google Fonts (`Inter` and `Outfit`).
- Defines spacing and radius constants used across screens.

Design intent:

- Light theme: clean slate background, bright indigo seed.
- Dark theme: “Pro mode” feel, deep slate surfaces.

### 5.2 Components and patterns
Common UI patterns:

- `Card`-based sections with consistent spacing.
- `RefreshIndicator` on screens that display DB-backed lists.
- Animated/interactive elements using `flutter_animate` and custom animation controllers.

---

## 6) Data Layer (SQLite “Backend”)
The app is primarily offline-first; the “backend” is SQLite.

### 6.1 Database service
`lib/services/database_service.dart` is the real DB layer.

- Database file: `habit_tracker.db`
- DB schema version: **6** (`_databaseVersion = 6`)
- Opened via `openDatabase(path, version: ..., onCreate: ..., onUpgrade: ...)`

> Note: There are older/unused constants (`AppConfig.databaseVersion`, `Constants.databaseVersion`) that do not match the actual DB version. The authoritative version is `DatabaseService._databaseVersion`.

### 6.2 Tables & schema
#### 6.2.1 `habits`
Key columns:

- `id` (PK autoincrement)
- `name` (TEXT, required)
- `description` (TEXT, optional)
- `category` (TEXT)
- `target_frequency` (INTEGER, default 1)
- `color_code` (TEXT)
- `icon_name` (TEXT)
- `is_active` (INTEGER bool)
- `has_freeze` (INTEGER bool)

Scheduling/reminders (added over versions):

- `frequency_type` (TEXT, default 'daily')
- `interval_minutes` (INTEGER)
- `window_start_time`, `window_end_time` (TEXT HH:MM)
- `is_reminder_enabled` (INTEGER bool)
- `reminder_time` (TEXT HH:MM)

Timestamps:

- `created_at`, `updated_at`

#### 6.2.2 `habit_logs`
Key columns:

- `id` (PK)
- `habit_id` (FK → habits.id)
- `completed_at` (TEXT ISO datetime)
- `note` (TEXT)
- `input_method` (TEXT: manual/voice/notification)
- `mood_rating` (INTEGER optional)
- `status` (TEXT: 'completed' | 'skipped')

Used for:

- daily completion state
- multi-frequency progress (e.g., 3x per day)
- streak calculation with skip support

#### 6.2.3 `ai_insights`
Cache table for generated AI content:

- `user_id` (TEXT)
- `insight_type` (TEXT, e.g. weekly_summary)
- `content` (TEXT)
- `data_hash` (TEXT)
- `created_at`, `expires_at`

#### 6.2.4 `user_settings`
Key-value store:

- `key` (TEXT PK)
- `value` (TEXT)
- `updated_at` (TEXT)

Used for theme mode and subscription status.

#### 6.2.5 `notification_settings`
Stores reminder definitions:

- `title`, `message`
- `time_hour`, `time_minute`
- `days_of_week` (CSV)
- `type` (simple/ringing/alarm)
- `repetition` (oneTime/daily/weekly/monthly)
- `is_enabled` (bool)
- `habit_ids` (CSV)
- `next_scheduled_time` (optional)

### 6.3 DB operations overview
- Habits: create/read/update/delete + active filtering
- Logs: insert logs and query ranges
- Streak: calculated from logs with handling for multi-frequency + skip/freeze
- Analytics: aggregate queries for totals and “recent” activity
- Notifications: CRUD in DB + scheduled via NotificationService

> Note: `lib/utils/database_helper.dart` exists but is empty; it appears unused.

---

## 7) State Management & Data Flow
The app follows a “Provider → Service → DB/Platform/API” flow:

- Screens display and mutate state by calling provider methods.
- Providers call services (DB, notifications, widgets, AI, voice platform channel).
- Providers notify listeners (UI rebuild).

Typical flows:

### 7.1 Habit list + completion
Dashboard → HabitCard → HabitProvider.logHabitCompletion() → DatabaseService.logHabit() → refresh today logs → rebuild

### 7.2 Voice command to log
VoiceInputScreen → VoiceProvider.startListening() → PlatformSpeechService → Android SpeechRecognizer → VoiceProvider receives words → VoiceProvider.processVoiceInput() → GeminiService.parse → VoiceProvider.executeVoiceCommand() → HabitProvider.logHabitCompletion/logHabitSkip → DB

### 7.3 Notifications
SettingsScreen creates/edits notification settings → stored in DB → NotificationService.scheduleNotification() schedules OS notifications → payload routed to DashboardScreen via payloadStream → dashboard shows simple dialog (Simple) or opens full-screen “incoming call” UI (Ringing/Alarm).

### 7.4 Home widget updates
HabitProvider loads/logs → WidgetService.updateHabitStatus()/updateStreak() → HomeWidget saves data and triggers widget refresh.

---

## 8) AI Integration (Gemini)
### 8.1 Service
`lib/services/gemini_service.dart` is a lightweight HTTP client over Gemini.

Key methods:

- `processVoiceInput(voiceText, userHabits)` → builds a prompt describing habits and asks model to return structured result.
- `generateDailyTip()` → short motivational message.
- `generateWeeklyInsight(analyticsData)` → longer summary.

Robustness features:

- Retry loop up to `AppConfig.maxAiRetries`
- Response extraction tries multiple JSON shapes
- Parsing failures fall back to local heuristic processing

Security note:

- `AppConfig.geminiApiKey` is currently hard-coded in `lib/config/app_config.dart`. For a production app, this should be moved out of the client (or at least provided via build-time secrets) because a compiled client can be reverse engineered.

### 8.2 Insight caching
`AnalyticsProvider` caches weekly insight in SQLite:

- Reads cached row from `ai_insights` where `expires_at > now`.
- If missing/expired, calls Gemini and stores new insight with 1-day TTL.

---

## 9) Voice Recognition (Platform Channel)
### 9.1 Flutter side
`lib/services/platform_speech_service.dart`:

- Uses `MethodChannel('habit_tracker/speech')`
- Provides streams:
  - words stream
  - listening state stream
  - confidence stream
  - errors stream

`VoiceProvider` subscribes to these streams and exposes UI-friendly fields:

- `_currentWords`, `_isListening`, `_confidence`, `_status`, `_error`

### 9.2 Android side
`android/.../SpeechToTextPlugin.kt`:

- Implements:
  - `initialize`
  - `startListening`
  - `stopListening`
  - `cancel`
  - `getAvailableLanguages`
  - `hasRecognitionSupport`

It wraps Android `SpeechRecognizer` and pushes results back to Flutter via:

- `onSpeechResult` (recognizedWords + confidence)
- `onListeningStateChanged`
- `onError`

It also includes improved handling for “no match / timeout” cases, attempting to avoid showing errors when the user did speak.

---

## 10) Notifications & Reminders
### 10.1 Notification service
`lib/services/notification_service.dart`:

- Initializes `FlutterLocalNotificationsPlugin` with callbacks.
- Requests notification permissions (and exact alarm permission on Android 12+).
- Schedules notifications using `zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle`.
- Creates Android notification channels at startup. Some channels use “v2” IDs to avoid the Android limitation that channel properties are immutable after creation.

A key design choice:

- Notification taps are streamed into the app via `_payloadController` (`payloadStream`).

### 10.2 Payload handling and habit actions
Dashboard listens to payloads and routes behavior based on notification type:

- Payload format: `custom_notification:{type}:{settingsId}:{habitId1,habitId2,...}`
  - `type` is one of the `NotificationType` enum names (e.g. `simple`, `ringing`, `alarm`).

UI behavior:

- **Simple**: Dashboard shows the “Did you do it?” dialog (complete / skip).
- **Ringing / Alarm**: Dashboard opens a full-screen “incoming call” style page.

Background behavior (important Android-only design):

- Ringing/Alarm notifications include **Accept** and **Reject** action buttons.
- If the user taps **Accept** or **Reject**, a background handler logs the result directly to SQLite even if the UI is not running:
  - Accept → `completed`
  - Reject → `skipped`

### 10.3 Notification types
Notification types can be:

- Simple
- Ringing (persistent/call-like)
- Alarm (full-screen intent)

`NotificationSetupScreen` gates Ringing/Alarm behind Premium.

### 10.4 Android guarantees & limitations (official docs)
This project uses `flutter_local_notifications` for scheduling + delivery. Android has platform-level constraints that the app cannot fully override.

**Notification permission (Android 13+)**

- Android 13+ requires `POST_NOTIFICATIONS` runtime permission for most notifications. If the user denies it, reminders will not appear.
- Official Android docs: https://developer.android.com/develop/ui/views/notifications/notification-permission

**Exact alarms (Android 12+, behavior change on Android 14)**

- “Exact alarms” are required for precise delivery (`exactAllowWhileIdle`).
- On Android 14+, `SCHEDULE_EXACT_ALARM` is **denied by default** for most newly installed apps and must be explicitly granted in settings (“Alarms & reminders”).
- Official Android docs: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms

**Full-screen intent (Android 14+)**

- Android 14 introduced stronger limits around full-screen intent notifications. Even with `USE_FULL_SCREEN_INTENT` declared, the user may need to enable the app in “Manage full screen intents” (Special app access).
- When full-screen is denied, the expected fallback is typically a heads-up notification rather than launching a full-screen UI.
- Official AOSP docs: https://source.android.com/docs/core/permissions/fsi-limits

**CallStyle notifications vs “call-like UX”**

- Android’s `Notification.CallStyle` template is intended for **call apps** and integrates with Telecom APIs.
- This app implements a **call-like UX** (full-screen activity + Accept/Reject actions) but does not claim to be a full Telecom/CallStyle implementation.
- Official Android docs: https://developer.android.com/develop/ui/views/notifications/call-style

**OEM background restrictions**

- Some Android OEM builds can restrict background execution and cause scheduled notifications to be unreliable when the app is backgrounded/terminated.
- The `flutter_local_notifications` maintainers explicitly call out that this is an OS restriction that the plugin cannot resolve in code.
- Plugin docs: https://pub.dev/packages/flutter_local_notifications (see “Caveats and limitations” → “Scheduled Android notifications”)

---

## 11) Premium / Monetization System
### 11.1 Provider
`lib/providers/user_provider.dart`:

- Stores subscription status in `user_settings` under key `subscription_status`.
- Premium considered active when `subscription_status == 'active'`.
- Enforces free-tier habit limit and feature gating.

### 11.2 Premium dialog
`lib/widgets/premium_dialog.dart` shows a branded premium upsell modal.

### 11.3 Limits
Important note about limit constants:

- `Constants.freeHabitLimit` is **3**.
- `AppConfig.freeHabitLimit` is **5**.

Most UI enforcement uses `Constants.freeHabitLimit` (3). You should treat the “real” limit as 3 unless you intentionally unify these values.

---

## 12) Screens / Pages (Detailed)

### 12.1 MainNavigationScreen (root tabs)
File: `lib/main.dart`

Purpose:

- Hosts the 5 primary screens in an `IndexedStack`.
- Runs initial app setup (loads providers and data).

UX:

- `NavigationBar` with 5 destinations.

Key implementation notes:

- Uses `IndexedStack` to preserve tab state (e.g., scroll positions).

---

### 12.2 DashboardScreen
File: `lib/screens/dashboard_screen.dart`

Purpose:

- Primary landing page.
- Shows overview content and today’s habits.
- Provides quick access to voice input and habit creation.
- Handles notification payloads to prompt user to complete/skip.

UI structure:

- `RefreshIndicator` → `CustomScrollView`
- Top: lightweight `SliverAppBar` with Settings and a Notifications icon (notifications button currently TODO).
- Greeting block (“Good Morning/Afternoon/Evening”).
- `BentoGrid` (stats tiles + daily AI tip tile).
- “Your Habits” section header + add button.
- `SliverList` of `HabitCard` (active habits).
- Center floating `VoiceButton` that opens VoiceInputScreen.

Data dependencies:

- `HabitProvider`: `loadHabits()`, `todayHabits`, logging actions.
- `UserProvider`: premium validation for habit creation, theme mode.
- `NotificationService`: permission request and payload stream.

Notification flow:

- On init: requests notification permissions (after first frame).
- Checks initial payload (cold start from notification).
- Subscribes to `payloadStream` and triggers `_showHabitActionDialog(habitId)`.

Habit creation gating:

- Uses `userProvider.validateHabitCreation()`.
- If blocked: shows `PremiumDialog`.

---

### 12.3 HabitSetupScreen (Add / Edit Habit)
File: `lib/screens/habit_setup_screen.dart`

Purpose:

- Create a new habit or edit an existing habit.
- Collects habit metadata (name/description/category/icon/color).
- Collects habit target frequency (e.g., 1/day, 3/day).
- Collects flexible scheduling configuration.
- Collects per-habit reminder configuration.

Key states:

- Form controllers for name/description.
- UI state for category/icon/color selection.
- `_targetFrequency` for multi-frequency habits.

Scheduling (flexible):

- `_frequencyType` (daily/interval)
- `_intervalMinutes`
- `_windowStartTime`, `_windowEndTime`

Reminder settings:

- `_isReminderEnabled`
- `_reminderTime`

Premium gating:

- On screen load (new habit only), checks `validateHabitCreation()` and may show PremiumDialog and auto-pop.

Operations:

- Create habit → `HabitProvider.addHabit(habit, isPremium: userProvider.isPremium)`
- Update habit → `HabitProvider.updateHabit(habit)`
- Delete habit → via confirmation dialog and provider.

Notifications integration:

- Screen imports `NotificationService`; habit-level reminders appear to be supported by DB schema and UI, and may be scheduled when saving (depends on deeper code in later parts of the screen).

---

### 12.4 VoiceInputScreen
File: `lib/screens/voice_input_screen.dart`

Purpose:

- Let user speak a natural language habit update.
- Display recognized speech live.
- Process speech text via AI (Gemini) into a structured command.
- Execute the command (log completion/skip).

UI structure:

- AppBar with “Tips” icon.
- Main content includes:
  - voice visualizer
  - status card
  - captured text card
  - “auto-process” checkbox
  - action buttons (listen/process/clear/etc.)
- Bottom panel includes stop listening button + instructions.

Auto-process:

- Toggle stored using `SharedPreferences` key: `auto_process_voice`.
- When enabled, the screen will automatically call `_processVoiceInput()` after listening ends and there are words.

Data dependencies:

- `VoiceProvider`: state and actions.
- `HabitProvider`: needed for list of habits and executing command.

Voice command pipeline:

1. `VoiceProvider.startListening()`
2. Words stream updates `voiceProvider.currentWords`
3. Process → `voiceProvider.processVoiceInput(words, habitProvider.habits)`
4. Execute → `voiceProvider.executeVoiceCommand(command, habitProvider)`

---

### 12.5 AnalyticsScreen
File: `lib/screens/analytics_screen.dart`

Purpose:

- Provide progress visualization and insights.

Layout:

- Tabbed UI:
  - Overview
  - Insights

Overview tab:

- Activity heatmap (`flutter_heatmap_calendar`) using `AnalyticsProvider.heatmapData`.
- Stats overview card:
  - total habits
  - logs in last 7 days
  - best streak (DB query)
  - completion rate
- Weekly progress chart (via `ProgressChart` widget).
- Habit breakdown (premium-gated).
- Streak leaderboard.

Insights tab:

- Weekly insight (cached / AI generated)
- AI recommendations (premium-gated)
- Pattern analysis (premium-gated)
- Goal suggestions

Important implementation notes:

- `AnalyticsProvider.getWeeklyProgress()` currently returns placeholder data (zeros). The charts may be visually present but not data-driven yet.

---

### 12.6 SettingsScreen
File: `lib/screens/settings_screen.dart`

Purpose:

- Account/premium status management.
- Notification management.
- Appearance (theme mode).
- Voice-related settings.
- Data tools.
- About section.

Key features:

#### Account
- Shows premium vs free.
- Provides an “Upgrade” button which opens PremiumDialog.

#### Notifications
- Loads notification settings from SQLite (`DatabaseService.getNotificationSettings()`).
- Free users limited to 3 reminders; premium users up to 20.
- Can add/edit/delete notifications (navigates to NotificationSetupScreen).

#### Appearance
- Theme mode stored in `user_settings` key `theme_mode` and used by `MaterialApp.themeMode`.

---

### 12.7 NotificationSetupScreen
File: `lib/screens/notification_setup_screen.dart`

Purpose:

- Create or edit a reminder (stored in DB + scheduled in OS).

Fields:

- Title (optional)
- Message (optional)
- Time selection
- Type: simple/ringing/alarm
- Repetition: oneTime/daily/weekly/monthly
- Days of week selection
- Habit associations (choose which habits this reminder relates to)
- Enable switch

Premium gating:

- Ringing/alarm types are gated for free users.

Scheduling:

- Uses `NotificationService.scheduleNotification(settings, associatedHabits: ...)`.
- Stores settings in DB via `DatabaseService`.

---

### 12.8 HabitHistoryScreen
File: `lib/screens/habit_history_screen.dart`

Purpose:

- Shows a per-habit timeline of logs.
- Groups logs by day.
- Shows streak and per-day progress for multi-frequency habits.

Implementation details:

- Loads logs via `HabitProvider.getHabitHistory(habitId)`.
- Loads streak via `HabitProvider.getHabitStreak(habitId)`.
- Groups logs by date and displays them in expandable day cards.
- For multi-frequency habits, shows a progress bar and counts `completedCount/target`.
- Supports “skipped” logs and displays “Skipped (Streak Frozen)”.

---

## 13) Widgets (Key)
### 13.1 HabitCard
File: `lib/widgets/habit_card.dart`

- Displays one habit with icon, category pill, streak badge.
- Completion UI:
  - If `targetFrequency > 1`, shows radial progress indicator and `count/target`.
  - Otherwise shows a checkbox-like completion button.
- Tap opens habit detail bottom sheet (with options like edit/history).

### 13.2 VoiceButton
File: `lib/widgets/voice_button.dart`

- Animated mic button.
- Indicates listening/processing/error with icon changes.
- Ripple effect while listening.

### 13.3 BentoGrid
File: `lib/widgets/dashboard/bento_grid.dart`

- 3 tiles:
  - Streak tile (wide)
  - Daily completion percent
  - “AI Insight” quick tile that calls `AnalyticsProvider.getDailyTip()`

> Note: HabitProvider.longestStreak is currently a stub returning 0, so streak tile may not reflect actual longest streak.

### 13.4 PremiumDialog
File: `lib/widgets/premium_dialog.dart`

- Premium upsell dialog with scrollable features list.

---

## 14) Feature Inventory (What exists today)
### Core
- Habit CRUD (create/edit/delete)
- Logging completions and skips
- Multi-frequency habits (progress count toward target)
- Local database storage and offline capability

### Voice
- Android speech recognition via custom plugin
- Voice UI with listening status + transcription
- AI parsing + execution of “complete/skip” commands

### Analytics
- Heatmap (based on DB query)
- Summary stats (total habits/logs, recent logs, completion rate)
- Weekly insight (AI + cached)

### Notifications
- Notification settings CRUD
- Scheduling across days/repetition types
- Payload handling that prompts user to complete/skip

### Home Widget
- Writes completion counts + streak to home widget storage

### Premium
- Habit creation limit enforcement (free tier)
- Premium gating for:
  - detailed breakdown
  - some AI insight features
  - advanced notification types

---

## 15) Known Gaps / Inconsistencies (Important for maintenance)
- `lib/utils/database_helper.dart` is empty (likely legacy).
- Multiple constants disagree:
  - free habit limit is 3 in `Constants` but 5 in `AppConfig`.
  - DB version constants in `AppConfig`/`Constants` don’t match `DatabaseService`.
- Some analytics methods are placeholders (weekly progress returns zeros).
- `HabitProvider.longestStreak` is stubbed (always 0).
- `AppConfig.geminiApiKey` is hard-coded (security risk for real production).

---

## 16) Suggested Reading Order for Developers
1. `lib/main.dart`
2. `lib/screens/dashboard_screen.dart`
3. `lib/providers/habit_provider.dart`
4. `lib/services/database_service.dart`
5. `lib/screens/voice_input_screen.dart` + `lib/providers/voice_provider.dart`
6. `lib/services/platform_speech_service.dart` + `android/.../SpeechToTextPlugin.kt`
7. `lib/screens/settings_screen.dart` + `lib/screens/notification_setup_screen.dart`
8. `lib/services/notification_service.dart`
9. `lib/screens/analytics_screen.dart` + `lib/providers/analytics_provider.dart`

---

## Appendix A) Quick “What calls what?”
- UI → Providers:
  - Dashboard: HabitProvider/UserProvider/NotificationService
  - VoiceInput: VoiceProvider/HabitProvider
  - HabitSetup: HabitProvider/UserProvider/NotificationService
  - Analytics: AnalyticsProvider/HabitProvider/UserProvider
  - Settings: UserProvider/DatabaseService/NotificationService
- Providers → Services:
  - HabitProvider → DatabaseService + NotificationService + WidgetService
  - AnalyticsProvider → DatabaseService + GeminiService
  - VoiceProvider → PlatformSpeechService + GeminiService
  - UserProvider → DatabaseService

