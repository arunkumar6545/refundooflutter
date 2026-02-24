# Install Flutter and run Refundoo

You need Flutter installed once; then you can build and run the app.

---

## 1. Download Flutter (Windows)

- Go to: **https://docs.flutter.dev/get-started/install/windows**
- Click **Download Flutter SDK** and get the `.zip` for Windows.

---

## 2. Extract

- Unzip to a folder **without spaces**, e.g.:
  - `C:\flutter`
  - or `C:\dev\flutter`
- Avoid: `C:\Program Files`, or any path with spaces.

---

## 3. Add Flutter to PATH

1. Press **Win + R**, type **`sysdm.cpl`**, Enter.
2. Open the **Advanced** tab → **Environment Variables**.
3. Under **User variables**, select **Path** → **Edit** → **New**.
4. Add the **bin** folder of Flutter, e.g. **`C:\flutter\bin`**.
5. Click **OK** on all windows.

---

## 4. Check installation

1. **Close and reopen** your terminal (or Cursor).
2. Run:
   ```bash
   flutter doctor
   ```
3. Fix what it asks for:
   - **Android**: Install [Android Studio](https://developer.android.com/studio) and create an emulator (AVD), or connect a physical Android device with USB debugging on.
   - **Android licenses**: Run `flutter doctor --android-licenses` and accept.
   - **iOS**: Only on Mac with Xcode (for this project you can run on Android only).

---

## 5. Run Refundoo

In a terminal (from the project folder):

```bash
cd c:\Users\am893131\Documents\refundoo
flutter pub get
flutter run
```

- If you have an **emulator** running or a **device** connected, Flutter will ask you to pick one.
- The app will build and launch (first run can take a few minutes).

---

## Troubleshooting

| Issue | What to do |
|-------|------------|
| `flutter` not found | New PATH only applies in **new** terminals. Close Cursor/terminal and open again. Or restart the PC. |
| No devices | Start an Android emulator from Android Studio (AVD Manager), or connect a phone with USB debugging enabled. |
| Build errors | Run `flutter clean` then `flutter pub get` and `flutter run` again. |
| Android licenses | Run `flutter doctor --android-licenses` and accept all. |

After Flutter is installed and `flutter doctor` is happy, **Refundoo** will build and run with `flutter run`.
