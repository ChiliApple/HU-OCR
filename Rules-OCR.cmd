@echo off
setlocal
cd /d "%~dp0"
echo [CMD] HU-OCR Regel-Editor (cwd: %cd%)
if not exist "scripts\Rules-GUI.ps1" (
    echo [FEHLER] scripts\Rules-GUI.ps1 nicht gefunden.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Rules-GUI.ps1"
set EC=%errorlevel%
echo.
echo Regel-Editor beendet (ExitCode %EC%)
pause
endlocal
