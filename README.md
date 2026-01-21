# Habit Tracker

A Flutter habit tracker with reminders and analytics. The app is currently fully free and does not include AI/voice features.

## 🌟 Features

### Core Features

- **Habit Logging**: Track completions and skips
- **Reminders**: Schedule simple/ringing/alarm-style notifications
- **Local Data Storage**: All data stored locally using SQLite for privacy and offline functionality
- **Beautiful Analytics**: Track your progress with interactive charts and detailed analytics
- **Streak Tracking**: Monitor your habit streaks and celebrate milestones

## 🚀 Getting Started

### Prerequisites

- Flutter 3.32.6 or later
- Dart 3.8.1 or later
- Android Studio / VS Code


### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/ai-voice-habit-tracker.git
   cd ai-voice-habit-tracker
   ```

## 📦 Play Console Readiness

### Launcher Icons

1. Place the following files in assets/icons:
   - app_icon.png (1024x1024)
   - app_icon_foreground.png (432x432, transparent)
2. Generate launcher icons:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

### Android Release Signing

1. Create a release keystore (example):
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy android/key.properties.template to android/key.properties and fill in values.
3. Build a release bundle for Play Console:
   ```bash
   flutter build appbundle --release
   ```
