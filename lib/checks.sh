#!/bin/bash
# =============================================================================
# distup Pre-upgrade Checks Library
# Common functions for system validation before upgrades
# =============================================================================

# Minimum disk space required (in GB)
MIN_DISK_SPACE_GB=5

# -----------------------------------------------------------------------------
# Disk Space Check
# -----------------------------------------------------------------------------

# Check if sufficient disk space is available
# Returns: 0 if OK, 1 if insufficient space
check_disk_space() {
    local mount_point="${1:-/}"
    local required_gb="${2:-$MIN_DISK_SPACE_GB}"

    local available_kb
    available_kb=$(df -k "$mount_point" | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))

    if [[ $available_gb -lt $required_gb ]]; then
        echo -e "${RED}[ERROR]${NC} Insufficient disk space on $mount_point"
        echo "  Required: ${required_gb}GB"
        echo "  Available: ${available_gb}GB"
        return 1
    fi

    echo -e "${GREEN}[OK]${NC} Disk space: ${available_gb}GB available on $mount_point"
    return 0
}

# -----------------------------------------------------------------------------
# Network Connectivity Check
# -----------------------------------------------------------------------------

# Check if network is available
# Returns: 0 if connected, 1 if no network
check_network() {
    local test_hosts=("1.1.1.1" "8.8.8.8" "9.9.9.9")

    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" &>/dev/null; then
            echo -e "${GREEN}[OK]${NC} Network connectivity verified"
            return 0
        fi
    done

    echo -e "${RED}[ERROR]${NC} No network connectivity detected"
    echo "  Please check your internet connection"
    return 1
}

# Check if a specific mirror/URL is reachable
# Usage: check_mirror "https://example.com"
check_mirror() {
    local url="$1"
    local timeout="${2:-10}"

    if command -v curl &>/dev/null; then
        if curl -s --head --connect-timeout "$timeout" "$url" &>/dev/null; then
            return 0
        fi
    elif command -v wget &>/dev/null; then
        if wget -q --spider --timeout="$timeout" "$url" &>/dev/null; then
            return 0
        fi
    fi

    echo -e "${YELLOW}[WARNING]${NC} Mirror may be unreachable: $url"
    return 1
}

# -----------------------------------------------------------------------------
# Battery Check (for laptops)
# -----------------------------------------------------------------------------

# Check battery status - warn if on battery with low charge
# Returns: 0 if OK or not a laptop, 1 if low battery warning
check_battery() {
    local min_charge="${1:-50}"

    # Check if this is a laptop with battery
    if [[ ! -d /sys/class/power_supply/BAT0 ]] && [[ ! -d /sys/class/power_supply/BAT1 ]]; then
        # No battery detected - probably a desktop/server
        return 0
    fi

    local bat_path
    if [[ -d /sys/class/power_supply/BAT0 ]]; then
        bat_path="/sys/class/power_supply/BAT0"
    else
        bat_path="/sys/class/power_supply/BAT1"
    fi

    # Check if on AC power
    local ac_online=0
    if [[ -f /sys/class/power_supply/AC/online ]]; then
        ac_online=$(cat /sys/class/power_supply/AC/online)
    elif [[ -f /sys/class/power_supply/ACAD/online ]]; then
        ac_online=$(cat /sys/class/power_supply/ACAD/online)
    fi

    if [[ "$ac_online" == "1" ]]; then
        echo -e "${GREEN}[OK]${NC} Running on AC power"
        return 0
    fi

    # Check battery level
    local capacity=100
    if [[ -f "${bat_path}/capacity" ]]; then
        capacity=$(cat "${bat_path}/capacity")
    fi

    if [[ $capacity -lt $min_charge ]]; then
        echo -e "${YELLOW}[WARNING]${NC} Running on battery with ${capacity}% charge"
        echo "  Recommend connecting to AC power before upgrading"
        echo "  Minimum recommended: ${min_charge}%"
        return 1
    fi

    echo -e "${GREEN}[OK]${NC} Battery at ${capacity}%"
    return 0
}

# -----------------------------------------------------------------------------
# Run All Pre-upgrade Checks
# -----------------------------------------------------------------------------

# Run all pre-upgrade checks
# Returns: 0 if all pass, 1 if any critical check fails
run_pre_upgrade_checks() {
    local failed=0
    local warnings=0

    echo ""
    echo "Running pre-upgrade checks..."
    echo "────────────────────────────────────────"

    # Disk space check (critical)
    if ! check_disk_space "/"; then
        failed=1
    fi

    # Network check (critical)
    if ! check_network; then
        failed=1
    fi

    # Battery check (warning only)
    if ! check_battery; then
        warnings=1
    fi

    echo "────────────────────────────────────────"

    if [[ $failed -eq 1 ]]; then
        echo ""
        echo -e "${RED}Pre-upgrade checks failed!${NC}"
        echo "Please resolve the issues above before proceeding."
        return 1
    fi

    if [[ $warnings -eq 1 ]]; then
        echo ""
        echo -e "${YELLOW}Pre-upgrade checks passed with warnings.${NC}"
        read -rp "Continue anyway? [y/N]: " continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            return 1
        fi
    else
        echo ""
        echo -e "${GREEN}All pre-upgrade checks passed!${NC}"
    fi

    return 0
}
