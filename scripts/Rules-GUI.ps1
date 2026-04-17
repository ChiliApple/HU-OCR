<#
.SYNOPSIS
    HU-OCR Regel-Editor: Keywords -> Praefix fuer Ausgabe-Dateiname.
.DESCRIPTION
    Laedt/speichert NamingRules in config.json (im Tool-Root).
    Liste scrollbar mit Buttons Neu/Bearbeiten/Loeschen/Hoch/Runter + Enable-Checkbox.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Root       = Split-Path -Parent $PSScriptRoot
$ConfigFile = Join-Path $Root 'config.json'
$DefaultCfg = Join-Path $Root 'config.default.json'

if (-not (Test-Path -LiteralPath $ConfigFile)) {
    if (Test-Path -LiteralPath $DefaultCfg) { Copy-Item $DefaultCfg $ConfigFile -Force }
    else {
        [System.Windows.Forms.MessageBox]::Show("config.json und config.default.json fehlen. Bitte zuerst Start-OCR.cmd ausfuehren.","HU-OCR Regel-Editor",0,16) | Out-Null
        exit 1
    }
}

$cfg = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json

# Defaults falls neue Felder fehlen (Migration)
if ($null -eq $cfg.NamingEnabled)         { $cfg | Add-Member -NotePropertyName NamingEnabled -NotePropertyValue $true -Force }
if ($null -eq $cfg.NamingTemplate)        { $cfg | Add-Member -NotePropertyName NamingTemplate -NotePropertyValue '{Prefix}_{Timestamp}' -Force }
if ($null -eq $cfg.NamingTemplateFallback){ $cfg | Add-Member -NotePropertyName NamingTemplateFallback -NotePropertyValue '{OriginalName}' -Force }
if ($null -eq $cfg.NamingTextBytes)       { $cfg | Add-Member -NotePropertyName NamingTextBytes -NotePropertyValue 2048 -Force }
if ($null -eq $cfg.NamingRules)           { $cfg | Add-Member -NotePropertyName NamingRules -NotePropertyValue (@()) -Force }

$script:Rules = [System.Collections.ArrayList]::new()
foreach ($r in @($cfg.NamingRules)) {
    [void]$script:Rules.Add([PSCustomObject]@{
        Name      = [string]$r.Name
        Keywords  = @($r.Keywords)
        MatchMode = if ($r.MatchMode) { [string]$r.MatchMode } else { 'any' }
        Prefix    = [string]$r.Prefix
        Priority  = if ($r.Priority) { [int]$r.Priority } else { 1 }
        Enabled   = if ($null -ne $r.Enabled) { [bool]$r.Enabled } else { $true }
    })
}

# ---------- Edit-Dialog fuer einzelne Regel ----------
function Show-RuleDialog {
    param($Rule)
    $d = New-Object System.Windows.Forms.Form
    $d.Text = if ($Rule) { "Regel bearbeiten" } else { "Neue Regel" }
    $d.Size = New-Object System.Drawing.Size(520,420)
    $d.StartPosition = "CenterParent"
    $d.FormBorderStyle = "FixedDialog"

    $lN = New-Object System.Windows.Forms.Label; $lN.Location = '15,15';  $lN.Size='120,20'; $lN.Text='Name:'
    $tN = New-Object System.Windows.Forms.TextBox; $tN.Location='140,13'; $tN.Size='340,20'
    $d.Controls.AddRange(@($lN,$tN))

    $lK = New-Object System.Windows.Forms.Label; $lK.Location='15,45';  $lK.Size='120,20'; $lK.Text='Keywords (ein Wort pro Zeile):'
    $tK = New-Object System.Windows.Forms.TextBox; $tK.Location='140,43'; $tK.Size='340,140'; $tK.Multiline=$true; $tK.ScrollBars='Vertical'
    $d.Controls.AddRange(@($lK,$tK))

    $lM = New-Object System.Windows.Forms.Label; $lM.Location='15,195'; $lM.Size='120,20'; $lM.Text='Match-Modus:'
    $cM = New-Object System.Windows.Forms.ComboBox; $cM.Location='140,193'; $cM.Size='120,20'; $cM.DropDownStyle='DropDownList'
    [void]$cM.Items.AddRange(@('any','all'))
    $d.Controls.AddRange(@($lM,$cM))

    $lP = New-Object System.Windows.Forms.Label; $lP.Location='15,225'; $lP.Size='120,20'; $lP.Text='Praefix:'
    $tP = New-Object System.Windows.Forms.TextBox; $tP.Location='140,223'; $tP.Size='200,20'
    $d.Controls.AddRange(@($lP,$tP))

    $lPr = New-Object System.Windows.Forms.Label; $lPr.Location='15,255'; $lPr.Size='120,20'; $lPr.Text='Priority (0-99):'
    $nPr = New-Object System.Windows.Forms.NumericUpDown; $nPr.Location='140,253'; $nPr.Size='80,20'; $nPr.Minimum=0; $nPr.Maximum=99
    $d.Controls.AddRange(@($lPr,$nPr))

    $cE = New-Object System.Windows.Forms.CheckBox; $cE.Location='140,285'; $cE.Size='120,20'; $cE.Text='Aktiv'
    $d.Controls.Add($cE)

    if ($Rule) {
        $tN.Text = $Rule.Name
        $tK.Text = ($Rule.Keywords -join "`r`n")
        $cM.SelectedItem = if ($Rule.MatchMode -eq 'all') { 'all' } else { 'any' }
        $tP.Text = $Rule.Prefix
        $nPr.Value = [Math]::Max(0,[Math]::Min(99,[int]$Rule.Priority))
        $cE.Checked = [bool]$Rule.Enabled
    } else {
        $cM.SelectedItem = 'any'
        $nPr.Value = 5
        $cE.Checked = $true
    }

    $b1 = New-Object System.Windows.Forms.Button; $b1.Text='OK'; $b1.Location='290,330'; $b1.Size='90,28'
    $b1.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $b2 = New-Object System.Windows.Forms.Button; $b2.Text='Abbrechen'; $b2.Location='390,330'; $b2.Size='90,28'
    $b2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $d.AcceptButton = $b1; $d.CancelButton = $b2
    $d.Controls.AddRange(@($b1,$b2))

    $b1.Add_Click({
        if (-not $tN.Text.Trim()) {
            [System.Windows.Forms.MessageBox]::Show("Name erforderlich.","Fehler",0,16)|Out-Null
            $d.DialogResult=[System.Windows.Forms.DialogResult]::None; return
        }
        if (-not $tP.Text.Trim()) {
            [System.Windows.Forms.MessageBox]::Show("Praefix erforderlich.","Fehler",0,16)|Out-Null
            $d.DialogResult=[System.Windows.Forms.DialogResult]::None; return
        }
        $kws = @($tK.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($kws.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Mindestens 1 Keyword erforderlich.","Fehler",0,16)|Out-Null
            $d.DialogResult=[System.Windows.Forms.DialogResult]::None; return
        }
    })

    if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return [PSCustomObject]@{
            Name      = $tN.Text.Trim()
            Keywords  = @($tK.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            MatchMode = [string]$cM.SelectedItem
            Prefix    = $tP.Text.Trim()
            Priority  = [int]$nPr.Value
            Enabled   = [bool]$cE.Checked
        }
    }
    return $null
}

# ---------- Main Form ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "HU-OCR - Regel-Editor"
$form.Size = New-Object System.Drawing.Size(780,540)
$form.StartPosition = "CenterScreen"

# Icon laden (wenn vorhanden)
$iconPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\icon.ico'
if (Test-Path -LiteralPath $iconPath) {
    try { $form.Icon = New-Object System.Drawing.Icon($iconPath) } catch {}
}
$form.MinimumSize = New-Object System.Drawing.Size(780,540)

# Template + global settings oben
$lblGlob = New-Object System.Windows.Forms.Label
$lblGlob.Location='15,12'; $lblGlob.Size='750,14'; $lblGlob.Text='Vorlage fuer Dateinamen bei Treffer:'
$form.Controls.Add($lblGlob)

$chkEnable = New-Object System.Windows.Forms.CheckBox
$chkEnable.Location='15,32'; $chkEnable.Size='280,22'; $chkEnable.Text='Naming-Regeln aktiv (Gesamt-Schalter)'
$chkEnable.Checked = [bool]$cfg.NamingEnabled
$form.Controls.Add($chkEnable)

$lblT = New-Object System.Windows.Forms.Label; $lblT.Location='15,58'; $lblT.Size='160,20'; $lblT.Text='Template (Treffer):'
$txtT = New-Object System.Windows.Forms.TextBox; $txtT.Location='180,56'; $txtT.Size='280,20'; $txtT.Text=[string]$cfg.NamingTemplate
$form.Controls.Add($lblT); $form.Controls.Add($txtT)

$lblF = New-Object System.Windows.Forms.Label; $lblF.Location='15,82'; $lblF.Size='160,20'; $lblF.Text='Template (Kein Treffer):'
$txtF = New-Object System.Windows.Forms.TextBox; $txtF.Location='180,80'; $txtF.Size='280,20'; $txtF.Text=[string]$cfg.NamingTemplateFallback
$form.Controls.Add($lblF); $form.Controls.Add($txtF)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Location='470,56'; $lblHint.Size='290,46'
$lblHint.Text="Platzhalter:`r`n{Prefix}  {Timestamp}  {OriginalName}"
$lblHint.ForeColor=[System.Drawing.Color]::DimGray
$form.Controls.Add($lblHint)

# ListView mit Regeln
$lv = New-Object System.Windows.Forms.ListView
$lv.Location='15,115'; $lv.Size='750,330'
$lv.Anchor='Top,Left,Right,Bottom'
$lv.View='Details'; $lv.FullRowSelect=$true; $lv.GridLines=$true; $lv.CheckBoxes=$true
[void]$lv.Columns.Add('Name',180)
[void]$lv.Columns.Add('Keywords',260)
[void]$lv.Columns.Add('Mode',50)
[void]$lv.Columns.Add('Prefix',110)
[void]$lv.Columns.Add('Prio',50)
$form.Controls.Add($lv)

function Refresh-List {
    $lv.BeginUpdate()
    $lv.Items.Clear()
    foreach ($r in $script:Rules) {
        $it = New-Object System.Windows.Forms.ListViewItem($r.Name)
        $it.Checked = [bool]$r.Enabled
        [void]$it.SubItems.Add((($r.Keywords -join ', ')))
        [void]$it.SubItems.Add($r.MatchMode)
        [void]$it.SubItems.Add($r.Prefix)
        [void]$it.SubItems.Add([string]$r.Priority)
        $it.Tag = $r
        [void]$lv.Items.Add($it)
    }
    $lv.EndUpdate()
}
Refresh-List

$lv.Add_ItemChecked({
    param($s,$e)
    if ($null -ne $e.Item -and $null -ne $e.Item.Tag) { $e.Item.Tag.Enabled = [bool]$e.Item.Checked }
})

# Buttons rechts von ListView (anchor right)
$btnNew  = New-Object System.Windows.Forms.Button; $btnNew.Text='Neu';          $btnNew.Location='15,455';  $btnNew.Size='90,30'; $btnNew.Anchor='Bottom,Left'
$btnEdit = New-Object System.Windows.Forms.Button; $btnEdit.Text='Bearbeiten';  $btnEdit.Location='115,455'; $btnEdit.Size='90,30'; $btnEdit.Anchor='Bottom,Left'
$btnDel  = New-Object System.Windows.Forms.Button; $btnDel.Text='Loeschen';     $btnDel.Location='215,455'; $btnDel.Size='90,30'; $btnDel.Anchor='Bottom,Left'
$btnUp   = New-Object System.Windows.Forms.Button; $btnUp.Text='Hoch';          $btnUp.Location='315,455';  $btnUp.Size='60,30'; $btnUp.Anchor='Bottom,Left'
$btnDn   = New-Object System.Windows.Forms.Button; $btnDn.Text='Runter';        $btnDn.Location='385,455'; $btnDn.Size='60,30'; $btnDn.Anchor='Bottom,Left'
$btnSave = New-Object System.Windows.Forms.Button; $btnSave.Text='Speichern';   $btnSave.Location='555,455'; $btnSave.Size='100,30'; $btnSave.Anchor='Bottom,Right'
$btnCancel = New-Object System.Windows.Forms.Button; $btnCancel.Text='Abbrechen'; $btnCancel.Location='665,455'; $btnCancel.Size='100,30'; $btnCancel.Anchor='Bottom,Right'

$form.Controls.AddRange(@($btnNew,$btnEdit,$btnDel,$btnUp,$btnDn,$btnSave,$btnCancel))

$btnNew.Add_Click({
    $r = Show-RuleDialog -Rule $null
    if ($r) { [void]$script:Rules.Add($r); Refresh-List }
})
$btnEdit.Add_Click({
    if ($lv.SelectedItems.Count -eq 0) { return }
    $idx = $lv.SelectedIndices[0]
    $r = Show-RuleDialog -Rule $script:Rules[$idx]
    if ($r) { $script:Rules[$idx] = $r; Refresh-List; $lv.Items[$idx].Selected = $true }
})
$lv.Add_MouseDoubleClick({ $btnEdit.PerformClick() })
$btnDel.Add_Click({
    if ($lv.SelectedItems.Count -eq 0) { return }
    $idx = $lv.SelectedIndices[0]
    if ([System.Windows.Forms.MessageBox]::Show("Regel loeschen?","Bestaetigung",4,32) -eq 'Yes') {
        $script:Rules.RemoveAt($idx); Refresh-List
    }
})
$btnUp.Add_Click({
    if ($lv.SelectedItems.Count -eq 0) { return }
    $idx = $lv.SelectedIndices[0]
    if ($idx -gt 0) {
        $x = $script:Rules[$idx]; $script:Rules.RemoveAt($idx); $script:Rules.Insert($idx-1,$x)
        Refresh-List; $lv.Items[$idx-1].Selected = $true
    }
})
$btnDn.Add_Click({
    if ($lv.SelectedItems.Count -eq 0) { return }
    $idx = $lv.SelectedIndices[0]
    if ($idx -lt ($script:Rules.Count-1)) {
        $x = $script:Rules[$idx]; $script:Rules.RemoveAt($idx); $script:Rules.Insert($idx+1,$x)
        Refresh-List; $lv.Items[$idx+1].Selected = $true
    }
})

$btnSave.Add_Click({
    $cfg.NamingEnabled          = [bool]$chkEnable.Checked
    $cfg.NamingTemplate         = $txtT.Text
    $cfg.NamingTemplateFallback = $txtF.Text
    # Rules als Array of PSCustomObject
    $arr = @()
    foreach ($r in $script:Rules) {
        $arr += [PSCustomObject]@{
            Name      = $r.Name
            Keywords  = @($r.Keywords)
            MatchMode = $r.MatchMode
            Prefix    = $r.Prefix
            Priority  = [int]$r.Priority
            Enabled   = [bool]$r.Enabled
        }
    }
    $cfg.NamingRules = $arr
    try {
        ($cfg | ConvertTo-Json -Depth 10) | Set-Content -Path $ConfigFile -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("config.json gespeichert.","Gespeichert",0,64)|Out-Null
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Fehler: $_","Speichern fehlgeschlagen",0,16)|Out-Null
    }
})
$btnCancel.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $form.Close() })

[void]$form.ShowDialog()
