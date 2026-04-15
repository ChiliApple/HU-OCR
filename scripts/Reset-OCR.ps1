<#
.SYNOPSIS
    Bereinigt den OCR-Projektordner fuer einen Clean-Test.
.DESCRIPTION
    Loescht alle durch Bootstrap/Laufzeit erzeugten Artefakte:
      - bin\               (Python, Tesseract, Ghostscript, qpdf)
      - .firstrun.done
      - config.json        (user-Ordner-Einstellung)
      - logs\
      - processed\
      - quarantine\
    Behaelt:
      - Start-OCR.cmd / Start-OCR.ps1 / Config-GUI.ps1
      - config.default.json
      - README.txt
      - Reset-OCR.*
#>
[CmdletBinding()]
param(
    [switch]$Confirm    # Standard: OHNE Rueckfrage. Mit -Confirm = mit Rueckfrage.
)

$ErrorActionPreference = 'Stop'
# Tool-Root = Parent von scripts\
$Root = Split-Path -Parent $PSScriptRoot

$targets = @(
    (Join-Path $Root 'bin'),
    (Join-Path $Root 'logs'),
    (Join-Path $Root 'processed'),
    (Join-Path $Root 'quarantine'),
    (Join-Path $Root '.firstrun.done'),
    (Join-Path $Root 'config.json')
)

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  HU-OCR - Reset / Clean-Test-Umgebung"       -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Folgendes wird geloescht:" -ForegroundColor Cyan
foreach ($t in $targets) {
    if (Test-Path $t) {
        $size = 0
        try {
            if ((Get-Item $t -Force).PSIsContainer) {
                $size = (Get-ChildItem $t -Recurse -Force -ErrorAction SilentlyContinue |
                         Measure-Object -Property Length -Sum).Sum
            } else {
                $size = (Get-Item $t -Force).Length
            }
        } catch {}
        $sizeMb = [math]::Round($size/1MB, 2)
        Write-Host ("  [X] {0,-55} {1,8} MB" -f (Split-Path $t -Leaf), $sizeMb) -ForegroundColor Gray
    } else {
        Write-Host ("  [ ] {0,-55} (nicht vorhanden)" -f (Split-Path $t -Leaf)) -ForegroundColor DarkGray
    }
}
Write-Host ""

if ($Confirm) {
    Write-Host -NoNewline "Wirklich loeschen? (j/N): " -ForegroundColor Yellow
    $ans = [Console]::ReadLine()
    if ($ans -notmatch '^[jJyY]') {
        Write-Host "Abgebrochen." -ForegroundColor Yellow
        exit 0
    }
}

$deleted = 0; $failed = 0
foreach ($t in $targets) {
    if (Test-Path $t) {
        try {
            Remove-Item -Path $t -Recurse -Force -ErrorAction Stop
            Write-Host ("  OK  {0}" -f (Split-Path $t -Leaf)) -ForegroundColor Green
            $deleted++
        } catch {
            Write-Host ("  ERR {0}: {1}" -f (Split-Path $t -Leaf), $_.Exception.Message) -ForegroundColor Red
            $failed++
        }
    }
}

Write-Host ""
Write-Host ("=== Reset fertig === Geloescht: {0} | Fehler: {1}" -f $deleted,$failed) -ForegroundColor Cyan
Write-Host ""
Write-Host "Naechster Start = First-