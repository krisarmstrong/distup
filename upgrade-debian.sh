#!/bin/bash
# =============================================================================
# Script Name:    upgrade-debian.sh
# Description:    Upgrade Debian to Stable, Testing, or Sid (Unstable)
# Author:         Kris Armstrong
# Created:        2025-12-23
# Last Modified:  2025-12-23
# Version:        1.2.0
# License:        MIT
#
# Usage:          sudo ./upgrade-debian.sh [OPTIONS] [stable|testing|sid]
#                 sudo ./upgrade-debian.sh              # Interactive menu
#                 sudo ./upgrade-debian.sh stable       # Upgrade to stable
#                 sudo ./upgrade-debian.sh testing      # Upgrade to testing
#                 sudo ./upgrade-debian.sh sid          # Upgrade to sid/unstable
#                 sudo ./upgrade-debian.sh --dry-run    # Show what would be done
#
# Requirements:   - Debian 10 (Buster) or later
#                 - Root/sudo privileges
#                 - Active internet connection
#                 - Sufficient disk space (~5GB recommended)
#
# Supported Paths:
#   Stable:       Current stable Debian release (most reliable)
#   Testing:      Next stable release in preparation (newer packages)
#   Sid:          Unstable/rolling branch (bleeding edge, may break)
#
# Notes:          - Moving to Sid is generally a one-way trip
#                 - Back up important data before upgrading
#                 - Testing and Sid are not recommended for production
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
LOG_FILE="/var/log/upgrade-debian-$(date +%Y%m%d-%H%M%S).log"

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

# Debian mirror
DEBIAN_MIRROR="http://deb.debian.org/debian"
DEBIAN_SECURITY="http://security.debian.org/debian-security"

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
        echo "Usage: sudo $0 [stable|testing|sid]"
        exit 1
    fi
}

# Check if system is Debian
check_debian() {
    if [[ ! -f /etc/debian_version ]]; then
        print_error "This script is designed for Debian only"
        exit 1
    fi

    # Make sure it's not Ubuntu or another derivative
    if [[ -f /etc/os-release ]] && grep -q "Ubuntu" /etc/os-release; then
        print_error "This script is for Debian, not Ubuntu. Use upgrade-ubuntu.sh instead."
        exit 1
    fi
}

# Display current system information
show_system_info() {
    print_status "Current System Information:"
    echo "  Distribution: Debian $(cat /etc/debian_version)"

    # Try to get codename
    if command -v lsb_release &>/dev/null; then
        echo "  Codename:     $(lsb_release -c | cut -f2)"
    fi

    echo "  Kernel:       $(uname -r)"
    echo ""
}

# Display interactive menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "    Debian Upgrade Script v1.2.0"
    echo "=========================================="
    echo ""
    echo "Select upgrade path:"
    echo ""
    echo "  1) Stable  - Current stable Debian release"
    echo "              (Most reliable, recommended for servers)"
    echo ""
    echo "  2) Testing - Next stable release in development"
    echo "              (Newer packages, mostly stable)"
    echo ""
    echo "  3) Sid     - Unstable/rolling release"
    echo "              (Bleeding edge, may break things)"
    echo ""
    echo "  q) Quit"
    echo ""
    read -rp "Enter choice [1/2/3/q]: " choice

    case $choice in
        1) MODE="stable" ;;
        2) MODE="testing" ;;
        3) MODE="sid" ;;
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

# Backup current sources.list
backup_sources() {
    print_status "Backing up current sources.list..."
    log "Backing up /etc/apt/sources.list"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd cp /etc/apt/sources.list /etc/apt/sources.list.bak
        run_cmd cp -r /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
    else
        cp /etc/apt/sources.list /etc/apt/sources.list.bak

        # Also backup sources.list.d if it exists and has files
        if [[ -d /etc/apt/sources.list.d ]] && [[ -n "$(ls -A /etc/apt/sources.list.d 2>/dev/null)" ]]; then
            cp -r /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
        fi
    fi

    print_success "Backup saved to /etc/apt/sources.list.bak"
}

# Configure repositories for stable
configure_stable_repos() {
    print_status "Configuring repositories for Stable..."
    log "Setting repositories to stable"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would write to /etc/apt/sources.list:"
        echo "  # Debian Stable"
        echo "  deb ${DEBIAN_MIRROR} stable main contrib non-free non-free-firmware"
        echo "  deb ${DEBIAN_MIRROR} stable-updates main contrib non-free non-free-firmware"
        echo "  deb ${DEBIAN_SECURITY} stable-security main contrib non-free non-free-firmware"
    else
        cat >/etc/apt/sources.list <<EOF
# Debian Stable
deb ${DEBIAN_MIRROR} stable main contrib non-free non-free-firmware
deb ${DEBIAN_MIRROR} stable-updates main contrib non-free non-free-firmware
deb ${DEBIAN_SECURITY} stable-security main contrib non-free non-free-firmware
EOF
    fi

    print_success "Repositories configured for Stable"
}

# Configure repositories for testing
configure_testing_repos() {
    print_status "Configuring repositories for Testing..."
    log "Setting repositories to testing"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would write to /etc/apt/sources.list:"
        echo "  # Debian Testing"
        echo "  deb ${DEBIAN_MIRROR} testing main contrib non-free non-free-firmware"
        echo "  deb ${DEBIAN_MIRROR} testing-updates main contrib non-free non-free-firmware"
        echo "  deb ${DEBIAN_SECURITY} testing-security main contrib non-free non-free-firmware"
    else
        cat >/etc/apt/sources.list <<EOF
# Debian Testing
deb ${DEBIAN_MIRROR} testing main contrib non-free non-free-firmware
deb ${DEBIAN_MIRROR} testing-updates main contrib non-free non-free-firmware
deb ${DEBIAN_SECURITY} testing-security main contrib non-free non-free-firmware
EOF
    fi

    print_success "Repositories configured for Testing"
}

# Configure repositories for sid
configure_sid_repos() {
    print_status "Configuring repositories for Sid (Unstable)..."
    log "Setting repositories to sid"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would write to /etc/apt/sources.list:"
        echo "  # Debian Sid (Unstable)"
        echo "  deb ${DEBIAN_MIRROR} sid main contrib non-free non-free-firmware"
    else
        # Sid has no -updates or -security repositories
        cat >/etc/apt/sources.list <<EOF
# Debian Sid (Unstable)
deb ${DEBIAN_MIRROR} sid main contrib non-free non-free-firmware
EOF
    fi

    print_success "Repositories configured for Sid"
}

# Update package index
update_index() {
    print_status "Updating package index..."
    log "Running apt update"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd apt update
    else
        apt update 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "Package index updated"
}

# Perform system upgrade
perform_upgrade() {
    print_status "Upgrading system packages..."
    print_warning "This may take a while. Do not interrupt."
    log "Running apt full-upgrade"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd apt full-upgrade -y
    else
        # Use full-upgrade for distribution upgrades
        apt full-upgrade -y 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "System packages upgraded"
}

# Clean up old packages
cleanup_packages() {
    print_status "Cleaning up old packages..."
    log "Running apt autoremove and clean"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd apt autoremove -y
        run_cmd apt clean
    else
        apt autoremove -y 2>&1 | tee -a "$LOG_FILE"
        apt clean 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "Cleanup completed"
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
    echo "  Distribution: Debian $(cat /etc/debian_version)"
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

# Restore sources on failure
restore_sources() {
    if [[ -f /etc/apt/sources.list.bak ]]; then
        print_warning "Restoring original sources.list..."
        cp /etc/apt/sources.list.bak /etc/apt/sources.list
        apt update
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
                echo "upgrade-debian.sh version 1.2.0"
                exit 0
                ;;
            --help | -h)
                echo "Usage: sudo $0 [OPTIONS] [stable|testing|sid]"
                echo ""
                echo "Options:"
                echo "  --dry-run      Show what would be done without making changes"
                echo "  --skip-checks  Skip pre-upgrade system checks"
                echo "  --version      Show version information"
                echo "  --help         Show this help message"
                echo ""
                echo "Modes:"
                echo "  stable       Upgrade to current stable release"
                echo "  testing      Upgrade to testing branch"
                echo "  sid          Upgrade to sid/unstable branch"
                exit 0
                ;;
            stable | testing | sid)
                MODE=$1
                shift
                ;;
            *)
                print_error "Invalid argument: $1"
                echo "Usage: sudo $0 [--dry-run] [stable|testing|sid]"
                exit 1
                ;;
        esac
    done

    # Set trap to restore sources on failure
    trap restore_sources ERR

    # Pre-flight checks
    check_root
    check_debian

    # Run pre-upgrade checks (unless skipped or dry-run)
    if [[ "$SKIP_CHECKS" != true && "$DRY_RUN" != true ]]; then
        if type run_pre_upgrade_checks &>/dev/null; then
            if ! run_pre_upgrade_checks; then
                exit 1
            fi
        fi
    fi

    # Initialize log
    log "=== Debian Upgrade Script Started ==="
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

    echo ""
    print_status "Upgrade Plan:"
    echo "  Target: Debian $MODE"
    echo ""

    # Extra warning for sid
    if [[ "$MODE" == "sid" ]]; then
        print_warning "=========================================="
        print_warning "WARNING: Sid is Debian's unstable branch!"
        print_warning "- Packages may be broken"
        print_warning "- Not recommended for production"
        print_warning "- Difficult to downgrade from Sid"
        print_warning "=========================================="
        echo ""
    fi

    # Confirm before proceeding
    if [[ "$DRY_RUN" == true ]]; then
        read -rp "Continue with dry run? [y/N]: " confirm
    else
        read -rp "Continue with upgrade? [y/N]: " confirm
    fi

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        exit 0
    fi

    # Execute upgrade steps
    echo ""
    backup_sources
    echo ""

    case $MODE in
        stable) configure_stable_repos ;;
        testing) configure_testing_repos ;;
        sid) configure_sid_repos ;;
    esac

    echo ""
    update_index
    echo ""
    perform_upgrade
    echo ""
    cleanup_packages

    # Show results
    show_final_info

    log "=== Debian Upgrade Script Completed ==="
}

# Run main function with all arguments
main "$@"
