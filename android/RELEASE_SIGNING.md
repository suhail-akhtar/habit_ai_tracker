# Android Release Signing Setup

This guide explains how to set up release signing for the AI Habit Tracker app to publish to Google Play Store.

## Overview

The app is now configured to use release signing for production builds. You need to:

1. Generate a keystore file
2. Create the `key.properties` file
3. Build the release APK

## Step 1: Generate a Keystore

Run this command in your terminal (from any directory):

```bash
keytool -genkey -v -keystore ai-habit-tracker-release-key.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias ai-habit-tracker
```

**Important Notes:**

- Use a **strong password** for both keystore and key
- Remember the passwords - you'll need them for updates
- Keep the keystore file **secure** - losing it means you can't update your app
- The alias name `ai-habit-tracker` is already configured in the build file

**When prompted, provide:**

- Your name and organization details
- A secure password (use the same for keystore and key for simplicity)
- Save this information securely!

## Step 2: Create key.properties File

Create a file named `key.properties` in the `android` folder with this content:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=ai-habit-tracker
storeFile=../ai-habit-tracker-release-key.keystore
```

**Replace the placeholders:**

- `YOUR_KEYSTORE_PASSWORD`: Password you used for the keystore
- `YOUR_KEY_PASSWORD`: Password you used for the key (usually same as keystore)

## Step 3: Move the Keystore File

Move the generated `ai-habit-tracker-release-key.keystore` file to your project root directory (same level as the `android` folder).

Your project structure should look like:

```
habit_ai_tracker/
├── ai-habit-tracker-release-key.keystore  ← Your keystore here
├── android/
│   ├── key.properties                      ← Your properties here
│   └── app/
├── lib/
└── ...
```

## Step 4: Build Release APK

Once the keystore and properties file are set up, you can build a release APK:

```bash
flutter build apk --release
```

Or build an App Bundle (recommended for Play Store):

```bash
flutter build appbundle --release
```

## Security Notes

✅ **Already Protected:**

- `key.properties` is already in `.gitignore`
- `*.keystore` files are already in `.gitignore`
- These files will NOT be committed to version control

⚠️ **Important:**

- **NEVER** share your keystore file or passwords
- **BACKUP** your keystore file securely
- **REMEMBER** your passwords - losing them means you can't update your app
- Store keystore and passwords in a secure password manager

## Troubleshooting

**Error: "Keystore was tampered with, or password was incorrect"**

- Check your passwords in `key.properties`
- Verify the keystore file path is correct

**Error: "Could not find key.properties"**

- Ensure `key.properties` is in the `android` folder
- Check file spelling and location

**Build fails with signing errors:**

- Verify the keystore alias matches what you used when creating the keystore
- Check that all paths in `key.properties` are correct

## Production Checklist

Before uploading to Google Play Store:

- [ ] Keystore created and backed up securely
- [ ] `key.properties` file created with correct passwords
- [ ] Release build completes successfully
- [ ] APK/Bundle signed with release key (not debug key)
- [ ] App tested on release build
- [ ] Version code incremented for updates

## Next Steps

After setting up signing:

1. Test the release build thoroughly
2. Prepare store listing materials (screenshots, descriptions)
3. Configure store listing and pricing
4. Upload to Google Play Console
5. Submit for review
