# K3s Management Tasks for Blueberry K3s
# vim: set ft=make :

# Initialize K3s as a server (single-node control plane)
k3s-init-server:
    #!/usr/bin/bash
    echo "╔════════════════════════════════════════════════╗"
    echo "║  K3s Server Initialization                     ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    echo "This will initialize K3s in server mode (control plane)."
    echo ""
    echo "After initialization, this node will run Kubernetes workloads."
    echo ""
    echo "Press Ctrl+C to abort, or Enter to continue..."
    read -r

    sudo /usr/local/bin/blueberry-k3s-bootstrap server

# Initialize K3s as an agent (worker node)
k3s-init-agent:
    #!/usr/bin/bash
    echo "╔════════════════════════════════════════════════╗"
    echo "║  K3s Agent Initialization                      ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    echo "This will initialize K3s in agent mode (worker node)."
    echo ""
    echo "You will need:"
    echo "  1. The K3s server URL (e.g., https://192.168.1.100:6443)"
    echo "  2. The K3s server token"
    echo ""
    echo "To get the token from the server, run:"
    echo "  sudo cat /var/lib/rancher/k3s/server/node-token"
    echo ""
    read -p "Server URL: " server_url
    read -p "Server Token: " server_token

    if [[ -z "$server_url" || -z "$server_token" ]]; then
        echo "Error: Server URL and token are required."
        exit 1
    fi

    sudo /usr/local/bin/blueberry-k3s-bootstrap agent --server "$server_url" --token "$server_token"

# Show K3s status and version information
k3s-status:
    #!/usr/bin/bash
    echo "╔════════════════════════════════════════════════╗"
    echo "║  K3s Status                                    ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    # Check which mode is running
    if systemctl is-active k3s-server.service &>/dev/null; then
        echo "Mode: Server"
        echo "Status:"
        systemctl status k3s-server.service --no-pager
        echo ""
        if command -v kubectl &>/dev/null; then
            echo "─── Cluster Info ───────────────────────────────────"
            kubectl get nodes 2>/dev/null || echo "kubectl not responding (K3s may be starting...)"
        fi
    elif systemctl is-active k3s-agent.service &>/dev/null; then
        echo "Mode: Agent"
        echo "Status:"
        systemctl status k3s-agent.service --no-pager
    elif systemctl is-enabled k3s-server.service &>/dev/null; then
        echo "Mode: Server (configured but not running)"
        systemctl status k3s-server.service --no-pager
    elif systemctl is-enabled k3s-agent.service &>/dev/null; then
        echo "Mode: Agent (configured but not running)"
        systemctl status k3s-agent.service --no-pager
    else
        echo "K3s is not initialized."
        echo ""
        echo "To initialize K3s, run:"
        echo "  ujust k3s-init-server  (for server/control plane)"
        echo "  ujust k3s-init-agent   (for worker node)"
    fi
    echo ""

# Display K3s version information
k3s-version:
    #!/usr/bin/bash
    echo "╔════════════════════════════════════════════════╗"
    echo "║  K3s Version Information                       ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    if [[ -f /etc/blueberry-k3s/version ]]; then
        BINARY_VERSION=$(cat /etc/blueberry-k3s/version)
        echo "Image K3s version:  $BINARY_VERSION"
    else
        echo "Image K3s version:  (unknown)"
    fi

    if [[ -f /var/lib/rancher/k3s/.version ]]; then
        STATE_VERSION=$(cat /var/lib/rancher/k3s/.version)
        echo "State K3s version:  $STATE_VERSION"

        if [[ "$BINARY_VERSION" == "$STATE_VERSION" ]]; then
            echo "Version status:     ✓ Compatible"
        else
            echo "Version status:     ✗ MISMATCH (K3s will not start)"
        fi
    else
        echo "State K3s version:  (not initialized)"
    fi

    echo ""

    if command -v k3s &>/dev/null; then
        echo "─── K3s Binary Info ────────────────────────────────"
        k3s --version
    fi
    echo ""

# Get K3s server token (for adding agents)
k3s-get-token:
    #!/usr/bin/bash
    if [[ ! -f /var/lib/rancher/k3s/server/node-token ]]; then
        echo "Error: K3s server token not found."
        echo "This command only works on K3s server nodes."
        exit 1
    fi

    echo "╔════════════════════════════════════════════════╗"
    echo "║  K3s Server Token                              ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    echo "Use this token when initializing K3s agents:"
    echo ""
    sudo cat /var/lib/rancher/k3s/server/node-token
    echo ""

# Enable kubectl access for current user (without sudo)
k3s-kubeconfig-user:
    #!/usr/bin/bash
    echo "╔════════════════════════════════════════════════╗"
    echo "║  Enable kubectl for Current User              ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    
    # Determine the actual user (not root when run via sudo)
    if [[ -n "$SUDO_USER" ]]; then
        REAL_USER="$SUDO_USER"
    else
        REAL_USER="$USER"
    fi
    
    # Get the user's actual home directory
    REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    
    if [[ -z "$REAL_HOME" || "$REAL_HOME" == "/" ]]; then
        echo "Error: Could not determine home directory for user '$REAL_USER'"
        exit 1
    fi
    
    echo "Configuring kubectl for user: $REAL_USER"
    echo "Target: $REAL_HOME/.kube/config"
    echo "Source: /etc/rancher/k3s/k3s.yaml"
    echo ""
    echo "⚠️  WARNING: This grants cluster admin access to user '$REAL_USER'."
    echo ""
    read -p "Press Enter to continue, or Ctrl+C to abort..."
    echo ""

    # Check if K3s is initialized
    if [[ ! -f /etc/rancher/k3s/k3s.yaml ]]; then
        echo "Error: K3s kubeconfig not found."
        echo "Initialize K3s first: ujust k3s-init-server"
        exit 1
    fi

    # Create .kube directory in user's home (as root if needed)
    sudo mkdir -p "$REAL_HOME/.kube"

    # Copy kubeconfig
    sudo cp /etc/rancher/k3s/k3s.yaml "$REAL_HOME/.kube/config"

    # Set ownership to the actual user
    sudo chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.kube/config"

    # Set secure permissions
    sudo chmod 600 "$REAL_HOME/.kube/config"

    echo "✓ Kubeconfig copied to $REAL_HOME/.kube/config"
    echo "✓ Ownership: $REAL_USER:$REAL_USER"
    echo "✓ Permissions: 600"
    echo ""
    echo "You can now run kubectl without sudo:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A"
    echo ""
    echo "Note: The kubeconfig will need to be updated after K3s upgrades."
    echo "      Re-run this command if kubectl stops working after an upgrade."
    echo ""

# Reset K3s (DESTRUCTIVE - removes all K3s state)
k3s-reset:
    #!/usr/bin/bash
    echo "╔════════════════════════════════════════════════╗"
    echo "║  K3s Reset (DESTRUCTIVE)                       ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    echo "⚠️  WARNING: This will:"
    echo "  - Stop K3s services"
    echo "  - Disable K3s services"
    echo "  - Delete all K3s state (/var/lib/rancher/k3s)"
    echo "  - Delete all K3s configuration (/etc/rancher/k3s)"
    echo "  - Remove all Kubernetes workloads"
    echo "  - Remove all persistent volumes"
    echo ""
    echo "This operation is IRREVERSIBLE."
    echo ""
    read -p "Type 'RESET' to confirm: " confirm

    if [[ "$confirm" != "RESET" ]]; then
        echo "Aborted."
        exit 1
    fi

    echo ""
    echo "Resetting K3s..."

    # Stop services
    sudo systemctl stop k3s-server.service k3s-agent.service 2>/dev/null || true

    # Disable services
    sudo systemctl disable k3s-server.service k3s-agent.service 2>/dev/null || true

    # Remove state (use k3s-killall.sh if available)
    if [[ -x /usr/local/bin/k3s-killall.sh ]]; then
        sudo /usr/local/bin/k3s-killall.sh || true
    fi

    # Remove directories
    sudo rm -rf /var/lib/rancher/k3s
    sudo rm -rf /etc/rancher/k3s
    sudo rm -rf /etc/blueberry-k3s/k3s-*.env

    echo ""
    echo "✓ K3s reset complete."
    echo ""
    echo "K3s has been removed. You can reinitialize with:"
    echo "  ujust k3s-init-server"
    echo "  ujust k3s-init-agent"
    echo ""

# Show K3s logs (server or agent)
k3s-logs:
    #!/usr/bin/bash
    if systemctl is-active k3s-server.service &>/dev/null; then
        sudo journalctl -u k3s-server.service -f --no-hostname
    elif systemctl is-active k3s-agent.service &>/dev/null; then
        sudo journalctl -u k3s-agent.service -f --no-hostname
    else
        echo "K3s is not running."
        exit 1
    fi

# Bootstrap FluxCD on K3s cluster (GitHub)
flux-bootstrap-github:
    #!/usr/bin/bash
    echo "╔════════════════════════════════════════════════╗"
    echo "║  FluxCD Bootstrap (GitHub)                     ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    echo "This will bootstrap FluxCD on your K3s cluster using GitHub."
    echo ""
    echo "Requirements:"
    echo "  1. K3s server must be running (ujust k3s-init-server)"
    echo "  2. GitHub repository (will be created if it doesn't exist)"
    echo "  3. GitHub personal access token with 'repo' scope"
    echo ""
    read -p "GitHub Owner (username or org): " owner
    read -p "Repository Name: " repo
    read -p "Token File Path [~/.github-token]: " token_file

    token_file=${token_file:-~/.github-token}

    if [[ -z "$owner" || -z "$repo" ]]; then
        echo "Error: Owner and repository name are required."
        exit 1
    fi

    sudo /usr/local/bin/blueberry-flux-bootstrap github \
        --owner "$owner" \
        --repository "$repo" \
        --token-file "$token_file"

# Check FluxCD status
flux-status:
    #!/usr/bin/bash
    if ! command -v flux &>/dev/null; then
        echo "FluxCD CLI not installed (this should not happen on blueberry-k3s)"
        exit 1
    fi

    echo "╔════════════════════════════════════════════════╗"
    echo "║  FluxCD Status                                 ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    # Show version
    FLUX_VERSION=$(cat /etc/blueberry-k3s/flux-version 2>/dev/null || echo "unknown")
    echo "FluxCD CLI version: $FLUX_VERSION"
    echo ""

    # Check if Flux is installed on cluster
    if flux check &>/dev/null; then
        echo "FluxCD Status: ✓ Installed"
        echo ""
        flux check
        echo ""
        echo "─── Flux Resources ─────────────────────────────────"
        kubectl get pods -n flux-system 2>/dev/null || echo "flux-system namespace not found"
    else
        echo "FluxCD Status: ✗ Not installed on cluster"
        echo ""
        echo "To bootstrap FluxCD:"
        echo "  ujust flux-bootstrap-github"
    fi

# Display FluxCD version
flux-version:
    #!/usr/bin/bash
    if [[ -f /etc/blueberry-k3s/flux-version ]]; then
        echo "FluxCD CLI version: $(cat /etc/blueberry-k3s/flux-version)"
    else
        echo "FluxCD version file not found"
    fi

    if command -v flux &>/dev/null; then
        echo ""
        flux --version
    fi
