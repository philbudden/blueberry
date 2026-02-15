#!/bin/bash
# install-flux.sh - Install FluxCD CLI binaries

set -ouex pipefail

### FluxCD Version Configuration
# Pinned version per image release
# FluxCD provides GitOps automation for Kubernetes
FLUX_VERSION="v2.4.0"

### Install FluxCD CLI Binary
# Download and install flux CLI from upstream GitHub releases
# The flux CLI is used to bootstrap and manage FluxCD on K3s clusters

echo "Installing FluxCD ${FLUX_VERSION} for aarch64..."

# Download flux CLI binary
curl -fsSL "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/flux_${FLUX_VERSION#v}_linux_arm64.tar.gz" \
    | tar xz -C /usr/local/bin flux

# Set permissions
chmod 755 /usr/local/bin/flux

# Verify installation
/usr/local/bin/flux --version

### Record installed version
# This file tracks the FluxCD CLI version installed in the image
mkdir -p /etc/blueberry-k3s
echo "${FLUX_VERSION}" > /etc/blueberry-k3s/flux-version

echo "FluxCD ${FLUX_VERSION} installed successfully"
