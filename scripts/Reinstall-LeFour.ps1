# Reinstall-LeFour.ps1 - remet en place le PC a partir de D:\Sauvegarde-PC
# Lancer en administrateur :  powershell -ExecutionPolicy Bypass -File .\Reinstall-LeFour.ps1
# Ne supprime jamais rien : il copie et installe seulement.

$ErrorActionPreference = 'Continue'
$S = 'D:\Sauvegarde-PC'
$log = Join-Path ([Environment]::GetFolderPath('Desktop')) 'reinstall-log.txt'
Start-Transcript -Path $log -Append | Out-Null

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Relance PowerShell en administrateur (clic droit > Executer en tant qu''administrateur).' -ForegroundColor Red
    Stop-Transcript | Out-Null; exit 1
}
if (-not (Test-Path $S)) { Write-Host "Introuvable : $S" -ForegroundColor Red; Stop-Transcript | Out-Null; exit 1 }

function Step($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Copie($src, $dst, $extra = @()) {
    if (Test-Path $src) {
        robocopy $src $dst /E /R:1 /W:1 /NFL /NDL /NP /XF 'KMS_Pico*' @extra | Out-Null
        if ($LASTEXITCODE -ge 8) { Write-Host "  ERREUR copie $src" -ForegroundColor Red } else { Write-Host "  OK  $src -> $dst" -ForegroundColor Green }
    } else { Write-Host "  absent : $src" -ForegroundColor Yellow }
}
function Installe($nom, $exe, $params) {
    $f = Join-Path "$S\Setups" $exe
    if (-not (Test-Path $f)) { Write-Host "  absent : $exe" -ForegroundColor Yellow; return }
    Write-Host "  Installation : $nom"
    try {
        if ($exe -like '*.msi') { Start-Process msiexec.exe -ArgumentList "/i `"$f`" /qn /norestart" -Wait }
        elseif ($params) { Start-Process $f -ArgumentList $params -Wait }
        else { Start-Process $f -Wait }
        Write-Host "  OK  $nom" -ForegroundColor Green
    } catch { Write-Host "  ERREUR $nom : $_" -ForegroundColor Red }
}

# 1. Dossiers perso
Step 'Fichiers perso'
$U = $env:USERPROFILE
Copie "$S\Bureau"          ([Environment]::GetFolderPath('Desktop'))
Copie "$S\Documents"       ([Environment]::GetFolderPath('MyDocuments'))
Copie "$S\Photos"          ([Environment]::GetFolderPath('MyPictures'))
Copie "$S\Musique"         ([Environment]::GetFolderPath('MyMusic'))
Copie "$S\Videos"          ([Environment]::GetFolderPath('MyVideos'))
Copie "$S\Telechargements" "$U\Downloads"

# 2. Navigateurs, Discord, lanceurs de jeux
Step 'Applications'
Installe 'Chrome'          'ChromeSetup.exe'               '/silent /install'
Installe 'Brave'           'BraveBrowserSetup.exe'         '/silent /install'
Installe 'Discord'         'DiscordSetup.exe'              '-s'
Installe 'Steam'           'SteamSetup.exe'                '/S'
Installe 'Epic Games'      'EpicGamesLauncherInstaller.msi'
Installe 'Ubisoft Connect' 'UbisoftConnectInstaller.exe'   '/S'
Installe 'Rockstar'        'Rockstar-Games-Launcher.exe'   # fenetre a valider
Installe 'Valorant (Riot)' 'Riot-Valorant-Installer.exe'   # fenetre a valider

# 3. Tes apps (les fenetres d'installation s'ouvrent, valide-les)
Step 'Apps LeFour'
$M = 'Mes apps (LeFour, Coffre)'
Installe 'LeFourOpti 2.1'  "$M\LeFourOptiV2.1-Setup.exe"
Installe 'LeFourAdmin 2.1' "$M\LeFourAdminV2.1-Setup.exe"
Installe 'LePad 2.1'       "$M\LePadV2.1-Setup.exe"
Installe 'Coffre 2.1'      "$M\CoffreV2.1-Setup.exe"

# 4. Manette PS4 (DS4Windows) + ses reglages
Step 'DS4Windows'
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id Ryochan7.DS4Windows -e --accept-source-agreements --accept-package-agreements
} else { Write-Host '  winget absent : installe DS4Windows a la main (ds4-windows.com)' -ForegroundColor Yellow }
Copie "$S\Reglages-apps\DS4Windows" "$env:APPDATA\DS4Windows" @('/XD','Logs')

# 5. Reglages Fortnite
Step 'Fortnite'
$FC = "$env:LOCALAPPDATA\FortniteGame\Saved\Config"
Copie "$S\Reglages-apps\Fortnite-Config\WindowsClient" "$FC\WindowsClient" @('/XF','*.bak-claude')
if (Test-Path "$S\Reglages-apps\Fortnite-Config\ClientSettings.Sav") {
    New-Item -ItemType Directory -Force $FC | Out-Null
    Copy-Item "$S\Reglages-apps\Fortnite-Config\ClientSettings.Sav" $FC -Force
    Write-Host '  OK  ClientSettings.Sav' -ForegroundColor Green
}

# 6. Claude et ChatGPT/Codex (conversations, reglages)
Step 'Claude et Codex'
Copie "$S\Claude\.claude"               "$U\.claude"
if (Test-Path "$S\Claude\.claude.json") { Copy-Item "$S\Claude\.claude.json" $U -Force; Write-Host '  OK  .claude.json' -ForegroundColor Green }
Copie "$S\Claude\AppData-Roaming-Claude" "$env:APPDATA\Claude"
Copie "$S\ChatGPT-Codex\.codex"          "$U\.codex"
Copie "$S\ChatGPT-Codex\AppData-Local-OpenAI" "$env:LOCALAPPDATA\OpenAI"
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id Anthropic.Claude -e --accept-source-agreements --accept-package-agreements
}

Step 'Termine'
Write-Host "Journal : $log"
Write-Host 'A faire a la main : pilote AMD (amd.com/fr/support), licence LePad, coffre.dat, ouvrir LIRE-APRES-REINSTALL.md' -ForegroundColor Yellow
Stop-Transcript | Out-Null
