#!/usr/bin/env bash
# Validation script for GitHub Actions workflows
# Usage: ./scripts/validate-workflows.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

echo "=== Validating GitHub Actions Workflows ==="
echo ""

# Check for required tools
MISSING_TOOLS=()
command -v actionlint &>/dev/null || MISSING_TOOLS+=("actionlint")
command -v yamllint &>/dev/null || MISSING_TOOLS+=("yamllint")

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "ERROR: Missing required tools: ${MISSING_TOOLS[*]}"
    echo "Run devcontainer rebuild or install manually."
    exit 1
fi

# Count workflows
WORKFLOW_COUNT=$(find .github/workflows -name "*.yml" -o -name "*.yaml" | wc -l)
echo "Found ${WORKFLOW_COUNT} workflow file(s)"
echo ""

# Run yamllint
echo "→ Running yamllint..."
if yamllint -s .github/workflows/; then
    echo "  ✓ YAML syntax valid"
else
    echo "  ✗ YAML syntax errors found"
    exit 1
fi
echo ""

# Run actionlint
echo "→ Running actionlint..."
if actionlint .github/workflows/*.yml; then
    echo "  ✓ Workflow logic valid"
else
    echo "  ✗ Workflow issues found"
    exit 1
fi
echo ""

echo "✓ All workflows validated successfully"
