#!/usr/bin/env bash
set -euo pipefail

echo "=== Blueberry devcontainer post-create setup ==="

# Install act (GitHub Actions local runner)
echo "Installing act..."
if ! command -v act &>/dev/null; then
    curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
fi

# Install actionlint (GitHub Actions workflow linter)
echo "Installing actionlint..."
if ! command -v actionlint &>/dev/null; then
    bash <(curl https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash) latest /usr/local/bin
    sudo chmod +x /usr/local/bin/actionlint
fi

# Install yamllint (YAML linter)
echo "Installing yamllint..."
if ! command -v yamllint &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y yamllint
fi

# Install buildah (for build testing, rootless mode)
echo "Installing buildah..."
if ! command -v buildah &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y buildah
fi

# Configure Docker group access
echo "Configuring Docker socket access..."
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    sudo groupadd -f -g "$DOCKER_GID" docker_host
    sudo usermod -aG docker_host vscode || true
fi

# Setup QEMU for multi-arch support (optional, for ARM64 emulation)
echo "Setting up QEMU binfmt support..."
if command -v docker &>/dev/null; then
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes 2>/dev/null || true
fi

echo "✓ Setup complete!"
echo ""
echo "Available testing commands:"
echo "  just validate-workflows    # Fast syntax check"
echo "  just test-workflow <name>  # Simulate GitHub Actions"
echo "  just test-build <variant>  # Test image build"
