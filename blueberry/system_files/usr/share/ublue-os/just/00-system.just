# System Management Tasks for Blueberry
# vim: set ft=make :

# Display system information
system-info:
    #!/usr/bin/bash
    echo "╔════════════════════════════════════════════════╗"
    echo "║     Blueberry System Information               ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    echo "Image:        $(grep PRETTY_NAME /usr/lib/os-release | cut -d= -f2 | tr -d '"')"
    echo "Kernel:       $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime:       $(uptime -p | sed 's/up //')"
    echo ""
    echo "─── Storage ────────────────────────────────────────"
    df -h / | awk 'NR==1{print "Filesystem     Size  Used Avail Use%"} NR>1{printf "%-14s %4s %5s %5s %4s\n", $1, $2, $3, $4, $5}'
    echo ""
    echo "─── Memory ─────────────────────────────────────────"
    free -h | grep -E "^Mem|^Swap" | awk '{printf "%-6s %7s total, %7s used, %7s free\n", $1, $2, $3, $4}'
    echo ""
    echo "─── Network ────────────────────────────────────────"
    ip -brief addr show | grep -v "lo " | awk '{printf "%-10s %s\n", $1, $3}'
    echo ""

# Show current image version and update status
image-info:
    #!/usr/bin/bash
    echo "╔════════════════════════════════════════════════╗"
    echo "║     Blueberry Image Information                ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    rpm-ostree status
    echo ""

# Show system logs from current boot
logs-this-boot:
    #!/usr/bin/bash
    sudo journalctl --no-hostname --no-pager -b 0

# Show system logs from previous boot
logs-last-boot:
    #!/usr/bin/bash
    sudo journalctl --no-hostname --no-pager -b -1

# Verify storage primitives are available
verify-storage-tools:
    #!/usr/bin/bash
    echo "╔════════════════════════════════════════════════╗"
    echo "║     Blueberry Storage Tool Verification        ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    tools=(smartctl hdparm mdadm cockpit-storaged)

    for tool in "${tools[@]}"; do
        if rpm -q "$tool" &>/dev/null 2>&1 || command -v "$tool" &>/dev/null 2>&1; then
            echo "✓ $tool"
        else
            echo "✗ $tool (not found)"
        fi
    done
    echo ""

    if rpm -q pcp-zeroconf &>/dev/null; then
        echo "✓ PCP (Performance Co-Pilot)"
        systemctl is-active pmcd.service pmlogger.service 2>/dev/null | sed 's/^/  /' || echo "  (services not started)"
    else
        echo "✗ PCP (not found)"
    fi
    echo ""

# Show PCP monitoring status
monitoring-status:
    #!/usr/bin/bash
    if ! rpm -q pcp-zeroconf &>/dev/null; then
        echo "PCP (Performance Co-Pilot) is not installed"
        exit 1
    fi

    echo "╔════════════════════════════════════════════════╗"
    echo "║     PCP Monitoring Status                      ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""

    systemctl status pmcd.service pmlogger.service --no-pager
    echo ""
