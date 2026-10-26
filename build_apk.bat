@echo off
cd /d "%~dp0mobile"
echo ========================================================
echo FitHayot 360 - Android APK fayl yig'ilmoqda (Release)...
echo Server: https://fithayot360-api.onrender.com
echo ========================================================
echo.
flutter build apk --release --dart-define=API_BASE_URL=https://fithayot360-api.onrender.com
echo.
if %ERRORLEVEL% EQU 0 (
    echo ========================================================
    echo TABRIKLAYMIZ! APK muvaffaqiyatli tayyorlandi!
    echo Fayl manzili:
    echo %~dp0mobile\build\app\outputs\flutter-apk\app-release.apk
    echo ========================================================
    explorer /select,"%~dp0mobile\build\app\outputs\flutter-apk\app-release.apk"
) else (
    echo ========================================================
    echo Xatolik yuz berdi. Iltimos tekshirib ko'ring.
    echo ========================================================
)
pause
