@echo off
cd /d "%~dp0mobile"
echo ========================================================
echo FitHayot 360 - Brauzerda (Chrome) ishga tushirilmoqda...
echo ========================================================
flutter run -d chrome --dart-define=API_BASE_URL=https://fithayot360-api.onrender.com
pause
