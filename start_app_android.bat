@echo off
cd /d "%~dp0mobile"
echo ========================================================
echo FitHayot 360 - Android emulyatorda ishga tushirilmoqda...
echo ========================================================
flutter run --dart-define=API_BASE_URL=https://fithayot360-api.onrender.com
pause
