#!/bin/bash
# =============================================================================
# Script Name:    upgrade-kali.sh
# Description:    Update Kali Linux rolling release or switch to bleeding-edge
# Author:         Kris Armstrong
# Created:        2025-12-23
# Last Modified:  2025-12-23
# Version:        1.2.0
# License:        MIT
#
# Usage:          sudo ./upgrade-kali.sh [OPTIONS] [rolling|bleeding-edge]
#                 sudo ./upgrade-kali.sh                 # Interactive menu
#                 sudo ./upgrade-kali.sh rolling         # Standard rolling
#                 sudo ./upgrade-kali.sh bleeding-edge   # Bleeding edge packages
#                 sudo ./upgrade-kali.sh --dry-run       # Show what would be done
#
# Requirements:   - Kali Linux 2020.1 or later
#                 - Root/sudo privileges
#                 - Active internet connection
#                 - Sufficient disk space (~5GB recommended)
#
# Supported Paths:
#   Rolling:       Standard Kali rolling release (recommended)
#   Bleeding-edge: Experimental packages from bleeding-edge repository
#
# Notes:          - Kali is a rolling release, always updating
#                 - Bleeding-edge may have untested tools
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
LOG_FILE="/var/log/upgrade-kali-$(date +%Y%m%d-%H%M%S).log"

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

# Kali mirror
KALI_MIRROR="http://http.kali.org/kali"

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
        echo "Usage: sudo $0 [rolling|bleeding-edge]"
        exit 1
    fi
}

# Check if system is Kali
check_kali() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot determine distribution"
        exit 1
    fi

    if ! grep -qi "kali" /etc/os-release; then
        print_error "This script is designed for Kali Linux only"
        exit 1
    fi
}

# Display current system information
show_system_info() {
    print_status "Current System Information:"
    echo "  Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "  Version:      $(grep VERSION= /etc/os-release | cut -d'"' -f2)"
    echo "  Kernel:       $(uname -r)"
    echo ""
}

# Display interactive menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "    Kali Linux Upgrade Script v1.2.0"
    echo "=========================================="
    echo ""
    echo "Select upgrade path:"
    echo ""
    echo "  1) Rolling       - Standard Kali rolling release"
    echo "                    (Recommended for most users)"
    echo ""
    echo "  2) Bleeding-edge - Experimental packages"
    echo "                    (May contain untested tools)"
    echo ""
    echo "  q) Quit"
    echo ""
    read -rp "Enter choice [1/2/q]: " choice

    case $choice in
        1) MODE="rolling" ;;
        2) MODE="bleeding-edge" ;;
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
    else
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
    fi

    print_success "Backup saved to /etc/apt/sources.list.bak"
}

# Configure repositories for rolling
configure_rolling_repos() {
    print_status "Configuring repositories for Rolling..."
    log "Setting repositories to kali-rolling"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would write to /etc/apt/sources.list:"
        echo "  # Kali Rolling Repository"
        echo "  deb ${KALI_MIRROR} kali-rolling main contrib non-free non-free-firmware"
    else
        cat >/etc/apt/sources.list <<EOF
# Kali Rolling Repository
deb ${KALI_MIRROR} kali-rolling main contrib non-free non-free-firmware
EOF
    fi

    print_success "Repositories configured for Rolling"
}

# Configure repositories for bleeding-edge
configure_bleeding_edge_repos() {
    print_status "Configuring repositories for Bleeding-edge..."
    log "Setting repositories to kali-rolling + kali-bleeding-edge"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would write to /etc/apt/sources.list:"
        echo "  # Kali Rolling Repository"
        echo "  deb ${KALI_MIRROR} kali-rolling main contrib non-free non-free-firmware"
        echo "  # Kali Bleeding Edge Repository (experimental)"
        echo "  deb ${KALI_MIRROR} kali-bleeding-edge main contrib non-free non-free-firmware"
    else
        cat >/etc/apt/sources.list <<EOF
# Kali Rolling Repository
deb ${KALI_MIRROR} kali-rolling main contrib non-free non-free-firmware

# Kali Bleeding Edge Repository (experimental)
deb ${KALI_MIRROR} kali-bleeding-edge main contrib non-free non-free-firmware
EOF
    fi

    print_success "Repositories configured for Rolling + Bleeding-edge"
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
    echo "  Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "  Version:      $(grep VERSION= /etc/os-release | cut -d'"' -f2)"
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
                echo "upgrade-kali.sh version 1.2.0"
                exit 0
                ;;
            --help | -h)
                echo "Usage: sudo $0 [OPTIONS] [rolling|bleeding-edge]"
                echo ""
                echo "Options:"
                echo "  --dry-run       Show what would be done without making changes"
                echo "  --skip-checks   Skip pre-upgrade system checks"
                echo "  --version       Show version information"
                echo "  --help          Show this help message"
                echo ""
                echo "Modes:"
                echo "  rolling         Standard Kali rolling release"
                echo "  bleeding-edge   Add bleeding-edge repository"
                exit 0
                ;;
            rolling | bleeding-edge)
                MODE=$1
                shift
                ;;
            *)
                print_error "Invalid argument: $1"
                echo "Usage: sudo $0 [--dry-run] [rolling|bleeding-edge]"
                exit 1
                ;;
        esac
    done

    # Set trap to restore sources on failure
    trap restore_sources ERR

    # Pre-flight checks
    check_root
    check_kali

    # Run pre-upgrade system checks
    if [[ "$SKIP_CHECKS" != true && "$DRY_RUN" != true ]]; then
        if type run_pre_upgrade_checks &>/dev/null; then
            if ! run_pre_upgrade_checks; then
                exit 1
            fi
        fi
    fi

    # Initialize log
    log "=== Kali Linux Upgrade Script Started ==="
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
    echo "  Target: Kali $MODE"
    echo ""

    # Extra warning for bleeding-edge
    if [[ "$MODE" == "bleeding-edge" ]]; then
        print_warning "=========================================="
        print_warning "WARNING: Bleeding-edge contains experimental packages!"
        print_warning "- Tools may be untested or broken"
        print_warning "- Not recommended for critical work"
        print_warning "=========================================="
        echo ""
    fi

    # Confirm before proceeding
    read -rp "Continue with upgrade? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        exit 0
    fi

    # Execute upgrade steps
    echo ""
    backup_sources
    echo ""

    case $MODE in
        rolling) configure_rolling_repos ;;
        bleeding-edge) configure_bleeding_edge_repos ;;
    esac

    echo ""
    update_index
    echo ""
    perform_upgrade
    echo ""
    cleanup_packages

    # Show results
    show_final_info

    log "=== Kali Linux Upgrade Script Completed ==="
}

# Run main function with all arguments
main "$@"
