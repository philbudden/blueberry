# Local Testing Quick Reference

## Fast Commands

```bash
# Before committing/pushing
just pre-push                           # Full validation suite

# Validate workflows only
just validate-workflows                 # YAML + workflow linting

# Test a workflow
just test-workflow build-43.yml         # Dry-run (shows plan)
just test-workflow-run build-43.yml     # Full execution

# Test image builds
just test-build blueberry-minimal       # Single variant
just test-build blueberry               # With dependencies
just test-build-all                     # Full stack
```

## When To Use What

| Task | Command | Time | Use Case |
|------|---------|------|----------|
| Pre-commit check | `just pre-push` | ~10s | Always before pushing |
| Workflow syntax | `just validate-workflows` | ~5s | After editing .yml files |
| Workflow logic | `just test-workflow <name>` | ~2min | Testing job dependencies |
| Build syntax | `just test-build <variant>` | varies | After editing Containerfile |
| Full CI simulation | `just test-build-all && just test-workflow-run <name>` | ~30min+ | Major changes |

## Common Scenarios

### I changed a workflow file
```bash
just validate-workflows              # Fast syntax check
just test-workflow build-43.yml      # See what it would do
```

### I changed a Containerfile
```bash
just test-build blueberry-minimal    # Test the build
```

### I'm about to push
```bash
just pre-push                        # Validate everything
```

### Workflow fails in CI
```bash
# Reproduce locally
just test-workflow-run build-43.yml

# Debug with verbose output
act push --workflows .github/workflows/build-43.yml --verbose
```

## Tool Locations

| Tool | Purpose | Direct Usage |
|------|---------|--------------|
| actionlint | Workflow validation | `actionlint .github/workflows/*.yml` |
| yamllint | YAML syntax | `yamllint .github/workflows/` |
| act | Run GHA locally | `act push --workflows .github/workflows/build-43.yml` |
| docker/buildah | Build images | `docker build --platform linux/aarch64 ...` |

## Flags & Options

### test-workflow
- Default: Dry-run mode (safe)
- `ACT_RUN=1`: Full execution mode
- Event types: `push`, `pull_request`, `workflow_dispatch`

### test-build
- `FEDORA_VERSION=43`: Override Fedora version
- `ARCH=aarch64`: Architecture (default)
- Tag argument: Custom image tag

## Troubleshooting

```bash
# Check Docker access
docker info

# Verify tools installed
which act actionlint yamllint buildah

# List available workflows
ls .github/workflows/*.yml

# Check test script help
./scripts/test-build.sh              # Shows usage
./scripts/test-workflow.sh           # Shows available workflows
```

## ARM64 Performance

| Method | Speed | Accuracy | Use For |
|--------|-------|----------|---------|
| Syntax validation | Fast | 100% | Pre-commit checks |
| QEMU emulation | 5-10x slower | 95% | Structure testing |
| GitHub Actions ARM | Native | 100% | Production builds |

**Recommendation:** Use local for syntax, GitHub Actions for real builds.

## Documentation

- Full guide: [docs/TESTING.md](TESTING.md)
- Architecture: [AGENTS.md](../AGENTS.md)
- Build workflows: [.github/workflows/](../.github/workflows/)

## Getting Help

```bash
just --list                          # All available recipes
just --list CI                       # CI testing recipes only
./scripts/validate-workflows.sh --help
./scripts/test-workflow.sh
./scripts/test-build.sh
```
