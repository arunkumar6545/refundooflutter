# Refundoo

Refund tracking app for Android and iOS. Scan SMS and emails to detect refunds and track them in one dashboard.

## Features

- **SMS scanning** (Android): Detect refund-related text messages from retailers and airlines.
- **Email sync**: Connect your email (Gmail/Outlook) with permission to scan for refund confirmations.
- **Dashboard**: See total pending refunds, wait time, and refunds by category (Travel, Retail, Services).
- **Refund progress tree**: Per-refund timeline (message parsed → merchant confirmed → bank processing → funds released).
- **Profile & permissions**: Sync permissions screen, profile with AI shopper persona, integrations.

Design follows the stitch bento dashboards (primary `#4ce6e6`, Manrope font, light/dark theme).

## Installing Flutter (Windows)

If you don’t have Flutter yet:

1. **Download Flutter SDK**
   - Open: https://docs.flutter.dev/get-started/install/windows
   - Download the latest **Flutter SDK** (zip) from the official link, or use:
   - Direct zip: https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip (check the site for the latest stable version).

2. **Extract**
   - Unzip to a folder **without spaces** in the path, e.g. `C:\flutter` or `C:\dev\flutter`.
   - Do **not** put it under `C:\Program Files`.

3. **Add Flutter to PATH**
   - Press **Win + R**, type `sysdm.cpl`, Enter.
   - **Advanced** tab → **Environment Variables**.
   - Under **User variables**, select **Path** → **Edit** → **New**.
   - Add the path to the `bin` folder inside the Flutter folder, e.g. `C:\flutter\bin`.
   - OK out of all dialogs.

4. **Windows desktop build**: If you run `flutter run -d windows` and see "Building with plugins requires symlink support", enable **Developer Mode**: run `start ms-settings:developers` and turn **Developer Mode** ON. Then run the app again.

5. **Open a new terminal** (so the new PATH is loaded) and run:
   ```bash
   flutter doctor
   ```
   Fix any issues it reports (e.g. install Android Studio or accept licenses for Android; for iOS you need a Mac with Xcode).

6. **Then in this project folder** run:
   ```bash
   cd c:\Users\am893131\Documents\refundoo
   flutter pub get
   flutter run
   ```
   Pick an attached device or emulator when prompted. To use an Android emulator, create one in Android Studio (AVD Manager) and start it before `flutter run`.

## After making code changes

**Build and restart every time after a change.** Stop the app (e.g. press `q` in the terminal), then run again (`flutter run` or **RUN_REFUNDOO.bat**) so changes are reflected.

## Build Artifacts & APK Paths

### Latest ready-to-install release

The latest signed release APK is always committed to:

```
releases/app-release.apk          ← arm64-v8a  (~22 MB, for most modern phones)
```

Download it directly from GitHub → **releases/** folder → click the file → **Download raw file**.

---

### Where Flutter puts APKs after a local build

| Build command | Output path (relative to project root) |
|---|---|
| `flutter build apk --debug` | `build\app\outputs\flutter-apk\app-debug.apk` |
| `flutter build apk --release` (fat) | `build\app\outputs\flutter-apk\app-release.apk` |
| `flutter build apk --release --split-per-abi` | `build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk` |
| | `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` ← **recommended** |
| | `build\app\outputs\flutter-apk\app-x86_64-release.apk` |
| `flutter build appbundle --release` | `build\app\outputs\bundle\release\app-release.aab` |
| `flutter build ipa` (macOS only) | `build\ios\ipa\Refundoo.ipa` |

> **Which APK to use?** Almost all phones sold since 2016 are `arm64-v8a`. Use the split APK for side-loading; use the App Bundle (AAB) for Google Play.

---

### Build & install locally (Android over USB / Wi-Fi ADB)

```powershell
# 1. Build signed release split APKs
flutter build apk --release --split-per-abi

# 2. Copy the arm64 slice to releases/ (tracked by Git)
Copy-Item "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "releases\app-release.apk" -Force

# 3a. Install over USB
adb install -r "releases\app-release.apk"

# 3b. Install over Wi-Fi ADB (replace IP:PORT with your device)
adb connect 192.168.x.x:38267
adb -s 192.168.x.x:38267 install -r "releases\app-release.apk"
```

> If install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (signing key changed), uninstall first:
> ```powershell
> adb uninstall com.refundoo.refundoo
> adb install "releases\app-release.apk"
> ```

---

### Android signing (release builds)

| File | Purpose |
|---|---|
| `android/key.properties` | Points Gradle to the keystore (**gitignored** – local only) |
| `android/app/refundoo-release.keystore` | Self-signed keystore (**gitignored** – local only) |
| `android/app/build.gradle` | Reads `key.properties` for the `release` signing config |

To regenerate the keystore on a new machine:
```powershell
keytool -genkey -v -keystore android\app\refundoo-release.keystore `
  -alias refundoo -keyalg RSA -keysize 2048 -validity 10000
```
Then create `android/key.properties`:
```
storePassword=<your_password>
keyPassword=<your_password>
keyAlias=refundoo
storeFile=refundoo-release.keystore
```

---

### CI / CD (Codemagic)

Automated builds are defined in `codemagic.yaml`. Each workflow produces artifacts downloadable from the Codemagic dashboard:

| Workflow | Artifact |
|---|---|
| `android-release` | `app-arm64-v8a-release.apk` + other ABI slices |
| `android-debug-fat` | `app-debug.apk` (fat, all ABIs) |
| `ios-unsigned` | `Refundoo.ipa` (no code-sign, sideload via Sideloadly) |

See **[BUILD_ANDROID_IOS.md](BUILD_ANDROID_IOS.md)** for the full step-by-step list to run and generate Android and iOS apps (including licenses, emulator, APK, App Bundle, and iOS on Mac).

To **publish the Android app to Google Play Store**, see **[PUBLISH_GOOGLE_PLAY.md](PUBLISH_GOOGLE_PLAY.md)** (account, signing, App Bundle, store listing, upload, review).

## Setup (after Flutter is installed)

1. **Generate platform folders** (if you cloned without them or get missing platform errors):
   ```bash
   cd refundoo
   flutter create . --org com.refundoo --project-name refundoo --platforms android,ios
   ```
   If prompted about existing files, choose to keep your existing `lib/` and `pubspec.yaml` and only add/update platform code.

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Run**:
   ```bash
   flutter run
   ```

## Android

- **SMS**: Requires `READ_SMS` and `RECEIVE_SMS` in `AndroidManifest.xml` (already added). The app will request permission at runtime when you enable SMS in Sync Permissions.
- **Min SDK**: 21. Target SDK: 34.

## iOS

- **SMS**: iOS does not allow third-party apps to read SMS. Refund detection on iOS relies on **Email Sync** only.
- **Email**: Use OAuth (e.g. Sign in with Apple or Google) and Gmail API / Microsoft Graph for read-only inbox access. The current `EmailSyncService` is a placeholder; implement OAuth and API calls when ready.

## Project structure

```
lib/
  app/                   # App widget, MaterialApp.router
  core/
    router/              # go_router routes (app_router.dart)
    theme/               # AppColors, AppTheme, responsive.dart (breakpoints)
    widgets/             # AppLogo (CustomPainter), AppDrawer
  features/
    add_refund/          # Manual add-refund form
    dashboard/           # Main dashboard (bento cards, categories, activity list)
    login/               # Google Sign-In / guest login
    permissions/         # Sync Permissions (SMS + multi-account email)
    profile/             # Profile, settings, integrations
    refund_detail/       # Per-refund progress timeline + coin animation
    reports/             # Charts & analytics screen
    splash/              # Splash with launch-sync radar animation
  models/                # RefundItem, RefundCategory, RefundTimelineStep
  services/              # SmsScannerService, EmailScannerService,
                         # RefundDetectionService, RefundStorageService, AuthService

android/
  app/src/main/res/      # Launcher icons (all mipmap densities)
  app/src/main/res/_gen_icons.py   # Regenerate icons: python _gen_icons.py
  key.properties         # (gitignored) signing config
  app/refundoo-release.keystore    # (gitignored) release keystore

releases/
  app-release.apk        # Latest arm64 release APK (tracked by Git)

codemagic.yaml           # CI/CD: android-release, ios-unsigned workflows
```

## SMS permission

- SMS scanning **requires explicit user permission**. On the **Sync Permissions** screen, when the user turns **SMS Access** on, the app requests the `READ_SMS` / `RECEIVE_SMS` permission.
- If the user denies, the toggle is set back to off and a snackbar offers a link to **Settings** to enable the permission later.
- Quick Sync only scans SMS when the user has both enabled SMS in the app and granted the system permission. All scanning runs on device; nothing is sent to a server.

## Local storage

- **All tracking details are saved and read from local memory only** (SharedPreferences). Refund items are stored as JSON and persist across app restarts.
- The dashboard loads refunds from local storage on launch; if none exist, a small default set is saved so the UI has sample data. Quick Sync merges any newly detected refunds (e.g. from SMS) with existing ones and saves the combined list locally.
- The refund detail screen loads the selected refund by ID from the same local storage. No tracking data is uploaded to any server.

---

**Version**: 1.0.0  
**Package**: `com.refundoo.refundoo`  
**Min SDK**: 21 (Android 5.0) · **Target SDK**: 34  
**Flutter**: ≥ 3.0.0
