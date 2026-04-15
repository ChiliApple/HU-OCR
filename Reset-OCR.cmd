@echo off
REM Reset HU-OCR environment (clean test)
REM  Reset-OCR.cmd           -> direkt loeschen (Standard)
REM  Reset-OCR.cmd -Confirm  -> mit Rueckfrage
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Reset-OCR.ps1" %*
endlocal
