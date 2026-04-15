@echo off
REM ============================================================
REM  HU-OCR - Start (First-Run Bootstrap + Watcher)
REM ============================================================
setlocal
cd /d "%~dp0"
echo [CMD] HU-OCR Start (cwd: %cd%)
if not exist "scripts\Start-OCR.ps1" (
    echo.
    echo [FEHLER] scripts\Start-OCR.ps1 nicht gefunden.
    echo          Bitte komplette Ordnerstruktur aus GitHub Release neu laden:
    echo          https://github.com/ChiliApple/HU-OCR/