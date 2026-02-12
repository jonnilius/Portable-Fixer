# Portable-Maker.ps1
$Name = "Portable-Fixer"
$Version = "0.1.2"

# Einstellungen
$Context = [ordered]@{}
. .\WindowsForms.ps1


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
        [int[]]$Margin = 1,
        [int]$Width    = $host.UI.RawUI.BufferSize.Width
    )

    # Padding
    $MarginTop    = if ($Margin.Count -ge 1) { $Margin[0] } else { 0 }
    $MarginRight  = if ($Margin.Count -ge 2) { $Margin[1] } else { $MarginTop }
    $MarginBottom = if ($Margin.Count -ge 3) { $Margin[2] } else { $MarginTop }
    $MarginLeft   = if ($Margin.Count -ge 4) { $Margin[3] } else { $MarginRight }
    
    # Width
    $innerWidth = $Width - $MarginLeft - $MarginRight
    $Line       = (" " * $MarginLeft) + ("=" * $innerWidth) + (" " * $MarginRight)


    Clear-Host
    Write-Host ("`n" * $MarginTop) -NoNewline
    Write-Host $Line -ForegroundColor $Color
    Write-Host ($Text.PadLeft(($innerWidth + $Text.Length) / 2).PadRight($innerWidth))
    Write-Host $Line -ForegroundColor $Color
    Write-Host ("`n" * $MarginBottom)
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
        [string]$Publisher,
        [string]$Homepage,
        [string]$Category,
        [string]$Description,
        [string]$Language,
        # [Control] Sektion
        [int]$Icons = 1,
        [string]$Start,
        [string]$ExtractIcon        
    )
    # [Format] Sektion
    $Content = "[Format]`n"
    $Content += "Type=$Type`n"
    $Content += "Version=$Version`n"

    # [Details] Sektion
    $Content += "`n[Details]`n"
    $Content += Use-Ternary ($AppName -ne "") { "Name=$AppName`n" } { "Name=$AppID`n" }
    $Content += Use-Ternary ($AppID -ne "") { "AppID=$AppID`n" } { "AppID=$AppName`n" }
    if ( $Publisher ) { $Content += "Publisher=$Publisher`n" }
    if ( $Homepage ) { $Content += "Homepage=$Homepage`n" }
    if ( $Category ) { $Content += "Category=$Category`n" }
    if ( $Description ) { $Content += "Description=$Description`n" }
    if ( $Language ) { $Content += "Language=$Language`n" }

    # [Control] Sektion
    $Content += "`n[Control]`n"
    $Content += Use-Ternary ($Icons) { "Icons=$Icons`n" } { "Icons=1`n" }
    $Content += Use-Ternary ($Start -ne "") { "Start=$Start`n" } { "Start=$AppName.exe`n" }
    if ( $ExtractIcon ) { $Content += "ExtractIcon=$ExtractIcon`n" }

    # appinfo.ini Pfad festlegen
    if( -not $ExportPath ){{ throw "New-AppInfoIni: 'ExportPath' ist erforderlich." }}
    $ExportFile = Join-Path -Path $ExportPath -ChildPath "appinfo.ini"

    if ( $ExtractIcon ) { $Content += "ExtractIcon=$ExtractIcon`n" }

    $Content | Set-Content -Path $ExportFile -Encoding UTF8
}
function New-AppLauncherIni {
    param (
        [hashtable]$Context,
        [string]$ExportPath,
        [bool]$SingleAppInstance = $true
    )
    # [Launch] Sektion
    $Content = "[Launch]`n"
    $Content += "ProgramExecutable=" + (Join-Path -Path $Context.AppName -ChildPath $Context.AppNameExe) + "`n"


    $ExportFile = Join-Path -Path $ExportPath -ChildPath "$($Context.AppID).ini"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ExportFile, $Content, $utf8NoBom)
}


function Read-Key {
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
        [int[]]$Margin      = @(0,0,0,2),

        [switch]$YesNo,
        [switch]$Silent
    )
    [System.Console]::CursorVisible = $false

    # Switch-Parameter
    if ( $YesNo ) { $ValidKeys = @('Y','N') }
    if ( $Silent ) { $Text = "" }

    # Tastendruck abfragen
    do {
        Write-Text $Text -ForegroundColor $Color -Margin $Margin -NoNewline
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
    } 
    while ( $ValidKeys.Count -gt 0 -and $key -notin $ValidKeys )
    [System.Console]::CursorVisible = $true

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

function Write-Text {
    param (
        [string]$Text,
        [System.ConsoleColor]$ForegroundColor = "White",
        # Layout-Parameter
        [ValidateSet("Left","Center","Right")]
        [string]$Alignment,

        # Margin
        [int[]]$Margin = @(0,0,0,2),   # Margin: [Top,Right,Bottom,Left]

        # Switch-Parameter
        [switch]$NoNewline
    )
    $Text = $Text.Trim()

    # Margin
    $MarginTop      = if ( $Margin.Count -ge 1 ) { $Margin[0] } else { 0 }
    $MarginRight    = if ( $Margin.Count -ge 2 ) { $Margin[1] } else { $MarginTop }
    $MarginBottom   = if ( $Margin.Count -ge 3 ) { $Margin[2] } else { $MarginTop }
    $MarginLeft     = if ( $Margin.Count -ge 4 ) { $Margin[3] } else { $MarginRight }

    # Width
    $Width = $host.UI.RawUI.BufferSize.Width
    $innerWidth = $Width - $MarginLeft - $MarginRight

    # Text ausrichten / Margin anwenden
    if ( $Alignment ) {
        switch ( $Alignment ) {
            "Left"   { $Text = ( " " * $MarginLeft) + $Text.PadRight($innerWidth) + ( " " * $MarginRight) }
            "Center" { $Text = ( " " * $MarginLeft) + $Text.PadLeft( ($innerWidth + $Text.Length) / 2 ).PadRight($innerWidth) + ( " " * $MarginRight) }
            "Right"  { $Text = ( " " * $MarginLeft) + $Text.PadLeft($innerWidth) + ( " " * $MarginRight) }
        }
    } else { $Text = ( " " * $MarginLeft) + $Text + ( " " * $MarginRight) }
    $Text = ( "`n" * $MarginTop ) + $Text + ( "`n" * $MarginBottom )


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
        [string]$Character = "-",
        [string]$ForegroundColor = "DarkRed",
        [int]$Width = $host.UI.RawUI.BufferSize.Width,
        [int[]]$Margin = 1
    )

    $MarginTop = if ( $Margin.Count -ge 1 ) { $Margin[0] } else { 0 }
    $MarginRight = if ( $Margin.Count -ge 2 ) { $Margin[1] } else { $MarginTop }
    $MarginBottom = if ( $Margin.Count -ge 3 ) { $Margin[2] } else { $MarginTop }
    $MarginLeft = if ( $Margin.Count -ge 4 ) { $Margin[3] } else { $MarginRight }
    $LineWidth = $Width - $MarginLeft - $MarginRight

    Write-Host ("`n" * $MarginTop) -NoNewline
    Write-Host (" " * $MarginLeft) -NoNewline
    Write-Host ($Character * $LineWidth) -ForegroundColor $ForegroundColor -NoNewline
    Write-Host (" " * $MarginRight) -NoNewline
    Write-Host ("`n" * $MarginBottom)

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
    Write-Text $Context.sourcePath -Margin 0,0,0,1

    # Startdatei (EXE) auswählen
    Write-Text "Startdatei (EXE) auswählen:" DarkCyan -NoNewline
    $Context.AppNameExe = Get-File -Title "Startdatei (EXE) auswählen:" -InitialDirectory $Context.sourcePath -Name
    Write-Text $Context.AppNameExe -Margin 0,0,0,1
    
    # Speicherort für die portable Anwendung auswählen (Zielordner)
    Write-Text "Zielordner für die portable Anwendung auswählen:" DarkCyan -NoNewline
    $Context.destinationPath = Get-Folder -Description "Zielordner:" -FullName
    Write-Text $Context.destinationPath -Margin 0,0,1,1

    # Splash-Bild auswählen
    Write-Text "Splash-Bild auswählen:" Cyan -NoNewline
    $Context.sourceSplashFile = Get-File -Title "Splash-Bild auswählen:" -InitialDirectory $Context.sourcePath -FullName
    Write-Text $Context.sourceSplashFile -Margin 0,0,1,1

    # Anwendungsname abfragen
    $Context.AppName = Read-CleanString -Prompt "Anwendungsname:" -SkipSpaces
    $Context.AppID = Read-CleanString -Prompt "Anwendungs-ID:" -Default $Context.AppName
    
    Write-Line

    return $Context
}


#######
function Update-DesktopIni{
    # Header
    Set-Header "Desktop.ini erstellen/bearbeiten"

    # Ordner auswählen
    Write-Text "Ordner:" Yellow -NoNewline
    $FolderPath = Get-Folder -Description "Wählen den Ordner aus:" -FullName
    Write-Text $FolderPath

    # Icon-Quelle auswählen
    Write-Text "Icon-Quelle:" Yellow -NoNewline
    $IconFile   = Get-File -Title "Pfad zur Icon-Datei:" -InitialDirectory $FolderPath -FullName
    Write-Text $IconFile

    # Dateiinhalt erstellen und speichern
    Write-Host
    Write-Results "Erstelle:" "desktop.ini" -Colors @("Red","Yellow")
    $ExportFile = Join-Path -Path $FolderPath -ChildPath "desktop.ini"
    $IconExtension = [System.IO.Path]::GetExtension($IconFile)
    $IconResource = if ( $IconExtension -eq ".ico" ) { $IconFile } else { "$IconFile,0" }
    $FileContent = @"
[.ShellClassInfo]
IconResource=$IconResource

[ViewState]
FolderType=Generic
"@
    Set-Content -Path $ExportFile -Encoding Unicode -Value $FileContent -Force

    # Attribute setzen: versteckt und System
    attrib +h +s $ExportFile
    attrib +r $FolderPath

    # Abschlussmeldung
    Write-Text "Fertig!" Green
    Write-Text "Die desktop.ini wurde erstellt unter:" Yellow -NoNewline
    Write-Text $FolderPath 
    Read-Key -Silent
}

# HEADER & USERINPUT ###############################################################################

while($true){
    Set-Header "$Name v$Version"

    Write-Text "1) PortableApps.com Anwendung erstellen" Yellow
    Write-Text "2) Desktop.ini erstellen/bearbeiten" Yellow
    Write-Text "q) Beenden" Red -Margin 1,0,1,2
    Write-Line
    
    $answer = Read-Key "Wählen Sie eine Option (1/2/q):" -ValidKeys @('1','2','q')
    Write-Line
    switch ($answer) {
        '1' { 
            Set-Header "Portable Anwendung erstellen"

            # Portable App erstellen
            $Context = Set-PortableApp -Context (Get-ApplicationInfo $Context)

            # Abschlussmeldung
            Write-Text "Fertig!" Green -Margin 0,0,1,2
            Write-Text $Context.AppName -ForegroundColor Cyan -Margin 0,0,1,2 -NoNewline
            Write-Text " wurde erfolgreich portabel gemacht."
            Write-Line
            

            # PortableApps.com Launcher Generator
            Write-Text "Suche nach PortableApps.com Launcher Generator..." DarkGray -NoNewline
            if(Test-Path (Join-Path -Path $Context.destinationPath -ChildPath "PortableApps.comLauncher/PortableApps.comLauncherGenerator.exe")){
                Write-Text "starten" Green
                Start-Process -FilePath (Join-Path -Path $Context.destinationPath -ChildPath "PortableApps.comLauncher/PortableApps.comLauncherGenerator.exe")
            } else { Write-Text " Nicht gefunden!" Red }
            
            Start-Sleep -Seconds 2
        }
        '2' { Update-DesktopIni }
        'q' { exit }
        Default {}
    }
}