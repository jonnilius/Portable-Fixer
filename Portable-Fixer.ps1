Add-Type -AssemblyName System.Windows.Forms

# Portable-Maker.ps1
$Name = "Portable-Fixer"
$Version = "0.1.2"

# Einstellungen
$Context = [ordered]@{}


function Use-Ternary {
    <#  -- Ternary-Operator Funktion --
    # Parameter:
    # - $Condition: Die Bedingung, die ausgewertet werden soll (bool).
    # - $TrueValue: Der Wert oder Ausdruck, der zurückgegeben wird, wenn die Bedingung wahr ist (scriptblock).
    # - $FalseValue: Der Wert oder Ausdruck, der zurückgegeben wird, wenn die Bedingung falsch ist (scriptblock).
    #>
    param (
        [bool]$Condition,
        [scriptblock]$TrueValue,
        [scriptblock]$FalseValue
    )
    if ( $Condition ) { & $TrueValue } else { & $FalseValue }
}

# Entfernt Leerzeichen und Sonderzeichen aus einem String
function ConvertTo-CleanString {
    param (
        [Parameter(ValueFromPipeline = $true)]
        [string]$String,
        [switch]$SkipSpaces,
        [switch]$SkipSpecialChars
    )
    if ( -not $SkipSpaces )       { $String = $String -replace '\s','' }
    if ( -not $SkipSpecialChars ) { $String = $String -replace '[^a-zA-Z0-9]','' }

    $String 
}
# Exportiert das Icon aus einer EXE-Datei als ICO-Datei
function Export-AppIcon {
    param (
        [string]$ExeFile,   # Icon-Quelle (Programmdatei)
        [string]$ExportPath # Export-Ordner für das Icon
    )

    # System.Drawing Assembly laden
    try { Add-Type -AssemblyName System.Drawing -ErrorAction Stop }
    catch {
        Write-Warning "Automatische Icon-Extraktion nicht verfügbar. Bitto ICO manuell einfügen unter:"
        Write-Warning " > $ExportPath\appicon.ico"
        return
    }

    # Prüfen und Vorbereiten der Pfade
    if (-not (Test-Path $ExeFile -PathType Leaf)) { throw "Die angegebene Programmdatei '$ExeFile' existiert nicht." }
    if (-not (Test-Path $ExportPath)) { New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null }
    $AppIconFile = Join-Path -Path $ExportPath -ChildPath "appicon.ico"

    # Shell-Icon extrahieren
    $AppIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($ExeFile)
    if (-not $AppIcon) { throw "Kein Icon in '$ExeFile' gefunden." }

    # Shell-Icon speichern
    $Stream = [System.IO.File]::Create($AppIconFile)
    try { $AppIcon.Save($Stream) }
    finally {
        $Stream.Dispose()
        $AppIcon.Dispose()
    }
}
# Liest einen Eingabewert, gibt Debug-Wert zurück wenn Debug-Modus aktiv ist
function Get-InputValue {
    param (
        [string]$Key,
        [scriptblock]$Prompt
    )
    # Debug-Werte zurückgeben, wenn Debug-Modus aktiv ist
    if ($DebugMode -and $DebugValues.ContainsKey($Key) -and $null -ne $DebugValues[$Key]) {
        Write-Results "$Key =" $DebugValues[$Key] -ColorLeft Yellow
        return $DebugValues[$Key]
    }

    & $Prompt
}
function Set-Header {
    param (
        [string]$Text,
        [string]$Color = "DarkRed",
        [int[]]$Padding = 1
    )
    # Padding
    $PadLeft    = Use-Ternary ($Padding.Count -ge 1) { $Padding[0] } { 0 }
    $PadTop     = Use-Ternary ($Padding.Count -ge 2) { $Padding[1] } { $PadLeft }
    $PadRight   = Use-Ternary ($Padding.Count -ge 3) { $Padding[2] } { $PadLeft }
    $PadBottom  = Use-Ternary ($Padding.Count -ge 4) { $Padding[3] } { $PadTop }
    
    # Width
    $Width = $host.UI.RawUI.BufferSize.Width - $PadLeft - $PadRight
    $headerLine = (" " * $PadLeft) + ("=" * $Width) + (" " * $PadRight)


    Clear-Host
    Write-Host ("`n" * $PadTop) -NoNewline
    Write-Host $headerLine -ForegroundColor $Color
    Write-Host ($Text.PadLeft(($Width + $Text.Length) / 2).PadRight($Width))
    Write-Host $headerLine -ForegroundColor $Color
    Write-Host ("`n" * $PadBottom)
}
function Set-PortableApp {
    param (
        [hashtable]$Context
    )

    # Pfade definieren
    $rootPath           = Join-Path -Path $Context.destinationPath  -ChildPath $Context.AppID       # ./AppNamePortable
    $AppNamePath        = Join-Path -Path $rootPath -ChildPath "App\$($Context.AppName)"            # ./AppNamePortable/App/AppName
    $AppInfoPath        = Join-Path -Path $rootPath -ChildPath "App\AppInfo"                        # ./AppNamePortable/App/AppInfo
    $AppLauncherPath    = Join-Path -Path $rootPath -ChildPath "App\AppInfo\Launcher"               # ./AppNamePortable/App/AppInfo/Launcher
    $paths = @($rootPath, $AppNamePath, $AppInfoPath, $AppLauncherPath)

    # Verzeichnisstruktur erstellen
    Write-Results "Erstelle:" "Ordner" -Colors @("Red","Yellow")
    foreach ( $path in $paths ) { New-Item -ItemType Directory -Path $path -Force | Out-Null}

    # desktop.ini im Hauptverzeichnis erstellen
    Write-Results "Konfiguriere:" "$($Context.AppID)\desktop.ini" -Colors @("Red","Yellow")
    New-DesktopIni -IconFile (Join-Path -Path $AppNamePath -ChildPath $Context.AppNameExe) -ExportPath $rootPath

    # Programmdateien kopieren
    Write-Results "Kopiere:" "$($Context.AppID)\App\$($Context.AppName)\* " -Colors @("Red","Yellow")
    Copy-Item -Path (Join-Path -Path $Context.sourcePath -ChildPath "*") -Destination $AppNamePath -Recurse -Force

    # appinfo.ini erstellen
    Write-Results "Erstelle:" "$($Context.AppID)\App\AppInfo\appinfo.ini " -Colors @("Red","Yellow")
    New-AppInfoIni -ExportPath $AppInfoPath -Context $Context

    # Icon extrahieren / setzen
    Write-Results "Extrahiere:" "$($Context.AppID)\App\AppInfo\appicon.ico " -Colors @("Red","Yellow")
    Export-AppIcon -ExeFile (Join-Path -Path $AppNamePath -ChildPath $Context.AppNameExe) -ExportPath $AppInfoPath

    # Launcher.ini erstellen
    Write-Results "Erstelle:" "$($Context.AppID)\App\AppInfo\Launcher\Launcher.ini " -Colors @("Red","Yellow")
    New-AppLauncherIni -ExportPath $AppLauncherPath -Context $Context

    # Splash-Bild kopieren
    Write-Results "Kopiere:" "$($Context.AppID)\App\AppInfo\Launcher\Splash.jpg " -Colors @("Red","Yellow")
    Copy-Item -Path $Context.sourceSplashFile -Destination (Join-Path -Path $AppLauncherPath -ChildPath "Splash.jpg") -Force

    $Context
}

function New-AppInfoIni {
    param (
        [hashtable]$Context,
        [string]$ExportPath,    # Speicherordner der appinfo.ini

        # [Format] Sektion
        [string]$Type    = "PortableApps.comFormat",
        [string]$Version = "3.5",
        # [Details] Sektion
        [string]$AppName = $Context.AppName,
        [string]$AppID   = $Context.AppID,
        # [Control] Sektion
        [int]$Icons = 1,
        [string]$Start,
        [string]$ExtractIcon        
    )
    # appinfo.ini Parameter setzen
    if( -not $AppName ){ $AppName = $AppID }
    if( -not $AppID ){ $AppID = $AppName -replace '\s','' }   
    if( -not $Start ){ $Start = "$AppID.exe" }

    # appinfo.ini Pfad festlegen
    if( -not $ExportPath ){{ throw "New-AppInfoIni: 'ExportPath' ist erforderlich." }}
    $ExportFile = Join-Path -Path $ExportPath -ChildPath "appinfo.ini"

    $Content = @"
[Format]
Type=$Type
Version=$Version

[Details]
Name=$AppName
AppID=$AppID

[Control]
Icons=$Icons
Start=$Start
"@ 
    if ( $ExtractIcon ) { $Content += "ExtractIcon=$ExtractIcon`n" }

    $Content | Set-Content -Path $ExportFile -Encoding UTF8
}
function New-AppLauncherIni {
    param (
        [hashtable]$Context,
        [string]$ExportPath    # Speicherordner der AppLauncher.ini
    )
    # AppLauncher.ini Parameter setzen
    $ProgramExecutable = Join-Path -Path $Context.AppName -ChildPath $Context.AppNameExe

    $Content = @"
[Launch]
ProgramExecutable=$ProgramExecutable
"@
    $ExportFile = Join-Path -Path $ExportPath -ChildPath "$($Context.AppID).ini"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ExportFile, $Content, $utf8NoBom)
}

function New-DesktopIni {
    param (
        [string]$IconFile,       # Pfad zur EXE-Datei für das Icon
        [string]$ExportPath # betroffenes Verzeichnis
    )
    if (-not $ExportPath) { throw "New-DesktopIni: 'ExportPath' ist erforderlich." }
        
    $ExportFile = Join-Path -Path $ExportPath -ChildPath "desktop.ini"
    
    @"
[.ShellClassInfo]
IconResource=$IconFile,0

[ViewState]
FolderType=Generic
"@ | Set-Content -Path $ExportFile -Encoding Unicode -Force

    # Attribute setzen: versteckt und System
    attrib +h +s $ExportFile
    attrib +r $ExportPath
}

function Read-KeyString {
    <#  Erwartet einen Tastendruck 
        Der Benutzer wird nach einer Taste (einem Zeichen) gefragt, welches sich 
        in $ValidKeys befinden muss. Der dann akzeptierte gedrückte Tastendruck 
        (das Zeichen) wird zurückgegeben. Wird kein Array mit gültigen Tasten 
        übergeben, wird jede Taste akzeptiert.
        Mit -YesNo wird eine Ja/Nein-Abfrage erstellt, die nur 'Y' oder 'N' akzeptiert
        #>
    param (
        [string]$Text       = "Drücken Sie eine Taste:",
        [string]$Color      = "Yellow",
        [array]$ValidKeys   = @(),
        [int[]]$Padding     = @(2,0,0,0),

        [switch]$YesNo
    )
    
    # Padding
    $PadLeft    = Use-Ternary ($Padding.Count -ge 1) { $Padding[0] } { 0 }
    $PadTop     = Use-Ternary ($Padding.Count -ge 2) { $Padding[1] } { $PadLeft }
    $PadRight   = Use-Ternary ($Padding.Count -ge 3) { $Padding[2] } { $PadLeft }
    $PadBottom  = Use-Ternary ($Padding.Count -ge 4) { $Padding[3] } { $PadTop }
    $Text = (" " * $PadLeft) + $Text + (" " * $PadRight)
    $Text = ("`n" * $PadTop) + $Text + ("`n" * $PadBottom)

    # ValidKeys
    if ( $YesNo ) { $ValidKeys = @('Y','N') }

    # Tastendruck abfragen
    do {
        Write-Host $Text -ForegroundColor $Color -NoNewline
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
    } 
    while ( $ValidKeys.Count -gt 0 -and $key -notin $ValidKeys )

    if ( $YesNo ){ return $key -eq 'Y' }
    $key
}
function Read-CleanString {
    param (
        # Prompt-Parameter
        [string]$Prompt      = "Geben Sie einen Wert ein:",
        [string]$PromptColor = "Yellow",
        [int]$PromptWidth    = 20,
        [int]$PromptLeft    = 2,

        [string]$Default = "",
        [switch]$SkipSpaces,
        [switch]$SkipSpecialChars
    )

    # Eingabeaufforderung anzeigen und Benutzereingabe lesen
    $Prompt = (" " * $PromptLeft) + $Prompt
    Write-Host $Prompt.PadRight($PromptWidth) -ForegroundColor $PromptColor -NoNewline
    $UserInput = (Read-Host).Trim()

    # Standardwert verwenden, wenn keine Eingabe erfolgt ist
    if ( [string]::IsNullOrWhiteSpace($UserInput) -and -not [string]::IsNullOrWhiteSpace($Default) ) { 
        $UserInput = $Default 
    }
    $UserInput | ConvertTo-CleanString -SkipSpaces:$SkipSpaces -SkipSpecialChars:$SkipSpecialChars
}
function Get-File {
    <# Rückgabewerte:
    - $null, wenn die Auswahl abgebrochen wurde.
    - [string] mit dem Pfad der ausgewählten Datei, wenn $FullName gesetzt ist.
    - [string] mit dem Dateinamen der ausgewählten Datei, wenn $Name gesetzt
    - [System.IO.FileInfo] Objekt der ausgewählten Datei, wenn keine Schalter gesetzt sind.
    #>
    param(
        [string]$Title = "Wählen Sie eine Datei aus",
        [string]$InitialDirectory, # Optionaler Startordner für den Datei-Auswahldialog

        [switch]$FullName,
        [switch]$Name
    )
    # Datei-Auswahldialog erstellen
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Title = $Title
    $fileDialog.Filter = "Alle Dateien (*.*)|*.*"
    if ( $InitialDirectory ) { if (Test-Path $InitialDirectory -PathType Container) { $fileDialog.InitialDirectory = $InitialDirectory } }

    # Dialog anzeigen und ausgewählten Dateipfad zurückgeben
    try { if ( $fileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK ) { return $null } }
    finally { $fileDialog.Dispose() }
    
    # Rückgabewert basierend auf den Schaltern
    if ( $FullName ) { return $fileDialog.FileName } 
    elseif ( $Name ) { return [System.IO.Path]::GetFileName($fileDialog.FileName) } 
    else { return Get-Item $fileDialog.FileName }
}
function Get-Folder {
    param(
        [string]$Description = "Wählen Sie einen Ordner aus:",
        # Rückgabewerte:
        [switch]$FullName,
        [switch]$Name,
        [switch]$WriteSelectedPath
    )
    # Ordner-Auswahldialog erstellen
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = $Description
    
    # Ordner-Auswahldialog anzeigen
    $dialogResult = $folderBrowser.ShowDialog()
    if ( $dialogResult -ne [System.Windows.Forms.DialogResult]::OK ) { return $null } # Auswahl wurde abgebrochen, null zurückgeben
    if ( $WriteSelectedPath ) { Write-Host $folderBrowser.SelectedPath }

    # Rückgabewert basierend auf den Schaltern
    if ( $FullName ) { return $folderBrowser.SelectedPath } # [string] mit dem vollständigen Pfad
    elseif ( $Name ) { return [System.IO.Path]::GetFileName($folderBrowser.SelectedPath) } # [string] mit dem Ordnernamen
    else { return Get-Item $folderBrowser.SelectedPath } # [System.IO.DirectoryInfo] Objekt
}
function Get-Key {
    param(
        [string]$KeyName = "Enter"
    )
    do { $key = [System.Console]::ReadKey($true) }
    until ( $key.Key -eq $KeyName )
}

function Write-Text {
    param (
        [string]$Text,
        [System.ConsoleColor]$ForegroundColor = "White",
        [switch]$NoNewline,
        # Layout-Parameter
        [ValidateSet("Left","Center","Right")]
        [string]$Alignment,
        [int[]]$Padding = @(2,0,0,0) # Padding: [Left, Top, Right, Bottom]
    )
    $Text = $Text.Trim()

    # Padding
    $PadLeft   = Use-Ternary ($Padding.Count -ge 1) { $Padding[0] } { 0 }
    $PadRight  = Use-Ternary ($Padding.Count -ge 3) { $Padding[2] } { $PadLeft }

    # Width
    $Width = $host.UI.RawUI.BufferSize.Width
    $innerWidth = $Width - $PadLeft - $PadRight

    # Text ausrichten
    if ( $Alignment ) {
        switch ( $Alignment ) {
            "Left"   { $Text = ( " " * $PadLeft) + $Text.PadRight($innerWidth) + ( " " * $PadRight) }
            "Center" { $Text = ( " " * $PadLeft) + $Text.PadLeft( ($innerWidth + $Text.Length) / 2 ).PadRight($innerWidth) + ( " " * $PadRight) }
            "Right"  { $Text = ( " " * $PadLeft) + $Text.PadLeft($innerWidth) + ( " " * $PadRight) }
        }
    } else {
        $Text = ( " " * $PadLeft) + $Text + ( " " * $PadRight)
    }

    # Padding Top/Bottom
    $PadTop    = Use-Ternary ($Padding.Count -ge 2) { $Padding[1] } { $PadLeft }
    $PadBottom = Use-Ternary ($Padding.Count -ge 4) { $Padding[3] } { $PadTop }
    $Text = ( "`n" * $PadTop ) + $Text + ( "`n" * $PadBottom )


    # Write-Host mit Parameter-Hashtable aufrufen
    $params = @{
        Object = $Text
        ForegroundColor = $ForegroundColor
        NoNewline = $NoNewline
    }
    Write-Host @params
}
function Write-Line {
    param (
        [int]$Width = $host.UI.RawUI.BufferSize.Width,
        [string]$Character = "-",
        [string]$ForegroundColor = "DarkRed",
        [switch]$Padding
    )
    $Line = ""+($Character * $Width)+""
    if ( $Padding ) { $Line = "`n$Line`n" }

    Write-Host $Line -ForegroundColor $ForegroundColor
}
function Write-Space {
    param (
        [int]$Lines = 1
    )
    for ( $i = 0; $i -lt $Lines; $i++ ) {
        Write-Host ""
    }
}
function Write-Results {
    param (
        [Parameter(Position = 0)]
        [string]$TextLeft,
        [Parameter(Position = 1)]
        [string]$TextRight,

        [int]$SpaceLeft = 2,
        [switch]$NoSpace,
        [string[]]$Colors = @("DarkCyan","Cyan"),
        [string]$ColorLeft,
        [string]$ColorRight
    )
    Write-Host (" " * $SpaceLeft) -NoNewline
    
    if ( $ColorLeft )  { $Colors[0] = $ColorLeft  }
    Write-Host $TextLeft -ForegroundColor $Colors[0] -NoNewline
    
    if ( -not $NoSpace ) { Write-Host " " -NoNewline }

    if ( $ColorRight ) { $Colors[1] = $ColorRight }
    Write-Host $TextRight -ForegroundColor $Colors[1]
}
function Get-ApplicationInfo {
    param ( [hashtable]$Context )
    
    # Programmordner abfragen (Quellordner)
    Write-Text "Wählen Sie den Programmordner aus:" DarkCyan -NoNewline
    $Context.sourcePath = Get-Folder -Description "Programmordner:" -FullName
    Write-Text $Context.sourcePath -Padding @(1,0,0,0)

    # Startdatei (EXE) auswählen
    Write-Text "Startdatei (EXE) auswählen:" DarkCyan -NoNewline
    $Context.AppNameExe = Get-File -Title "Startdatei (EXE) auswählen:" -InitialDirectory $Context.sourcePath -Name
    Write-Text $Context.AppNameExe -Padding @(1,0,0,0)
    
    # Speicherort für die portable Anwendung auswählen (Zielordner)
    Write-Text "Zielordner für die portable Anwendung auswählen:" DarkCyan -NoNewline
    $Context.destinationPath = Get-Folder -Description "Zielordner:" -FullName
    Write-Text $Context.destinationPath -Padding @(1,0,0,1)

    # Splash-Bild auswählen
    Write-Text "Splash-Bild auswählen:" Cyan -NoNewline
    $Context.sourceSplashFile = Get-File -Title "Splash-Bild auswählen:" -InitialDirectory $Context.sourcePath -FullName
    Write-Text $Context.sourceSplashFile -Padding @(1,0,0,1)

    # Anwendungsname abfragen
    $Context.AppName = Read-CleanString -Prompt "Anwendungsname:" -SkipSpaces
    $Context.AppID = Read-CleanString -Prompt "Anwendungs-ID:" -Default $Context.AppName
    
    Write-Line -Padding

    return $Context
}


# HEADER & USERINPUT ###############################################################################

while($true){
    Set-Header -Text "$Name v$Version"

    Write-Text "1) PortableApps.com Anwendung erstellen" Yellow
    Write-Text "2) Desktop.ini erstellen/bearbeiten" Yellow
    Write-Text "q) Beenden" Red -Padding @(2,1,0,1)
    
    $answer = Read-KeyString "Wählen Sie eine Option (1/2/q):" -ValidKeys @('1','2','q')
    Write-Line -Padding
    switch ($answer) {
        '1' { 
            Set-Header "Portable Anwendung erstellen"

            # Portable App erstellen
            $Context = Set-PortableApp -Context (Get-ApplicationInfo $Context)

            # Abschlussmeldung
            Write-Text "Fertig!" Green -Padding @(2,0,0,1)
            Write-Text $Context.AppName -ForegroundColor Cyan -Padding @(2,0,0,1) -NoNewline
            Write-Text " wurde erfolgreich portabel gemacht."
            Write-Line -Padding
            

            # PortableApps.com Launcher Generator
            Write-Text "Suche nach PortableApps.com Launcher Generator..." DarkGray -NoNewline
            if(Test-Path (Join-Path -Path $Context.destinationPath -ChildPath "PortableApps.comLauncher/PortableApps.comLauncherGenerator.exe")){
                Write-Text "starten" Green
                Start-Process -FilePath (Join-Path -Path $Context.destinationPath -ChildPath "PortableApps.comLauncher/PortableApps.comLauncherGenerator.exe")
            } else { Write-Text " Nicht gefunden!" Red }
            
            Write-Text "[ENTER]" Yellow -Alignment Center -Padding 3
            Get-Key
        }
        '2' { 
            Set-Header "Desktop.ini erstellen/bearbeiten"

            # Benutzereingaben für desktop.ini
            Write-Text "Ordner:" Yellow -NoNewline
            $folderPath = Get-Folder -Description "Wählen den Ordner aus:"
            Write-Text "Icon-Quelle:" Yellow -NoNewline -Padding @(2,0,0,1)
            $iconFile   = Get-File -Title "Pfad zur EXE-Datei für das Icon:" -FullName
    
            Write-Results "Erstelle:" "desktop.ini" -Colors @("Red","Yellow")
            New-DesktopIni -IconFile $iconFile -ExportPath $folderPath
            Write-Text "Fertig!" Green -Padding @(2,1,0,1)
            Write-Text "Die desktop.ini wurde erstellt unter:" Yellow -Padding @(2,0,0,1) -NoNewline
            Write-Text $folderPath 
            Pause -Silent > $null
        }
        'q' { exit }
        Default {}
    }
}