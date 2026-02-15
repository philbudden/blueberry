#!/usr/bin/env bash
# Test building a Blueberry image variant locally
# Usage: ./scripts/test-build.sh <variant> [tag]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

VARIANT="${1:-}"
TAG="${2:-test}"
FEDORA_VERSION="${FEDORA_VERSION:-44}"
ARCH="${ARCH:-aarch64}"

VALID_VARIANTS=("blueberry-minimal" "blueberry")

if [ -z "${VARIANT}" ]; then
    echo "Usage: $0 <variant> [tag]"
    echo ""
    echo "Valid variants:"
    printf "  - %s\n" "${VALID_VARIANTS[@]}"
    exit 1
fi

# Validate variant
if [[ ! " ${VALID_VARIANTS[*]} " =~ ${VARIANT} ]]; then
    echo "ERROR: Invalid variant '${VARIANT}'"
    echo "Valid variants: ${VALID_VARIANTS[*]}"
    exit 1
fi

if [ ! -f "${VARIANT}/Containerfile" ]; then
    echo "ERROR: Containerfile not found: ${VARIANT}/Containerfile"
    exit 1
fi

echo "=== Testing build: ${VARIANT} ==="
echo "Tag: ${TAG}"
echo "Fedora Version: ${FEDORA_VERSION}"
echo "Architecture: ${ARCH}"
echo ""

# Determine build tool (prefer docker if available, fallback to buildah)
BUILD_CMD=""
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    BUILD_CMD="docker"
    echo "Using: docker"
elif command -v buildah &>/dev/null; then
    BUILD_CMD="buildah"
    echo "Using: buildah"
else
    echo "ERROR: Neither docker nor buildah available"
    exit 1
fi
echo ""

# Build arguments
BUILD_ARGS=(
    "--build-arg" "FEDORA_VERSION=${FEDORA_VERSION}"
    "--build-arg" "ARCH=${ARCH}"
    "--tag" "localhost/${VARIANT}:${TAG}"
    "--file" "${VARIANT}/Containerfile"
)

# Platform flag (Docker only)
if [ "${BUILD_CMD}" = "docker" ]; then
    BUILD_ARGS+=("--platform" "linux/${ARCH}")
fi

# Context directory
CONTEXT_DIR="${VARIANT}"

# Special handling for blueberry (depends on blueberry-minimal)
if [ "${VARIANT}" = "blueberry" ]; then
    echo "→ Checking for blueberry-minimal base image..."
    
    # Try to pull from registry, or build locally
    BASE_IMAGE="ghcr.io/philbudden/blueberry-minimal:${FEDORA_VERSION}"
    LOCAL_IMAGE="localhost/blueberry-minimal:${TAG}"
    
    if ! ${BUILD_CMD} pull "${BASE_IMAGE}" 2>/dev/null; then
        echo "  Base image not in registry, checking local..."
        
        if ! ${BUILD_CMD} inspect "${LOCAL_IMAGE}" &>/dev/null; then
            echo "  Building blueberry-minimal first..."
            "$0" blueberry-minimal "${TAG}"
        fi
        
        # Tag local image to match Containerfile expectation
        ${BUILD_CMD} tag "${LOCAL_IMAGE}" "${BASE_IMAGE}" 2>/dev/null || true
    fi
    
    BUILD_ARGS+=("--build-arg" "IMAGE_REGISTRY=ghcr.io/philbudden")
    echo ""
fi

# Execute build
echo "→ Building ${VARIANT}..."
echo "Command: ${BUILD_CMD} build ${BUILD_ARGS[*]} ${CONTEXT_DIR}"
echo ""

if ${BUILD_CMD} build "${BUILD_ARGS[@]}" "${CONTEXT_DIR}"; then
    echo ""
    echo "✓ Build successful: localhost/${VARIANT}:${TAG}"
    
    # Show image info
    echo ""
    echo "Image details:"
    ${BUILD_CMD} inspect "localhost/${VARIANT}:${TAG}" | grep -E '(Created|Architecture|Os):' || true
else
    echo ""
    echo "✗ Build failed"
    exit 1
fi
