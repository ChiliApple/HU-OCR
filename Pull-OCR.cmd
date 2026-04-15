@echo off
REM ============================================================
REM  HU-OCR - Manuelles Update vom GitHub-Repo
REM ============================================================
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Pull.ps1"
endlocal
