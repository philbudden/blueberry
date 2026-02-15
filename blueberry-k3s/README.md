# Blueberry K3s

Lightweight Kubernetes node image for aarch64 SBCs, built on Blueberry.

## Overview

`blueberry-k3s` provides a controlled, disciplined K3s environment suitable for:
- Edge Kubernetes workloads
- Learning Kubernetes on SBC hardware
- Lightweight container orchestration
- Single-node or small cluster deployments
- GitOps-driven infrastructure management

This image inherits all capabilities from `blueberry` (storage primitives, observability) and adds K3s with explicit lifecycle management.

## Included Components

### K3s
- **Current version**: v1.31.4+k3s1
- **Installation method**: Binary distribution from GitHub releases
- **Version pinning**: Explicit per image release
- **Components**: k3s, kubectl, crictl, ctr (single binary)

### FluxCD
- **Current version**: v2.4.0
- **Installation method**: Binary distribution from GitHub releases
- **Version pinning**: Explicit per image release
- **Purpose**: GitOps automation and continuous reconciliation

## Architecture

### Default State

- K3s binaries installed but **disabled by default**
- No automatic cluster initialization
- No background services running
- User must explicitly choose server or agent mode

### Bootstrap Mechanism

K3s initialization is performed via `ujust` commands:

- `ujust k3s-init-server` - Initialize as server (control plane)
- `ujust k3s-init-agent` - Initialize as agent (worker node)

Bootstrap script (`/usr/local/bin/blueberry-k3s-bootstrap`):
- Validates prerequisites
- Checks version compatibility
- Creates systemd configuration
- Enables and starts appropriate service
- Records state version for lifecycle tracking

### Version Tracking

Two version markers exist:

1. **Binary version** (`/etc/blueberry-k3s/version`)
   - Immutable (part of image)
   - Updated only via image upgrades
   - Reflects K3s binaries in `/usr/local/bin/k3s`

2. **State version** (`/var/lib/rancher/k3s/.version`)
   - Mutable (persists in /var)
   - Created during initialization
   - Reflects K3s state schema in `/var/lib/rancher/k3s`

### Version Compatibility

Before starting K3s, systemd units run `/usr/local/bin/blueberry-k3s-version-check`:

- If no state version exists → first-time init, allow startup
- If state version exists → compare with binary version
- If versions match → allow startup
- If versions mismatch → **refuse startup** (prevents corruption)

This prevents:
- Starting older K3s binaries against newer state (after rollback)
- Starting newer K3s binaries against older state (before explicit upgrade)

## Lifecycle Management

### Initial Installation

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/philbudden/blueberry-k3s:latest
systemctl reboot
```

### Bootstrap (Server Mode)

```bash
ujust k3s-init-server
```

This will:
1. Verify K3s is not already initialized
2. Create K3s configuration
3. Record state version
4. Enable k3s-server.service
5. Start K3s server
6. Display status and kubeconfig location

### Bootstrap (Agent Mode)

```bash
ujust k3s-init-agent
```

You will be prompted for:
- Server URL (e.g., `https://192.168.1.100:6443`)
- Server token (obtained from server via `ujust k3s-get-token`)

This will:
1. Verify K3s is not already initialized
2. Create K3s agent configuration
3. Record state version
4. Enable k3s-agent.service
5. Start K3s agent
6. Display status

### Image Upgrades

When a new blueberry-k3s image is released with a newer K3s version:

```bash
rpm-ostree upgrade
systemctl reboot
```

**After reboot:**
- K3s will detect version mismatch (binary newer than state)
- K3s services will refuse to start
- Operator must explicitly upgrade (mechanism TBD)

**Current limitation**: In-place state migration not yet implemented.

### Rollback

If you need to rollback to a previous image:

```bash
rpm-ostree rollback
systemctl reboot
```

**After rollback:**
- K3s will detect version mismatch (binary older than state)
- K3s services will refuse to start
- Resolution options:
  1. Roll forward: `rpm-ostree upgrade && systemctl reboot`
  2. Reset K3s: `ujust k3s-reset` (destructive, wipes all state)

### Reset (Destructive)

To completely remove K3s and start fresh:

```bash
ujust k3s-reset
```

This will:
- Stop K3s services
- Disable K3s services
- Delete all K3s state (`/var/lib/rancher/k3s`)
- Delete all K3s configuration (`/etc/rancher/k3s`)
- Remove all Kubernetes workloads and volumes

After reset, you can reinitialize with `ujust k3s-init-server` or `ujust k3s-init-agent`.

## Monitoring & Status

```bash
# K3s Commands
ujust k3s-status          # Service status, cluster info
ujust k3s-version         # Binary and state versions
ujust k3s-logs            # Follow K3s logs
ujust k3s-get-token       # Get server token (server only)
ujust k3s-kubeconfig-user # Enable kubectl without sudo

# FluxCD Commands
ujust flux-status      # Check FluxCD installation
ujust flux-version     # Show FluxCD CLI version
```

## GitOps with FluxCD

### Overview

FluxCD is pre-installed (CLI only) for GitOps automation. Bootstrap is explicit and user-controlled.

### Prerequisites

1. K3s server running (`ujust k3s-init-server`)
2. GitHub repository (will be created if it doesn't exist)
3. GitHub personal access token with `repo` scope

### Bootstrap FluxCD

```bash
# Create GitHub token file (root-readable location recommended)
sudo mkdir -p /etc/blueberry-k3s/secrets
echo 'ghp_your_token_here' | sudo tee /etc/blueberry-k3s/secrets/github-token
sudo chmod 600 /etc/blueberry-k3s/secrets/github-token

# Bootstrap FluxCD (interactive)
ujust flux-bootstrap-github
```

**Token File Locations**:
- **Recommended**: `/etc/blueberry-k3s/secrets/github-token` (root-readable, survives user changes)
- **Alternative**: `~/.github-token` (user home directory)

**Important**: The bootstrap script runs with `sudo` to access the K3s kubeconfig (`/etc/rancher/k3s/k3s.yaml`). Ensure the token file is readable by root.

During bootstrap, you'll provide:
- GitHub owner (username or organization)
- Repository name
- Token file path (defaults to `~/.github-token`)

### What Bootstrap Does

1. Validates K3s is running
2. Runs pre-flight checks
3. Installs FluxCD controllers to K3s cluster
4. Creates/updates GitHub repository with manifests
5. Configures continuous reconciliation

### Post-Bootstrap

After bootstrapping, FluxCD will:
- Continuously monitor the GitHub repository
- Automatically apply manifest changes
- Self-update when Flux manifests change
- Reconcile cluster state with Git

Check status:
```bash
ujust flux-status
kubectl get pods -n flux-system
flux get sources git
flux get kustomizations
```

### Repository Structure

FluxCD creates this structure in your repository:

```
fleet-infra/
└── clusters/
    └── blueberry/
        └── flux-system/
            ├── gotk-components.yaml
            ├── gotk-sync.yaml
            └── kustomization.yaml
```

Add your manifests alongside `flux-system/`:

```
fleet-infra/
└── clusters/
    └── blueberry/
        ├── flux-system/
        ├── apps/
        │   └── my-app.yaml
        └── infrastructure/
            └── storage.yaml
```

### Version Tracking

- FluxCD CLI version: `/etc/blueberry-k3s/flux-version` (immutable)
- FluxCD controllers version: Managed by Flux itself (self-updating)

### Uninstalling FluxCD

```bash
flux uninstall
```

This removes FluxCD from the cluster but does not affect the GitHub repository.

## Design Constraints

Per AGENTS.md and project requirements:

### Hard Rules

- K3s disabled by default ✓
- No automatic cluster initialization ✓
- User must explicitly choose server or agent mode ✓
- No HA assumptions ✓
- K3s version pinned per image release ✓
- Version skew detection ✓
- Rollback-aware ✓

### GitOps Rules

- FluxCD CLI pre-installed ✓
- Bootstrap is explicit, not automatic ✓
- FluxCD version pinned per image release ✓
- GitHub token from file (not CLI arguments) ✓
- K3s dependency validated before bootstrap ✓

### Single-Node Focus

This image is designed for single-node or small cluster deployments:
- No embedded etcd clustering by default
- No high availability assumptions
- No datacenter-scale features
- Suitable for 4-8GB RAM SBCs
- USB storage assumptions

### SBC Realism

Appropriate for:
- Raspberry Pi 4 (4-8GB)
- Similar aarch64 SBCs
- USB3 storage
- Limited cooling
- Home lab / edge environments

Not appropriate for:
- Production datacenter workloads
- High availability requirements
- Rack-scale clusters
- Mission-critical services

## Known Limitations

1. **In-place upgrades**: Not yet implemented. Upgrading K3s requires reset.
2. **Downgrade safety**: Requires destructive reset.
3. **State migration**: No automated migration between K3s versions.
4. **HA support**: Embedded etcd clustering not tested or supported.
5. **FluxCD providers**: Only GitHub supported; GitLab/generic git not yet implemented.

## Future Enhancements

Potential future features (not currently implemented):

- `ujust k3s-upgrade` - Safe in-place upgrade mechanism
- State backup/restore utilities
- Multi-node cluster management helpers
- K3s version migration tooling
- FluxCD GitLab/generic git provider support

## Files & Directories

### Immutable (part of image)

- `/usr/local/bin/k3s` - K3s binary
- `/usr/local/bin/kubectl` - Symlink to k3s
- `/usr/local/bin/crictl` - Symlink to k3s
- `/usr/local/bin/ctr` - Symlink to k3s
- `/usr/local/bin/flux` - FluxCD CLI binary
- `/usr/local/bin/blueberry-k3s-bootstrap` - K3s bootstrap script
- `/usr/local/bin/blueberry-flux-bootstrap` - FluxCD bootstrap script
- `/usr/local/bin/blueberry-k3s-version-check` - Version compatibility check
- `/usr/lib/systemd/system/k3s-server.service` - Server systemd unit
- `/usr/lib/systemd/system/k3s-agent.service` - Agent systemd unit
- `/etc/blueberry-k3s/version` - K3s binary version marker
- `/etc/blueberry-k3s/flux-version` - FluxCD CLI version marker

### Mutable (persists in /var)

- `/var/lib/rancher/k3s/` - K3s state directory
- `/var/lib/rancher/k3s/.version` - State version marker
- `/etc/rancher/k3s/` - K3s configuration
- `/etc/blueberry-k3s/k3s-server.env` - Server environment variables
- `/etc/blueberry-k3s/k3s-agent.env` - Agent environment variables

## Troubleshooting

### K3s refuses to start after upgrade

```bash
ujust k3s-version
```

If versions mismatch:
- Binary newer than state → upgrade required (not yet implemented)
- Binary older than state → rollback occurred, roll forward or reset

### K3s refuses to start after rollback

```bash
rpm-ostree upgrade
systemctl reboot
```

Or, if you want to start fresh:

```bash
ujust k3s-reset
ujust k3s-init-server  # or k3s-init-agent
```

### Check logs

```bash
ujust k3s-logs
```

Or directly:

```bash
journalctl -u k3s-server.service -f
journalctl -u k3s-agent.service -f
```

### Version mismatch details

```bash
cat /etc/blueberry-k3s/version              # K3s binary version
cat /etc/blueberry-k3s/flux-version         # FluxCD CLI version
cat /var/lib/rancher/k3s/.version           # K3s state version
/usr/local/bin/blueberry-k3s-version-check  # Run check manually
```

### FluxCD bootstrap fails

**Error: "dial tcp [::1]:8080: connect: connection refused"**

This means kubectl cannot find the K3s kubeconfig. The bootstrap script sets `KUBECONFIG=/etc/rancher/k3s/k3s.yaml` automatically, but verify K3s is running:

```bash
ujust k3s-status        # Ensure K3s is running
sudo kubectl get nodes  # Verify kubeconfig access
```

**kubectl requires sudo**

By default, K3s kubeconfig is root-only (`/etc/rancher/k3s/k3s.yaml`). To enable kubectl for your user without sudo:

```bash
ujust k3s-kubeconfig-user
```

This copies the kubeconfig to `~/.kube/config` with proper ownership.

**Error: "GitHub token file not found"**

Ensure the token file is readable by root (bootstrap runs with sudo):

```bash
# Recommended: Use root-accessible location
sudo mkdir -p /etc/blueberry-k3s/secrets
echo 'ghp_your_token_here' | sudo tee /etc/blueberry-k3s/secrets/github-token
sudo chmod 600 /etc/blueberry-k3s/secrets/github-token

# Then specify this path during bootstrap
```

**Error: "flux 2.4.0 <2.7.5 (new CLI version is available)"**

This is a warning, not an error. FluxCD v2.4.0 is pinned in the image. The controllers will auto-upgrade to match the manifests in your Git repository. This is expected behavior.

Verify GitHub token:
```bash
cat ~/.github-token     # Token should start with 'ghp_'
# Or:
sudo cat /etc/blueberry-k3s/secrets/github-token
```

Check network connectivity:
```bash
curl -I https://github.com
```

## Security Considerations

- K3s runs as root (required for container runtime)
- Firewall rules should be configured for K3s API (port 6443)
- Kubeconfig located at `/etc/rancher/k3s/k3s.yaml` (root-readable)
- Server token stored in `/var/lib/rancher/k3s/server/node-token` (protect accordingly)

## References

- [K3s Documentation](https://docs.k3s.io/)
- [K3s GitHub Releases](https://github.com/k3s-io/k3s/releases)
- [Blueberry AGENTS.md](../AGENTS.md) - Architectural constraints
- [Main README](../README.md) - Full project documentation
