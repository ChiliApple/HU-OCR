@echo off
REM ============================================================
REM  HU-OCR - Nur Config-GUI oeffnen (Eingangs-/Ausgangsordner aendern)
REM ============================================================
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Start-OCR.ps1" -ConfigOnly
endlocal
