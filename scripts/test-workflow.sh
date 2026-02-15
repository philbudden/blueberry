#!/usr/bin/env bash
# Test a GitHub Actions workflow locally using act
# Usage: ./scripts/test-workflow.sh <workflow-file> [event]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

WORKFLOW_FILE="${1:-}"
EVENT="${2:-push}"

if [ -z "${WORKFLOW_FILE}" ]; then
    echo "Usage: $0 <workflow-file> [event]"
    echo ""
    echo "Available workflows:"
    find .github/workflows -name "*.yml" -exec basename {} \;
    exit 1
fi

if [ ! -f ".github/workflows/${WORKFLOW_FILE}" ]; then
    echo "ERROR: Workflow file not found: .github/workflows/${WORKFLOW_FILE}"
    exit 1
fi

echo "=== Testing workflow: ${WORKFLOW_FILE} ==="
echo "Event: ${EVENT}"
echo ""

# Check if act is installed
if ! command -v act &>/dev/null; then
    echo "ERROR: act is not installed"
    echo "Run devcontainer rebuild or install manually: https://github.com/nektos/act"
    exit 1
fi

# Check Docker availability
if ! docker info &>/dev/null; then
    echo "ERROR: Docker is not available"
    echo "Ensure Docker socket is mounted in devcontainer"
    exit 1
fi

# Run act with dry-run by default, or full run if ACT_RUN=1
ACT_FLAGS=(
    "--workflows" ".github/workflows/${WORKFLOW_FILE}"
    "--eventpath" ".github/act-event.json"
    "--platform" "ubuntu-24.04=catthehacker/ubuntu:act-24.04"
)

# Use dry-run unless explicitly running
if [ "${ACT_RUN:-0}" != "1" ]; then
    ACT_FLAGS+=("--dryrun")
    echo "Running in DRY-RUN mode (set ACT_RUN=1 for full execution)"
    echo ""
fi

# Create minimal event payload
cat >.github/act-event.json <<EOF
{
  "ref": "refs/heads/main",
  "repository": {
    "default_branch": "main",
    "name": "blueberry",
    "owner": {
      "login": "philbudden"
    }
  }
}
EOF

# Run act
act "${EVENT}" "${ACT_FLAGS[@]}" "$@"

# Cleanup
rm -f .github/act-event.json

echo ""
echo "✓ Workflow test complete"
