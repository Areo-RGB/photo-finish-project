param(
  [string]$PixelDeviceId = "31071FDH2008FK",
  [string]$PeerDeviceId = "DMIFHU7HUG9PKVVK",
  [string]$PackageName = "com.paul.sprintsync",
  [string]$ProjectRoot = "",
  [switch]$SkipBuild,
  [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$helperPath = Join-Path $PSScriptRoot "mobile_mcp\mobile_mcp_helpers.ps1"
$stepsPath = Join-Path $PSScriptRoot "mobile_mcp\mobile_mcp_steps.ps1"

if (-not (Test-Path $helperPath)) {
  throw "Missing helper script: $helperPath"
}
if (-not (Test-Path $stepsPath)) {
  throw "Missing steps script: $stepsPath"
}

. $helperPath
. $stepsPath

$root = Resolve-ProjectRoot -ProjectRoot $ProjectRoot -ScriptRoot $PSScriptRoot
$apkPath = Join-Path $root "build\app\outputs\flutter-apk\app-debug.apk"

Write-Step "Project root: $root"
Ensure-DebugApk -ProjectRoot $root -ApkPath $apkPath -SkipBuild:$SkipBuild
Restart-AppOnDevices -PixelDeviceId $PixelDeviceId -PeerDeviceId $PeerDeviceId -PackageName $PackageName -ApkPath $apkPath -SkipInstall:$SkipInstall
Ensure-Permissions -PixelDeviceId $PixelDeviceId -PeerDeviceId $PeerDeviceId
Connect-DevicesInSetup -PixelDeviceId $PixelDeviceId -PeerDeviceId $PeerDeviceId
Enter-LobbyFromSetup -PixelDeviceId $PixelDeviceId -PeerDeviceId $PeerDeviceId
Assign-TwoDeviceRoles -HostDeviceId $PixelDeviceId
Start-MonitoringOnHost -HostDeviceId $PixelDeviceId
Show-FlowComplete -PixelDeviceId $PixelDeviceId -PeerDeviceId $PeerDeviceId