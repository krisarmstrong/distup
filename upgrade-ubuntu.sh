#!/bin/bash
# =============================================================================
# Script Name:    upgrade-ubuntu.sh
# Description:    Upgrade Ubuntu to latest LTS or standard release
# Author:         Kris Armstrong
# Created:        2025-12-23
# Last Modified:  2025-12-23
# Version:        1.2.0
# License:        MIT
#
# Usage:          sudo ./upgrade-ubuntu.sh [OPTIONS] [lts|release]
#                 sudo ./upgrade-ubuntu.sh              # Interactive menu
#                 sudo ./upgrade-ubuntu.sh lts          # Upgrade to latest LTS
#                 sudo ./upgrade-ubuntu.sh release      # Upgrade to latest release
#                 sudo ./upgrade-ubuntu.sh --dry-run    # Show what would be done
#
# Requirements:   - Ubuntu 18.04 or later
#                 - Root/sudo privileges
#                 - Active internet connection
#                 - Sufficient disk space (~5GB recommended)
#
# Supported Paths:
#   LTS:          Long Term Support releases (5 year support)
#                 e.g., 20.04 → 22.04 → 24.04
#   Release:      All releases including interim (9 month support)
#                 e.g., 24.04 → 24.10 → 25.04 → 25.10
#
# Notes:          - System will require reboot after upgrade
#                 - Back up important data before upgrading
#                 - Release upgrades may require multiple runs (one version at a time)
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
LOG_FILE="/var/log/upgrade-ubuntu-$(date +%Y%m%d-%H%M%S).log"

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
        echo "Usage: sudo $0 [lts|release]"
        exit 1
    fi
}

# Check if system is Ubuntu
check_ubuntu() {
    if [[ ! -f /etc/os-release ]] || ! grep -q "Ubuntu" /etc/os-release; then
        print_error "This script is designed for Ubuntu only"
        exit 1
    fi
}

# Display current system information
show_system_info() {
    print_status "Current System Information:"
    echo "  Distribution: $(lsb_release -d | cut -f2)"
    echo "  Codename:     $(lsb_release -c | cut -f2)"
    echo "  Kernel:       $(uname -r)"
    echo ""
}

# Display interactive menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "    Ubuntu Upgrade Script v1.2.0"
    echo "=========================================="
    echo ""
    echo "Select upgrade path:"
    echo ""
    echo "  1) LTS     - Latest Long Term Support release"
    echo "              (Stable, 5 year support, recommended for servers)"
    echo ""
    echo "  2) Release - Latest available release"
    echo "              (Newest features, 9 month support for interim releases)"
    echo ""
    echo "  q) Quit"
    echo ""
    read -rp "Enter choice [1/2/q]: " choice

    case $choice in
        1) MODE="lts" ;;
        2) MODE="release" ;;
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
        run_cmd apt update
        run_cmd apt upgrade -y
        run_cmd apt autoremove -y
        run_cmd apt clean
    else
        # Update package lists
        apt update | tee -a "$LOG_FILE"

        # Upgrade installed packages
        apt upgrade -y | tee -a "$LOG_FILE"

        # Remove unnecessary packages
        apt autoremove -y | tee -a "$LOG_FILE"

        # Clean package cache
        apt clean | tee -a "$LOG_FILE"
    fi

    print_success "System packages updated"
}

# Install required upgrade tools
install_upgrade_tools() {
    print_status "Installing update-manager-core..."
    log "Installing upgrade tools"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd apt install update-manager-core -y
    else
        apt install update-manager-core -y | tee -a "$LOG_FILE"
    fi

    print_success "Upgrade tools installed"
}

# Configure upgrade mode (LTS or normal releases)
configure_upgrade_mode() {
    local mode=$1
    local config_file="/etc/update-manager/release-upgrades"

    print_status "Configuring upgrade mode: $mode"
    log "Setting upgrade mode to: $mode"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd cp "$config_file" "${config_file}.bak"
        if [[ "$mode" == "lts" ]]; then
            run_cmd sed -i 's/Prompt=.*/Prompt=lts/' "$config_file"
        else
            run_cmd sed -i 's/Prompt=.*/Prompt=normal/' "$config_file"
        fi
    else
        # Backup original config
        if [[ -f "$config_file" ]]; then
            cp "$config_file" "${config_file}.bak"
        fi

        # Set the appropriate prompt value
        if [[ "$mode" == "lts" ]]; then
            sed -i 's/Prompt=.*/Prompt=lts/' "$config_file"
            print_status "Configured for LTS upgrades only"
        else
            sed -i 's/Prompt=.*/Prompt=normal/' "$config_file"
            print_status "Configured for all releases"
        fi
    fi
}

# Perform the release upgrade
perform_upgrade() {
    print_status "Starting release upgrade..."
    print_warning "This process may take a while. Do not interrupt."
    log "Starting release upgrade"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd do-release-upgrade -f DistUpgradeViewNonInteractive
        return 0
    else
        # Run upgrade in non-interactive mode
        # -f DistUpgradeViewNonInteractive: Non-interactive frontend
        if do-release-upgrade -f DistUpgradeViewNonInteractive; then
            print_success "Release upgrade completed"
            return 0
        else
            # Exit code 1 can mean "no upgrade available" which is fine
            return 1
        fi
    fi
}

# Check for additional available upgrades (for release mode)
check_additional_upgrades() {
    if [[ "$MODE" == "release" ]]; then
        print_status "Checking for additional release upgrades..."

        if [[ "$DRY_RUN" == true ]]; then
            run_cmd do-release-upgrade -f DistUpgradeViewNonInteractive -c
            return
        fi

        # Loop until no more upgrades available
        while do-release-upgrade -f DistUpgradeViewNonInteractive -c 2>/dev/null; do
            print_status "Another release available, continuing upgrade..."
            log "Performing additional release upgrade"

            if ! do-release-upgrade -f DistUpgradeViewNonInteractive; then
                break
            fi
        done
    fi
}

# Display final system information
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
    echo "  Distribution: $(lsb_release -d | cut -f2)"
    echo "  Codename:     $(lsb_release -c | cut -f2)"
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
                echo "upgrade-ubuntu.sh version 1.2.0"
                exit 0
                ;;
            --help | -h)
                echo "Usage: sudo $0 [OPTIONS] [lts|release]"
                echo ""
                echo "Options:"
                echo "  --dry-run      Show what would be done without making changes"
                echo "  --skip-checks  Skip pre-upgrade system checks"
                echo "  --version      Show version information"
                echo "  --help         Show this help message"
                echo ""
                echo "Modes:"
                echo "  lts          Upgrade to latest LTS release"
                echo "  release      Upgrade to latest release (including interim)"
                exit 0
                ;;
            lts | release)
                MODE=$1
                shift
                ;;
            *)
                print_error "Invalid argument: $1"
                echo "Usage: sudo $0 [--dry-run] [lts|release]"
                exit 1
                ;;
        esac
    done

    # Pre-flight checks
    check_root
    check_ubuntu

    # Run pre-upgrade checks (unless skipped or dry-run)
    if [[ "$SKIP_CHECKS" != true && "$DRY_RUN" != true ]]; then
        if type run_pre_upgrade_checks &>/dev/null; then
            if ! run_pre_upgrade_checks; then
                exit 1
            fi
        fi
    fi

    # Initialize log
    log "=== Ubuntu Upgrade Script Started ==="
    log "Mode: $MODE"
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

    # Confirm before proceeding
    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        print_status "This will SIMULATE upgrading your system to the latest $MODE release."
    else
        print_warning "This will upgrade your system to the latest $MODE release."
    fi
    read -rp "Continue? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        exit 0
    fi

    # Execute upgrade steps
    echo ""
    update_current_system
    echo ""
    install_upgrade_tools
    echo ""
    configure_upgrade_mode "$MODE"
    echo ""
    perform_upgrade
    check_additional_upgrades

    # Show results
    show_final_info

    log "=== Ubuntu Upgrade Script Completed ==="
}

# Run main function with all arguments
main "$@"
