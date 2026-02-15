#!/bin/bash
# cleanup.sh - Clean up image to reduce size

set -ouex pipefail

# Remove package manager caches
dnf5 clean all

# Remove temporary files
rm -rf /tmp/* /var/tmp/*

# Remove dnf logs and history
rm -rf /var/log/dnf*
rm -rf /var/lib/dnf/history*
