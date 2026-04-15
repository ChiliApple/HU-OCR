<#
.SYNOPSIS
    OCR Portable - Bootstrap + FileSystemWatcher
.DESCRIPTION
    First-Run:   Laedt Python Embeddable, Tesseract, Ghostscript, qpdf nach ./bin/,
                 installiert ocrmypdf in Python-Embeddable, oeffnet Config-GUI.
    Normal-Run:  Laedt config.json, startet Watcher auf InputFolder.
                 Neue PDFs -> ocrmypdf -> OutputFolder. Original -> ProcessedFolder.
                 Fehler -> QuarantineFolder.
.PARAMETER Reconfigure
    Erzwingt erneutes Oeffnen der Ordner-Auswahl-GUI.
.PARAMETER SkipBootstrap
    Ueberspringt First-Run-Check (Debug).
#>
[CmdletBinding()]
param(
    [switch]$Reconfigure,
    [switch]$ConfigOnly,     # nur GUI oeffnen, speichern, beenden (ohne Watcher)
    [switch]$SkipBootstrap
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# ==================================================================
# VERSION (MUSS als Literal stehen, wird vom Update-Check via Regex gematched)
# ==================================================================
$script:Version = '1.3.0'

# ==================================================================
# PFADE
#   $ScriptDir = .\scripts\   (dieses .ps1 liegt hier)
#   $Root      = Tool-Root    (Parent von scripts\)
# ==================================================================
$ScriptDir     = $PSScriptRoot
$Root          = Split-Path -Parent $PSScriptRoot
$BinDir        = Join-Path $Root 'bin'
$PythonDir     = Join-Path $BinDir 'python'
$PythonExe     = Join-Path $PythonDir 'python.exe'
$TesseractDir  = Join-Path $BinDir 'tesseract'
$TesseractExe  = Join-Path $TesseractDir 'tesseract.exe'
$TessdataDir   = Join-Path $TesseractDir 'tessdata'
$GsDir         = Join-Path $BinDir 'ghostscript'
$QpdfDir       = Join-Path $BinDir 'qpdf'
$SevenZipRExe  = Join-Path $BinDir '7zr.exe'
$SevenZipAExe  = Join-Path $BinDir '7z-extra\7za.exe'
$FirstRunFlag  = Join-Path $Root '.firstrun.done'
$ConfigFile    = Join-Path $Root 'config.json'
$DefaultCfg    = Join-Path $Root 'config.default.json'
$GuiScript     = Join-Path $ScriptDir 'Config-GUI.ps1'

# ==================================================================
# LOGGING
# ==================================================================
$script:LogFile = $null
function Initialize-Log {
    param([string]$LogFolder)
    if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null }
    $script:LogFile = Join-Path $LogFolder ("ocr_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd'))
}
function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','OK','DEBUG')][string]$Level = 'INFO'
    )
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] [$Level] $Message"
    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'OK'    { Write-Host $line -ForegroundColor Green }
        'DEBUG' { Write-Host $line -ForegroundColor DarkGray }
        default { Write-Host $line }
    }
    if ($script:LogFile) {
        try { Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 } catch {}
    }
}

function Clear-OldLogs {
    param([string]$LogFolder,[int]$RetentionDays)
    if (-not (Test-Path $LogFolder)) { return }
    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    Get-ChildItem -Path $LogFolder -Filter 'ocr_*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        ForEach-Object {
            try { Remove-Item $_.FullName -Force; Write-Log "Alte Log-Datei geloescht: $($_.Name)" 'DEBUG' } catch {}
        }
}

# ==================================================================
# UPDATE-CHECK (GitHub public repo, kein Token noetig)
# ==================================================================
$script:UpdateRepoApi = 'https://api.github.com/repos/ChiliApple/HU-OCR/contents/scripts/Start-OCR.ps1?ref=main'

function Invoke-UpdateCheck {
    try {
        $ua = 'Mozilla/5.0 HU-OCR-UpdateCheck'
        $r = Invoke-WebRequest -Uri $script:UpdateRepoApi `
              -Headers @{ Accept = 'application/vnd.github.v3.raw' } `
              -UserAgent $ua -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $text = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
        if ($text -match "\`$script:Version\s*=\s*'([0-9\.]+)'") {
            $remote = $Matches[1]
            Write-Log "Update-Check: Lokal v$($script:Version) | Remote v$remote" 'DEBUG'
            $cmp = 0
            try { $cmp = ([Version]$remote).CompareTo([Version]$script:Version) } catch {}
            if ($cmp -gt 0) {
                Write-Host ""
                Write-Host "  !!  NEUE VERSION VERFUEGBAR: v$remote  (aktuell v$($script:Version))  !!" -ForegroundColor Yellow
                Write-Host -NoNewline "  Jetzt updaten? (j/N): " -ForegroundColor Yellow
                $ans = [Console]::ReadLine()
                if ($ans -match '^[jJyY]') {
                    $pull = Join-Path $ScriptDir 'Pull.ps1'
                    if (Test-Path -LiteralPath $pull) {
                        Write-Log "Update gestartet. Tool schliesst in 3s..." 'OK'
                        Start-Process -FilePath 'powershell.exe' `
                            -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File',$pull) | Out-Null
                        Start-Sleep -Seconds 3
                        exit 0
                    } else {
                        Write-Log "Pull.ps1 nicht gefunden - kein Update moeglich." 'WARN'
                    }
                } else {
                    Write-Log "Update verschoben." 'INFO'
                }
            }
        }
    } catch {
        Write-Log "Update-Check fehlgeschlagen: $($_.Exception.Message)" 'DEBUG'
    }
}

# ==================================================================
# CONFIG LADEN
# ==================================================================
function Load-Config {
    if (-not (Test-Path $ConfigFile)) {
        if (-not (Test-Path $DefaultCfg)) {
            throw "Weder config.json noch config.default.json gefunden. Installation defekt."
        }
        Copy-Item $DefaultCfg $ConfigFile -Force
        Write-Host "[INFO] config.json aus config.default.json erstellt."
    }
    Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
}
function Save-Config {
    param($Config)
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigFile -Encoding UTF8
}

# ==================================================================
# DOWNLOAD-HELFER
# ==================================================================
function Get-File {
    param([string]$Url,[string]$Target,[int]$MinSizeBytes = 1024)
    $dir = Split-Path $Target -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Write-Log "Download: $Url" 'INFO'
    $ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
    Invoke-WebRequest -Uri $Url -OutFile $Target -UseBasicParsing -UserAgent $ua -MaximumRedirection 10
    if (-not (Test-Path $Target)) { throw "Download nicht gespeichert: $Url" }
    $sz = (Get-Item $Target).Length
    $mb = [math]::Round($sz/1MB,2)
    Write-Log "  -> ${sz} bytes (${mb} MB)" 'DEBUG'
    if ($sz -lt $MinSizeBytes) {
        throw "Download zu klein ($sz bytes, erwartet >= $MinSizeBytes). Evtl. Fehlerseite statt Datei: $Url"
    }
}

# ==================================================================
# FIRST-RUN BOOTSTRAP
# ==================================================================
function Invoke-NativeCommand {
    <#
        Wrapper fuer native EXE-Aufrufe im Bootstrap.
        PS5 + ErrorActionPreference='Stop' wuerde stderr-Output als terminating error werten.
        Lokal auf Continue setzen, Exit-Code pruefen.
    #>
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$PassThruOutput,
        [switch]$CaptureOutput    # gibt Output bei Fehler ueber Write-Log aus
    )
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($PassThruOutput) {
            & $FilePath @Arguments *>&1 | Out-Host
            return $LASTEXITCODE
        }
        if ($CaptureOutput) {
            $out = & $FilePath @Arguments 2>&1
            $ec  = $LASTEXITCODE
            if ($ec -ne 0) {
                Write-Log "Native Command ExitCode=$ec. Output:" 'WARN'
                $out | ForEach-Object { Write-Log "  | $_" 'DEBUG' }
            }
            return $ec
        }
        & $FilePath @Arguments *>&1 | Out-Null
        return $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEap }
}

function Find-SystemSevenZip {
    # Suche nach installiertem 7-Zip (robuster als portable 7za bei neuen NSIS)
    $candidates = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$env:ProgramW6432\7-Zip\7z.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    return $null
}

function Invoke-Bootstrap {
    param($Config)

    Write-Log "=== FIRST-RUN BOOTSTRAP ===" 'INFO'
    Write-Log "Dies kann einige Minuten dauern (ca. 400 MB Download)." 'INFO'

    if (-not (Test-Path $BinDir)) { New-Item -ItemType Directory -Path $BinDir -Force | Out-Null }

    # --- 7-Zip Strategie ---
    #   1. System-7z bevorzugen (oft bereits auf Geraeten installiert, robuster bei neueren NSIS)
    #   2. Fallback: 7zr.exe -> 7z-extra.7z -> 7za.exe (portable)
    $script:SevenZ = Find-SystemSevenZip
    if ($script:SevenZ) {
        Write-Log "System-7-Zip gefunden: $script:SevenZ" 'OK'
    } else {
        Write-Log "Kein System-7-Zip -> lade portable 7za" 'INFO'
        if (-not (Test-Path $SevenZipRExe)) {
            Get-File -Url $Config.Downloads.SevenZip -Target $SevenZipRExe -MinSizeBytes 100000
            Write-Log "7zr.exe bereit." 'OK'
        }
        if (-not (Test-Path $SevenZipAExe)) {
            $extraArchive = Join-Path $BinDir '7z-extra.7z'
            $extraDir     = Join-Path $BinDir '7z-extra'
            Get-File -Url $Config.Downloads.SevenZipExtra -Target $extraArchive -MinSizeBytes 500000
            if (Test-Path $extraDir) { Remove-Item $extraDir -Recurse -Force }
            New-Item -ItemType Directory -Path $extraDir -Force | Out-Null
            $ec = Invoke-NativeCommand -FilePath $SevenZipRExe -Arguments @('x',$extraArchive,"-o$extraDir",'-y') -CaptureOutput
            if ($ec -ne 0) { throw "7z-extra Extraktion fehlgeschlagen (ExitCode=$ec)." }
            Remove-Item $extraArchive -Force
            if (-not (Test-Path $SevenZipAExe)) { throw "7za.exe nach Extraktion nicht gefunden." }
            Write-Log "7za.exe (NSIS-faehig) bereit." 'OK'
        }
        $script:SevenZ = $SevenZipAExe
    }

    # --- Python Embeddable ---
    if (-not (Test-Path $PythonExe)) {
        $zipPath = Join-Path $BinDir 'python.zip'
        Get-File -Url $Config.Downloads.Python -Target $zipPath
        if (Test-Path $PythonDir) { Remove-Item $PythonDir -Recurse -Force }
        Expand-Archive -Path $zipPath -DestinationPath $PythonDir -Force
        Remove-Item $zipPath -Force

        # pythonXX._pth patchen: 'import site' aktivieren
        $pthFile = Get-ChildItem -Path $PythonDir -Filter 'python*._pth' | Select-Object -First 1
        if ($pthFile) {
            $content = Get-Content $pthFile.FullName
            $content = $content -replace '^#\s*import site', 'import site'
            Set-Content -Path $pthFile.FullName -Value $content -Encoding ASCII
        }
        Write-Log "Python Embeddable bereit." 'OK'
    }

    # --- pip installieren ---
    $pipExe = Join-Path $PythonDir 'Scripts\pip.exe'
    if (-not (Test-Path $pipExe)) {
        $getPip = Join-Path $BinDir 'get-pip.py'
        Get-File -Url $Config.Downloads.GetPip -Target $getPip
        $ec = Invoke-NativeCommand -FilePath $PythonExe -Arguments @($getPip,'--no-warn-script-location') -PassThruOutput
        if ($ec -ne 0) { throw "pip-Install fehlgeschlagen (ExitCode=$ec)." }
        Remove-Item $getPip -Force
        Write-Log "pip installiert." 'OK'
    }

    # --- ocrmypdf + pikepdf in Embeddable-Python ---
    $ec = Invoke-NativeCommand -FilePath $PythonExe -Arguments @('-c','import ocrmypdf')
    $hasOcr = ($ec -eq 0)

    if (-not $hasOcr) {
        Write-Log "Installiere ocrmypdf + Abhaengigkeiten (dauert laenger)..." 'INFO'
        $ec = Invoke-NativeCommand -FilePath $PythonExe -Arguments @('-m','pip','install','--upgrade','pip','--no-warn-script-location') -PassThruOutput
        if ($ec -ne 0) { throw "pip-Upgrade fehlgeschlagen (ExitCode=$ec)." }
        $ec = Invoke-NativeCommand -FilePath $PythonExe -Arguments @('-m','pip','install','ocrmypdf','pikepdf','--no-warn-script-location') -PassThruOutput
        if ($ec -ne 0) { throw "ocrmypdf-Install fehlgeschlagen (ExitCode=$ec)." }
        Write-Log "ocrmypdf installiert." 'OK'
    } else {
        Write-Log "ocrmypdf bereits vorhanden." 'DEBUG'
    }

    # --- Tesseract (NSIS-Installer extrahieren) ---
    if (-not (Test-Path $TesseractExe)) {
        $tessInstaller = Join-Path $BinDir 'tesseract-setup.exe'
        # UB-Mannheim-Installer >= 30 MB erwartet
        Get-File -Url $Config.Downloads.Tesseract -Target $tessInstaller -MinSizeBytes 20000000
        if (Test-Path $TesseractDir) { Remove-Item $TesseractDir -Recurse -Force }
        New-Item -ItemType Directory -Path $TesseractDir -Force | Out-Null
        $ec = Invoke-NativeCommand -FilePath $script:SevenZ -Arguments @('x',$tessInstaller,"-o$TesseractDir",'-y') -CaptureOutput
        if ($ec -ne 0) { throw "Tesseract-Extraktion fehlgeschlagen (ExitCode=$ec). Siehe Log-Output oben." }
        Remove-Item $tessInstaller -Force
        # NSIS-Metadaten aufraeumen
        Get-ChildItem -Path $TesseractDir -Filter '$*' -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $TesseractExe)) { throw "tesseract.exe nach Extraktion nicht gefunden." }
        Write-Log "Tesseract bereit." 'OK'
    }

    # --- Tessdata (deu + osd) ---
    if (-not (Test-Path $TessdataDir)) { New-Item -ItemType Directory -Path $TessdataDir -Force | Out-Null }
    $deuFile = Join-Path $TessdataDir 'deu.traineddata'
    $osdFile = Join-Path $TessdataDir 'osd.traineddata'
    if (-not (Test-Path $deuFile)) { Get-File -Url $Config.Downloads.TessdataDeu -Target $deuFile; Write-Log "deu.traineddata bereit." 'OK' }
    if (-not (Test-Path $osdFile)) { Get-File -Url $Config.Downloads.TessdataOsd -Target $osdFile; Write-Log "osd.traineddata bereit." 'OK' }

    # --- Ghostscript (NSIS-Installer via 7zr) ---
    $gsExe = Get-ChildItem -Path $GsDir -Filter 'gswin64c.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $gsExe) {
        $gsInstaller = Join-Path $BinDir 'gs-setup.exe'
        Get-File -Url $Config.Downloads.Ghostscript -Target $gsInstaller
        if (Test-Path $GsDir) { Remove-Item $GsDir -Recurse -Force }
        New-Item -ItemType Directory -Path $GsDir -Force | Out-Null
        $ec = Invoke-NativeCommand -FilePath $script:SevenZ -Arguments @('x',$gsInstaller,"-o$GsDir",'-y') -CaptureOutput
        if ($ec -ne 0) { throw "Ghostscript-Extraktion fehlgeschlagen (ExitCode=$ec)." }
        Remove-Item $gsInstaller -Force
        Get-ChildItem -Path $GsDir -Filter '$*' -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $gsExe = Get-ChildItem -Path $GsDir -Filter 'gswin64c.exe' -Recurse | Select-Object -First 1
        if (-not $gsExe) { throw "gswin64c.exe nach Extraktion nicht gefunden." }
        Write-Log "Ghostscript bereit." 'OK'
    }

    # --- qpdf (ZIP) ---
    $qpdfExe = Get-ChildItem -Path $QpdfDir -Filter 'qpdf.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $qpdfExe) {
        $qpdfZip = Join-Path $BinDir 'qpdf.zip'
        Get-File -Url $Config.Downloads.Qpdf -Target $qpdfZip
        if (Test-Path $QpdfDir) { Remove-Item $QpdfDir -Recurse -Force }
        Expand-Archive -Path $qpdfZip -DestinationPath $QpdfDir -Force
        Remove-Item $qpdfZip -Force
        $qpdfExe = Get-ChildItem -Path $QpdfDir -Filter 'qpdf.exe' -Recurse | Select-Object -First 1
        if (-not $qpdfExe) { throw "qpdf.exe nach Extraktion nicht gefunden." }
        Write-Log "qpdf bereit." 'OK'
    }

    # --- Marker ---
    Set-Content -Path $FirstRunFlag -Value (Get-Date -Format 'o') -Encoding UTF8
    Write-Log "=== BOOTSTRAP ABGESCHLOSSEN ===" 'OK'
}

# ==================================================================
# PROCESS-LOKALE PATH-SETUP
# ==================================================================
function Set-ToolPaths {
    $gsBin  = (Get-ChildItem -Path $GsDir  -Filter 'gswin64c.exe' -Recurse | Select-Object -First 1).DirectoryName
    $qpdfBin= (Get-ChildItem -Path $QpdfDir -Filter 'qpdf.exe'    -Recurse | Select-Object -First 1).DirectoryName
    $pyScripts = Join-Path $PythonDir 'Scripts'
    $paths = @($TesseractDir, $gsBin, $qpdfBin, $PythonDir, $pyScripts)
    $env:PATH = ($paths -join ';') + ';' + $env:PATH
    $env:TESSDATA_PREFIX = $TessdataDir
    Write-Log "PATH (Prozess) gesetzt: Tesseract, GS, qpdf, Python." 'DEBUG'
}

# ==================================================================
# CONFIG GUI AUFRUFEN
# ==================================================================
function Invoke-ConfigGui {
    param($Config)
    Write-Log "Oeffne Ordner-Auswahl-GUI..." 'INFO'
    $result = & $GuiScript -InitialInput $Config.InputFolder -InitialOutput $Config.OutputFolder
    if (-not $result) {
        Write-Log "GUI abgebrochen. Beende." 'WARN'
        exit 1
    }
    $Config.InputFolder  = $result.InputFolder
    $Config.OutputFolder = $result.OutputFolder
    Save-Config $Config
    Write-Log "Config gespeichert: IN=$($Config.InputFolder)  OUT=$($Config.OutputFolder)" 'OK'
    return $Config
}

# ==================================================================
# DATEI BEREIT (kein Write-Lock mehr)?
# ==================================================================
function Wait-FileReady {
    param([string]$Path,[int]$TimeoutSec,[int]$PollMs)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $fs = [System.IO.File]::Open($Path,'Open','Read','None')
            $fs.Close(); $fs.Dispose()
            return $true
        } catch {
            Start-Sleep -Milliseconds $PollMs
        }
    }
    return $false
}

# ==================================================================
# OCR AUSFUEHREN
# ==================================================================
function Invoke-OcrFile {
    param(
        [string]$InputPdf,
        $Config
    )
    $fileName = [System.IO.Path]::GetFileName($InputPdf)
    Write-Log "OCR START: $fileName" 'INFO'

    # Datei-Ready-Check
    if (-not (Wait-FileReady -Path $InputPdf -TimeoutSec $Config.FileReadyTimeoutSec -PollMs $Config.FileReadyPollMs)) {
        Write-Log "Datei nach $($Config.FileReadyTimeoutSec)s noch gesperrt: $fileName -> Quarantaene." 'ERROR'
        Move-ToQuarantine -Path $InputPdf -Config $Config
        return
    }

    # OneDrive-Fix: Input SOFORT aus OneDrive-Pfad nach lokalem Temp MOVEN (nicht copy).
    # Damit kann OneDrive die Datei waehrend OCR nicht mehr beruehren.
    $tempDir = Join-Path $env:TEMP ("hu-ocr\work_" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $ext = [System.IO.Path]::GetExtension($fileName)
    $tmpIn  = Join-Path $tempDir ("input$ext")
    $tmpOut = Join-Path $tempDir ("output$ext")
    try {
        Move-Item -LiteralPath $InputPdf -Destination $tmpIn -Force -ErrorAction Stop
        $sz = (Get-Item -LiteralPath $tmpIn).Length
        Write-Log "  Eingang->Temp verschoben: ${sz} bytes" 'DEBUG'
    } catch {
        Write-Log "Eingang->Temp fehlgeschlagen: $($_.Exception.Message)" 'ERROR'
        Move-ToQuarantine -Path $InputPdf -Config $Config
        try { Remove-Item -LiteralPath $tempDir -Recurse -Force } catch {}
        return
    }

    # Finaler Output-Pfad (mit Konflikt-Timestamp)
    $outPath = Join-Path $Config.OutputFolder $fileName
    if (Test-Path -LiteralPath $outPath) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $extO = [System.IO.Path]::GetExtension($fileName)
        $ts   = Get-Date -Format 'yyyyMMdd-HHmmss'
        $outPath = Join-Path $Config.OutputFolder "${base}_${ts}${extO}"
    }

    # ocrmypdf auf Temp-Kopien
    $maxAttempts = 1 + [int]$Config.OcrRetryCount
    $attempt = 0
    $success = $false

    $argParts = @('-m','ocrmypdf')
    $argParts += $Config.OcrArguments
    $argParts += "`"$tmpIn`""
    $argParts += "`"$tmpOut`""
    $argString = $argParts -join ' '

    while ($attempt -lt $maxAttempts -and -not $success) {
        $attempt++
        Write-Log "ocrmypdf Versuch ${attempt}/${maxAttempts}: $fileName" 'INFO'

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $PythonExe
        $psi.Arguments              = $argString
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow         = $true
        $psi.WorkingDirectory       = $tempDir

        try {
            $proc = [System.Diagnostics.Process]::Start($psi)
            $outTask = $proc.StandardOutput.ReadToEndAsync()
            $errTask = $proc.StandardError.ReadToEndAsync()
            if (-not $proc.WaitForExit($Config.OcrTimeoutSec * 1000)) {
                try { $proc.Kill() } catch {}
                Write-Log "Timeout nach $($Config.OcrTimeoutSec)s: $fileName" 'ERROR'
                continue
            }
            $ec     = $proc.ExitCode
            $stderr = $errTask.Result
            if ($ec -eq 0 -and (Test-Path -LiteralPath $tmpOut)) {
                $success = $true
            } else {
                $clean = ($stderr -replace '\r?\n',' | ').Trim()
                Write-Log "ocrmypdf ExitCode=${ec}: $clean" 'WARN'
            }
        } catch {
            Write-Log "Exception: $($_.Exception.Message)" 'ERROR'
        }
    }

    if ($success) {
        try {
            # OCR-Ergebnis in Ausgangsordner
            Move-Item -LiteralPath $tmpOut -Destination $outPath -Force -ErrorAction Stop
            Write-Log "OCR OK: $fileName -> $([System.IO.Path]::GetFileName($outPath))" 'OK'
            # Original (liegt jetzt in Temp) in processed
            $processedDir = Resolve-Folder $Config.ProcessedFolder
            if (-not (Test-Path -LiteralPath $processedDir)) { New-Item -ItemType Directory -Path $processedDir -Force | Out-Null }
            $procTarget = Join-Path $processedDir $fileName
            if (Test-Path -LiteralPath $procTarget) {
                $b = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
                $e = [System.IO.Path]::GetExtension($fileName)
                $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
                $procTarget = Join-Path $processedDir "${b}_${ts}${e}"
            }
            Move-Item -LiteralPath $tmpIn -Destination $procTarget -Force -ErrorAction Stop
            Write-Log "  Original -> processed: $([System.IO.Path]::GetFileName($procTarget))" 'DEBUG'
        } catch {
            Write-Log "Result-Move fehlgeschlagen: $($_.Exception.Message)" 'ERROR'
            # Original aus Temp in Quarantaene retten
            if (Test-Path -LiteralPath $tmpIn) {
                $qDir = Resolve-Folder $Config.QuarantineFolder
                if (-not (Test-Path -LiteralPath $qDir)) { New-Item -ItemType Directory -Path $qDir -Force | Out-Null }
                try { Move-Item -LiteralPath $tmpIn -Destination (Join-Path $qDir $fileName) -Force } catch {}
            }
        }
    } else {
        Write-Log "OCR FEHLGESCHLAGEN nach $maxAttempts Versuchen: $fileName" 'ERROR'
        # Original aus Temp in Quarantaene
        if (Test-Path -LiteralPath $tmpIn) {
            $qDir = Resolve-Folder $Config.QuarantineFolder
            if (-not (Test-Path -LiteralPath $qDir)) { New-Item -ItemType Directory -Path $qDir -Force | Out-Null }
            $qTarget = Join-Path $qDir $fileName
            if (Test-Path -LiteralPath $qTarget) {
                $b = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
                $e = [System.IO.Path]::GetExtension($fileName)
                $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
                $qTarget = Join-Path $qDir "${b}_${ts}${e}"
            }
            try { Move-Item -LiteralPath $tmpIn -Destination $qTarget -Force } catch {
                Write-Log "Quarantine-Move fehlgeschlagen: $_" 'WARN'
            }
        }
    }

    # Temp-Ordner aufraeumen
    try { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
}

function Resolve-Folder {
    param([string]$PathValue)
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return $PathValue }
    return (Join-Path $Root $PathValue)
}

function Move-WithRetry {
    param([string]$Source,[string]$Target,[int]$Retries = 5,[int]$DelayMs = 500)
    for ($i=1; $i -le $Retries; $i++) {
        if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
            # Evtl. OneDrive-Verzoegerung - kurz warten und nochmal pruefen
            Start-Sleep -Milliseconds $DelayMs
            if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
                throw "Quelldatei nicht vorhanden: $Source"
            }
        }
        try {
            Move-Item -LiteralPath $Source -Destination $Target -Force -ErrorAction Stop
            return $true
        } catch {
            if ($i -eq $Retries) { throw }
            Start-Sleep -Milliseconds ($DelayMs * $i)
        }
    }
    return $false
}

function Move-ToProcessed {
    param([string]$Path,$Config)
    $dest = Resolve-Folder $Config.ProcessedFolder
    if (-not (Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
    $target = Join-Path $dest ([System.IO.Path]::GetFileName($Path))
    if (Test-Path -LiteralPath $target) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $ext  = [System.IO.Path]::GetExtension($Path)
        $ts   = Get-Date -Format 'yyyyMMdd-HHmmss'
        $target = Join-Path $dest "${base}_${ts}${ext}"
    }
    try { Move-WithRetry -Source $Path -Target $target | Out-Null }
    catch { Write-Log "Verschieben processed fehlgeschlagen: $($_.Exception.Message)" 'WARN' }
}

function Move-ToQuarantine {
    param([string]$Path,$Config)
    $dest = Resolve-Folder $Config.QuarantineFolder
    if (-not (Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
    $target = Join-Path $dest ([System.IO.Path]::GetFileName($Path))
    if (Test-Path -LiteralPath $target) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $ext  = [System.IO.Path]::GetExtension($Path)
        $ts   = Get-Date -Format 'yyyyMMdd-HHmmss'
        $target = Join-Path $dest "${base}_${ts}${ext}"
    }
    try { Move-WithRetry -Source $Path -Target $target | Out-Null }
    catch { Write-Log "Verschieben quarantine fehlgeschlagen: $($_.Exception.Message)" 'WARN' }
}

# ==================================================================
# WATCHER MIT DEBOUNCE (robust fuer UNC/Netzwerk-Pfade)
# ==================================================================
function Test-WatcherPath {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Container) { return $true }
    if ($Path -match '^\\\\') {
        Write-Log "UNC-Pfad nicht erreichbar: $Path - versuche Reconnect..." 'WARN'
        try {
            if ($Path -match '^(\\\\[^\\]+\\[^\\]+)') {
                $share = $Matches[1]
                $null  = & net.exe use $share /PERSISTENT:NO 2>&1
                Start-Sleep -Seconds 1
                if (Test-Path -LiteralPath $Path -PathType Container) {
                    Write-Log "Reconnect erfolgreich: $share" 'OK'
                    return $true
                }
            }
        } catch {}
        Write-Log "Reconnect fehlgeschlagen." 'ERROR'
    }
    return $false
}

function New-ConfiguredWatcher {
    param([string]$Path)
    $w = New-Object System.IO.FileSystemWatcher
    $w.Path = $Path
    $w.Filter = '*.pdf'
    $w.IncludeSubdirectories = $false
    $w.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite, Size'
    $w.InternalBufferSize = 65536
    $w.EnableRaisingEvents = $true
    return $w
}

function Start-Watcher {
    param($Config)

    $isUnc = $Config.InputFolder -match '^\\\\'
    Write-Log "Starte Watcher: $($Config.InputFolder)" 'OK'
    if ($isUnc) { Write-Log "  (UNC-Pfad erkannt - verstaerkte Fehlertoleranz aktiv)" 'INFO' }
    Write-Log "Output: $($Config.OutputFolder)" 'INFO'
    Write-Log "STRG+C zum Beenden." 'INFO'

    if (-not (Test-WatcherPath -Path $Config.InputFolder)) {
        Write-Log "Eingangsordner NICHT erreichbar - Watcher startet trotzdem, retry laeuft." 'WARN'
    }

    $pending = New-Object System.Collections.Hashtable
    $lock    = New-Object object
    $errorFlag = @{ ErrorOccurred = $false; LastMsg = '' }

    $action = {
        $p = $Event.SourceEventArgs.FullPath
        $h = $Event.MessageData.Pending
        $l = $Event.MessageData.Lock
        [System.Threading.Monitor]::Enter($l)
        try { $h[$p] = [DateTime]::UtcNow } finally { [System.Threading.Monitor]::Exit($l) }
    }
    $errorAction = {
        $e = $Event.SourceEventArgs.GetException()
        $Event.MessageData.ErrorFlag.ErrorOccurred = $true
        $Event.MessageData.ErrorFlag.LastMsg       = $e.Message
    }
    $msg = @{ Pending = $pending; Lock = $lock; ErrorFlag = $errorFlag }

    $watcher = New-ConfiguredWatcher -Path $Config.InputFolder
    $subs = @()
    $subs += Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action -MessageData $msg
    $subs += Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action -MessageData $msg
    $subs += Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action -MessageData $msg
    $subs += Register-ObjectEvent -InputObject $watcher -EventName Error   -Action $errorAction -MessageData $msg

    Get-ChildItem -Path $Config.InputFolder -Filter '*.pdf' -File -ErrorAction SilentlyContinue | ForEach-Object {
        [System.Threading.Monitor]::Enter($lock)
        try { $pending[$_.FullName] = [DateTime]::UtcNow } finally { [System.Threading.Monitor]::Exit($lock) }
    }

    $debounceMs      = [int]$Config.DebounceMs
    $lastHealthCheck = [DateTime]::UtcNow
    $healthIntervalS = 30

    try {
        while ($true) {
            Start-Sleep -Milliseconds 500

            if ($errorFlag.ErrorOccurred) {
                Write-Log "Watcher-Error: $($errorFlag.LastMsg) - Neustart..." 'WARN'
                $errorFlag.ErrorOccurred = $false
                try {
                    $watcher.EnableRaisingEvents = $false
                    foreach ($s in $subs) { Unregister-Event -SourceIdentifier $s.Name -EA SilentlyContinue }
                    $watcher.Dispose()
                } catch {}
                $tryReconnect = $true
                while ($tryReconnect) {
                    if (Test-WatcherPath -Path $Config.InputFolder) {
                        try {
                            $watcher = New-ConfiguredWatcher -Path $Config.InputFolder
                            $subs = @()
                            $subs += Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action -MessageData $msg
                            $subs += Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action -MessageData $msg
                            $subs += Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action -MessageData $msg
                            $subs += Register-ObjectEvent -InputObject $watcher -EventName Error   -Action $errorAction -MessageData $msg
                            Write-Log "Watcher neu verbunden." 'OK'
                            $tryReconnect = $false
                        } catch {
                            Write-Log "Watcher-Recreate Fehler: $_ - retry in 10s..." 'WARN'
                            Start-Sleep -Seconds 10
                        }
                    } else {
                        Write-Log "Pfad nicht erreichbar - retry in 10s..." 'WARN'
                        Start-Sleep -Seconds 10
                    }
                }
            }

            if ($isUnc -and (([DateTime]::UtcNow - $lastHealthCheck).TotalSeconds -ge $healthIntervalS)) {
                $lastHealthCheck = [DateTime]::UtcNow
                if (-not (Test-Path -LiteralPath $Config.InputFolder -PathType Container)) {
                    Write-Log "Health-Check: Pfad verloren -> Reconnect..." 'WARN'
                    $errorFlag.ErrorOccurred = $true
                    $errorFlag.LastMsg = 'Health-Check failed'
                    continue
                }
            }

            $ready = @()
            [System.Threading.Monitor]::Enter($lock)
            try {
                $now = [DateTime]::UtcNow
                $keys = @($pending.Keys)
                foreach ($k in $keys) {
                    if (($now - $pending[$k]).TotalMilliseconds -ge $debounceMs) {
                        $ready += $k
                        $pending.Remove($k)
                    }
                }
            } finally { [System.Threading.Monitor]::Exit($lock) }

            foreach ($f in $ready) {
                if (Test-Path -LiteralPath $f) {
                    Invoke-OcrFile -InputPdf $f -Config $Config
                }
            }
        }
    } finally {
        try { $watcher.EnableRaisingEvents = $false } catch {}
        Get-EventSubscriber | Unregister-Event -ErrorAction SilentlyContinue
        try { $watcher.Dispose() } catch {}
        Write-Log "Watcher beendet." 'INFO'
    }
}

# ==================================================================
# MAIN
# ==================================================================
try {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  HU-OCR v$($script:Version) - Start"          -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    $cfg = Load-Config

    $logFolder = Resolve-Folder $cfg.LogFolder
    Initialize-Log $logFolder
    Clear-OldLogs -LogFolder $logFolder -RetentionDays $cfg.LogRetentionDays

    if (-not $SkipBootstrap -and -not (Test-Path $FirstRunFlag)) {
        Invoke-Bootstrap -Config $cfg
    } else {
        Write-Log "Bootstrap uebersprungen (bereits erledigt)." 'DEBUG'
    }

    Set-ToolPaths
    Invoke-UpdateCheck

    $defaultIn  = Join-Path $Root 'Scan-Eingang'
    $defaultOut = Join-Path $Root 'Scan-Ausgang'
    foreach ($d in @($defaultIn, $defaultOut)) {
        if (-not (Test-Path -LiteralPath $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
            Write-Log "Ordner angelegt: $d" 'DEBUG'
        }
    }
    if (-not $cfg.InputFolder)  { $cfg.InputFolder  = $defaultIn }
    if (-not $cfg.OutputFolder) { $cfg.OutputFolder = $defaultOut }

    $needGui = $Reconfigure -or $ConfigOnly -or -not (Test-Path -LiteralPath $cfg.InputFolder)
    if ($needGui) {
        $cfg = Invoke-ConfigGui -Config $cfg
    } else {
        Save-Config $cfg
    }

    if ($ConfigOnly) {
        Write-Log "Config gespeichert. Beende (ConfigOnly-Modus)." 'OK'
        exit 0
    }

    foreach ($p in @($cfg.OutputFolder, (Resolve-Folder $cfg.ProcessedFolder), (Resolve-Folder $cfg.QuarantineFolder))) {
        if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    }

    Start-Watcher -Config $cfg
}
catch {
    Write-Log "FATAL: $($_.Exception.Message)" 'ERROR'
    Write-Log $_.ScriptStackTrace 'DEBUG'
    exit 1
}
