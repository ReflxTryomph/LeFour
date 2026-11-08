# Reinstall-LeFour-Partie2.ps1 - suite de LIRE-APRES-REINSTALL.md
# Lancer en administrateur :  powershell -ExecutionPolicy Bypass -File .\Reinstall-LeFour-Partie2.ps1

$ErrorActionPreference = 'Continue'
$S = 'D:\Sauvegarde-PC'
$log = Join-Path ([Environment]::GetFolderPath('Desktop')) 'reinstall-log-partie2.txt'
Start-Transcript -Path $log -Append | Out-Null

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Relance PowerShell en administrateur.' -ForegroundColor Red; Stop-Transcript | Out-Null; exit 1
}
if (-not (Test-Path $S)) { $S = 'E:\Sauvegarde-PC' }
if (-not (Test-Path $S)) { Write-Host 'Sauvegarde-PC introuvable sur D: ou E:' -ForegroundColor Red; Stop-Transcript | Out-Null; exit 1 }

function Step($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t)   { Write-Host "  OK  $t" -ForegroundColor Green }
function Oui($q)  { (Read-Host "$q (o/n)") -match '^[oOyY]' }
function Copie($src, $dst) {
    if (-not (Test-Path $src)) { Write-Host "  absent : $src" -ForegroundColor Yellow; return }
    robocopy $src $dst /E /R:1 /W:1 /NFL /NDL /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Write-Host "  ERREUR copie $src" -ForegroundColor Red } else { Ok "$src -> $dst" }
}
$wg = [bool](Get-Command winget -ErrorAction SilentlyContinue)
function Winget($id, $nom, $src = 'winget') {
    if (-not $wg) { Write-Host "  winget absent, installe $nom a la main" -ForegroundColor Yellow; return }
    Write-Host "  Installation : $nom"
    winget install --id $id -e --source $src --accept-source-agreements --accept-package-agreements --silent
}

# 1. Photos : Photos\Images doit aller directement dans Images (pas Images\Images)
Step 'Photos'
$P = [Environment]::GetFolderPath('MyPictures')
if (Test-Path "$P\Images") {
    robocopy "$P\Images" $P /E /MOVE /R:1 /W:1 /NFL /NDL /NP | Out-Null
    Ok 'Images\Images remis dans Images'
}

# 2. Coffre
Step 'Coffre'
if (Oui 'Remettre ton coffre.dat dans %APPDATA%\Coffre ? (ecrase le coffre vide cree a l installation)') {
    Get-Process | Where-Object { $_.ProcessName -like '*Coffre*' } | Stop-Process -Force -ErrorAction SilentlyContinue
    if (Test-Path "$env:APPDATA\Coffre\coffre.dat") { Copy-Item "$env:APPDATA\Coffre\coffre.dat" "$env:APPDATA\Coffre\coffre.dat.vide-$(Get-Date -f yyyyMMddHHmm)" }
    Copie "$S\Coffre\Donnees (coffre.dat)" "$env:APPDATA\Coffre"
}

# 3. LePad
Step 'LePad'
Copie "$S\Reglages-apps\LePad" "$env:LOCALAPPDATA\LePad"

# 4. Fortnite (apres le 1er lancement)
Step 'Fortnite'
if (Oui 'As-tu deja lance Fortnite une fois sur ce Windows (puis ferme) ?') {
    Get-Process | Where-Object { $_.ProcessName -like 'Fortnite*' } | Stop-Process -Force -ErrorAction SilentlyContinue
    $FC = "$env:LOCALAPPDATA\FortniteGame\Saved\Config"
    Copie "$S\Reglages-apps\Fortnite-Config\WindowsClient" "$FC\WindowsClient"
    Copy-Item "$S\Reglages-apps\Fortnite-Config\ClientSettings.Sav" $FC -Force -ErrorAction SilentlyContinue
    $ini = "$FC\WindowsClient\GameUserSettings.ini"
    if (Test-Path $ini) {
        (Get-Content $ini) -replace '^(LastConfirmedFullscreenMode|PreferredFullscreenMode|FullscreenMode)=.*', '$1=0' | Set-Content $ini -Encoding UTF8
        Ok 'Fortnite en plein ecran exclusif'
    }
} else { Write-Host '  Lance Fortnite une fois, ferme-le, puis relance ce script.' -ForegroundColor Yellow }

# 5. Logiciels qui n'etaient pas dans Setups
Step 'Logiciels'
Winget 'Git.Git'                    'Git'
Winget 'GitHub.cli'                 'GitHub CLI'
Winget 'Microsoft.VisualStudioCode' 'VS Code'
Winget 'OpenJS.NodeJS.LTS'          'Node.js'
Winget 'OBSProject.OBSStudio'       'OBS'
if (Oui 'Installer Medal ?')        { Winget 'Medal.TV' 'Medal' }
Winget '9NT1R1C2HH7J'               'ChatGPT' 'msstore'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
if (Get-Command npm -ErrorAction SilentlyContinue) { npm install -g @openai/codex; Ok 'Codex (CLI)' }

# 6. Reglages perf
Step 'Reglages perf'
reg add 'HKCU\Software\Microsoft\GameBar' /v AutoGameModeEnabled /t REG_DWORD /d 1 /f | Out-Null; Ok 'Mode Jeu active'
reg add 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power' /v HiberbootEnabled /t REG_DWORD /d 0 /f | Out-Null; Ok 'Demarrage rapide coupe'
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT; Ok 'Veille selective USB coupee'
Get-PnpDevice -Class USB -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.InstanceId)\Device Parameters"
    if (Test-Path $k) { Set-ItemProperty $k -Name 'EnhancedPowerManagementEnabled' -Value 0 -Type DWord -ErrorAction SilentlyContinue }
}
$eth = Get-NetAdapter -Physical | Where-Object { $_.MediaType -eq '802.3' }
foreach ($a in $eth) {
    Disable-NetAdapterPowerManagement -Name $a.Name -NoRestart -ErrorAction SilentlyContinue
    foreach ($kw in '*EEE','EEELinkAdvertisement','GreenEthernet','PowerSavingMode','*SelectiveSuspend','ULPMode','EnableGreenEthernet','AdvancedEEE') {
        Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword $kw -RegistryValue 0 -NoRestart -ErrorAction SilentlyContinue
    }
    Ok "Economies d'energie coupees sur $($a.Name)"
}
if ($eth | Where-Object Status -eq 'Up') {
    $wifi = Get-NetAdapter -Physical | Where-Object { $_.MediaType -eq 'Native 802.11' -and $_.Status -ne 'Disabled' }
    if ($wifi -and (Oui 'Tu es en Ethernet : desactiver le Wi-Fi ?')) { $wifi | Disable-NetAdapter -Confirm:$false; Ok 'Wi-Fi desactive' }
}

Step 'Termine'
Write-Host "Journal : $log"
Write-Host 'A faire toi-meme : pilote AMD Adrenalin (amd.com/fr/support), puis "gh auth login", puis redemarrer.' -ForegroundColor Yellow
Stop-Transcript | Out-Null
