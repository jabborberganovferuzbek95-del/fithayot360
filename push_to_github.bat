@echo off
cd /d "%~dp0"
echo ========================================================
echo FitHayot 360 - GitHub'ga yuklash (Push)
echo Repozitoriy: https://github.com/jabborberganovferuzbek95-del/fithayot360.git
echo ========================================================
echo.
git push -u origin main
echo.
if %ERRORLEVEL% EQU 0 (
    echo ========================================================
    echo TABRIKLAYMIZ! Kodlar GitHub'ga muvaffaqiyatli yuklandi!
    echo ========================================================
) else (
    echo ========================================================
    echo Xatolik yuz berdi. Iltimos qaytadan urinib ko'ring.
    echo ========================================================
)
pause
