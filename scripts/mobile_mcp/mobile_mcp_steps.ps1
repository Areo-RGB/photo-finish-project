Set-StrictMode -Version Latest

function Ensure-DebugApk(
  [string]$ProjectRoot,
  [string]$ApkPath,
  [switch]$SkipBuild
) {
  if (-not $SkipBuild) {
    Write-Step "Building debug APK"
    Push-Location $ProjectRoot
    try {
      & flutter build apk --debug
      if ($LASTEXITCODE -ne 0) {
        throw "flutter build apk failed."
      }
    } finally {
      Pop-Location
    }
  }

  if (-not (Test-Path $ApkPath)) {
    throw "APK not found: $ApkPath"
  }
}

function Restart-AppOnDevices(
  [string]$PixelDeviceId,
  [string]$PeerDeviceId,
  [string]$PackageName,
  [string]$ApkPath,
  [switch]$SkipInstall
) {
  Write-Step "Terminating app on both devices"
  [void](Invoke-Mobile "mobile-terminate-app" @("--device", $PixelDeviceId, "--package-name", $PackageName))
  [void](Invoke-Mobile "mobile-terminate-app" @("--device", $PeerDeviceId, "--package-name", $PackageName))

  if (-not $SkipInstall) {
    Write-Step "Installing APK on both devices"
    [void](Invoke-Mobile "mobile-install-app" @("--device", $PixelDeviceId, "--path", $ApkPath))
    [void](Invoke-Mobile "mobile-install-app" @("--device", $PeerDeviceId, "--path", $ApkPath))
  }

  Write-Step "Launching app on both devices"
  [void](Invoke-Mobile "mobile-launch-app" @("--device", $PixelDeviceId, "--package-name", $PackageName))
  [void](Invoke-Mobile "mobile-launch-app" @("--device", $PeerDeviceId, "--package-name", $PackageName))
  Start-Sleep -Seconds 2
}

function Ensure-Permissions(
  [string]$PixelDeviceId,
  [string]$PeerDeviceId
) {
  Write-Step "Requesting permissions on both devices"
  Write-Info "Fast parallel tap on both devices (max 5s)"

  $pixelTap = @{ x = 324; y = 693 }
  $peerTap = @{ x = 370; y = 749 }

  $pixelJob = Start-Job -ScriptBlock {
    param($deviceId, $x, $y)
    & mobile-mcp mobile-click-on-screen-at-coordinates --device $deviceId --x $x --y $y -t 5000 -o json *> $null
  } -ArgumentList $PixelDeviceId, $pixelTap.x, $pixelTap.y

  $peerJob = Start-Job -ScriptBlock {
    param($deviceId, $x, $y)
    & mobile-mcp mobile-click-on-screen-at-coordinates --device $deviceId --x $x --y $y -t 5000 -o json *> $null
  } -ArgumentList $PeerDeviceId, $peerTap.x, $peerTap.y

  $jobs = @($pixelJob, $peerJob)

  $null = Wait-Job -Job $jobs -Timeout 5
  $runningJobs = @($jobs | Where-Object { $_.State -eq "Running" })
  if ($runningJobs.Count -gt 0) {
    Write-Info "Permission tap timed out on one or more devices after 5s; continuing."
    $runningJobs | Stop-Job | Out-Null
  }
  $jobs | Receive-Job | Out-Null
  $jobs | Remove-Job -Force | Out-Null
}

function Connect-DevicesInSetup(
  [string]$PixelDeviceId,
  [string]$PeerDeviceId
) {
  Write-Step "Creating lobby on Pixel and joining from peer"
  if (-not (Wait-And-ClickLabel $PixelDeviceId "Create Lobby")) {
    throw "Could not find 'Create Lobby' on Pixel."
  }
  if (-not (Wait-And-ClickLabel $PeerDeviceId "Join Lobby")) {
    throw "Could not find 'Join Lobby' on peer."
  }

  Write-Step "Connecting peer to host"
  $connectOk = Wait-Until {
    return (Click-Label $PeerDeviceId "Connect")
  } -ProgressLabel "Waiting for peer Connect button"
  if (-not $connectOk) {
    throw "Peer could not find/click Connect."
  }

  Write-Step "Waiting for both devices to show connected count >= 2"
  $pixelReady = Ensure-LabelContains $PixelDeviceId "Devices connected: 2"
  $peerReady = Ensure-LabelContains $PeerDeviceId "Devices connected: 2"
  if (-not $pixelReady -or -not $peerReady) {
    throw "Connection did not stabilize on both devices."
  }
}

function Enter-LobbyFromSetup(
  [string]$PixelDeviceId,
  [string]$PeerDeviceId
) {
  Write-Step "Entering lobby on both devices"
  $pixelAlreadyLobby = Ensure-LabelContains $PixelDeviceId "Lobby" 2
  if (-not $pixelAlreadyLobby) {
    if (-not (Wait-And-ClickLabel $PixelDeviceId "Next")) {
      throw "Could not click Next on Pixel."
    }
  }

  $peerAlreadyLobby = Ensure-LabelContains $PeerDeviceId "Lobby" 2
  if (-not $peerAlreadyLobby) {
    if (-not (Wait-And-ClickLabel $PeerDeviceId "Next")) {
      throw "Could not click Next on peer."
    }
  }
}

function Open-RoleMenu([string]$HostDeviceId, [int]$Index = 0) {
  foreach ($label in @("Unassigned", "Start", "Stop", "Split")) {
    if (Click-Label $HostDeviceId $label -Index $Index) {
      return $true
    }
  }
  return $false
}

function Set-RoleOnHost(
  [string]$HostDeviceId,
  [int]$DeviceIndex,
  [ValidateSet("Unassigned", "Start", "Split", "Stop")][string]$Role
) {
  if (-not (Open-RoleMenu $HostDeviceId $DeviceIndex)) {
    throw "Could not open role menu index $DeviceIndex on host."
  }
  if (-not (Wait-And-ClickLabel $HostDeviceId $Role)) {
    throw "Could not set role '$Role' on host for index $DeviceIndex."
  }
}

function Assign-TwoDeviceRoles(
  [string]$HostDeviceId
) {
  Write-Step "Assigning roles on Pixel host"
  Set-RoleOnHost $HostDeviceId 0 "Start"
  Set-RoleOnHost $HostDeviceId 0 "Stop"
}

function Start-MonitoringOnHost([string]$HostDeviceId) {
  Write-Step "Starting monitoring on Pixel"
  if (-not (Wait-And-ClickLabel $HostDeviceId "Start Monitoring")) {
    throw "Could not click Start Monitoring on Pixel."
  }
}

function Show-FlowComplete([string]$PixelDeviceId, [string]$PeerDeviceId) {
  Write-Step "Flow complete"
  Write-Host "Pixel: $PixelDeviceId" -ForegroundColor Green
  Write-Host "Peer:  $PeerDeviceId" -ForegroundColor Green
  Write-Host "You can now run a real motion pass and watch Advanced Detection stats." -ForegroundColor Yellow
}
