#!/bin/bash
# install-blueberry-minimal.sh - Install Blueberry Minimal packages and enable services

set -ouex pipefail

### Install packages

# Install core packages from Fedora repos
dnf5 install -y \
    git \
    cockpit-networkmanager \
    cockpit-podman \
    cockpit-selinux \
    cockpit-system \
    firewalld \
    glibc-langpack-en \
    open-vm-tools \
    podman \
    podman-compose \
    qemu-guest-agent \
    tmux \
    wireguard-tools

# Install Tailscale from upstream repo
dnf5 -y config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf5 -y install tailscale
# Remove repo file to keep image clean
rm /etc/yum.repos.d/tailscale.repo

### Configure firewall

# Switch to server profile to allow cockpit by default
cp -a /etc/firewalld/firewalld-server.conf /etc/firewalld/firewalld.conf

### Enable system services

# Enable containerized Cockpit web interface
systemctl enable cockpit.service

# Enable Tailscale VPN
systemctl enable tailscaled

# Enable automatic system updates (staged)
systemctl enable rpm-ostreed-automatic.timer

# Enable Podman socket for API access
systemctl enable podman.socket
