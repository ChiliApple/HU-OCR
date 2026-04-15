<#
.SYNOPSIS
    HU-OCR Pull-Script - holt aktuelle Skript-Dateien aus dem GitHub-Repo.
.DESCRIPTION
    Public Repo ChiliApple/HU-OCR - kein Token benoetigt.
    Ueberschreibt NUR Skript-/Config-Template-Dateien, laesst bin/, logs/,
    processed/, quarantine/, config.json, .firstrun.done unangetastet.
.NOTES
    Wird automatisch durch Start-OCR.ps1 gestartet wenn ein Update verfuegbar ist.
    Manueller Aufruf: powershell -ExecutionPolicy Bypass -File Pull.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$Owner  = 'ChiliApple'
$Repo   = 'HU-OCR'
$Branch = 'main'
$Target = $PSScriptRoot

# Nur diese Dateien werden aktualisiert - alles andere bleibt lokal
$UpdateFiles = @(
    'Start-OCR.ps1',
    'Start-OCR.cmd',
    'Config-GUI.ps1',
    'Reset-OCR.ps1',
    'Reset-OCR.cmd',
    'Pull.ps1',
    'config.default.json',
    'Anleitung.md',
    'README.md'
)

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  HU-OCR Pull"                                -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Repo:   $Owner/$Repo ($Branch)" -ForegroundColor Gray
Write-Host "Ziel:   $Target"                -ForegroundColor Gray
Write-Host ""

$ua = 'Mozilla/5.0 HU-OCR-Pull'
$hdrRaw = @{ Accept = 'application/vnd.github.v3.raw' }

# Commit-SHA des aktuellen main
try {
    $ref = Invoke-RestMethod "https://api.github.com/repos/$Owner/$Repo/git/refs/heads/$Branch" `
            -Headers @{ Accept = 'application/vnd.github.v3+json' } -UserAgent $ua -TimeoutSec 15
    $sha = $ref.object.sha
    Write-Host "Commit: $sha" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "[FEHLER] Konnte Commit-Info nicht abrufen: $_" -ForegroundColor Red
    Read-Host "Enter zum Beenden"
    exit 1
}

$ok = 0; $fail = 0; $skip = 0
foreach ($f in $UpdateFiles) {
    $url   = "https://api.github.com/repos/$Owner/$Repo/contents/$f`?ref=$Branch"
    $local = Join-Path $Target $f
    Write-Host ("  {0,-28} ... " -f $f) -NoNewline
    try {
        Invoke-WebRequest -Uri $url -Headers $hdrRaw -UserAgent $ua -UseBasicParsing `
                          -OutFile $local -TimeoutSec 30 -ErrorAction Stop
        $sz = (Get-Item -LiteralPath $local).Length
        Write-Host ("OK ({0} bytes)" -f $sz) -ForegroundColor Green
        $ok++
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match '404') {
            Write-Host "nicht im Repo (skip)" -ForegroundColor DarkGray
            $skip++
        } else {
            Write-Host "FEHLER: $msg" -ForegroundColor Red
            $fail++
        }
    }
}

Write-Host ""
Write-Host ("=== Pull fertig ===  OK: $ok  |  Skip: $skip  |  Fehler: $fail") -ForegroundColor Cyan
Write-Host ""
Write-Host "Starte nun: .\Start-OCR.cmd" -ForegroundColor Yellow
Write-Host ""
Read-Host "Enter zum Beenden"
