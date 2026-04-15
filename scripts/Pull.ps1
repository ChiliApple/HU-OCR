<#
.SYNOPSIS
    HU-OCR Pull - holt aktuelle Skript-/Config-/Doc-Dateien aus dem GitHub-Repo.
.DESCRIPTION
    Public Repo ChiliApple/HU-OCR - kein Token benoetigt.
    Aktualisiert NUR die explizit gelisteten Dateien (siehe $Files).
    bin\, logs\, processed\, quarantine\, config.json, .firstrun.done bleiben unangetastet.
.NOTES
    Wird automatisch von Start-OCR.ps1 aufgerufen wenn Update verfuegbar.
    Manuell: Pull-OCR.cmd
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$Owner   = 'ChiliApple'
$Repo    = 'HU-OCR'
$Branch  = 'main'
# Script liegt in scripts/ -> Tool-Root = Parent
$ScriptDir = $PSScriptRoot
$Target    = Split-Path -Parent $PSScriptRoot

# Mapping: Repo-Pfad -> lokaler Ziel-Pfad (relativ zu Target)
$Files = @(
    @{ Repo='Start-OCR.cmd';           Local='Start-OCR.cmd'           },
    @{ Repo='Reset-OCR.cmd';           Local='Reset-OCR.cmd'           },
    @{ Repo='Config-OCR.cmd';          Local='Config-OCR.cmd'          },
    @{ Repo='Pull-OCR.cmd';            Local='Pull-OCR.cmd'            },
    @{ Repo='config.default.json';     Local='config.default.json'     },
    @{ Repo='docs/README.md';          Local='docs\README.md'          },
    @{ Repo='docs/Anleitung.md';       Local='docs\Anleitung.md'       },
    @{ Repo='docs/LICENSE';            Local='docs\LICENSE'            },
    @{ Repo='docs/NOTICE.md';          Local='docs\NOTICE.md'          },
    @{ Repo='scripts/Start-OCR.ps1';   Local='scripts\Start-OCR.ps1'   },
    @{ Repo='scripts/Config-GUI.ps1';  Local='scripts\Config-GUI.ps1'  },
    @{ Repo='scripts/Reset-OCR.ps1';   Local='scripts\Reset-OCR.ps1'   },
    @{ Repo='scripts/Pull.ps1';        Local='scripts\Pull.ps1'        }
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

try {
    $ref = Invoke-RestMethod "https://api.github.com/repos/$Owner/$Repo/git/refs/heads/$Branch" `
            -Headers @{ Accept = 'application/vnd.github.v3+json' } -UserAgent $ua -TimeoutSec 15
    Write-Host "Commit: $($ref.object.sha)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "[FEHLER] Konnte Commit-Info nicht abrufen: $_" -ForegroundColor Red
    Read-Host "Enter zum Beenden"
    exit 1
}

foreach ($sub in @('scripts','docs')) {
    $d = Join-Path $Target $sub
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$ok = 0; $fail = 0; $skip = 0
foreach ($f in $Files) {
    $url   = "https://api.github.com/repos/$Owner/$Repo/contents/$($f.Repo)?ref=$Branch"
    $local = Join-Path $Target $f.Local
    $dir   = Split-Path -Parent $local
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Write-Host ("  {0,-30} ... " -f $f.Repo) -NoNewline
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
Read-Host "Enter zum B