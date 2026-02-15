#!/bin/bash
# install-blueberry-k3s.sh - Install K3s binaries and dependencies

set -ouex pipefail

### K3s Version Configuration
# This version is pinned per image release
# K3s binary installation follows upstream binary distribution
K3S_VERSION="v1.31.4+k3s1"

### Install K3s Binary
# Download and install K3s from upstream GitHub releases
# K3s provides a single binary that includes server, agent, kubectl, and crictl

echo "Installing K3s ${K3S_VERSION} for aarch64..."

# Download K3s binary
curl -fsSL -o /usr/local/bin/k3s \
    "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-arm64"

# Set permissions
chmod 755 /usr/local/bin/k3s

# Verify download
/usr/local/bin/k3s --version

# Create symlinks for K3s utilities
ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
ln -sf /usr/local/bin/k3s /usr/local/bin/crictl
ln -sf /usr/local/bin/k3s /usr/local/bin/ctr

### Create K3s directories
# These directories are required for K3s operation
# Note: /var/lib/rancher/k3s is created at build time to satisfy bootc linting
#       but will be recreated at runtime by bootstrap script (since /var is mutable)

mkdir -p /etc/rancher/k3s
mkdir -p /var/lib/rancher/k3s
mkdir -p /etc/blueberry-k3s

### Record installed version
# This file tracks the K3s binary version installed in the image
# Used for version skew detection at runtime

echo "${K3S_VERSION}" > /etc/blueberry-k3s/version

### Install required kernel modules and dependencies
# K3s requires specific kernel modules for networking and storage

# iptables for K3s network policy
dnf5 install -y iptables

### Configure SELinux context
# K3s requires proper SELinux contexts for /var/lib/rancher

# Set SELinux context for K3s directories (will be applied on first boot)
semanage fcontext -a -t container_var_lib_t "/var/lib/rancher(/.*)?" || true

### Update OS release

# Tweak os-release to reflect blueberry-k3s variant
sed -i '/^PRETTY_NAME/s/(Blueberry)/(Blueberry K3s)/' /usr/lib/os-release
