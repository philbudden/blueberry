#!/bin/bash
# install-blueberry.sh - Install storage primitives and observability packages

set -ouex pipefail

### Install packages

# Storage primitives - disk tools, RAID, LVM, filesystem utilities
dnf5 install -y \
    cockpit-storaged \
    dosfstools \
    e2fsprogs \
    exfatprogs \
    hdparm \
    lvm2 \
    mdadm \
    smartctl \
    xfsprogs

# Observability - Performance Co-Pilot with zero-config mode
dnf5 install -y \
    pcp-zeroconf

### Enable system services

# Enable PCP services for performance monitoring
systemctl enable pmcd
systemctl enable pmlogger
