# Blueberry

Blueberry aims to be a light-weight server OS for aarch64-SBC's like the Raspberry Pi 4, heavily influenced by [Universal Blue](https://universal-blue.org/), in particular [uCore](https://github.com/ublue-os/ucore), but built on Fedora IOT. Like uCore, it's an opinionated, "batteries included" custom image, built daily with some common tools added in.

Blueberry provides a layered image family for different use cases:

- **blueberry-minimal**: Minimal container host
- **blueberry**: Storage primitives and observability (builds on minimal)
- **blueberry-k3s**: Lightweight Kubernetes (coming soon)

## Image Variants

### Blueberry Minimal

Based on [uCore minimal](https://github.com/ublue-os/ucore?tab=readme-ov-file#ucore-minimal), suitable for running containerized workloads on aarch64 systems supported by [Fedora IOT](https://docs.fedoraproject.org/en-US/iot/reference-platforms/).

- Starts with a [Fedora IOT image](https://quay.io/repository/fedora/fedora-iot)
- Adds the following:
  - [bootc](https://github.com/containers/bootc) (new way to update container native systems)
  - [cockpit](https://cockpit-project.org) (podman container and system management)
  - [firewalld](https://firewalld.org/)
  - guest VM agents (`qemu-guest-agent` and `open-vm-tools`))
  - [podman-compose](https://github.com/containers/podman-compose) *podman is pre-installed in Fedora IOT*
  - [tailscale](https://tailscale.com) and [wireguard-tools](https://www.wireguard.com)
  - [tmux](https://github.com/tmux/tmux/wiki/Getting-Started)
- Enables staging of automatic system updates via rpm-ostreed
- Enables password based SSH auth (required for locally running cockpit web interface)

**To rebase to blueberry-minimal:**
```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/philbudden/blueberry-minimal:latest
systemctl reboot
```

### Blueberry

Builds on **blueberry-minimal** with storage primitives and observability for NAS workloads and general-purpose server use.

Adds:
- **Storage primitives**:
  - `smartctl` - SMART disk health monitoring
  - `hdparm` - Disk parameter management and benchmarking
  - `cockpit-storaged` - Web UI for storage management
  - `lvm2` - LVM volume management
  - `mdadm` - Software RAID (RAID1 mirroring recommended for redundancy; RAID0 available but not recommended for USB storage)
  - Filesystem tools: `xfsprogs`, `dosfstools`, `exfatprogs`
- **Observability**:
  - `pcp-zeroconf` - Performance Co-Pilot with zero-config mode

**Design philosophy**: This image provides storage *primitives*, not policy. Stateful services like SMB, NFS, and backup tools should run in containers on top of this base.

**To rebase to blueberry:**
```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/philbudden/blueberry:latest
systemctl reboot
```

## Architecture & Installation

- **Architecture**: aarch64 only (for SBCs like Raspberry Pi 4)
- **Installation method**: Rebase from existing Fedora IoT installation only
- **Not supported**: Fresh installations, ISO/disk images, x86_64 architecture

> [!IMPORTANT]
> Per [cockpit's instructions](https://cockpit-project.org/running.html#coreos) the cockpit-ws RPM is **not** installed, rather it is provided as a pre-defined systemd service which runs a podman container.

> [!NOTE]
> Key differences between Blueberry Minimal and uCore-minimal:
> - **Architecture**: aarch64 only (uCore supports x86_64 and aarch64)
> - **Installation**: Rebase-only (uCore supports fresh installs via ISO/disk images)
> - **Container tools**: Given the focus on SBC hardware, a single container engine is preferred. Podman is provided out-of-the-box with Fedora IoT.
> - **udev rules**: Not required, as only devices already supported by Fedora IoT are currently in scope.
> - **ZFS**: Generally discouraged on SBCs due to poor performance with USB-based storage.
> - **NVIDIA support**: While some older GPUs have been adapted for Raspberry Pi devices, this remains a rare and non-standard use case.

## Repository Structure

The repository follows [uCore's](https://github.com/ublue-os/ucore) organizational conventions:

```
blueberry-minimal/                  # Minimal image source directory
├── Containerfile                   # Image build definition
├── install-blueberry-minimal.sh    # Package installation script
├── cleanup.sh                      # Image cleanup script
└── system_files/                   # System configuration hierarchy
    ├── etc/                        # System configuration files
    │   └── ssh/sshd_config.d/      # SSH configuration
    └── usr/lib/systemd/system/     # Systemd unit files

blueberry/                          # Storage + observability image (builds from blueberry-minimal)
├── Containerfile                   # Image build definition
├── install-blueberry.sh            # Package installation script
├── cleanup.sh                      # Image cleanup script
└── system_files/                   # System configuration hierarchy
    ├── etc/                        # System configuration files
    └── usr/                        # Additional system files
```

This structure:
- Separates build logic from system configuration
- Mirrors the Linux filesystem hierarchy for clarity
- Enables clean multi-image support with layered variants
- Maintains compatibility with uCore patterns
- Provides clear separation: `blueberry-minimal` → `blueberry` → `blueberry-k3s` (future)

## Build & Release

Blueberry follows uCore's build workflow conventions:

- **Workflow organization**: Version-specific workflows (`build-43.yml`, `build-44.yml`) delegate to a reusable workflow (`reusable-build.yml`)
- **Build schedule**: Daily builds at 2:30 UTC (Fedora 44) and 2:35 UTC (Fedora 43)
- **Image registry**: GitHub Container Registry (GHCR)
- **Image signing**: All published images are signed with Cosign
- **Tags**:
  - `latest` - Most recent build of the default version (Fedora 44)
  - `YYYYMMDD` - Daily dated builds (e.g., `20260214`)
  
Images are built only for **aarch64** architecture and are intended for **rebase-only** installation on existing Fedora IoT systems.

## Development & Testing

Blueberry includes local testing infrastructure for validating workflows and builds before pushing to GitHub.

**Quick validation:**
```bash
just pre-push        # Validate workflows and shell scripts
```

**Test workflows locally:**
```bash
just test-workflow build-43.yml     # Dry-run simulation
just test-workflow-run build-43.yml # Full execution
```

**Test image builds:**
```bash
just test-build blueberry-minimal   # Single variant
just test-build-all                 # Full dependency chain
```

See [docs/TESTING.md](docs/TESTING.md) for detailed testing documentation.

**Development environment:**
- Uses devcontainer with Docker socket binding
- Includes `act` for GitHub Actions simulation
- Includes `actionlint` and `yamllint` for validation
- Supports ARM64 emulation via QEMU (slower, for syntax testing)
- Full ARM64 builds use GitHub Actions native runners
