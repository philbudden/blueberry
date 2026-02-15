#!/bin/bash
# install-blueberry.sh - Install storage primitives and observability packages

set -ouex pipefail

### Install packages

# Storage Primitives
# - Disk health monitoring and management
# - Software RAID for multi-disk resilience
# - Cockpit storage management interface
dnf5 install -y \
    cockpit-storaged \
    hdparm \
    mdadm \
    smartmontools

# Observability
# - Performance Co-Pilot for system monitoring
dnf5 install -y \
    pcp-zeroconf

### Configure services

# Enable PCP services for performance monitoring
systemctl enable pmcd
systemctl enable pmlogger

### Update OS release

# Tweak os-release to reflect blueberry variant
sed -i '/^PRETTY_NAME/s/(Blueberry Minimal)/(Blueberry)/' /usr/lib/os-release
