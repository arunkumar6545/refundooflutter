# Complete steps to generate Android and iOS apps (Refundoo)

You have Flutter and Android installed. Follow these steps to run and build the app on Android and (on a Mac) iOS.

---

## After making code changes

**Build and restart every time after a change.** Hot reload (`r`) may not pick up all updates (e.g. new files, model changes, routing). To see your changes:

1. Stop the running app (press `q` in the terminal where `flutter run` is active, or close the app).
2. Run again: `flutter run` (or `flutter run -d chrome` / `flutter run -d android`), or double‑click **RUN_REFUNDOO.bat**.

---

## Part 1: One-time setup

### Step 1.1 – Confirm Flutter and project

1. Open a **new** Command Prompt or PowerShell (so `PATH` includes Flutter).
2. Run:
   ```bash
   flutter --version
   ```
   You should see the Flutter version (e.g. 3.41.x).

3. Go to the project:
   ```bash
   cd c:\Users\am893131\Documents\refundoo
   ```

4. Get dependencies:
   ```bash
   flutter pub get
   ```

### Step 1.2 – Run Flutter doctor

```bash
flutter doctor
```

Fix everything it reports:

- **Android toolchain**
  - If it says “Android license status unknown”, run:
    ```bash
    flutter doctor --android-licenses
    ```
  - Type `y` and Enter for each license.
- **Android Studio**
  - If missing: install from https://developer.android.com/studio and run its setup. Then run `flutter doctor` again.
- **Connected device**
  - Either connect a physical Android device with USB debugging enabled, or create an emulator (Step 1.3).

### Step 1.3 – (Optional) Create an Android emulator

1. Open **Android Studio**.
2. **Tools** → **Device Manager** (or **AVD Manager**).
3. **Create Device** → pick a phone (e.g. Pixel 6) → **Next**.
4. Select a system image (e.g. API 34) → **Download** if needed → **Next** → **Finish**.
5. Start the emulator with the **Play** button.
6. Leave it running so `flutter run` can use it.

---

## Part 2: Android app – run and build

### Step 2.1 – Run on Android (emulator or device)

1. If using an emulator, start it from Android Studio (Device Manager).
2. If using a phone: enable **Developer options** and **USB debugging**, connect via USB.
3. In the project folder:
   ```bash
   cd c:\Users\am893131\Documents\refundoo
   flutter run
   ```
4. When Flutter lists devices, choose the Android device/emulator (e.g. type the number and Enter).
5. The app will build and launch on the selected device.
6. **After any code change:** stop the app (`q` in the terminal), then run `flutter run` (or this step again) to build and restart so changes are reflected.

To run only on Android and avoid choosing a device:

```bash
flutter run -d android
```

### Step 2.2 – Build Android APK (debug, for testing)

```bash
cd c:\Users\am893131\Documents\refundoo
flutter build apk --debug
```

Output:

- `build\app\outputs\flutter-apk\app-debug.apk`

Install on a device:

```bash
flutter install
```

or copy `app-debug.apk` to the device and open it (install from unknown sources allowed).

### Step 2.3 – Build Android APK (release, for distribution)

1. (Optional) Configure signing:
   - In Android Studio: **File** → **Project Structure** → **Modules** → **app** → **Signing Configs**.
   - Or add a `key.properties` and configure `android/app/build.gradle` (see [Flutter docs – Android signing](https://docs.flutter.dev/deployment/android#signing-the-app)).

2. Build release APK:
   ```bash
   cd c:\Users\am893131\Documents\refundoo
   flutter build apk --release
   ```

   Output:

   - `build\app\outputs\flutter-apk\app-release.apk`

3. (Optional) Build App Bundle for Play Store:
   ```bash
   flutter build appbundle --release
   ```
   Output: `build\app\outputs\bundle\release\app-release.aab`

### Step 2.4 – Android summary checklist

| Step | Command / action |
|------|-------------------|
| Licenses | `flutter doctor --android-licenses` |
| Dependencies | `flutter pub get` |
| Run on device/emulator | `flutter run -d android` |
| Debug APK | `flutter build apk --debug` |
| Release APK | `flutter build apk --release` |
| Play Store bundle | `flutter build appbundle --release` |

---

## Part 3: iOS app (Mac only)

iOS builds require a **Mac** with **Xcode**. You cannot build for iOS on Windows.

### Step 3.1 – On the Mac: install Xcode and tools

1. Install **Xcode** from the Mac App Store.
2. Open **Xcode** once and accept the license; allow it to install components.
3. Install CocoaPods (for iOS dependencies):
   ```bash
   sudo gem install cocoapods
   ```
4. In Terminal, run:
   ```bash
   flutter doctor
   ```
   Fix any issues (e.g. “Xcode not selected” → run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`).

### Step 3.2 – Copy or clone the project on the Mac

- Copy the whole `refundoo` folder to the Mac (e.g. via USB, cloud, or git), or clone the repo there.
- Open Terminal on the Mac and go to the project:
  ```bash
  cd /path/to/refundoo
  ```

### Step 3.3 – Get dependencies and iOS pods

```bash
flutter pub get
cd ios && pod install && cd ..
```

(If `pod install` fails, try `pod repo update` then `pod install` again.)

### Step 3.4 – Run on iOS simulator

1. List simulators:
   ```bash
   flutter devices
   ```
2. Run on the default simulator:
   ```bash
   flutter run -d ios
   ```
   Or pick one, e.g.:
   ```bash
   flutter run -d "iPhone 15"
   ```

### Step 3.5 – Run on a physical iPhone

1. Connect the iPhone with a cable.
2. On the iPhone: **Settings** → **Developer** → enable developer mode (if shown).
3. In Xcode: **Window** → **Devices and Simulators** and trust the device if asked.
4. In the project:
   ```bash
   flutter run -d <device-id>
   ```
   Use the device ID from `flutter devices`.

### Step 3.6 – Build iOS release (IPA) for TestFlight / App Store

1. Open the iOS project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. In Xcode:
   - Select the **Runner** project in the left sidebar.
   - Under **Signing & Capabilities**, choose your **Team** (Apple ID) and set **Bundle Identifier** (e.g. `com.refundoo.refundoo`).
   - Select **Any iOS Device** as the run destination.
3. In Terminal:
   ```bash
   cd /path/to/refundoo
   flutter build ios --release
   ```
4. In Xcode: **Product** → **Archive**. When the archive is created, use **Distribute App** to upload to App Store Connect (TestFlight or App Store).

### Step 3.7 – iOS summary checklist (on Mac)

| Step | Command / action |
|------|-------------------|
| Xcode | Install from App Store, open once, accept license |
| CocoaPods | `sudo gem install cocoapods` |
| Flutter doctor | `flutter doctor` and fix issues |
| Dependencies | `flutter pub get` |
| Pods | `cd ios && pod install && cd ..` |
| Run on simulator | `flutter run -d ios` |
| Run on device | `flutter run -d <device-id>` |
| Release build | `flutter build ios --release` then **Product** → **Archive** in Xcode |

---

## Quick reference (your machine – Windows + Android)

Since you already have Android installed:

1. **Check setup**
   ```bash
   flutter doctor
   flutter doctor --android-licenses   # if prompted
   ```

2. **Run on Android**
   ```bash
   cd c:\Users\am893131\Documents\refundoo
   flutter pub get
   flutter run -d android
   ```

3. **Build Android release APK**
   ```bash
   cd c:\Users\am893131\Documents\refundoo
   flutter build apk --release
   ```
   APK path: `build\app\outputs\flutter-apk\app-release.apk`.

For **iOS**, use a Mac and follow **Part 3** above.
