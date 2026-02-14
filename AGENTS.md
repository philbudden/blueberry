# Blueberry — Atomic Fedora IoT Images for aarch64 SBCs

This document defines the architectural intent, guardrails, constraints, and working rules for contributors and automated agents working on the Blueberry repository.

Blueberry is an immutable, atomic Fedora IoT–based image family designed for aarch64 single-board computers (SBCs) such as Raspberry Pi devices.

This file is not a checklist.

It is a long-term design contract.

If a proposed change conflicts with this document, the change is wrong unless the document is updated intentionally.

## 1. Project Intent

Blueberry exists to build:
- Minimal, reproducible, purpose-built atomic OS images
- Designed for edge/SBC environments
- Container-first systems
- GitOps-oriented workflows
- Industry-relevant infrastructure patterns

The project is educational, public, and intended to reflect production-adjacent architecture without becoming a general-purpose Linux distribution.

Blueberry prioritizes clarity and discipline over feature breadth.

## 2. Non-Negotiable Constraints

These constraints must be preserved.

### Base OS

- Fedora IoT is mandatory.
- rpm-ostree / atomic model is mandatory.
- Immutable design principles must be preserved.

### Container Philosophy

- Services run in containers.
- Host-level services must be minimal and justified.
- Podman is preferred for non-Kubernetes workloads.
- Kubernetes runtime will use CRI-compatible runtimes (not Podman).

### GitOps

- GitOps-first mindset.
- Declarative configuration.
- Reproducible builds.
- Pinned versions where appropriate.

### Cockpit

- Cockpit is required and supported.
- Web management exposure must be deliberate and secure.

### Target Environment

- aarch64 SBC hardware.
- Limited RAM.
- USB-attached storage.
- Limited IO bandwidth.
- Non-datacenter assumptions.

Do not design for rack-scale clusters unless explicitly requested.

## 3. Project Non-Goals

Blueberry is not:
- A general-purpose Linux distribution
- A desktop OS
- A full NAS appliance distribution
- A hypervisor platform
- A high-availability datacenter platform
- A feature accumulation experiment

Avoid creeping scope.

## 4. Image Layering Model

Blueberry follows this strict layering:

blueberry-minimal
        ↓
blueberry (storage-primitives + pcp)
        ↓
blueberry-k3s

No circular dependencies.

No cross-variant feature leakage.

### 4.1 blueberry-minimal

Purpose:
- Clean atomic container host for SBCs.

Includes:
- Fedora IoT base
- Podman (from base)
- Cockpit
- firewalld
- Tailscale + wireguard tools
- VM guest agents
- tmux
- Minimal required utilities

Must remain:
- Small
- Boring
- Stable
- Free of storage policy and Kubernetes logic

No NAS daemons.

No Kubernetes binaries.

No storage orchestration logic.

### 4.2 blueberry (storage-primitives + pcp)

Purpose:
- Provide storage primitives appropriate for:  
- Lightweight NAS workloads (containerized services)
- Kubernetes nodes
- Provide performance observability via PCP.

Allowed:
- Disk tooling (smart tools, filesystem utilities)
- RAID primitives (if justified)
- Mount support
- udev rules if necessary
- PCP

Not allowed:
- SMB server daemons by default
- NFS server by default
- SnapRAID, MergerFS, or policy-layer storage unless explicitly justified
- Cloud backup tools as host dependencies
- ZFS (inappropriate for SBC/USB storage constraints)

This layer must contain primitives, not policy.

NAS services should run in containers on top of this image.

### 4.3 blueberry-k3s

Purpose:
- Lightweight Kubernetes node image for SBCs.

Includes:
- Everything from blueberry
- K3S binaries (pinned version)
- Systemd units (disabled by default)
- Activation/bootstrap script

Hard rules:
- K3S is disabled by default.
- No automatic cluster initialization.
- User must explicitly choose server or agent mode.
- No HA assumptions unless explicitly added later.
- K3S version must be pinned per image release.

Lifecycle rules:
- Explicit handling of version skew.
- Guardrails against starting older binaries against newer state.
- Clear upgrade expectations.
- Rollback implications documented.

## 5. Repository Structure Conventions

The repository must:
- Clearly separate:  
- Shared base logic
- Variant-specific logic
- Build definitions
- CI configuration
- Documentation

Avoid duplication.

Prefer composition over copy-paste.

Shared components must live in clearly defined directories.

Variant directories must:
- Only contain variant-specific logic.
- Avoid modifying upstream layers unnecessarily.

Naming must be consistent and predictable.

No hidden build logic in arbitrary scripts.

## 6. Dependency Rules

Every dependency must justify its existence.

Before adding a package, answer:
1. Which image(s) require it?
2. Can this functionality run in a container instead?
3. Does it add a long-running daemon?
4. Does it increase attack surface?
5. Does it assume datacenter resources?
6. Does it meaningfully impact RAM or IO?

If unclear, do not add it.

### SBC Realism Constraints

Assume:
- 4–8GB RAM
- USB3 storage bottlenecks
- No ECC memory
- Consumer-grade SSDs or HDDs
- Limited cooling

Avoid:
- Heavy monitoring stacks
- Background indexing services
- Large dependency trees
- Datacenter HA tooling

## 7. Kubernetes Guardrails

K3S is allowed but controlled.

Mandatory:
- Pinned version
- Deterministic installation at build time
- Idempotent activation script
- Explicit server/agent selection
- No implicit state mutation

Rollback reality:
- rpm-ostree rollback does not revert /var.

Therefore:
- K3S startup must detect incompatible state versions.
- Downgrade scenarios must fail safely.
- State schema expectations must be documented.

No hidden assumptions.

## 8. Build and CI Principles

Builds must be:
- Reproducible
- Deterministic
- Version-pinned where required
- Clear when they fail

CI should:
- Build all variants
- Fail loudly
- Avoid silent drift

Avoid:
- Implicit version pulls without pinning
- “Latest” tags in critical infrastructure components
- Mutable external dependencies

## 9. Safe Change Protocol

Agents must:
- Scan the repository before restructuring.
- Propose a plan before large refactors.
- Separate structural refactors from behavioral changes.
- Keep diffs small and reviewable.
- Prefer reversible changes.
- Avoid “clever” optimizations without measurable benefit.

Refactors must:
- Preserve build outputs unless explicitly changing behavior.
- Not introduce functional drift.
- Update documentation if structure changes.

Never combine:
- Structural reorganization
- New features
- Dependency changes

Into one commit.

## 10. Definition of “Clean Enough” (Refactor Completion Criteria)

The repository is considered clean when:
- Layer boundaries are obvious and enforced.
- No duplication between variants.
- Shared logic lives in one place.
- Builds are deterministic.
- Variants are composable and understandable.
- Documentation reflects architecture.
- No accidental dependency leakage exists.

Clarity is more important than cleverness.

## 11. Working Style Guide for Agents

When making changes:
1. Read the full AGENTS.md before acting.
2. Scan repository structure.
3. Identify layering boundaries.
4. Propose a concise plan if the change is large.
5. Execute in small steps.
6. Document rationale in commit messages.
7. Avoid assumptions about hardware scale.

Prefer:
- Simplicity
- Predictability
- Boring solutions

Avoid:
- Abstractions that obscure intent
- Overengineering
- “Future-proofing” without a concrete need
- Introducing HA or distributed assumptions without explicit request

If a change feels like “this would be cool”, stop.

If a change makes the system heavier, justify it.

If uncertain, ask before proceeding.

## 12. Philosophy

Blueberry is:
- Intentional
- Conservative
- Reproducible
- Edge-aware
- Industry-aligned
- Minimal by design

It should feel like a disciplined appliance foundation, not a hobbyist Linux remix.

Every addition must earn its place.
