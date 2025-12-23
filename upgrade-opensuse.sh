#!/bin/bash
# =============================================================================
# Script Name:    upgrade-opensuse.sh
# Description:    Upgrade openSUSE Leap to latest or switch to Tumbleweed
# Author:         Kris Armstrong
# Created:        2025-12-23
# Last Modified:  2025-12-23
# Version:        1.2.0
# License:        MIT
#
# Usage:          sudo ./upgrade-opensuse.sh [OPTIONS] [leap|tumbleweed]
#                 sudo ./upgrade-opensuse.sh               # Interactive menu
#                 sudo ./upgrade-opensuse.sh leap          # Latest Leap
#                 sudo ./upgrade-opensuse.sh tumbleweed    # Switch to Tumbleweed
#                 sudo ./upgrade-opensuse.sh --dry-run     # Show what would be done
#
# Requirements:   - openSUSE Leap 15.x or Tumbleweed
#                 - Root/sudo privileges
#                 - Active internet connection
#                 - Sufficient disk space (~5GB recommended)
#
# Supported Paths:
#   Leap:         Latest stable Leap release (e.g., 15.5 → 15.6)
#   Tumbleweed:   Rolling release (bleeding edge)
#
# Notes:          - Switching to Tumbleweed is generally a one-way trip
#                 - Tumbleweed receives daily updates
#                 - Back up important data before upgrading
# =============================================================================

set -e # Exit immediately if a command exits with non-zero status

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="/var/log/upgrade-opensuse-$(date +%Y%m%d-%H%M%S).log"

# Dry run mode
DRY_RUN=false

# Skip pre-upgrade checks
SKIP_CHECKS=false

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/checks.sh" ]]; then
    # shellcheck source=lib/checks.sh
    source "$SCRIPT_DIR/lib/checks.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/snapshot.sh" ]]; then
    # shellcheck source=lib/snapshot.sh
    source "$SCRIPT_DIR/lib/snapshot.sh"
fi
if [[ -f "$SCRIPT_DIR/lib/hooks.sh" ]]; then
    # shellcheck source=lib/hooks.sh
    source "$SCRIPT_DIR/lib/hooks.sh"
fi

# openSUSE mirror
OPENSUSE_MIRROR="https://download.opensuse.org"

# -----------------------------------------------------------------------------
# FUNCTIONS
# -----------------------------------------------------------------------------

# Print colored status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Log message to file and stdout
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Execute command or show in dry-run mode
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would execute: $*"
        log "[DRY-RUN] Would execute: $*"
    else
        "$@"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo "Usage: sudo $0 [leap|tumbleweed]"
        exit 1
    fi
}

# Check if system is openSUSE
check_opensuse() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot determine distribution"
        exit 1
    fi

    if ! grep -qi "opensuse" /etc/os-release; then
        print_error "This script is designed for openSUSE only"
        exit 1
    fi
}

# Detect if running Leap or Tumbleweed
detect_variant() {
    if grep -qi "tumbleweed" /etc/os-release; then
        CURRENT_VARIANT="tumbleweed"
    else
        CURRENT_VARIANT="leap"
    fi
}

# Get latest Leap version
get_latest_leap() {
    curl -s "${OPENSUSE_MIRROR}/distribution/leap/" |
        sed -n 's/.*href="\.\/\([0-9]*\.[0-9]*\)\/.*/\1/p' |
        grep -E '^1[56]\.' |
        sort -V |
        tail -1
}

# Display current system information
show_system_info() {
    print_status "Current System Information:"
    echo "  Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "  Variant:      $CURRENT_VARIANT"
    echo "  Kernel:       $(uname -r)"
    echo ""
}

# Display interactive menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "    openSUSE Upgrade Script v1.2.0"
    echo "=========================================="
    echo ""
    echo "Current: $CURRENT_VARIANT"
    echo ""
    echo "Select upgrade path:"
    echo ""
    echo "  1) Leap       - Latest stable Leap release"
    echo "                 (Recommended for servers/workstations)"
    echo ""
    echo "  2) Tumbleweed - Rolling release"
    echo "                 (Latest packages, continuous updates)"
    echo ""
    echo "  q) Quit"
    echo ""
    read -rp "Enter choice [1/2/q]: " choice

    case $choice in
        1) MODE="leap" ;;
        2) MODE="tumbleweed" ;;
        q | Q)
            echo "Exiting."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Backup repository configuration
backup_repos() {
    print_status "Backing up repository configuration..."
    log "Backing up /etc/zypp/repos.d/"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd cp -r /etc/zypp/repos.d /etc/zypp/repos.d.bak
    else
        if [[ -d /etc/zypp/repos.d ]]; then
            cp -r /etc/zypp/repos.d /etc/zypp/repos.d.bak
        fi
    fi

    print_success "Backup saved to /etc/zypp/repos.d.bak"
}

# Refresh repositories
refresh_repos() {
    print_status "Refreshing repositories..."
    log "Running zypper ref"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd zypper --non-interactive ref
    else
        zypper --non-interactive ref 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "Repositories refreshed"
}

# Upgrade to latest Leap
upgrade_to_leap() {
    local target_version
    target_version=$(get_latest_leap)

    print_status "Upgrading to openSUSE Leap $target_version..."
    log "Target: Leap $target_version"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd zypper --releasever="$target_version" ref
        run_cmd zypper --releasever="$target_version" dup --no-allow-vendor-change -y
    else
        # Change repositories to target version
        print_status "Updating repository URLs..."
        zypper --releasever="$target_version" ref 2>&1 | tee -a "$LOG_FILE"

        # Perform distribution upgrade
        print_status "Performing distribution upgrade..."
        print_warning "This may take a while. Do not interrupt."

        zypper --releasever="$target_version" dup --no-allow-vendor-change -y 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "Upgraded to Leap $target_version"
}

# Switch to Tumbleweed
switch_to_tumbleweed() {
    print_status "Switching to openSUSE Tumbleweed..."
    log "Target: Tumbleweed"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd zypper modifyrepo --disable --all
        run_cmd zypper addrepo --check --refresh --name "openSUSE-Tumbleweed-Oss" "${OPENSUSE_MIRROR}/tumbleweed/repo/oss/" repo-oss
        run_cmd zypper addrepo --check --refresh --name "openSUSE-Tumbleweed-Non-Oss" "${OPENSUSE_MIRROR}/tumbleweed/repo/non-oss/" repo-non-oss
        run_cmd zypper addrepo --check --refresh --name "openSUSE-Tumbleweed-Update" "${OPENSUSE_MIRROR}/update/tumbleweed/" repo-update
        run_cmd zypper --non-interactive ref
        run_cmd zypper dup --no-allow-vendor-change -y
    else
        # Disable all current repos
        print_status "Disabling current repositories..."
        zypper modifyrepo --disable --all 2>&1 | tee -a "$LOG_FILE"

        # Add Tumbleweed repositories
        print_status "Adding Tumbleweed repositories..."

        zypper addrepo --check --refresh --name "openSUSE-Tumbleweed-Oss" \
            "${OPENSUSE_MIRROR}/tumbleweed/repo/oss/" repo-oss 2>&1 | tee -a "$LOG_FILE" || true

        zypper addrepo --check --refresh --name "openSUSE-Tumbleweed-Non-Oss" \
            "${OPENSUSE_MIRROR}/tumbleweed/repo/non-oss/" repo-non-oss 2>&1 | tee -a "$LOG_FILE" || true

        zypper addrepo --check --refresh --name "openSUSE-Tumbleweed-Update" \
            "${OPENSUSE_MIRROR}/update/tumbleweed/" repo-update 2>&1 | tee -a "$LOG_FILE" || true

        # Refresh and upgrade
        print_status "Refreshing repositories..."
        zypper --non-interactive ref 2>&1 | tee -a "$LOG_FILE"

        print_status "Performing distribution upgrade..."
        print_warning "This may take a while. Do not interrupt."

        zypper dup --no-allow-vendor-change -y 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "Switched to Tumbleweed"
}

# Update Tumbleweed (if already on it)
update_tumbleweed() {
    print_status "Updating Tumbleweed..."
    log "Updating existing Tumbleweed"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd zypper --non-interactive ref
        run_cmd zypper dup -y
    else
        zypper --non-interactive ref 2>&1 | tee -a "$LOG_FILE"
        zypper dup -y 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "Tumbleweed updated"
}

# Display final information
show_final_info() {
    echo ""
    echo "=========================================="
    if [[ "$DRY_RUN" == true ]]; then
        echo "    Dry Run Complete"
    else
        echo "    Upgrade Complete"
    fi
    echo "=========================================="
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        print_success "Dry run completed - no changes were made"
        echo ""
        echo "  Log file:     $LOG_FILE"
        echo ""
        print_status "Run without --dry-run to perform actual upgrade"
        return
    fi

    print_success "System has been upgraded"
    echo ""
    echo "  Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "  Kernel:       $(uname -r)"
    echo ""
    echo "  Log file:     $LOG_FILE"
    echo ""
    print_warning "A system reboot is recommended"
    echo ""
    read -rp "Reboot now? [y/N]: " reboot_choice

    if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
        log "User initiated reboot"
        reboot
    else
        echo ""
        echo "Run 'sudo reboot' when ready"
    fi
}

# Restore repos on failure
restore_repos() {
    if [[ -d /etc/zypp/repos.d.bak ]]; then
        print_warning "Restoring original repositories..."
        rm -rf /etc/zypp/repos.d
        mv /etc/zypp/repos.d.bak /etc/zypp/repos.d
        zypper ref
    fi
}

# -----------------------------------------------------------------------------
# MAIN EXECUTION
# -----------------------------------------------------------------------------

main() {
    # Parse command line arguments
    MODE="menu"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-checks)
                SKIP_CHECKS=true
                shift
                ;;
            --version | -V)
                echo "upgrade-opensuse.sh version 1.2.0"
                exit 0
                ;;
            --help | -h)
                echo "Usage: sudo $0 [OPTIONS] [leap|tumbleweed]"
                echo ""
                echo "Options:"
                echo "  --dry-run      Show what would be done without making changes"
                echo "  --skip-checks  Skip pre-upgrade system checks"
                echo "  --version      Show version information"
                echo "  --help         Show this help message"
                echo ""
                echo "Modes:"
                echo "  leap           Upgrade to latest Leap release"
                echo "  tumbleweed     Switch to Tumbleweed rolling release"
                exit 0
                ;;
            leap | tumbleweed)
                MODE=$1
                shift
                ;;
            *)
                print_error "Invalid argument: $1"
                echo "Usage: sudo $0 [--dry-run] [leap|tumbleweed]"
                exit 1
                ;;
        esac
    done

    # Set trap to restore repos on failure
    trap restore_repos ERR

    # Pre-flight checks
    check_root
    check_opensuse
    detect_variant

    # Run pre-upgrade system checks
    if [[ "$SKIP_CHECKS" != true && "$DRY_RUN" != true ]]; then
        if type run_pre_upgrade_checks &>/dev/null; then
            if ! run_pre_upgrade_checks; then
                exit 1
            fi
        fi
    fi

    # Initialize log
    log "=== openSUSE Upgrade Script Started ==="
    log "Current variant: $CURRENT_VARIANT"
    [[ "$DRY_RUN" == true ]] && log "DRY RUN MODE - No changes will be made"

    # Show dry-run banner
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo -e "${YELLOW}=========================================="
        echo "           DRY RUN MODE"
        echo "    No changes will be made to system"
        echo "==========================================${NC}"
    fi

    # Show current system info
    show_system_info

    # Show menu if no argument provided
    if [[ "$MODE" == "menu" ]]; then
        show_menu
    fi

    log "Selected upgrade mode: $MODE"

    # Display target
    echo ""
    if [[ "$MODE" == "tumbleweed" ]]; then
        print_status "Upgrade Plan:"
        echo "  Current: $CURRENT_VARIANT"
        echo "  Target:  Tumbleweed (rolling)"

        if [[ "$CURRENT_VARIANT" != "tumbleweed" ]]; then
            echo ""
            print_warning "=========================================="
            print_warning "WARNING: Switching to Tumbleweed!"
            print_warning "- This is generally a one-way migration"
            print_warning "- You will receive daily updates"
            print_warning "- Not recommended for production servers"
            print_warning "=========================================="
        fi
    else
        local latest
        latest=$(get_latest_leap)
        print_status "Upgrade Plan:"
        echo "  Target: openSUSE Leap $latest"
    fi
    echo ""

    # Confirm before proceeding
    read -rp "Continue with upgrade? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        exit 0
    fi

    # Execute upgrade steps
    echo ""
    backup_repos
    echo ""
    refresh_repos
    echo ""

    if [[ "$MODE" == "tumbleweed" ]]; then
        if [[ "$CURRENT_VARIANT" == "tumbleweed" ]]; then
            update_tumbleweed
        else
            switch_to_tumbleweed
        fi
    else
        upgrade_to_leap
    fi

    # Show results
    show_final_info

    log "=== openSUSE Upgrade Script Completed ==="
}

# Run main function with all arguments
main "$@"
