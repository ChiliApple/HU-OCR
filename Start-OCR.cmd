@echo off
REM ============================================================
REM  HU-OCR - Start (First-Run Bootstrap + Watcher)
REM  Usage:
REM    Start-OCR.cmd              -> Normal
REM    Start-OCR.cmd -Reconfigure -> Ordner-Auswahl + Watcher
REM ============================================================
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Start-OCR.ps1" %*
if errorlevel 1 (
    echo.
    echo [!] Start-OCR beendet mit Fehler.
 