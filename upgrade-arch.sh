#!/bin/bash
# =============================================================================
# Script Name:    upgrade-arch.sh
# Description:    Update Arch Linux rolling release to latest packages
# Author:         Kris Armstrong
# Created:        2025-12-23
# Last Modified:  2025-12-23
# Version:        1.0.0
# License:        MIT
#
# Usage:          sudo ./upgrade-arch.sh
#                 sudo ./upgrade-arch.sh --refresh     # Force refresh mirrors
#                 sudo ./upgrade-arch.sh --clean       # Clean cache after upgrade
#
# Requirements:   - Arch Linux
#                 - Root/sudo privileges
#                 - Active internet connection
#
# Notes:          - Arch is a rolling release, always updating to latest
#                 - Review pacman output for any manual interventions
#                 - Check archlinux.org/news before major updates
#                 - Back up important data regularly
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
LOG_FILE="/var/log/upgrade-arch-$(date +%Y%m%d-%H%M%S).log"

# Options
REFRESH_MIRRORS=false
CLEAN_CACHE=false

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

# Display usage
show_usage() {
    echo "Usage: sudo $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --refresh    Force refresh package databases"
    echo "  --clean      Clean package cache after upgrade"
    echo "  --help       Show this help message"
    echo ""
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo "Usage: sudo $0"
        exit 1
    fi
}

# Check if system is Arch
check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        print_error "This script is designed for Arch Linux only"
        exit 1
    fi
}

# Display current system information
show_system_info() {
    print_status "Current System Information:"
    echo "  Distribution: Arch Linux"
    echo "  Kernel:       $(uname -r)"
    echo "  Pacman:       $(pacman -V | head -1)"
    echo ""
}

# Check for Arch news (important announcements)
check_arch_news() {
    print_status "Checking Arch Linux news for important updates..."
    
    # Try to fetch recent news headlines
    if command -v curl &> /dev/null; then
        echo ""
        echo "Recent Arch Linux News (check archlinux.org/news for details):"
        echo "---"
        curl -s "https://archlinux.org/feeds/news/" 2>/dev/null | \
            grep -oP '(?<=<title>).*(?=</title>)' | \
            head -5 || echo "  Unable to fetch news. Check archlinux.org/news manually."
        echo "---"
        echo ""
    fi
}

# Sync package databases
sync_databases() {
    print_status "Syncing package databases..."
    log "Running pacman -Syy"
    
    if [[ "$REFRESH_MIRRORS" == true ]]; then
        # Force refresh all databases
        pacman -Syy 2>&1 | tee -a "$LOG_FILE"
    else
        # Normal sync
        pacman -Sy 2>&1 | tee -a "$LOG_FILE"
    fi
    
    print_success "Package databases synced"
}

# Check for available updates
check_updates() {
    print_status "Checking for available updates..."
    
    local updates
    updates=$(pacman -Qu 2>/dev/null | wc -l)
    
    if [[ "$updates" -eq 0 ]]; then
        print_success "System is already up to date!"
        exit 0
    else
        echo "  $updates package(s) available for upgrade"
        echo ""
        
        # Show packages to be upgraded
        print_status "Packages to be upgraded:"
        pacman -Qu 2>/dev/null | head -20
        
        local total
        total=$(pacman -Qu 2>/dev/null | wc -l)
        if [[ "$total" -gt 20 ]]; then
            echo "  ... and $((total - 20)) more"
        fi
        echo ""
    fi
}

# Perform system upgrade
perform_upgrade() {
    print_status "Upgrading system packages..."
    print_warning "Review any prompts carefully. Do not interrupt."
    log "Running pacman -Syu"
    
    pacman -Syu --noconfirm 2>&1 | tee -a "$LOG_FILE"
    
    print_success "System packages upgraded"
}

# Clean package cache
clean_cache() {
    if [[ "$CLEAN_CACHE" == true ]]; then
        print_status "Cleaning package cache..."
        log "Running pacman -Sc"
        
        # Remove old package versions, keep only latest
        pacman -Sc --noconfirm 2>&1 | tee -a "$LOG_FILE"
        
        print_success "Package cache cleaned"
    fi
}

# Check for orphaned packages
check_orphans() {
    print_status "Checking for orphaned packages..."
    
    local orphans
    orphans=$(pacman -Qtdq 2>/dev/null | wc -l)
    
    if [[ "$orphans" -gt 0 ]]; then
        print_warning "Found $orphans orphaned package(s):"
        pacman -Qtdq 2>/dev/null
        echo ""
        echo "To remove orphans: sudo pacman -Rns \$(pacman -Qtdq)"
    else
        print_success "No orphaned packages found"
    fi
}

# Check for .pacnew/.pacsave files
check_pacnew() {
    print_status "Checking for .pacnew/.pacsave files..."
    
    local pacnew
    pacnew=$(find /etc -name "*.pacnew" -o -name "*.pacsave" 2>/dev/null | wc -l)
    
    if [[ "$pacnew" -gt 0 ]]; then
        print_warning "Found $pacnew configuration file(s) needing attention:"
        find /etc -name "*.pacnew" -o -name "*.pacsave" 2>/dev/null
        echo ""
        echo "Review and merge these files manually."
    else
        print_success "No .pacnew/.pacsave files found"
    fi
}

# Display final information
show_final_info() {
    echo ""
    echo "=========================================="
    echo "    Upgrade Complete"
    echo "=========================================="
    echo ""
    print_success "System has been upgraded"
    echo ""
    echo "  Distribution: Arch Linux"
    echo "  Kernel:       $(uname -r)"
    echo ""
    echo "  Log file:     $LOG_FILE"
    echo ""
    
    # Check if kernel was upgraded
    local running_kernel installed_kernel
    running_kernel=$(uname -r)
    installed_kernel=$(pacman -Q linux 2>/dev/null | awk '{print $2}' || echo "unknown")
    
    if [[ "$running_kernel" != *"$installed_kernel"* ]]; then
        print_warning "Kernel was upgraded. Reboot required!"
        echo ""
        read -p "Reboot now? [y/N]: " reboot_choice
        
        if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
            log "User initiated reboot"
            reboot
        else
            echo ""
            echo "Run 'sudo reboot' when ready"
        fi
    fi
}

# -----------------------------------------------------------------------------
# MAIN EXECUTION
# -----------------------------------------------------------------------------

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --refresh)
                REFRESH_MIRRORS=true
                shift
                ;;
            --clean)
                CLEAN_CACHE=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Pre-flight checks
    check_root
    check_arch
    
    # Initialize log
    log "=== Arch Linux Upgrade Script Started ==="
    
    echo ""
    echo "=========================================="
    echo "    Arch Linux Upgrade Script v1.0.0"
    echo "=========================================="
    echo ""
    
    # Show current system info
    show_system_info
    
    # Check Arch news
    check_arch_news
    
    # Confirm before proceeding
    read -p "Continue with system upgrade? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        exit 0
    fi
    
    # Execute upgrade steps
    echo ""
    sync_databases
    echo ""
    check_updates
    perform_upgrade
    echo ""
    clean_cache
    echo ""
    check_orphans
    echo ""
    check_pacnew
    
    # Show results
    show_final_info
    
    log "=== Arch Linux Upgrade Script Completed ==="
}

# Run main function with all arguments
main "$@"
