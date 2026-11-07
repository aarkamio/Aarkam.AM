#!/usr/bin/env bash
# ==============================================================================
# Aarkam AM CLI — Standalone Release Build & Packaging Automation Script (Linux)
# ==============================================================================

set -Eeuo pipefail

VERSION="${1:-1.0.2}"
FRAMEWORK="${2:-net10.0}"
RELEASE_TAG="v${VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLI_PROJ="${REPO_ROOT}/src/AM.CLI/AM.CLI.csproj"
DIST_DIR="${REPO_ROOT}/dist"
BUNDLES_DIR="${DIST_DIR}/bundles"
STAGING_WIN="${DIST_DIR}/staging/win-x64"
STAGING_LINUX="${DIST_DIR}/staging/linux-x64"

export DOTNET_CLI_TELEMETRY_OPTOUT=1

echo "======================================================================"
echo " Aarkam AM CLI — Standalone Production Release Packager"
echo " Version: V-${VERSION} (${RELEASE_TAG}) [${FRAMEWORK}]"
echo "======================================================================"

rm -rf "${DIST_DIR}/staging"
mkdir -p "${BUNDLES_DIR}" "${STAGING_WIN}" "${STAGING_LINUX}"

# 1. Publish Windows x64
echo "[INFO]  Publishing Windows x64 standalone binary..."
dotnet publish "${CLI_PROJ}" -f "${FRAMEWORK}" -c Release -r win-x64 --self-contained true \
    /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true \
    /p:Version="${VERSION}" /p:InformationalVersion="V-${VERSION}" -o "${STAGING_WIN}"

# 2. Publish Linux x64
echo "[INFO]  Publishing Linux x64 standalone binary..."
dotnet publish "${CLI_PROJ}" -f "${FRAMEWORK}" -c Release -r linux-x64 --self-contained true \
    /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true \
    /p:Version="${VERSION}" /p:InformationalVersion="V-${VERSION}" -o "${STAGING_LINUX}"

# 3. Stage companion files
for target in "${STAGING_WIN}" "${STAGING_LINUX}"; do
    cp "${REPO_ROOT}/LICENSE" "${target}/"
    cp "${DIST_DIR}/INSTALLATION_GUIDE.md" "${target}/"
    cp "${DIST_DIR}/RELEASE_NOTES.md" "${target}/"
    cp "${REPO_ROOT}/src/AM.CLI/appsettings.json" "${target}/"
done

# 4. Create ZIP bundles
WIN_ZIP="am-v${VERSION}-win-x64.zip"
LINUX_ZIP="am-v${VERSION}-linux-x64.zip"

echo "[INFO]  Creating ${WIN_ZIP}..."
(cd "${STAGING_WIN}" && zip -9 -r "${BUNDLES_DIR}/${WIN_ZIP}" .)

echo "[INFO]  Creating ${LINUX_ZIP}..."
(cd "${STAGING_LINUX}" && zip -9 -r "${BUNDLES_DIR}/${LINUX_ZIP}" .)

# 5. Checksums
echo "[INFO]  Generating SHA-256 manifest..."
(cd "${BUNDLES_DIR}" && sha256sum "${WIN_ZIP}" "${LINUX_ZIP}" > "SHA256SUMS.txt")

rm -rf "${DIST_DIR}/staging"

echo "======================================================================"
echo " Standalone AM Release Packaging Complete!"
cat "${BUNDLES_DIR}/SHA256SUMS.txt"
echo "======================================================================"
