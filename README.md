# PunyaDaan 🙏

A Flutter mobile application that connects **Donators** with **Donees** (temples, organizations, and charitable events) to facilitate seamless charitable donations with QR-based giving, event management, and an admin moderation dashboard.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Project Setup](#project-setup)
- [Firebase Configuration](#firebase-configuration)
- [Running the App](#running-the-app)
- [Project Structure](#project-structure)
- [User Roles](#user-roles)
- [Troubleshooting](#troubleshooting)

---

## Features

- 🔐 **Google Sign-In** authentication with role-based routing
- 🙏 **Donator role** — browse events, donate via QR scan, track donation history & Punya Score
- 🏛️ **Donee role** — register temples/organizations, create events, manage fundraisers
- 🛡️ **Admin dashboard** — approve/reject events, manage users, handle deactivation requests
- 📸 **Profile photo upload** via Cloudinary
- 🔔 **Push notifications** via Firebase Cloud Messaging (FCM)
- 📍 **Geolocation** for temple & event mapping
- 🔊 **Bell sound** notification on donation received
- 📊 **Real-time Firestore** data streams throughout the app

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart SDK ^3.11.1) |
| Backend / Database | Firebase Firestore |
| Authentication | Firebase Auth + Google Sign-In |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Image Storage | Cloudinary REST API |
| QR Scanning | mobile_scanner ^7.2.0 |
| Navigation | Named routes via AppRouter |

---

## Prerequisites

Before setting up the project, make sure the following tools are installed on your laptop.

### 1. Flutter SDK

Download and install Flutter from the official site:  
👉 https://docs.flutter.dev/get-started/install

- Recommended Flutter channel: **stable**
- Minimum Dart SDK: **3.11.1**

After installing, verify your installation:

```bash
flutter doctor
```

All checkmarks should be green (except Web/Desktop if you only need Android/iOS).

### 2. Android Studio

Download Android Studio from:  
👉 https://developer.android.com/studio

During installation, ensure you install:
- **Android SDK** (API Level 33 or higher recommended)
- **Android SDK Command-line Tools**
- **Android Emulator** (or connect a physical device)

Set your `ANDROID_HOME` environment variable to the SDK path (e.g., `C:\Users\<you>\AppData\Local\Android\Sdk` on Windows).

### 3. Java Development Kit (JDK)

The project uses **Java 17**. Install JDK 17 from:  
👉 https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html

Or use the JDK bundled with Android Studio (found in `Android Studio > Settings > Build Tools > Gradle > Gradle JDK`).

### 4. Git

Ensure Git is installed:  
👉 https://git-scm.com/downloads

---

## Project Setup

### Step 1 — Clone the Repository

```bash
git clone https://github.com/Santhosh7474/punyadaan.git
cd punyadaan
```

### Step 2 — Install Flutter Dependencies

```bash
flutter pub get
```

This downloads all packages listed in `pubspec.yaml`.

### Step 3 — Verify Your Environment

```bash
flutter doctor -v
```

Resolve any issues flagged (most commonly: accepting Android licenses).

To accept Android licenses:

```bash
flutter doctor --android-licenses
```

Type `y` and press Enter for each prompt.

---

## Firebase Configuration

The app is already connected to the Firebase project `punyadaan-e0972`. The configuration files are included in the repository:

| File | Location |
|---|---|
| Android config | `android/app/google-services.json` |
| Firebase Dart options | `lib/firebase_options.dart` |

> **No additional Firebase setup is required** to run the app — the config files are pre-configured. However, if you need to connect your **own Firebase project**, follow the steps below.

<details>
<summary><strong>Optional: Connect your own Firebase project</strong></summary>

1. Go to [Firebase Console](https://console.firebase.google.com/) and create a new project.
2. Register an Android app with package name `com.example.punyadaan`.
3. Download `google-services.json` and replace `android/app/google-services.json`.
4. Enable the following Firebase services:
   - **Authentication** → Google Sign-In provider
   - **Cloud Firestore** → Start in test mode
   - **Firebase Storage** (optional)
   - **Cloud Messaging** (for push notifications)
5. Update `lib/firebase_options.dart` with your project's API keys.
6. In Firebase Console → Authentication → Settings → Authorized domains, add `localhost`.
7. In Firebase Console → Authentication → Sign-in method → Google, add your **SHA-1** fingerprint:
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Copy the **SHA-1** from the `debug` variant and add it to your Firebase Android app settings.

</details>

---

## Running the App

### Option A — Run on a Physical Android Device

1. Enable **Developer Options** on your Android phone:
   - Go to `Settings → About Phone` and tap **Build Number** 7 times.
   - Go back to `Settings → Developer Options` and enable **USB Debugging**.

2. Connect your phone via USB cable.

3. Verify your device is detected:
   ```bash
   flutter devices
   ```

4. Run the app:
   ```bash
   flutter run
   ```

### Option B — Run on an Android Emulator

1. Open **Android Studio → Device Manager**.
2. Create a virtual device (e.g., Pixel 6, API 33).
3. Start the emulator.
4. In your terminal:
   ```bash
   flutter run
   ```

### Option C — Run on iOS (macOS only)

> iOS builds require a Mac with Xcode installed.

```bash
# Install CocoaPods if not already installed
sudo gem install cocoapods

# Navigate to ios folder and install pods
cd ios
pod install
cd ..

# Run the app
flutter run
```

---

## Building a Release APK (Android)

To produce a release-ready APK:

```bash
flutter build apk --release
```

The output APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Project Structure

```
punyadaan/
├── android/                    # Android platform files
│   └── app/
│       └── google-services.json   # Firebase Android config
├── assets/
│   ├── animations/             # Lottie animation files
│   ├── icon/                   # App icon
│   ├── splash/                 # Splash screen image
│   ├── bell_sound.mp3          # Donation notification sound
│   └── ...
├── ios/                        # iOS platform files
├── lib/
│   ├── admin/                  # Admin dashboard screens
│   ├── auth/                   # Auth gate, login, role selection
│   ├── home/                   # Donator & Donee home pages + sub-screens
│   ├── models/                 # Data models (Organization, etc.)
│   ├── profile/                # Profile pages for both roles
│   ├── routes/                 # AppRouter (named route definitions)
│   ├── services/               # FCM, notification sound, permissions
│   ├── splash/                 # Splash screen
│   ├── firebase_options.dart   # Firebase project configuration
│   └── main.dart               # App entry point
├── analysis_options.yaml       # Dart linting rules
├── pubspec.yaml                # Dependencies & assets manifest
└── README.md
```

---

## User Roles

The app has three roles, selected at first sign-in:

| Role | Description |
|---|---|
| **Donator** | Browse events, scan QR codes to donate, view Punya Score & history |
| **Donee** | Register temples/organizations, create fundraising events |
| **Admin** | Approve events, manage users, handle deactivation requests |

> Admin access is granted directly in Firestore by setting a user's `role` field to `"admin"`.

---

## Troubleshooting

### `flutter pub get` fails
Ensure your internet connection is active and your Flutter SDK is on the **stable** channel:
```bash
flutter channel stable
flutter upgrade
flutter pub get
```

### `flutter doctor` shows Android SDK issues
Accept all Android licenses:
```bash
flutter doctor --android-licenses
```

### App crashes on startup with Firebase error
- Ensure `android/app/google-services.json` exists and is not corrupted.
- Make sure Google Sign-In SHA-1 fingerprint is registered in Firebase Console.

### Build fails with Gradle error
Make sure you are using **JDK 17**. In Android Studio:  
`File → Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK → Select 17`

### `PERMISSION_DENIED` in Firestore
Firestore security rules may be restricting access. For development, set rules to:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Device not detected (`flutter devices` shows nothing)
- Ensure USB Debugging is enabled on the device.
- Try a different USB cable or port.
- On Windows, install the USB driver for your phone manufacturer.

---

## Static Analysis

The project has **zero lint warnings or errors**. To verify:

```bash
flutter analyze
```

Expected output:
```
No issues found!
```

---

## Version Info

| Property | Value |
|---|---|
| App version | v1.2.1 |
| Flutter SDK | ≥ 3.x (stable) |
| Dart SDK | ^3.11.1 |
| Min Android SDK | As per Flutter defaults (API 21+) |
| Target Android SDK | As per Flutter defaults |

---

---

## Developer

**Santhosh Buchala**  
Junior Web Developer & Flutter Developer

📧 Open to collaboration, freelance opportunities, and developer discussions.

### Connect with me

- LinkedIn: https://www.linkedin.com/in/buchala-santhosh/
- GitHub: https://github.com/Santhosh7474

If you have any questions about the project, feel free to connect with me on LinkedIn.

---

⭐ If you found this project useful, consider giving the repository a star.
