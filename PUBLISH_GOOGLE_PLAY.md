# Publish Refundoo to Google Play Store

Follow these steps to publish your Android app (App Bundle) to the Google Play Store.

---

## 1. Google Play Developer account (one-time)

1. Go to [Google Play Console](https://play.google.com/console).
2. Sign in with your Google account.
3. **Create a developer account**:
   - Accept the Developer Distribution Agreement.
   - Pay the **one-time $25 USD** registration fee.
   - Choose **Personal** or **Organization**.
   - Complete identity verification (e.g. government ID, payment details).
4. New personal accounts may need to verify access to an Android device via the Play Console app.

---

## 2. Sign your app (required for release)

Google Play expects a **signed** Android App Bundle. Do this once and keep your keystore safe.

### 2.1 Create an upload keystore

In Command Prompt or PowerShell (Java is installed with Android Studio):

```bash
keytool -genkey -v -keystore c:\path\to\refundoo-upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Replace `c:\path\to\` with a folder where you’ll keep the keystore (e.g. `c:\Users\am893131\Documents\refundoo\keys\`).
- Set a **store password** and **key password** (and remember them).
- Fill in name/organization as prompted.

**Important:** Back up the `.jks` file and passwords. If you lose them, you cannot update the same app on Play Store.

### 2.2 Add `key.properties` (do not commit to git)

Create a file **`android/key.properties`** in the refundoo project with:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:\\path\\to\\refundoo-upload-keystore.jks
```

- Use your real passwords and the real path to the `.jks` file.
- On Windows use double backslashes (`\\`) in `storeFile`.
- Add `android/key.properties` to `.gitignore` so it is never committed.

### 2.3 Configure signing in Gradle

Edit **`android/app/build.gradle`**:

1. After the line `def localProperties = new Properties()` and the block that loads `local.properties`, add:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

2. Inside the `android { }` block, add a `signingConfigs` block before `buildTypes`:

```groovy
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
```

3. In `buildTypes { release { ... } }`, change to:

```groovy
release {
    signingConfig signingConfigs.release
}
```

Then build the bundle (Step 3). If you skip signing config, you can still build a debug APK, but Play Store requires a properly signed release bundle.

---

## 3. Build the Android App Bundle

From the project folder:

```bash
cd c:\Users\am893131\Documents\refundoo
flutter build appbundle --release
```

Output file:

- **`build\app\outputs\bundle\release\app-release.aab`**

This is the file you upload to Play Console (not the APK for store distribution).

---

## 4. Create your app in Play Console

1. In [Play Console](https://play.google.com/console), click **Create app**.
2. Fill in:
   - **App name:** Refundoo
   - **Default language**
   - **App or game:** App
   - **Free or paid:** Free (or Paid if you choose)
3. Accept declarations (e.g. export compliance, Developer Program Policies, Play App Signing).
4. Create the app. You’ll land on the app dashboard.

---

## 5. Set up your app in the dashboard

Play Console will show a checklist. Complete at least:

| Task | Where | What to do |
|------|--------|------------|
| **App access** | Policy → App access | Declare if all features are available without login or specify exceptions. |
| **Ads** | Policy → App content | If the app has no ads, declare “No, my app does not contain ads.” |
| **Content rating** | Policy → App content | Complete the questionnaire; get a rating (e.g. Everyone). |
| **Target audience** | Policy → App content | Set age groups. |
| **News app** | Policy → App content | Declare “No” if Refundoo is not a news app. |
| **Store listing** | Grow → Main store listing | Short description, full description, screenshots (phone 16:9 or 9:16), app icon 512×512, feature graphic 1024×500. |
| **Privacy policy** | Policy → App content | Required if you collect any user data. Add a URL to your privacy policy. |

For **screenshots**: run the app on an emulator or device, capture key screens (dashboard, add refund, etc.), and upload them in the required sizes.

---

## 6. Upload the App Bundle

1. In Play Console, open your app → **Release** → **Production** (or **Testing** for internal/closed testing first).
2. Click **Create new release**.
3. **Upload** the file:
   - **`build\app\outputs\bundle\release\app-release.aab`**
4. Add **Release name** (e.g. “1.0 (1)”) and optional **Release notes**.
5. Save. You can leave the release in draft until the rest of the setup is done.

---

## 7. Submit for review

1. Finish all required items in the checklist (content rating, store listing, privacy policy, etc.).
2. In the release, click **Review release** (or **Start rollout to Production**).
3. Submit. Google will review the app (often a few days; can be up to a week or more).
4. Once approved, the app will be available on Google Play in the countries/regions you selected.

---

## Quick reference

| Step | Action |
|------|--------|
| 1 | Create Play Developer account ($25 one-time), verify identity |
| 2 | Create upload keystore → `android/key.properties` → configure `android/app/build.gradle` |
| 3 | `flutter build appbundle --release` → get `app-release.aab` |
| 4 | Play Console → Create app → Complete dashboard checklist |
| 5 | Release → Upload `app-release.aab` → Submit for review |

**Links**

- [Play Console](https://play.google.com/console)
- [Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152)
- [Publish your app](https://support.google.com/googleplay/android-developer/answer/9859751)
- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
