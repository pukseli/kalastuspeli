param(
    [int]$Port = 7777,
    [int]$SyncHz = 20,
    [switch]$NoFirewall
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = "SilentlyContinue"

$WorkDir = Join-Path $env:LOCALAPPDATA "kalastuspeli-lan-test"
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

# Locate local project directory or download repository archive
$ProjectDir = $null
if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $ToolsDir = Split-Path $PSScriptRoot -Parent
    $CandidateDir = Split-Path $ToolsDir -Parent
    if (Test-Path (Join-Path $CandidateDir "project.godot")) {
        $ProjectDir = $CandidateDir
    }
}

if ([string]::IsNullOrWhiteSpace($ProjectDir)) {
    $RepoZip = Join-Path $WorkDir "repo.zip"
    $RepoExtractDir = Join-Path $WorkDir "repo"
    $RepoUrl = "https://github.com/pukseli/kalastuspeli/archive/refs/heads/main.zip"
    Write-Host "[SETUP] Downloading project archive from $RepoUrl ..."
    Invoke-WebRequest -UseBasicParsing -Uri $RepoUrl -OutFile $RepoZip
    if (Test-Path $RepoExtractDir) {
        Remove-Item -Recurse -Force $RepoExtractDir
    }
    Expand-Archive -Path $RepoZip -DestinationPath $RepoExtractDir -Force
    $ProjectDir = Join-Path $RepoExtractDir "kalastuspeli-main"
    if (-not (Test-Path (Join-Path $ProjectDir "project.godot"))) {
        throw "Failed to locate project.godot in extracted archive at $ProjectDir"
    }
}
Write-Host "[INFO] Project directory: $ProjectDir"

# Locate cached/installed Godot 4.3 Win64 or download it
$GodotDir = Join-Path $WorkDir "godot"
$GodotConsoleExe = Join-Path $GodotDir "Godot_v4.3-stable_win64_console.exe"
$GodotGuiExe = Join-Path $GodotDir "Godot_v4.3-stable_win64.exe"
$GodotExe = $null

if (Test-Path $GodotConsoleExe) {
    $GodotExe = $GodotConsoleExe
}
elseif (Test-Path $GodotGuiExe) {
    $GodotExe = $GodotGuiExe
}
else {
    $CmdGodot = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $CmdGodot) {
        $GodotExe = $CmdGodot.Source
    }
    else {
        $CmdGodot4 = Get-Command godot4 -ErrorAction SilentlyContinue
        if ($null -ne $CmdGodot4) {
            $GodotExe = $CmdGodot4.Source
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    $GodotZip = Join-Path $WorkDir "godot.zip"
    $GodotUrl = "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip"
    Write-Host "[SETUP] Downloading Godot 4.3 Win64 from $GodotUrl ..."
    Invoke-WebRequest -UseBasicParsing -Uri $GodotUrl -OutFile $GodotZip
    if (-not (Test-Path $GodotDir)) {
        New-Item -ItemType Directory -Force -Path $GodotDir | Out-Null
    }
    Expand-Archive -Path $GodotZip -DestinationPath $GodotDir -Force
    if (Test-Path $GodotConsoleExe) {
        $GodotExe = $GodotConsoleExe
    }
    elseif (Test-Path $GodotGuiExe) {
        $GodotExe = $GodotGuiExe
    }
    else {
        throw "Godot executable not found after extracting $GodotZip"
    }
}
Write-Host "[INFO] Using Godot: $GodotExe"

# Pre-import project assets
Write-Host "[SETUP] Pre-importing Godot project..."
$ErrorActionPreference = "Continue"
& $GodotExe --headless --audio-driver Dummy --path $ProjectDir --import | Out-Null
$ImportExit = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($ImportExit -ne 0) {
    Write-Warning "Godot --import exited with code $ImportExit (continuing anyway)."
}

# Print local IPv4 candidates and laptop join command
$IpCandidates = @(
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike '127.*' -and
        $_.IPAddress -notlike '169.254.*' -and
        $_.InterfaceAlias -notlike '*WSL*' -and
        $_.InterfaceAlias -notlike '*vEthernet*' -and
        $_.InterfaceAlias -notlike '*Bluetooth*'
    } |
    Sort-Object -Property @{ Expression = { if ($_.InterfaceAlias -match 'Ethernet') { 0 } else { 1 } } }, IPAddress
)

Write-Host ""
Write-Host "=== Host LAN IPv4 Addresses ==="
if ($IpCandidates.Count -gt 0) {
    foreach ($Entry in $IpCandidates) {
        Write-Host ("  - {0}: {1}/{2}" -f $Entry.InterfaceAlias, $Entry.IPAddress, $Entry.PrefixLength)
    }
    $TopIp = $IpCandidates[0].IPAddress
}
else {
    Write-Host "  (No non-loopback LAN IPv4 address detected)"
    $TopIp = "<HOST_IP>"
}

Write-Host ""
Write-Host "Laptop join command:"
Write-Host "  bash tools/test-lan/join_lan.sh $TopIp $Port"
Write-Host ""

# Configure temporary Windows Firewall inbound UDP rule if elevated
$RuleName = "Kalastuspeli-LAN-Test-UDP-$Port"
$Principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$CreatedRule = $false

if ($IsAdmin -and (-not $NoFirewall)) {
    Remove-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Allow -Protocol UDP -LocalPort $Port -Profile Any | Out-Null
    $CreatedRule = $true
    Write-Host "[FIREWALL] Added temporary inbound UDP rule '$RuleName' on port $Port (will be removed when Godot closes)."
}
elseif (-not $NoFirewall) {
    $ExistingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    if ($null -eq $ExistingRule) {
        Write-Host "[FIREWALL] Not running as Administrator and rule '$RuleName' was not found."
        Write-Host "  If the laptop cannot connect, run these commands in an elevated PowerShell:"
        Write-Host "    Add:    New-NetFirewallRule -DisplayName `"$RuleName`" -Direction Inbound -Action Allow -Protocol UDP -LocalPort $Port -Profile Any"
        Write-Host "    Remove: Remove-NetFirewallRule -DisplayName `"$RuleName`""
        Write-Host "  Note: Windows Defender Firewall may also show a prompt when Godot starts."
    }
    else {
        Write-Host "[FIREWALL] Existing firewall rule '$RuleName' detected."
    }
}

Write-Host "[HOST] Starting kalastuspeli host on UDP *:$Port (sync: $SyncHz Hz)..."
try {
    & $GodotExe --path $ProjectDir -- --env test --host --port $Port --sync-hz $SyncHz
}
finally {
    if ($CreatedRule) {
        Remove-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
        Write-Host "[CLEANUP] Removed temporary firewall rule: $RuleName"
    }
}
