@echo off
REM ============================================================
REM  OCR Portable - Starter
REM  Usage:
REM    Start-OCR.cmd              -> Normal run
REM    Start-OCR.cmd -Reconfigure -> Re-open folder selection GUI
REM ============================================================
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Start-OCR.ps1" %*
if errorlevel 1 (
    echo.
    echo [!] Start-OCR.ps1 beendet mit Fehler.
    pause
)
endlocal
