<#
.SYNOPSIS
    Aarkam AM CLI — Automated Production Installation & Bootstrap Script for Windows.

.DESCRIPTION
    Automates the production deployment of the Aarkam Distributed Control Plane CLI ('am') on
    Windows Server 2022 / Windows Server 2025 and Windows 10/11 Enterprise & Pro (x64).
    - Validates 64-bit architecture and optional Administrator elevation.
    - Creates isolated directory structure under 'C:\Program Files\Aarkam\AM' (or local user profile).
    - Provisions 'am.exe' and default 'appsettings.json'.
    - Updates Machine or User PATH environment variable safely without duplicates.
    - Broadcasts WM_SETTINGCHANGE so running and new terminal windows recognize 'am' instantly.
    - Verifies installation by testing 'am --version'.

.PARAMETER InstallDir
    Target directory for AM CLI binaries. Defaults to 'C:\Program Files\Aarkam\AM' (or '%LOCALAPPDATA%\Aarkam\AM' if not elevated).

.PARAMETER SourcePath
    Path to pre-published AM binaries, release zip archive, or repository root containing src\AM.CLI\AM.CLI.csproj.

.PARAMETER CoordinatorUrl
    Default Rokka Coordinator endpoint URL to configure in appsettings.json (defaults to "https://rokka-coordinator.aarkam:57774").
    Supports sovereign cluster DNS ('https://rokka-coordinator.aarkam:57774'), standard port 443 ('https://rokka-coordinator.aarkam'),
    or custom on-premises IP/path ('https://10.20.0.10:57774', 'https://localhost:57774').

.PARAMETER UserOnly
    Installs exclusively for the current user without requiring Administrator elevation.

.EXAMPLE
    .\install-am.ps1 -SourcePath "D:\repos\Aarkam.IO\V2\Aarkam.AM"
    
.EXAMPLE
    .\install-am.ps1 -SourcePath ".\dist\bundles\am-v1.0.0-win-x64.zip" -CoordinatorUrl "https://rokka-coordinator.aarkam:57774"

.EXAMPLE
    .\install-am.ps1 -CoordinatorUrl "https://rokka-coordinator.aarkam"
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "",
    [string]$SourcePath = "",
    [string]$CoordinatorUrl = "https://rokka-coordinator.aarkam:57774",
    [switch]$UserOnly
)

$ErrorActionPreference = "Stop"

function Write-Info  { param([string]$Message) Write-Host "[INFO]  $Message" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Message) Write-Host "[OK]    $Message" -ForegroundColor Green }
function Write-Warn  { param([string]$Message) Write-Host "[WARN]  $Message" -ForegroundColor Yellow }
function Write-Err   { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

Write-Host "======================================================================" -ForegroundColor Blue
Write-Host " Aarkam Distributed Control Plane CLI (am) — Production Installer     " -ForegroundColor Cyan
Write-Host " Version: V-1.0.0-GA | Air-Gapped Sovereign Edition                   " -ForegroundColor Blue
Write-Host "======================================================================" -ForegroundColor Blue

# ------------------------------------------------------------------------------
# Normalize Coordinator URL
# ------------------------------------------------------------------------------
$CoordinatorUrl = $CoordinatorUrl.Trim()
if (-not $CoordinatorUrl.StartsWith("http://", [System.StringComparison]::OrdinalIgnoreCase) -and
    -not $CoordinatorUrl.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) {
    $CoordinatorUrl = "https://$CoordinatorUrl"
}

# ------------------------------------------------------------------------------
# Step 1: Privilege & Architecture Check
# ------------------------------------------------------------------------------
if ([IntPtr]::Size -ne 8) {
    Write-Err "64-bit architecture (x64) is required. 32-bit execution is unsupported."
    exit 1
}

$isAdmin = $false
try {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    $isAdmin = $false
}

if (-not $isAdmin -and -not $UserOnly.IsPresent) {
    Write-Warn "Installer not running as Administrator. Falling back to CurrentUser installation."
    $UserOnly = [switch]::Present
}

# ------------------------------------------------------------------------------
# Step 2: Resolve Target Installation Directory
# ------------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    if ($isAdmin -and -not $UserOnly.IsPresent) {
        $InstallDir = Join-Path $env:ProgramFiles "Aarkam\AM"
    } else {
        $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
        $InstallDir = Join-Path $localAppData "Aarkam\AM"
    }
}

$CredentialsDir = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) "Aarkam"

Write-Info "Target installation directory: $InstallDir"
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
if (-not (Test-Path $CredentialsDir)) {
    New-Item -ItemType Directory -Path $CredentialsDir -Force | Out-Null
}

# ------------------------------------------------------------------------------
# Step 3: Deploy or Publish Binaries
# ------------------------------------------------------------------------------
$amExeTarget = Join-Path $InstallDir "am.exe"

if (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
    if ((Test-Path $SourcePath -PathType Leaf) -and $SourcePath.EndsWith(".zip")) {
        Write-Info "Extracting release bundle '$SourcePath'..."
        Expand-Archive -Path $SourcePath -DestinationPath $InstallDir -Force
    } elseif (Test-Path (Join-Path $SourcePath "am.exe")) {
        Write-Info "Copying pre-published binaries from '$SourcePath'..."
        Copy-Item -Path "$SourcePath\*" -Destination $InstallDir -Recurse -Force
    } elseif (Test-Path (Join-Path $SourcePath "src\AM.CLI\AM.CLI.csproj")) {
        Write-Info "Publishing AM CLI from source repository '$SourcePath'..."
        & dotnet publish (Join-Path $SourcePath "src\AM.CLI\AM.CLI.csproj") -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true -o $InstallDir
    } else {
        Write-Err "Invalid -SourcePath '$SourcePath'. Expected .zip bundle, directory containing am.exe, or repository root."
        exit 1
    }
} elseif (Test-Path ".\am.exe") {
    Write-Info "Copying binaries from current working directory..."
    Copy-Item -Path ".\*" -Destination $InstallDir -Recurse -Force
} elseif (Test-Path "..\src\AM.CLI\AM.CLI.csproj") {
    Write-Info "Publishing AM CLI from local repository..."
    & dotnet publish "..\src\AM.CLI\AM.CLI.csproj" -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true -o $InstallDir
} elseif (Test-Path ".\src\AM.CLI\AM.CLI.csproj") {
    Write-Info "Publishing AM CLI from root repository..."
    & dotnet publish ".\src\AM.CLI\AM.CLI.csproj" -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true -o $InstallDir
} else {
    Write-Warn "No source binaries detected. Ensure 'am.exe' is placed in '$InstallDir'."
}

if (-not (Test-Path $amExeTarget)) {
    Write-Err "Failed to locate '$amExeTarget' after deployment."
    exit 1
}

Write-Ok "Binary deployed successfully: $amExeTarget"

# ------------------------------------------------------------------------------
# Step 4: Configure appsettings.json
# ------------------------------------------------------------------------------
$appSettingsPath = Join-Path $InstallDir "appsettings.json"
if (-not (Test-Path $appSettingsPath)) {
    Write-Info "Generating initial appsettings.json..."
    $configContent = @"
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning"
    }
  },
  "Coordinator": {
    "Endpoint": "$CoordinatorUrl",
    "TimeoutSeconds": 30
  },
  "S3": {
    "DefaultEndpoint": "http://127.0.0.1:7772"
  }
}
"@
    Set-Content -Path $appSettingsPath -Value $configContent -Encoding utf8
    Write-Ok "Configured default coordinator endpoint: $CoordinatorUrl"
}

# ------------------------------------------------------------------------------
# Step 5: Configure Environment PATH safely
# ------------------------------------------------------------------------------
$targetScope = if ($isAdmin -and -not $UserOnly.IsPresent) { [EnvironmentVariableTarget]::Machine } else { [EnvironmentVariableTarget]::User }
$existingPath = [Environment]::GetEnvironmentVariable("Path", $targetScope)

$paths = $existingPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
if ($paths -notcontains $InstallDir) {
    Write-Info "Adding '$InstallDir' to $($targetScope.ToString()) PATH..."
    $newPath = "$existingPath;$InstallDir"
    [Environment]::SetEnvironmentVariable("Path", $newPath, $targetScope)
    $env:Path = "$env:Path;$InstallDir"
    Write-Ok "PATH updated successfully."
} else {
    Write-Ok "'$InstallDir' is already present in PATH."
}

# Broadcast WM_SETTINGCHANGE to notify running shell windows without requiring reboot
try {
    Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x001A
    $SMTO_ABORTIFHUNG = 0x0002
    $result = [UIntPtr]::Zero
    [Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Environment", $SMTO_ABORTIFHUNG, 5000, [ref]$result) | Out-Null
    Write-Ok "Broadcasted environment change notification to active Windows processes."
} catch {
    Write-Warn "Unable to broadcast environment change notification: $_"
}

# ------------------------------------------------------------------------------
# Step 6: Verify Installation
# ------------------------------------------------------------------------------
Write-Info "Verifying installation..."
try {
    $versionOutput = & $amExeTarget --version
    Write-Ok "AM CLI Verified: $versionOutput"
} catch {
    Write-Warn "Could not execute '$amExeTarget --version': $_"
}

Write-Host "======================================================================" -ForegroundColor Green
Write-Host " AM CLI Installation Completed Successfully!                         " -ForegroundColor Green
Write-Host " Run 'am --help' or 'am cluster fingerprint' to begin.                " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Green
