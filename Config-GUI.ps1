<#
.SYNOPSIS
    Windows.Forms GUI zur Auswahl von Input- und Output-Ordner.
.DESCRIPTION
    Wird von Start-OCR.ps1 aufgerufen wenn config.json fehlt oder -Reconfigure.
    Gibt ein PSCustomObject mit InputFolder + OutputFolder zurueck.
    Bei Abbruch: $null.
#>
param(
    [string]$InitialInput  = "",
    [string]$InitialOutput = ""
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "OCR Portable - Ordner auswaehlen"
$form.Size = New-Object System.Drawing.Size(560,260)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# --- Label Info ---
$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Location = New-Object System.Drawing.Point(15,15)
$lblInfo.Size = New-Object System.Drawing.Size(520,30)
$lblInfo.Text = "Bitte Eingangs- und Ausgangsordner waehlen. Neue PDFs im Eingang werden automatisch per OCR verarbeitet."
$form.Controls.Add($lblInfo)

# --- Input Folder ---
$lblIn = New-Object System.Windows.Forms.Label
$lblIn.Location = New-Object System.Drawing.Point(15,60)
$lblIn.Size = New-Object System.Drawing.Size(120,20)
$lblIn.Text = "Eingangsordner:"
$form.Controls.Add($lblIn)

$txtIn = New-Object System.Windows.Forms.TextBox
$txtIn.Location = New-Object System.Drawing.Point(140,58)
$txtIn.Size = New-Object System.Drawing.Size(300,20)
$txtIn.Text = $InitialInput
$form.Controls.Add($txtIn)

$btnIn = New-Object System.Windows.Forms.Button
$btnIn.Location = New-Object System.Drawing.Point(450,56)
$btnIn.Size = New-Object System.Drawing.Size(85,24)
$btnIn.Text = "Durchsuchen"
$btnIn.Add_Click({
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    $fb.Description = "Eingangsordner (gescannte PDFs)"
    if ($txtIn.Text -and (Test-Path $txtIn.Text)) {
        $fb.SelectedPath = $txtIn.Text
    } else {
        $fb.SelectedPath = $PSScriptRoot
    }
    if ($fb.ShowDialog() -eq "OK") { $txtIn.Text = $fb.SelectedPath }
})
$form.Controls.Add($btnIn)

# --- Output Folder ---
$lblOut = New-Object System.Windows.Forms.Label
$lblOut.Location = New-Object System.Drawing.Point(15,100)
$lblOut.Size = New-Object System.Drawing.Size(120,20)
$lblOut.Text = "Ausgangsordner:"
$form.Controls.Add($lblOut)

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Location = New-Object System.Drawing.Point(140,98)
$txtOut.Size = New-Object System.Drawing.Size(300,20)
$txtOut.Text = $InitialOutput
$form.Controls.Add($txtOut)

$btnOut = New-Object System.Windows.Forms.Button
$btnOut.Location = New-Object System.Drawing.Point(450,96)
$btnOut.Size = New-Object System.Drawing.Size(85,24)
$btnOut.Text = "Durchsuchen"
$btnOut.Add_Click({
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    $fb.Description = "Ausgangsordner (OCR-Ergebnis)"
    if ($txtOut.Text -and (Test-Path $txtOut.Text)) {
        $fb.SelectedPath = $txtOut.Text
    } else {
        $fb.SelectedPath = $PSScriptRoot
    }
    if ($fb.ShowDialog() -eq "OK") { $txtOut.Text = $fb.SelectedPath }
})
$form.Controls.Add($btnOut)

# --- Hinweis ---
$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Location = New-Object System.Drawing.Point(15,140)
$lblHint.Size = New-Object System.Drawing.Size(520,30)
$lblHint.ForeColor = [System.Drawing.Color]::DimGray
$lblHint.Text = "Tipp: Eingangs- und Ausgangsordner sollten NICHT identisch sein."
$form.Controls.Add($lblHint)

# --- Buttons OK / Cancel ---
$btnOk = New-Object System.Windows.Forms.Button
$btnOk.Location = New-Object System.Drawing.Point(340,180)
$btnOk.Size = New-Object System.Drawing.Size(90,28)
$btnOk.Text = "Speichern"
$btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $btnOk
$form.Controls.Add($btnOk)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Location = New-Object System.Drawing.Point(445,180)
$btnCancel.Size = New-Object System.Drawing.Size(90,28)
$btnCancel.Text = "Abbrechen"
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $btnCancel
$form.Controls.Add($btnCancel)

# --- Validation on OK ---
$btnOk.Add_Click({
    if (-not $txtIn.Text -or -not (Test-Path $txtIn.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Eingangsordner existiert nicht.","Fehler",0,16) | Out-Null
        $form.DialogResult = [System.Windows.Forms.DialogResult]::None
        return
    }
    if (-not $txtOut.Text) {
        [System.Windows.Forms.MessageBox]::Show("Ausgangsordner angeben.","Fehler",0,16) | Out-Null
        $form.DialogResult = [System.Windows.Forms.DialogResult]::None
        return
    }
    if ($txtIn.Text -eq $txtOut.Text) {
        [System.Windows.Forms.MessageBox]::Show("Eingangs- und Ausgangsordner muessen unterschiedlich sein.","Fehler",0,16) | Out-Null
        $form.DialogResult = [System.Windows.Forms.DialogResult]::None
        return
    }
    if (-not (Test-Path $txtOut.Text)) {
        try { New-Item -ItemType Directory -Path $txtOut.Text -Force | Out-Null }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Ausgangsordner konnte nicht erstellt werden: $_","Fehler",0,16) | Out-Null
            $form.DialogResult = [System.Windows.Forms.DialogResult]::None
            return
        }
    }
})

$result = $form.ShowDialog()
if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    [PSCustomObject]@{
        InputFolder  = $txtIn.Text
        OutputFolder = $txtOut.Text
    }
} else {
    $null
}
