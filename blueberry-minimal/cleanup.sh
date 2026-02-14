#!/bin/bash
# cleanup.sh - Clean up image layers to reduce size

set -ouex pipefail

# Cleanup temporary files
rm -rf /tmp/* /var/tmp/*

# Note: Package manager caches are handled by cache mounts in Containerfile
