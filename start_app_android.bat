@echo off
cd /d "%~dp0mobile"
echo ========================================================
echo FitHayot 360 - Android emulyatorda ishga tushirilmoqda...
echo ========================================================
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
pause
