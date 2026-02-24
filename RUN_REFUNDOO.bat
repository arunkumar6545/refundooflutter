@echo off
REM Run this in a new Command Prompt, or double-click, to build and launch Refundoo.
REM Flutter must be installed at C:\flutter (or set FLUTTER_ROOT below).
REM After making code changes: build and restart every time (stop app with 'q', then run this again).

set "FLUTTER_ROOT=C:\flutter"
set "PATH=%FLUTTER_ROOT%\bin;%PATH%"

cd /d "%~dp0"

echo.
echo === Refundoo - Flutter setup and run ===
echo.

echo [1/3] Checking Flutter...
flutter --version
if errorlevel 1 (
    echo.
    echo Flutter not found or failed. Make sure you extracted the zip to C:\flutter
    echo and that you run this script in a new Command Prompt after adding Flutter to PATH.
    pause
    exit /b 1
)

echo.
echo [2/3] Getting project dependencies...
flutter pub get
if errorlevel 1 (
    echo.
    echo flutter pub get failed.
    pause
    exit /b 1
)

echo.
echo [3/3] Launching app...
echo.
echo If you see "Building with plugins requires symlink support", enable Developer Mode:
echo   start ms-settings:developers
echo Then turn ON "Developer Mode" and run this script again.
echo.
echo Trying Chrome first (no extra settings needed)...
flutter run -d chrome
if errorlevel 1 (
  echo.
  echo Chrome failed. Trying Windows desktop...
  flutter run -d windows
)

pause
