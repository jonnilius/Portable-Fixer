# Portable-Maker.ps1
$Name = "Portable-Fixer"
$Version = "0.1.0"

# Einstellungen
$WindowWidth  = 80
$WindowHeight = 50
$ReadPromptWidth = 20
$ReadColor = "Cyan"

$host.UI.RawUI.BufferSize = $host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size ($($WindowWidth +1), $WindowHeight)

# Debug
$DebugMode = $false
$DebugValues = @{
    AppName         = "UniGetUI"
    AppID           = "UniGetUIPortable"
    SourcePath      = "C:\Users\John-Andreas\Downloads\UniGetUI v3.3.6 (x64)"
    AppExe          = "UniGetUI.exe"
    DestinationPath = "P:\PortableApps"
    SplashImage     = "P:\Documents\Pictures\Splash.jpg"
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
        [int]$Width = $WindowWidth,
        [string]$ForegroundColor = "DarkRed"
    )
    Write-Host ""( "=" * $Width ) -ForegroundColor $ForegroundColor
    Write-Host ($Text.PadLeft(($Width + $Text.Length) / 2).PadRight($Width))
    if( $DebugMode ){ Write-Host ("DEBUG MODE ACTIVE".PadLeft(($Width + 17) / 2).PadRight($Width)) -ForegroundColor Yellow }
    Write-Host ""( "=" * $Width ) -ForegroundColor $ForegroundColor
    if( $DebugMode ){ Write-Host ("- es werden Testwerte benutzt -".PadLeft(($Width + 31) / 2).PadRight($Width)) -ForegroundColor DarkGray }
    Write-Space
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
}
function Show-FolderBrowserDialog {
    param (
        [string]$Description = "Wählen Sie einen Ordner aus:"
    )
    Add-Type -AssemblyName System.Windows.Forms
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = $Description
    $folderBrowser.ShowNewFolderButton = $true

    $result = $folderBrowser.ShowDialog()
    if ( $result -eq [System.Windows.Forms.DialogResult]::OK ) {
        return $folderBrowser.SelectedPath
    }
    return $null
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
        [string]$Prompt      = "Drücken Sie eine Taste:",
        [string]$PromptColor = $ReadColor,
        [int]$PromptWidth    = $ReadPromptWidth,
        [int]$PromptLeft     = 2,

        [array]$ValidKeys    = @(),
        [switch]$YesNo
    )
    if ( $YesNo ) { $ValidKeys = @('Y','N') }

    $Prompt = (" " * $PromptLeft) + $Prompt
    do {
        Write-Host $Prompt.PadRight($PromptWidth) -ForegroundColor $PromptColor -NoNewline
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
        [string]$PromptColor = $ReadColor,
        [int]$PromptWidth    = $ReadPromptWidth,
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
function Read-FolderPath {
    param (
        [string]$Prompt      = "Wählen Sie einen Ordner aus:",
        [string]$PromptColor = $ReadColor,
        [int]$PromptWidth    = $ReadPromptWidth,
        [int]$PromptLeft     = 2,

        [switch]$UIBrowse
    )
    if ( $UIBrowse ) {
        $folderPath = Show-FolderBrowserDialog -Description $Prompt
        if ( $folderPath ) { return $folderPath }
    }
    $Prompt = (" " * $PromptLeft) + $Prompt
    do {
        Write-Host $Prompt.PadRight($PromptWidth) -ForegroundColor $PromptColor -NoNewline
        $UserInput = (Read-Host).Trim()
    } while ( -not (Test-Path -Path $UserInput -PathType Container) )

    $UserInput
}
function Read-FilePath {
    param (
        [string]$Prompt      = "Wählen Sie eine Datei aus:",
        [string]$PromptColor = $ReadColor,
        [int]$PromptWidth    = $ReadPromptWidth,
        [int]$PromptLeft    = 2,

        [string]$Location,
        [switch]$JustFileName
    )

    $Prompt = (" " * $PromptLeft) + $Prompt
    do {
        Write-Host $Prompt.PadRight($PromptWidth) -ForegroundColor $PromptColor -NoNewline
        $file = (Read-Host).Trim()

        if ( -not (Test-Path $file -PathType Leaf) -and $Location ){ 
            $file = Join-Path -Path $Location -ChildPath $file 
        }
    } while ( -not (Test-Path -Path $file -PathType Leaf) )

    if ( $JustFileName ) { $file = [System.IO.Path]::GetFileName($file) } 

    $file
}

function Write-Line {
    param (
        [int]$Width = $WindowWidth,
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


# HEADER & USERINPUT ###############################################################################
$Context = [ordered]@{}
Set-Header -Text "$Name v$Version"

Write-Host "  1) Portable Anwendung erstellen" -ForegroundColor Yellow
Write-Host "  2) Desktop.ini für bestehenden Ordner erstellen" -ForegroundColor Yellow
$answer = Read-KeyString -Prompt "Wählen Sie eine Option (1/2):" -ValidKeys @('1','2')
Write-Line -Padding
switch ($answer) {
    '1' { 
        # Anwendungsinformationen abfragen
        $Context.AppName         = Get-InputValue "AppName" { Read-CleanString -Prompt "Anwendungsname:" -SkipSpaces }
        $Context.AppID           = Get-InputValue "AppID" { Read-CleanString -Prompt "Anwendungs-ID:" -Default $Context.AppName }
        $Context.sourcePath      = Get-InputValue "SourcePath" { Read-FolderPath  -Prompt "Programmordner:" -UIBrowse }
        $Context.AppNameExe      = Get-InputValue "AppExe" { Read-FilePath    -Prompt "Programmdatei:" -JustFileName -Location $Context.sourcePath }
        $Context.destinationPath = Get-InputValue "DestinationPath" { Read-FolderPath  -Prompt "Zielordner:" }
        $Context.sourceSplashFile= Get-InputValue "SplashImage" { Read-FilePath    -Prompt "Splash-Bild:" }

        # Bestätigung vor dem Starten
        if( $DebugMode -and -not (Read-KeyString -Prompt "Test starten? (Y/N)" -PromptColor "Gray" -YesNo) ){ 
            Write-Host "  Vorgang wurde Abgebrochen!" -ForegroundColor Red
            Start-Sleep -Seconds 3
            exit
        }

        # Portable App erstellen
        Set-PortableApp -Context $Context

        # Abschlussmeldung
        Write-Host "`n  Fertig!" -ForegroundColor Green
        Write-Host "  Die portable Anwendung wurde erstellt unter:"
        Write-Host "   "$rootPath -ForegroundColor Yellow

        # PortableApps.com Launcher Ordner
        Write-Host "`n  Suche nach PortableApps.com Launcher Generator..." -ForegroundColor Yellow -NoNewline
        if(Test-Path (Join-Path -Path $Context.destinationPath -ChildPath "PortableApps.comLauncher/PortableApps.comLauncherGenerator.exe")){
            Write-Host " Gefunden!" -ForegroundColor Green
            if(Read-KeyString -Prompt "Möchten Sie den Launcher Generator jetzt starten? (Y/N)" -PromptColor "Gray" -YesNo){
                Start-Process -FilePath (Join-Path -Path $Context.destinationPath -ChildPath "PortableApps.comLauncher/PortableApps.comLauncherGenerator.exe")
            }
        } else { Write-Host " Nicht gefunden!" -ForegroundColor Red }
        Pause
     }
    '2' { 
        $folderPath = Read-FolderPath -Prompt "Ordnerpfad für desktop.ini:" -UIBrowse
        $iconFile   = Read-FilePath -Prompt "Pfad zur EXE-Datei für das Icon:"
        Write-Line -Padding
        Write-Results "Erstelle:" "desktop.ini" -Colors @("Red","Yellow")
        New-DesktopIni -IconFile $iconFile -ExportPath $folderPath
        Write-Host "`n  Fertig!" -ForegroundColor Green
        Write-Host "  Die desktop.ini wurde erstellt unter:"
        Write-Host "   "$folderPath -ForegroundColor Yellow
        Pause > $null
     }
    Default {}
}