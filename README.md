# Blueberry

Blueberry aims to be a light-weight server OS for aarch64-SBC's like the Raspberry Pi 4, heavily influenced by [Universal Blue](https://universal-blue.org/), in particular [uCore](https://github.com/ublue-os/ucore), but built on Fedora IOT. Like uCore, it's an opinionated, "batteries included" custom image, built daily with some common tools added in.

Blueberry provides two aarch64 images with a clear layering model:

## Image Family

```
blueberry-minimal (base container host)
        ↓
blueberry (storage primitives + observability)
        ↓
blueberry-k3s (planned: lightweight Kubernetes)
```

## Blueberry Minimal

The foundation image for containerized workloads on aarch64 SBCs. Based on [uCore minimal](https://github.com/ublue-os/ucore?tab=readme-ov-file#ucore-minimal), suitable for running containers on systems supported by [Fedora IOT](https://docs.fedoraproject.org/en-US/iot/reference-platforms/).

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

**Use blueberry-minimal when**: You need a clean, minimal atomic container host without storage or monitoring tooling.

### Installation (blueberry-minimal)

To rebase an existing Fedora IoT system to Blueberry Minimal:
```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/philbudden/blueberry-minimal:latest
systemctl reboot
```

## Blueberry

Builds on `blueberry-minimal` with storage primitives and observability for edge NAS workloads and Kubernetes nodes.

**Additional packages:**

**Storage Primitives:**
- `smartmontools` - Disk health monitoring (SMART)
- `hdparm` - Low-level disk parameter management
- `mdadm` - Software RAID for multi-disk resilience
- `cockpit-storaged` - Cockpit storage management UI

**Observability:**
- `pcp-zeroconf` - Performance Co-Pilot monitoring

**Design Philosophy:**
- Provides **primitives**, not policy
- Storage services (SMB, NFS, SnapRAID, MergerFS) run in **containers**, not on the host
- Lightweight monitoring suitable for SBC constraints (4-8GB RAM, USB storage)
- No ZFS (inappropriate for SBC/USB storage environments)

**Use blueberry when**: You need storage primitives for containerized NAS workloads, Kubernetes persistent volumes, or edge storage nodes.

### Installation (blueberry)

To rebase an existing Fedora IoT system to Blueberry:
```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/philbudden/blueberry:latest
systemctl reboot
```

### Package Rationale

**Why mdadm (Software RAID)?**

While USB storage is the primary target for SBC environments, multi-USB RAID configurations are legitimate and useful for:
- Data redundancy on edge nodes (RAID1 mirroring)
- Kubernetes persistent volume backing with resilience
- Containerized NAS services requiring underlying RAID
- Lightweight alternative to ZFS (which is too heavy for SBC/USB constraints)

`mdadm` is the only viable RAID primitive for this environment—no datacenter assumptions, minimal overhead, suitable for USB-connected drives.

## General Architecture & Installation

- **Architecture**: aarch64 only (for SBCs like Raspberry Pi 4)
- **Installation method**: Rebase from existing Fedora IoT installation only
- **Not supported**: Fresh installations, ISO/disk images, x86_64 architecture

To rebase an existing Fedora IoT system to Blueberry Minimal:
```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/philbudden/blueberry-minimal:latest
systemctl reboot
```

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
blueberry-minimal/                  # Minimal container host image
├── Containerfile                   # Image build definition
├── install-blueberry-minimal.sh    # Package installation script
├── cleanup.sh                      # Image cleanup script
└── system_files/                   # System configuration hierarchy
    ├── etc/                        # System configuration files
    │   └── ssh/sshd_config.d/      # SSH configuration
    └── usr/lib/systemd/system/     # Systemd unit files

blueberry/                          # Storage + observability image
├── Containerfile                   # Builds FROM blueberry-minimal
├── install-blueberry.sh            # Additional package installation
├── cleanup.sh                      # Image cleanup script
└── system_files/                   # Additional config (if needed)
```

This structure:
- Separates build logic from system configuration
- Mirrors the Linux filesystem hierarchy for clarity
- Enables clean multi-image support with layered variants (blueberry-minimal → blueberry → blueberry-k3s)
- Maintains compatibility with uCore patterns

## Build & Release

Blueberry follows uCore's build workflow conventions:

- **Workflow organization**: Version-specific workflows (`build-43.yml`, `build-44.yml`) delegate to a reusable workflow (`reusable-build.yml`)
- **Build schedule**: Daily builds at 2:30 UTC (Fedora 44) and 2:35 UTC (Fedora 43)
- **Image registry**: GitHub Container Registry (GHCR)
- **Image signing**: All published images are signed with Cosign
- **Build order**: Images build sequentially to respect dependencies (blueberry-minimal → blueberry)
- **Tags**:
  - `latest` - Most recent build of the default version (Fedora 44)
  - `YYYYMMDD` - Daily dated builds (e.g., `20260214`)
  
Images are built only for **aarch64** architecture and are intended for **rebase-only** installation on existing Fedora IoT systems.
