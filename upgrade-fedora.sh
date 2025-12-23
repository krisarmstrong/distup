#!/bin/bash
# =============================================================================
# Script Name:    upgrade-fedora.sh
# Description:    Upgrade Fedora to latest stable release or Rawhide
# Author:         Kris Armstrong
# Created:        2025-12-23
# Last Modified:  2025-12-23
# Version:        1.1.0
# License:        MIT
#
# Usage:          sudo ./upgrade-fedora.sh [OPTIONS] [stable|rawhide]
#                 sudo ./upgrade-fedora.sh              # Interactive menu
#                 sudo ./upgrade-fedora.sh stable       # Upgrade to latest stable
#                 sudo ./upgrade-fedora.sh rawhide      # Upgrade to Rawhide
#                 sudo ./upgrade-fedora.sh --dry-run    # Show what would be done
#
# Requirements:   - Fedora 35 or later
#                 - Root/sudo privileges
#                 - Active internet connection
#                 - Sufficient disk space (~5GB recommended)
#
# Supported Paths:
#   Stable:       Latest stable Fedora release
#                 e.g., 41 → 42 → 43
#   Rawhide:      Rolling development branch (bleeding edge)
#                 Continuously updated, may be unstable
#
# Notes:          - System will reboot automatically during upgrade
#                 - Rawhide is for testing only, not production
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
LOG_FILE="/var/log/upgrade-fedora-$(date +%Y%m%d-%H%M%S).log"

# Dry run mode
DRY_RUN=false

# URL to check for latest Fedora release
FEDORA_RELEASES_URL="https://dl.fedoraproject.org/pub/fedora/linux/releases/"

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
        echo "Usage: sudo $0 [stable|rawhide]"
        exit 1
    fi
}

# Check if system is Fedora
check_fedora() {
    if [[ ! -f /etc/fedora-release ]]; then
        print_error "This script is designed for Fedora only"
        exit 1
    fi
}

# Get current Fedora version
get_current_version() {
    rpm -E %fedora
}

# Get latest stable Fedora version from mirror
get_latest_version() {
    curl -s "$FEDORA_RELEASES_URL" |
        grep -oP 'href="\K[0-9]+(?=/")' |
        sort -n |
        tail -1
}

# Display current system information
show_system_info() {
    print_status "Current System Information:"
    echo "  Distribution: $(cat /etc/fedora-release)"
    echo "  Version:      Fedora $(get_current_version)"
    echo "  Kernel:       $(uname -r)"
    echo ""
}

# Display interactive menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "    Fedora Upgrade Script v1.1.0"
    echo "=========================================="
    echo ""
    echo "Select upgrade path:"
    echo ""
    echo "  1) Stable  - Latest stable Fedora release"
    echo "              (Recommended for most users)"
    echo ""
    echo "  2) Rawhide - Rolling development branch"
    echo "              (Bleeding edge, may be unstable)"
    echo ""
    echo "  q) Quit"
    echo ""
    read -rp "Enter choice [1/2/q]: " choice

    case $choice in
        1) MODE="stable" ;;
        2) MODE="rawhide" ;;
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

# Update current system packages
update_current_system() {
    print_status "Updating current system packages..."
    log "Starting system update"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd dnf upgrade --refresh -y
    else
        # Refresh metadata and upgrade
        dnf upgrade --refresh -y 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "System packages updated"
}

# Install system upgrade plugin
install_upgrade_plugin() {
    print_status "Installing DNF system upgrade plugin..."
    log "Installing dnf-plugin-system-upgrade"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd dnf install dnf-plugin-system-upgrade -y
    else
        dnf install dnf-plugin-system-upgrade -y 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "Upgrade plugin installed"
}

# Download upgrade packages
download_upgrade() {
    local target=$1

    print_status "Downloading Fedora $target packages..."
    print_warning "This may take a while depending on your connection."
    log "Downloading packages for Fedora $target"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd dnf system-upgrade download --releasever="$target" -y
    else
        # Download all packages needed for upgrade
        dnf system-upgrade download --releasever="$target" -y 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "Download completed"
}

# Perform the system upgrade (triggers reboot)
perform_upgrade() {
    echo ""
    echo "=========================================="
    if [[ "$DRY_RUN" == true ]]; then
        echo "    Dry Run Complete"
    else
        echo "    Ready to Upgrade"
    fi
    echo "=========================================="
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        print_success "Dry run completed - no changes were made"
        echo ""
        run_cmd dnf system-upgrade reboot
        echo ""
        echo "  Log file:     $LOG_FILE"
        echo ""
        print_status "Run without --dry-run to perform actual upgrade"
        return
    fi

    print_warning "The system will reboot to complete the upgrade."
    print_warning "This process may take 30-60 minutes."
    print_warning "Do not power off during the upgrade."
    echo ""

    read -rp "Proceed with upgrade and reboot? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log "User confirmed reboot for upgrade"
        print_status "Starting upgrade process..."

        # Trigger the upgrade (system will reboot)
        dnf system-upgrade reboot
    else
        echo ""
        print_status "Upgrade postponed."
        echo "Packages have been downloaded. To continue later, run:"
        echo "  sudo dnf system-upgrade reboot"
        echo ""
        log "User postponed reboot"
    fi
}

# Display final information (for already-upgraded systems)
show_final_info() {
    echo ""
    echo "=========================================="
    echo "    System Information"
    echo "=========================================="
    echo ""
    echo "  Distribution: $(cat /etc/fedora-release)"
    echo "  Kernel:       $(uname -r)"
    echo ""
    echo "  Log file:     $LOG_FILE"
    echo ""
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
            --version | -V)
                echo "upgrade-fedora.sh version 1.1.0"
                exit 0
                ;;
            --help | -h)
                echo "Usage: sudo $0 [OPTIONS] [stable|rawhide]"
                echo ""
                echo "Options:"
                echo "  --dry-run    Show what would be done without making changes"
                echo "  --version    Show version information"
                echo "  --help       Show this help message"
                echo ""
                echo "Modes:"
                echo "  stable       Upgrade to latest stable release"
                echo "  rawhide      Upgrade to Rawhide (rolling development)"
                exit 0
                ;;
            stable | rawhide)
                MODE=$1
                shift
                ;;
            *)
                print_error "Invalid argument: $1"
                echo "Usage: sudo $0 [--dry-run] [stable|rawhide]"
                exit 1
                ;;
        esac
    done

    # Pre-flight checks
    check_root
    check_fedora

    # Initialize log
    log "=== Fedora Upgrade Script Started ==="
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

    # Determine target version
    CURRENT=$(get_current_version)

    if [[ "$MODE" == "rawhide" ]]; then
        TARGET="rawhide"
        print_warning "Rawhide is a development branch and may be unstable!"
    else
        TARGET=$(get_latest_version)

        # Check if already at latest
        if [[ "$CURRENT" -ge "$TARGET" ]]; then
            print_success "Already running Fedora $CURRENT (latest stable)"
            exit 0
        fi
    fi

    echo ""
    print_status "Upgrade Plan:"
    echo "  Current: Fedora $CURRENT"
    echo "  Target:  Fedora $TARGET"
    echo ""

    # Confirm before proceeding
    read -rp "Continue with upgrade? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        exit 0
    fi

    # Execute upgrade steps
    echo ""
    update_current_system
    echo ""
    install_upgrade_plugin
    echo ""
    download_upgrade "$TARGET"
    echo ""
    perform_upgrade

    log "=== Fedora Upgrade Script Completed ==="
}

# Run main function with all arguments
main "$@"
