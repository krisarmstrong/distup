#!/bin/bash
# =============================================================================
# Script Name:    upgrade-ubuntu.sh
# Description:    Upgrade Ubuntu to latest LTS or standard release
# Author:         Kris Armstrong
# Created:        2025-12-23
# Last Modified:  2025-12-23
# Version:        1.0.0
# License:        MIT
#
# Usage:          sudo ./upgrade-ubuntu.sh [lts|release]
#                 sudo ./upgrade-ubuntu.sh              # Interactive menu
#                 sudo ./upgrade-ubuntu.sh lts          # Upgrade to latest LTS
#                 sudo ./upgrade-ubuntu.sh release      # Upgrade to latest release
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

set -e  # Exit immediately if a command exits with non-zero status

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
    echo "    Ubuntu Upgrade Script v1.0.0"
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
    read -p "Enter choice [1/2/q]: " choice
    
    case $choice in
        1) MODE="lts" ;;
        2) MODE="release" ;;
        q|Q) echo "Exiting."; exit 0 ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac
}

# Update current system packages
update_current_system() {
    print_status "Updating current system packages..."
    log "Starting system update"
    
    # Update package lists
    apt update | tee -a "$LOG_FILE"
    
    # Upgrade installed packages
    apt upgrade -y | tee -a "$LOG_FILE"
    
    # Remove unnecessary packages
    apt autoremove -y | tee -a "$LOG_FILE"
    
    # Clean package cache
    apt clean | tee -a "$LOG_FILE"
    
    print_success "System packages updated"
}

# Install required upgrade tools
install_upgrade_tools() {
    print_status "Installing update-manager-core..."
    log "Installing upgrade tools"
    
    apt install update-manager-core -y | tee -a "$LOG_FILE"
    
    print_success "Upgrade tools installed"
}

# Configure upgrade mode (LTS or normal releases)
configure_upgrade_mode() {
    local mode=$1
    local config_file="/etc/update-manager/release-upgrades"
    
    print_status "Configuring upgrade mode: $mode"
    log "Setting upgrade mode to: $mode"
    
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
}

# Perform the release upgrade
perform_upgrade() {
    print_status "Starting release upgrade..."
    print_warning "This process may take a while. Do not interrupt."
    log "Starting release upgrade"
    
    # Run upgrade in non-interactive mode
    # -f DistUpgradeViewNonInteractive: Non-interactive frontend
    if do-release-upgrade -f DistUpgradeViewNonInteractive; then
        print_success "Release upgrade completed"
        return 0
    else
        # Exit code 1 can mean "no upgrade available" which is fine
        return 1
    fi
}

# Check for additional available upgrades (for release mode)
check_additional_upgrades() {
    if [[ "$MODE" == "release" ]]; then
        print_status "Checking for additional release upgrades..."
        
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
    echo "    Upgrade Complete"
    echo "=========================================="
    echo ""
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
    read -p "Reboot now? [y/N]: " reboot_choice
    
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
    # Parse command line argument
    MODE=${1:-menu}
    
    # Validate mode if provided
    if [[ "$MODE" != "menu" && "$MODE" != "lts" && "$MODE" != "release" ]]; then
        print_error "Invalid argument: $MODE"
        echo "Usage: sudo $0 [lts|release]"
        exit 1
    fi
    
    # Pre-flight checks
    check_root
    check_ubuntu
    
    # Initialize log
    log "=== Ubuntu Upgrade Script Started ==="
    log "Mode: $MODE"
    
    # Show current system info
    show_system_info
    
    # Show menu if no argument provided
    if [[ "$MODE" == "menu" ]]; then
        show_menu
    fi
    
    log "Selected upgrade mode: $MODE"
    
    # Confirm before proceeding
    echo ""
    print_warning "This will upgrade your system to the latest $MODE release."
    read -p "Continue? [y/N]: " confirm
    
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
