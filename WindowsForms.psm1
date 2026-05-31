# Portable-Fixer.ps1

# === Assembly laden ===
Add-Type -AssemblyName System.Windows.Forms

$Script:DialogResult = @{
    OK      = [System.Windows.Forms.DialogResult]::OK
    Cancel  = [System.Windows.Forms.DialogResult]::Cancel
    Yes     = [System.Windows.Forms.DialogResult]::Yes
    No      = [System.Windows.Forms.DialogResult]::No
}

# === Auswahldialoge ===
function Get-File { # Datei-Auswahldialog
    param(
        [string]$Title = "Wählen Sie eine Datei aus",
        [string]$InitialDirectory, # Optionaler Startordner für den Datei-Auswahldialog

        [switch]$FullName, # [string] mit dem vollständigen Pfad der ausgewählten Datei
        [switch]$Name     # [string] mit dem Dateinamen der ausgewählten Datei
    )

    # Datei-Auswahldialog erstellen
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Title   = $Title
    $fileDialog.Filter  = "Alle Dateien (*.*)|*.*"
    if ( $InitialDirectory ) { 
        if   ( Test-Path $InitialDirectory -PathType Container) { $fileDialog.InitialDirectory = $InitialDirectory } 
        else { Write-Warning "Der angegebene InitialDirectory-Pfad existiert nicht oder ist kein Ordner: $InitialDirectory" }
    }

    # Datei-Auswahldialog anzeigen
    try { if ( $fileDialog.ShowDialog() -ne $DialogResult.OK ) { return $null } }
    finally { $fileDialog.Dispose() }
    
    # Rückgabewert basierend auf den Schaltern
    if ( $FullName ) { return $fileDialog.FileName } 
    elseif ( $Name ) { return [System.IO.Path]::GetFileName($fileDialog.FileName) } 
    else { return Get-Item $fileDialog.FileName }
    # [System.IO.FileInfo] Objekt
}
function Get-Folder { # Ordner-Auswahldialog
    param(
        [string]$Description = "Wählen Sie einen Ordner aus:",

        # Rückgabewerte:
        [switch]$FullName,  # [string] mit dem vollständigen Pfad
        [switch]$Name       # [string] mit dem Ordnernamen
    )
    # Ordner-Auswahldialog erstellen
    $BrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $BrowserDialog.Description = $Description
    
    # Ordner-Auswahldialog anzeigen
    try { if ( $BrowserDialog.ShowDialog() -ne $DialogResult.OK ) { return $null } }
    finally { $BrowserDialog.Dispose() }

    # Rückgabewert basierend auf den Schaltern
    if ( $FullName ) { return $BrowserDialog.SelectedPath }
    elseif ( $Name ) { return [System.IO.Path]::GetFileName($BrowserDialog.SelectedPath) }
    else { return Get-Item $BrowserDialog.SelectedPath } 
    # [System.IO.DirectoryInfo] Objekt
}