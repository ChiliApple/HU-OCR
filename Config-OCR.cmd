@echo off
setlocal
cd /d "%~dp0"
echo [CMD] HU-OCR Config-Only (cwd: %cd%)
if not exist "scripts\Start-OCR.ps1" (
    echo [FEHLER] scripts\Start-OCR.ps1 nicht gefunden.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Start-OCR.ps1" -ConfigOnly
set EC=%errorlevel%
echo.
echo Config beendet (ExitCode %EC%)
pause
endlocal
