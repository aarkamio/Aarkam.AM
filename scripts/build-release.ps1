<#
.SYNOPSIS
    Aarkam AM CLI — Standalone Release Build & Packaging Automation Script.

.DESCRIPTION
    Compiles, publishes, and packages standalone, single-file distribution bundles for:
    - Windows x64: dist/bundles/am-v1.0.0-win-x64.zip
    - Linux x64:   dist/bundles/am-v1.0.0-linux-x64.zip
    Also generates cryptographic SHA-256 manifests in dist/bundles/SHA256SUMS.txt.
#>

[CmdletBinding()]
param(
    [string]$Version = "1.0.2",
    [string]$ReleaseTag = "v1.0.2",
    [string]$Framework = "net10.0"
)

$ErrorActionPreference = "Stop"

function Write-Info  { param([string]$Message) Write-Host "[INFO]  $Message" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Message) Write-Host "[OK]    $Message" -ForegroundColor Green }
function Write-Err   { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot "..")
$CliProj = Join-Path $RepoRoot "src\AM.CLI\AM.CLI.csproj"
$DistDir = Join-Path $RepoRoot "dist"
$BundlesDir = Join-Path $DistDir "bundles"
$StagingWin = Join-Path $DistDir "staging\win-x64"
$StagingLinux = Join-Path $DistDir "staging\linux-x64"

Write-Host "======================================================================" -ForegroundColor Blue
Write-Host " Aarkam AM CLI — Standalone Production Release Packager                " -ForegroundColor Cyan
Write-Host " Version: V-$Version ($ReleaseTag)                                     " -ForegroundColor Blue
Write-Host "======================================================================" -ForegroundColor Blue

# Clean staging directories
foreach ($dir in @($StagingWin, $StagingLinux)) {
    if (Test-Path $dir) {
        Remove-Item -Path $dir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

if (-not (Test-Path $BundlesDir)) {
    New-Item -ItemType Directory -Path $BundlesDir -Force | Out-Null
}

$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"

# ------------------------------------------------------------------------------
# 1. Build & Publish Standalone Windows x64 Binary
# ------------------------------------------------------------------------------
Write-Info "Compiling standalone single-file binary for Windows (win-x64, $Framework)..."
& dotnet publish $CliProj -f $Framework -c Release -r win-x64 --self-contained true `
    /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true `
    /p:Version=$Version /p:InformationalVersion="V-$Version" -o $StagingWin

if (-not (Test-Path (Join-Path $StagingWin "am.exe"))) {
    Write-Err "Windows binary publish failed: am.exe not found."
    exit 1
}
Write-Ok "Windows publish succeeded."

# ------------------------------------------------------------------------------
# 2. Build & Publish Standalone Linux x64 Binary
# ------------------------------------------------------------------------------
Write-Info "Compiling standalone single-file binary for Linux (linux-x64, $Framework)..."
& dotnet publish $CliProj -f $Framework -c Release -r linux-x64 --self-contained true `
    /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true `
    /p:Version=$Version /p:InformationalVersion="V-$Version" -o $StagingLinux

if (-not (Test-Path (Join-Path $StagingLinux "am"))) {
    Write-Err "Linux binary publish failed: am not found."
    exit 1
}
Write-Ok "Linux publish succeeded."

# ------------------------------------------------------------------------------
# 3. Stage Companion Files
# ------------------------------------------------------------------------------
$companionFiles = @(
    (Join-Path $RepoRoot "LICENSE"),
    (Join-Path $DistDir "INSTALLATION_GUIDE.md"),
    (Join-Path $DistDir "RELEASE_NOTES.md")
)

foreach ($targetDir in @($StagingWin, $StagingLinux)) {
    foreach ($file in $companionFiles) {
        if (Test-Path $file) {
            Copy-Item -Path $file -Destination $targetDir -Force
        }
    }
    # Ensure appsettings.json exists
    $defaultSettings = Join-Path $RepoRoot "src\AM.CLI\appsettings.json"
    if (Test-Path $defaultSettings) {
        Copy-Item -Path $defaultSettings -Destination (Join-Path $targetDir "appsettings.json") -Force
    }
}

# ------------------------------------------------------------------------------
# 4. Create Release Bundles
# ------------------------------------------------------------------------------
$winZipName = "am-v$Version-win-x64.zip"
$linuxZipName = "am-v$Version-linux-x64.zip"

$winZipPath = Join-Path $BundlesDir $winZipName
$linuxZipPath = Join-Path $BundlesDir $linuxZipName

if (Test-Path $winZipPath) { Remove-Item $winZipPath -Force }
if (Test-Path $linuxZipPath) { Remove-Item $linuxZipPath -Force }

Write-Info "Creating $winZipName..."
Compress-Archive -Path "$StagingWin\*" -DestinationPath $winZipPath -CompressionLevel Optimal
Write-Ok "Created: $winZipPath ($((Get-Item $winZipPath).Length / 1MB | ForEach-Object { [math]::Round($_, 2) }) MB)"

Write-Info "Creating $linuxZipName..."
Compress-Archive -Path "$StagingLinux\*" -DestinationPath $linuxZipPath -CompressionLevel Optimal
Write-Ok "Created: $linuxZipPath ($((Get-Item $linuxZipPath).Length / 1MB | ForEach-Object { [math]::Round($_, 2) }) MB)"

# ------------------------------------------------------------------------------
# 5. Generate SHA-256 Manifest
# ------------------------------------------------------------------------------
Write-Info "Generating SHA-256 integrity checksums..."
$checksums = @()
foreach ($zipFile in @($winZipPath, $linuxZipPath)) {
    $hash = (Get-FileHash -Path $zipFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $name = Split-Path -Leaf $zipFile
    $checksums += "$hash  $name"
}

$checksumPath = Join-Path $BundlesDir "SHA256SUMS.txt"
Set-Content -Path $checksumPath -Value $checksums -Encoding utf8
Write-Ok "Checksum manifest written: $checksumPath"
Get-Content $checksumPath | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }

# ------------------------------------------------------------------------------
# 6. Mirror to Aarkam.IO Releases Directory
# ------------------------------------------------------------------------------
$externalReleasesDir = Join-Path $RepoRoot "..\Aarkam.IO\Releases\Am-Cli\V-$Version"
if (Test-Path (Join-Path $RepoRoot "..\Aarkam.IO\Releases")) {
    Write-Info "Mirroring release artifacts to Aarkam.IO ($externalReleasesDir)..."
    if (-not (Test-Path $externalReleasesDir)) {
        New-Item -ItemType Directory -Path $externalReleasesDir -Force | Out-Null
    }
    
    # Copy bundle archives and checksums
    Copy-Item -Path (Join-Path $BundlesDir "*") -Destination $externalReleasesDir -Force -Recurse
    
    # Mirror uncompressed staging trees for reference
    $targetLinux = Join-Path $externalReleasesDir "linux"
    $targetWin = Join-Path $externalReleasesDir "win"
    if (-not (Test-Path $targetLinux)) { New-Item -ItemType Directory -Path $targetLinux -Force | Out-Null }
    if (-not (Test-Path $targetWin)) { New-Item -ItemType Directory -Path $targetWin -Force | Out-Null }
    
    Copy-Item -Path "$StagingLinux\*" -Destination $targetLinux -Force -Recurse
    Copy-Item -Path "$StagingWin\*" -Destination $targetWin -Force -Recurse
    
    # Mirror companion docs
    foreach ($doc in @("INSTALLATION_GUIDE.md", "RELEASE_NOTES.md", "DOCKER_README.md")) {
        $docPath = Join-Path $DistDir $doc
        if (Test-Path $docPath) {
            Copy-Item -Path $docPath -Destination $externalReleasesDir -Force
        }
    }
    Write-Ok "Mirroring to Aarkam.IO completed."
}

# ------------------------------------------------------------------------------
# 7. Preserve Linux staging for container build (dist/linux)
# ------------------------------------------------------------------------------
$distLinux = Join-Path $DistDir "linux"
if (Test-Path $distLinux) { Remove-Item -Path $distLinux -Recurse -Force }
New-Item -ItemType Directory -Path $distLinux -Force | Out-Null
Copy-Item -Path "$StagingLinux\*" -Destination $distLinux -Force -Recurse

# Cleanup temporary staging directory
Remove-Item -Path (Join-Path $DistDir "staging") -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "======================================================================" -ForegroundColor Green
Write-Host " Standalone AM Release Packaging Complete!                            " -ForegroundColor Green
Write-Host " Distribution artifacts available in: $BundlesDir                     " -ForegroundColor Cyan
Write-Host " Docker payload staged in: $distLinux                                 " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Green
