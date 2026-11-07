<#
.SYNOPSIS
    Builds, tests, and publishes the Aarkam AM CLI Docker image to Docker Hub using Release Artifacts.

.DESCRIPTION
    Packages the pre-compiled, self-contained native Linux release artifacts from V-$Version/linux (or dist/linux)
    into a production-hardened container for the Aarkam AM CLI utility.

.PARAMETER DockerOrg
    The Docker Hub organization or username (defaults to 'aarkam').

.PARAMETER Version
    The release version tag (defaults to '1.0.2').

.PARAMETER Push
    When specified, pushes the built tags to Docker Hub.

.PARAMETER Test
    When specified, runs a test container to verify binary execution and help output.

.EXAMPLE
    .\scripts\publish-docker.ps1
    .\scripts\publish-docker.ps1 -Test
    .\scripts\publish-docker.ps1 -Push
    .\scripts\publish-docker.ps1 -DockerOrg "mycompany" -Push
#>
[CmdletBinding()]
param(
    [string]$DockerOrg = "aarkam",
    [string]$Version = "1.0.2",
    [switch]$Push,
    [switch]$Test
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent $ScriptDir
Set-Location $RepoRoot

$ImageName = "$DockerOrg/aarkam.am"
$TagV = "${ImageName}:v${Version}"
$TagNum = "${ImageName}:${Version}"
$TagLatest = "${ImageName}:latest"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Aarkam AM CLI v${Version} Docker Hub Build & Publish" -ForegroundColor Cyan
Write-Host " Image: $ImageName" -ForegroundColor Cyan
Write-Host " Tags:  v${Version}, ${Version}, latest" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Ensure staging payload exists
$distLinux = Join-Path $RepoRoot "dist\linux\am"
if (-not (Test-Path $distLinux)) {
    $candidatePayloadPaths = @(
        (Join-Path $RepoRoot "V-$Version\linux"),
        (Join-Path $RepoRoot "dist\linux")
    )
    $releaseLinux = $candidatePayloadPaths | Where-Object { Test-Path (Join-Path $_ "am") } | Select-Object -First 1
    if ($releaseLinux) {
        Write-Host "Staging release payload from $releaseLinux into dist/linux..." -ForegroundColor Yellow
        $targetDist = Join-Path $RepoRoot "dist\linux"
        New-Item -ItemType Directory -Path $targetDist -Force | Out-Null
        Copy-Item -Path "$releaseLinux\*" -Destination $targetDist -Recurse -Force
    } else {
        $candidateZips = @(
            (Join-Path $RepoRoot "V-$Version\am-v$Version-linux-x64.zip"),
            (Join-Path $RepoRoot "am-v$Version-linux-x64.zip")
        )
        $zipFound = $candidateZips | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($zipFound) {
            Write-Host "Inflating release payload from $zipFound into dist/linux..." -ForegroundColor Yellow
            $targetDist = Join-Path $RepoRoot "dist\linux"
            New-Item -ItemType Directory -Path $targetDist -Force | Out-Null
            Expand-Archive -Path $zipFound -DestinationPath $targetDist -Force
        } else {
            throw "Missing Linux release binary at $distLinux. Please stage release artifacts for V-$Version."
        }
    }
}

# 2. Check Docker availability
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "The 'docker' command line tool was not found on PATH. Please ensure Docker Desktop is running."
}

# 3. Build Docker Image
Write-Host "`n[1/3] Building Docker image: $TagV..." -ForegroundColor Green
docker build -f Dockerfile.release `
    -t $TagV `
    -t $TagNum `
    -t $TagLatest `
    .

if ($LASTEXITCODE -ne 0) {
    throw "Docker build failed with exit code $LASTEXITCODE."
}
Write-Host "Docker build completed successfully." -ForegroundColor Green

# 4. Optional Local Health Test
if ($Test) {
    Write-Host "`n[2/3] Testing container execution..." -ForegroundColor Green
    docker run --rm $TagV --help
}

# 5. Push to Docker Hub
if ($Push) {
    Write-Host "`n[3/3] Pushing images to Docker Hub..." -ForegroundColor Green
    docker push $TagV
    docker push $TagNum
    docker push $TagLatest

    Write-Host "`nAll tags pushed successfully to Docker Hub:" -ForegroundColor Cyan
    Write-Host " - $TagV" -ForegroundColor Cyan
    Write-Host " - $TagNum" -ForegroundColor Cyan
    Write-Host " - $TagLatest" -ForegroundColor Cyan
} else {
    Write-Host "`nBuild complete. Run with -Push to publish to Docker Hub:" -ForegroundColor Yellow
    Write-Host "  .\scripts\publish-docker.ps1 -Push" -ForegroundColor Yellow
}
