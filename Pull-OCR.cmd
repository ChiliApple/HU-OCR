@echo off
setlocal
cd /d "%~dp0"
echo [CMD] HU-OCR Pull (cwd: %cd%)
if not exist "scripts\Pull.ps1" (
    echo [FEHLER] scripts\Pull.ps1 nicht gefunden.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Pull.ps1"
set EC=%errorlevel%
echo.
echo Pull beendet (ExitCode %EC%)
pause
endlocal
