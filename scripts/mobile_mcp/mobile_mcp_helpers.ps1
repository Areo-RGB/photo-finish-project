Set-StrictMode -Version Latest

function Write-Step([string]$Message) {
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Info([string]$Message) {
  Write-Host "  - $Message" -ForegroundColor DarkGray
}

function Invoke-Mobile([string]$Tool, [string[]]$ToolArgs, [int]$TimeoutMs = 20000) {
  $output = & mobile-mcp $Tool @ToolArgs -t $TimeoutMs -o json 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "mobile-mcp $Tool failed: $output"
  }
  return ($output -join "`n")
}

function Get-JsonSlice([string]$Text) {
  $startIndex = $Text.IndexOf("[")
  $endIndex = $Text.LastIndexOf("]")
  if ($startIndex -lt 0 -or $endIndex -lt 0 -or $endIndex -le $startIndex) {
    return $null
  }
  return $Text.Substring($startIndex, $endIndex - $startIndex + 1)
}

function Get-Elements([string]$DeviceId) {
  $raw = Invoke-Mobile "mobile-list-elements-on-screen" @("--device", $DeviceId)
  $jsonSlice = Get-JsonSlice $raw
  if (-not $jsonSlice) {
    throw "Could not parse elements for device $DeviceId. Raw output: $raw"
  }
  return ($jsonSlice | ConvertFrom-Json)
}

function Get-CenterPoint($Element) {
  $x = [int]($Element.coordinates.x + [math]::Floor($Element.coordinates.width / 2))
  $y = [int]($Element.coordinates.y + [math]::Floor($Element.coordinates.height / 2))
  return @{ x = $x; y = $y }
}

function Click-At([string]$DeviceId, [int]$X, [int]$Y) {
  [void](Invoke-Mobile "mobile-click-on-screen-at-coordinates" @(
      "--device", $DeviceId,
      "--x", "$X",
      "--y", "$Y"
    ))
}

function Find-ElementsByLabel($Elements, [string]$Label, [switch]$Contains) {
  if ($Contains) {
    return @($Elements | Where-Object { $_.label -and $_.label.Contains($Label) })
  }
  return @($Elements | Where-Object { $_.label -eq $Label })
}

function Click-Label(
  [string]$DeviceId,
  [string]$Label,
  [switch]$Contains,
  [int]$Index = 0
) {
  $elements = Get-Elements $DeviceId
  $matches = @(Find-ElementsByLabel $elements $Label -Contains:$Contains)
  if ($matches.Count -le $Index) {
    return $false
  }
  $sorted = @($matches | Sort-Object { $_.coordinates.y })
  $target = $sorted[$Index]
  $center = Get-CenterPoint $target
  Click-At $DeviceId $center.x $center.y
  Start-Sleep -Milliseconds 450
  return $true
}

function Wait-Until(
  [scriptblock]$Condition,
  [int]$PollMilliseconds = 900,
  [string]$ProgressLabel = "Waiting",
  [int]$TimeoutSeconds = 0
) {
  $started = Get-Date
  $lastLog = $started
  while ($true) {
    if (& $Condition) {
      return $true
    }
    if ($TimeoutSeconds -gt 0 -and ((Get-Date) - $started).TotalSeconds -ge $TimeoutSeconds) {
      return $false
    }
    if (((Get-Date) - $lastLog).TotalSeconds -ge 10) {
      $elapsed = [int]((Get-Date) - $started).TotalSeconds
      if ($TimeoutSeconds -gt 0) {
        Write-Info "$ProgressLabel (elapsed ${elapsed}s / timeout ${TimeoutSeconds}s)"
      } else {
        Write-Info "$ProgressLabel (elapsed ${elapsed}s)"
      }
      $lastLog = Get-Date
    }
    Start-Sleep -Milliseconds $PollMilliseconds
  }
}

function Wait-And-ClickLabel(
  [string]$DeviceId,
  [string]$Label,
  [switch]$Contains,
  [int]$Index = 0,
  [int]$TimeoutSeconds = 0
) {
  return (Wait-Until {
      return (Click-Label $DeviceId $Label -Contains:$Contains -Index $Index)
    } -PollMilliseconds 800 -ProgressLabel "Waiting for '$Label' on $DeviceId" -TimeoutSeconds $TimeoutSeconds)
}

function Ensure-LabelContains(
  [string]$DeviceId,
  [string]$LabelContains,
  [int]$TimeoutSeconds = 0
) {
  return (Wait-Until {
      $elements = Get-Elements $DeviceId
      $found = @($elements | Where-Object {
          $_.label -and $_.label.Contains($LabelContains)
        })
      return $found.Count -gt 0
    } -ProgressLabel "Waiting for '$LabelContains' on $DeviceId" -TimeoutSeconds $TimeoutSeconds)
}

function Resolve-PermissionPrompt([string]$DeviceId) {
  $options = @(
    "While using the app",
    "While using the app only",
    "Only this time",
    "Allow",
    "ALLOW",
    "Continue"
  )
  foreach ($option in $options) {
    [void](Click-Label $DeviceId $option -Contains)
  }
}

function Get-PermissionsGranted([string]$DeviceId) {
  $elements = Get-Elements $DeviceId
  $sessionCards = @($elements | Where-Object {
      $_.label -and $_.label.Contains("Permissions granted:")
    })
  if ($sessionCards.Count -eq 0) {
    return $false
  }
  return $sessionCards[0].label.Contains("Permissions granted: true")
}

function Resolve-ProjectRoot([string]$ProjectRoot, [string]$ScriptRoot) {
  if ($ProjectRoot -and $ProjectRoot.Trim().Length -gt 0) {
    return (Resolve-Path $ProjectRoot).Path
  }
  return (Resolve-Path (Join-Path $ScriptRoot "..")).Path
}
