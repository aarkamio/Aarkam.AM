#!/usr/bin/env bash
# ==============================================================================
# Aarkam AM CLI — Docker Build and Publish Script (Linux/macOS)
# ==============================================================================

set -Eeuo pipefail

VERSION="${1:-1.0.2}"
IMAGE_REPO="${2:-aarkam/aarkam.am}"
PUSH="${3:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "======================================================================"
echo " Building Docker image: ${IMAGE_REPO}:v${VERSION}"
echo "======================================================================"

docker build \
    -t "${IMAGE_REPO}:v${VERSION}" \
    -t "${IMAGE_REPO}:${VERSION}" \
    -t "${IMAGE_REPO}:latest" \
    -f "${REPO_ROOT}/Dockerfile.release" \
    "${REPO_ROOT}"

echo "[OK] Docker image built successfully."

if [ "${PUSH}" = "true" ] || [ "${PUSH}" = "--push" ]; then
    echo "[INFO] Pushing image tags to Docker Hub..."
    docker push "${IMAGE_REPO}:v${VERSION}"
    docker push "${IMAGE_REPO}:${VERSION}"
    docker push "${IMAGE_REPO}:latest"
    echo "[OK] Push complete: https://hub.docker.com/r/${IMAGE_REPO}"
fi
