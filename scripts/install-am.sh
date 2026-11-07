#!/usr/bin/env bash
# ==============================================================================
# Aarkam AM CLI — Automated Production Installation & Bootstrap Script (Linux)
# ==============================================================================
# Target OS:   Ubuntu 22.04 / 24.04 LTS, Debian 12+, RHEL / Rocky / AlmaLinux 9+
# Component:   Aarkam Distributed Control Plane CLI (am)
# Current Ver: V-1.0.0-GA
# Security:    POSIX 0700/0600 Isolation, FIPS 140-3 Zero-Trust Architecture
# ==============================================================================

set -Eeuo pipefail

# ------------------------------------------------------------------------------
# Default Configuration & Paths
# ------------------------------------------------------------------------------
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/aarkam/am"
USER_CONFIG_DIR="${HOME}/.aarkam"
COORDINATOR_URL="https://rokka-coordinator.aarkam:57774"
BINARY_SOURCE=""
USER_ONLY="false"

# ------------------------------------------------------------------------------
# Output Formatting Helpers
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat <<EOF
Usage: sudo ./install-am.sh [OPTIONS]

Automated production installer for the Aarkam Distributed Control Plane CLI (am).

Options:
  --source <path>            Path to pre-published binary, release .zip, or repository root
  --install-dir <path>       Target binary directory (default: ${INSTALL_DIR})
  --coordinator-url <url>    Default Rokka Coordinator URL (default: ${COORDINATOR_URL})
  --user-only                Install into \${HOME}/.local/bin without requiring root/sudo
  -h, --help                 Display this help message

Examples:
  # Standard Production Installation:
  sudo ./install-am.sh --source ./dist/bundles/am-v1.0.0-linux-x64.zip

  # Install from Source Repository:
  sudo ./install-am.sh --source /path/to/Aarkam.AM

  # Non-root User Installation:
  ./install-am.sh --user-only --source ./am
EOF
    exit 0
}

# ------------------------------------------------------------------------------
# Parse Command-Line Arguments
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)           BINARY_SOURCE="$2"; shift 2 ;;
        --install-dir)      INSTALL_DIR="$2"; shift 2 ;;
        --coordinator-url)  COORDINATOR_URL="$2"; shift 2 ;;
        --user-only)        USER_ONLY="true"; shift 1 ;;
        -h|--help)          usage ;;
        *)                  log_error "Unknown argument: $1"; usage ;;
    esac
done

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN} Aarkam Distributed Control Plane CLI (am) — Production Installer     ${NC}"
echo -e "${BLUE} Version: V-1.0.0-GA | Air-Gapped Sovereign Edition                   ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Normalize Coordinator URL
if [[ "$COORDINATOR_URL" != http://* && "$COORDINATOR_URL" != https://* ]]; then
    COORDINATOR_URL="https://${COORDINATOR_URL}"
fi
log_info "Default Coordinator Endpoint: ${COORDINATOR_URL}"

# ------------------------------------------------------------------------------
# Step 1: Privilege & Architecture Verification
# ------------------------------------------------------------------------------
ARCH="$(uname -m)"
if [[ "${ARCH}" != "x86_64" && "${ARCH}" != "amd64" ]]; then
    log_error "Unsupported architecture: ${ARCH}. Only x86_64 / amd64 is supported for this release."
    exit 1
fi
log_ok "Architecture verified: ${ARCH}"

if [[ "${USER_ONLY}" == "true" ]]; then
    INSTALL_DIR="${HOME}/.local/bin"
    mkdir -p "${INSTALL_DIR}"
    log_info "Installing in user space: ${INSTALL_DIR}"
else
    if [[ $EUID -ne 0 ]]; then
        log_error "Root or sudo privileges required for system-wide install. Use --user-only for non-root install."
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# Step 2: Deploy Binary
# ------------------------------------------------------------------------------
TARGET_BIN="${INSTALL_DIR}/am"

deploy_binary() {
    if [[ -n "${BINARY_SOURCE}" ]]; then
        if [[ -f "${BINARY_SOURCE}" && "${BINARY_SOURCE}" == *.zip ]]; then
            log_info "Unpacking release archive '${BINARY_SOURCE}'..."
            TMP_DIR="$(mktemp -d)"
            unzip -q "${BINARY_SOURCE}" -d "${TMP_DIR}"
            if [[ -f "${TMP_DIR}/am" ]]; then
                cp "${TMP_DIR}/am" "${TARGET_BIN}"
            elif [[ -f "${TMP_DIR}/am.exe" ]]; then
                log_error "The specified zip archive contains Windows binaries (am.exe). Please supply the Linux bundle."
                rm -rf "${TMP_DIR}"
                exit 1
            fi
            rm -rf "${TMP_DIR}"
        elif [[ -f "${BINARY_SOURCE}/am" ]]; then
            log_info "Copying pre-published binary from '${BINARY_SOURCE}/am'..."
            cp "${BINARY_SOURCE}/am" "${TARGET_BIN}"
        elif [[ -f "${BINARY_SOURCE}" && $(basename "${BINARY_SOURCE}") == "am" ]]; then
            log_info "Copying binary '${BINARY_SOURCE}'..."
            cp "${BINARY_SOURCE}" "${TARGET_BIN}"
        elif [[ -f "${BINARY_SOURCE}/src/AM.CLI/AM.CLI.csproj" ]]; then
            log_info "Publishing AM CLI from source '${BINARY_SOURCE}'..."
            dotnet publish "${BINARY_SOURCE}/src/AM.CLI/AM.CLI.csproj" \
                -c Release \
                -r linux-x64 \
                --self-contained true \
                /p:PublishSingleFile=true \
                /p:IncludeNativeLibrariesForSelfExtract=true \
                -o /tmp/am_publish
            cp /tmp/am_publish/am "${TARGET_BIN}"
            rm -rf /tmp/am_publish
        else
            log_error "Invalid --source '${BINARY_SOURCE}'. Expected .zip bundle, directory containing am, or repository root."
            exit 1
        fi
    elif [[ -f "./am" ]]; then
        log_info "Copying binary from current directory..."
        cp "./am" "${TARGET_BIN}"
    elif [[ -f "./src/AM.CLI/AM.CLI.csproj" ]]; then
        log_info "Publishing AM CLI from local repository..."
        dotnet publish "./src/AM.CLI/AM.CLI.csproj" \
            -c Release \
            -r linux-x64 \
            --self-contained true \
            /p:PublishSingleFile=true \
            /p:IncludeNativeLibrariesForSelfExtract=true \
            -o /tmp/am_publish
        cp /tmp/am_publish/am "${TARGET_BIN}"
        rm -rf /tmp/am_publish
    else
        log_error "No binary source specified. Pass --source <path> to install."
        exit 1
    fi

    chmod 0755 "${TARGET_BIN}"
    log_ok "Binary installed at ${TARGET_BIN} (permissions 0755)."
}

deploy_binary

# ------------------------------------------------------------------------------
# Step 3: Setup User Credentials Directory
# ------------------------------------------------------------------------------
mkdir -p "${USER_CONFIG_DIR}"
chmod 0700 "${USER_CONFIG_DIR}"
log_ok "Secure credentials directory configured: ${USER_CONFIG_DIR} (mode 0700)."

# ------------------------------------------------------------------------------
# Step 4: Setup Global Configuration
# ------------------------------------------------------------------------------
if [[ "${USER_ONLY}" != "true" ]]; then
    mkdir -p "${CONFIG_DIR}"
    if [[ ! -f "${CONFIG_DIR}/appsettings.json" ]]; then
        cat > "${CONFIG_DIR}/appsettings.json" <<EOF
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning"
    }
  },
  "Coordinator": {
    "Endpoint": "${COORDINATOR_URL}",
    "TimeoutSeconds": 30
  },
  "S3": {
    "DefaultEndpoint": "http://127.0.0.1:7772"
  }
}
EOF
        chmod 0644 "${CONFIG_DIR}/appsettings.json"
        log_ok "Global configuration created at ${CONFIG_DIR}/appsettings.json."
    fi
fi

# ------------------------------------------------------------------------------
# Step 5: Verify Installation
# ------------------------------------------------------------------------------
log_info "Verifying AM CLI execution..."
if "${TARGET_BIN}" --version >/dev/null 2>&1; then
    VER="$("${TARGET_BIN}" --version | tail -n 1)"
    log_ok "Verification successful: ${VER}"
else
    log_warn "Binary installed but failed execution test. Check execute permissions and OS compatibility."
fi

echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN} AM CLI Installation Completed Successfully!                         ${NC}"
echo -e "${CYAN} Run 'am --help' or 'am cluster fingerprint' to begin.                ${NC}"
echo -e "${GREEN}======================================================================${NC}"
