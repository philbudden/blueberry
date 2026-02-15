# Local CI Testing Guide

This guide explains how to test GitHub Actions workflows and image builds locally before pushing to GitHub.

## Overview

The testing infrastructure provides three levels of validation:

1. **Fast Syntax Checks** (~5 seconds) - YAML linting and workflow validation
2. **Workflow Simulation** (~5-10 minutes) - Run GitHub Actions locally with `act`
3. **Build Testing** (variable) - Test Containerfile builds with emulation

## Prerequisites

After rebuilding the devcontainer, you'll have:
- ✅ Docker access (via host socket)
- ✅ `act` - GitHub Actions local runner
- ✅ `actionlint` - Workflow linter
- ✅ `yamllint` - YAML validator
- ✅ `buildah` - Container builds
- ✅ QEMU - ARM64 emulation support

## Quick Start

### Validate Before Push
```bash
just pre-push
```
Runs syntax checks and linting (fast feedback loop).

### Test a Workflow
```bash
# Dry-run (shows what would execute)
just test-workflow build-43.yml

# Full execution
just test-workflow-run build-43.yml
```

### Test Image Builds
```bash
# Test single variant
just test-build blueberry-minimal

# Test full dependency chain
just test-build-all
```

## Detailed Usage

### 1. Workflow Validation

**Command:**
```bash
just validate-workflows
```

**What it does:**
- Validates YAML syntax with `yamllint`
- Checks workflow logic with `actionlint`
- Catches common mistakes (invalid steps, missing inputs, etc.)

**When to use:**
- Before every commit
- After modifying workflow files
- As part of pre-push checks

**Example output:**
```
=== Validating GitHub Actions Workflows ===

Found 3 workflow file(s)

 Running yamllint...
  ✓ YAML syntax valid

 Running actionlint...
  ✓ Workflow logic valid

 All workflows validated successfully
```

### 2. Local Workflow Execution

**Dry-run mode (default):**
```bash
just test-workflow build-43.yml
```

Shows what steps would execute without running them.

**Full execution:**
```bash
just test-workflow-run build-43.yml
```

Actually runs the workflow steps.

**Custom event:**
```bash
just test-workflow build-43.yml pull_request
```

**What it validates:**
- Job dependencies
- Environment variable resolution
- Step ordering
- Conditional logic
- Matrix strategy setup

**Limitations:**
- Some GitHub-specific features won't work (OIDC, secrets management)
- ARM-specific runners are emulated as x86_64
- Third-party actions may behave differently

### 3. Build Testing

**Test a single variant:**
```bash
just test-build blueberry-minimal
```

**Test the full stack:**
```bash
just test-build-all
```

**With custom tag:**
```bash
just test-build blueberry-minimal my-test
```

**What it does:**
- Validates Containerfile syntax
- Tests build-arg propagation
- Checks layer dependencies (blueberry-minimal → blueberry)
- Handles multi-arch via QEMU

**Notes on ARM64:**
- Builds use QEMU user-mode emulation
- Expect 5-10x slower than native builds
- Some hardware-specific features won't work
- Full ARM64 testing happens in GitHub Actions

### 4. Direct Script Usage

If you need more control:

```bash
# Validate workflows
./scripts/validate-workflows.sh

# Test workflow with act directly
./scripts/test-workflow.sh build-43.yml push

# Test builds with environment overrides
FEDORA_VERSION=43 ./scripts/test-build.sh blueberry-minimal
```

## Architecture Notes

### Docker Socket Binding

The devcontainer mounts `/var/run/docker.sock` from the host:
- ✅ No Docker-in-Docker complexity
- ✅ Better performance
- ✅ Shared image cache
- ⚠️ Requires host Docker daemon

### Act Configuration

See `.actrc` for defaults:
- Uses `catthehacker/ubuntu:act-*` images (closer to GitHub runners)
- Binds Docker socket for nested operations
- Platform mappings for ubuntu-24.04

### Build Strategy

**blueberry-minimal:**
- Pulls Fedora IoT base from quay.io
- Builds standalone

**blueberry:**
- Requires blueberry-minimal as base
- Auto-builds minimal if not available
- Tags appropriately for layer resolution

## Common Workflows

### Before Pushing Changes

```bash
# Full validation suite
just pre-push

# If workflow changes, test them
just test-workflow build-43.yml
```

### After Modifying Containerfiles

```bash
# Quick syntax check
just test-build blueberry-minimal

# Full dependency test
just test-build-all
```

### Debugging Workflow Issues

```bash
# Dry-run first to see execution plan
just test-workflow build-43.yml

# If it looks good, full run
just test-workflow-run build-43.yml

# For more detail, run act directly with --verbose
cd /workspaces/github-com-philbudden-blueberry
act push --workflows .github/workflows/build-43.yml --verbose
```

### Testing Multi-Variant Builds

```bash
# Ensure clean state
docker images | grep blueberry

# Test sequential build (mimics CI)
just test-build-all

# Verify images exist
docker images | grep blueberry
```

## Troubleshooting

### "Docker is not available"
- Check: `docker info`
- Ensure devcontainer has socket mount
- Rebuild devcontainer if needed

### "act is not installed"
- Rebuild devcontainer to run post-create script
- Or install manually: https://nektosact.com/installation/index.html

### "actionlint: command not found"
- Rebuild devcontainer
- Or install: https://github.com/rhysd/actionlint

### Slow ARM64 Builds
- Expected: QEMU emulation is 5-10x slower
- For speed, test syntax only (dry builds)
- Use GitHub Actions for full ARM builds

### Act Workflow Fails
- Some GHA features aren't supported by act
- Check act compatibility: https://nektosact.com/
- Secrets/OIDC won't work locally
- Use workflow_dispatch with inputs for testing

## Integration with CI

This local testing **augments** GitHub Actions, doesn't replace it:

| Validation | Local | GitHub Actions |
|------------|-------|----------------|
| YAML syntax | ✅ Fast | ✅ Definitive |
| Workflow logic | ✅ Quick feedback | ✅ Full environment |
| x86_64 builds | ✅ Native speed | ✅ Native speed |
| ARM64 builds | ⚠️ Slow (QEMU) | ✅ Native ARM runners |
| Signing/ Not supported | ✅ Full deployment |pushing | 

**Recommended workflow:**
1. Validate locally with `just pre-push`
2. Test workflow logic with `just test-workflow <name>`
3. Push to feature branch
4. Let GitHub Actions run full ARM64 builds
5. Iterate based on CI feedback

## Files Reference

```
.devcontainer/
 post-create.sh          # Tool installation
.github/workflows/          # Workflow definitions
 build-43.yml
 build-44.yml
 reusable-build.yml
scripts/
 validate-workflows.sh   # YAML/workflow linting
 test-workflow.sh        # Run workflows with act
 test-build.sh           # Test image builds
.actrc                      # act configuration
.yamllint                   # YAML linting rules
Justfile                    # Convenient recipes
```

## Best Practices

1. **Always validate before pushing:**
   ```bash
   just pre-push
   ```

2. **Test workflows in dry-run first:**
   ```bash
   just test-workflow <workflow>
   ```

3. **Use specific tags for test builds:**
   ```bash
   just test-build blueberry-minimal test-$(date +%s)
   ```

4. **Clean up test images periodically:**
   ```bash
   docker images | grep localhost/blueberry
   docker rmi <image-id>
   ```

5. **Keep act config simple:**
   - Don't try to replicate every GHA feature
   - Focus on workflow logic validation
   - Accept that some things only work in real CI

## Further Reading

- [act documentation](https://nektosact.com/)
- [actionlint documentation](https://github.com/rhysd/actionlint)
- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [Blueberry AGENTS.md](../AGENTS.md) - Project architecture
