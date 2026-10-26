@echo off
cd /d "%~dp0backend"
set DATABASE_URL=sqlite:///./fithayot.db
set APP_ENV=development
set AUTO_CREATE_TABLES=true
set SEED_ON_START=true
set EXPOSE_RESET_TOKEN=true
echo ========================================================
echo FitHayot 360 Backend Server ishga tushdi!
echo Kompyuterda: http://localhost:8000/docs
echo Telefonda (Wi-Fi): http://172.18.165.187:8000
echo ========================================================
.\.venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000
pause

