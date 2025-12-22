# Firebase Setup for ECG App

## Problem
FCM (Firebase Cloud Messaging) cannot work without proper Firebase configuration files.

**Error:** `[core/no-app] No Firebase App '[DEFAULT]' has been created`

## Solution: Add Firebase Configuration

### Option 1: FlutterFire CLI (Recommended - Easiest)

1. **Install FlutterFire CLI:**
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. **Configure Firebase for your project:**
   ```bash
   cd "/Users/nandu/Development/college/Archive/ECG - 31.10.25"
   flutterfire configure
   ```
   
   This will:
   - Prompt you to select/create a Firebase project
   - Generate `lib/firebase_options.dart`
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place files in correct locations

3. **Update main.dart to use firebase_options:**
   ```dart
   import 'firebase_options.dart';
   
   // In initialize():
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

### Option 2: Manual Setup (If FlutterFire CLI doesn't work)

#### Step 1: Get google-services.json

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create new one)
3. Click on "Project Settings" (gear icon)
4. Scroll to "Your apps" section
5. Click "Add app" → Select Android icon
6. Register app with package name: `com.simats.saveethacardioapp`
7. Download `google-services.json`
8. Place it at: `android/app/google-services.json`

#### Step 2: Update android/build.gradle.kts

Add classpath to the root `android/build.gradle.kts`:

```kotlin
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
```

#### Step 3: Update android/app/build.gradle.kts

Add plugin at the top of `android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // ADD THIS LINE
}
```

#### Step 4: Verify Setup

Run:
```bash
cd android
./gradlew :app:dependencies | grep firebase
```

Should show firebase dependencies.

## Quick Test

After setup, run:
```bash
flutter run
```

Then check logs - you should see:
```
✅ Firebase.initializeApp() succeeded
🔵 Initial token: SUCCESS (...)
```

Instead of:
```
❌ [core/no-app] No Firebase App '[DEFAULT]' has been created
```

## Troubleshooting

**Problem:** FlutterFire CLI command not found
```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

**Problem:** Firebase project doesn't exist
- Create one at https://console.firebase.google.com/
- Enable Cloud Messaging in project settings

**Problem:** google-services.json wrong package name
- Package name must match `applicationId` in `android/app/build.gradle.kts`
- Current package: `com.simats.saveethacardioapp`
