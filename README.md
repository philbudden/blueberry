# Blueberry

Blueberry aims to be a light-weight server OS for aarch64-SBC's like the Raspberry Pi 4, heavily influenced by [Universal Blue](https://universal-blue.org/), in particular [uCore](https://github.com/ublue-os/ucore), but built on Fedora IOT. Like uCore, it's an opinionated, "batteries included" custom image, built daily with some common tools added in.

Blueberry began life as a series of Ansible playbooks for configuring a Fedora IOT install, however due to the Fedora IOT image not being publicly available, this involved layering many of the packages. Eventually the end product became unstable, and the project was shelved towards the end of 2024. In the intervening months however, the FedoreaIOT image has been made available on [quay.io](https://quay.io/repository/fedora/fedora-iot), making this now a viable project.

At present, Blueberry only builds a single, aarch64 image, based on [uCore minimal](https://github.com/ublue-os/ucore?tab=readme-ov-file#ucore-minimal), which is suitable for running containerized workloads on aarch64 systems supported by [Fedora IOT](https://docs.fedoraproject.org/en-US/iot/reference-platforms/), like it's influencer, this image tries to stay lightweight but functional:

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

> [!IMPORTANT]
> Per [cockpit's instructions](https://cockpit-project.org/running.html#coreos) the cockpit-ws RPM is **not** installed, rather it is provided as a pre-defined systemd service which runs a podman container.

> [!NOTE]
> Key differences between Blueberry and uCore-minimal:
> - **Container tools**: Given the focus on SBC hardware, a single container engine is preferred. Podman is provided out-of-the-box with Fedora IoT.
> - **udev rules**: Not required, as only devices already supported by Fedora IoT are currently in scope.
> - **ZFS**: Generally discouraged on SBCs due to poor performance with USB-based storage.
> - **NVIDIA support**: While some older GPUs have been adapted for Raspberry Pi devices, this remains a rare and non-standard use case.

## Repository Structure

The repository follows [uCore's](https://github.com/ublue-os/ucore) organizational conventions:

```
blueberry/                          # Main image source directory
├── Containerfile                   # Image build definition
├── install-blueberry.sh            # Package installation script
├── cleanup.sh                      # Image cleanup script
└── system_files/                   # System configuration hierarchy
    ├── etc/                        # System configuration files
    │   └── ssh/sshd_config.d/      # SSH configuration
    └── usr/lib/systemd/system/     # Systemd unit files
```

This structure:
- Separates build logic from system configuration
- Mirrors the Linux filesystem hierarchy for clarity
- Enables clean multi-image support for future variants
- Maintains compatibility with uCore patterns
