@echo off
setlocal
cd /d "%~dp0"
echo [CMD] HU-OCR Reset (cwd: %cd%)
if not exist "scripts\Reset-OCR.ps1" (
    echo [FEHLER] scripts\Reset-OCR.ps1 nicht gefunden.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Reset-OCR.