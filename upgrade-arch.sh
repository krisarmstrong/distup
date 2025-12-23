#!/bin/bash
# =============================================================================
# Script Name:    upgrade-arch.sh
# Description:    Update Arch Linux rolling release to latest packages
# Author:         Kris Armstrong
# Created:        2025-12-23
# Last Modified:  2025-12-23
# Version:        1.2.0
# License:        MIT
#
# Usage:          sudo ./upgrade-arch.sh
#                 sudo ./upgrade-arch.sh --refresh     # Force refresh mirrors
#                 sudo ./upgrade-arch.sh --clean       # Clean cache after upgrade
#                 sudo ./upgrade-arch.sh --dry-run     # Show what would be done
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
LOG_FILE="/var/log/upgrade-arch-$(date +%Y%m%d-%H%M%S).log"

# Options
REFRESH_MIRRORS=false
CLEAN_CACHE=false
DRY_RUN=false
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

# Display usage
show_usage() {
    echo "Usage: sudo $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --refresh      Force refresh package databases"
    echo "  --clean        Clean package cache after upgrade"
    echo "  --dry-run      Show what would be done without making changes"
    echo "  --skip-checks  Skip pre-upgrade system checks"
    echo "  --version      Show version information"
    echo "  --help         Show this help message"
    echo ""
}

# Display version
show_version() {
    echo "upgrade-arch.sh version 1.2.0"
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

# Display interactive menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "    Arch Linux Upgrade Script v1.2.0"
    echo "=========================================="
    echo ""
    echo "Select upgrade options:"
    echo ""
    echo "  1) Standard upgrade"
    echo "     Update all packages to latest versions"
    echo ""
    echo "  2) Refresh + Upgrade"
    echo "     Force refresh mirrors, then upgrade"
    echo ""
    echo "  3) Upgrade + Clean"
    echo "     Upgrade and clean package cache"
    echo ""
    echo "  4) Full maintenance"
    echo "     Refresh mirrors, upgrade, and clean cache"
    echo ""
    echo "  q) Quit"
    echo ""
    read -rp "Enter choice [1/2/3/4/q]: " choice

    case $choice in
        1) ;; # defaults are fine
        2) REFRESH_MIRRORS=true ;;
        3) CLEAN_CACHE=true ;;
        4)
            REFRESH_MIRRORS=true
            CLEAN_CACHE=true
            ;;
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

# Backup pacman configuration
backup_pacman_config() {
    print_status "Backing up pacman configuration..."
    log "Backing up /etc/pacman.conf and /etc/pacman.d/mirrorlist"

    local backup_dir
    backup_dir="/etc/pacman.d/backup-$(date +%Y%m%d-%H%M%S)"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd mkdir -p "$backup_dir"
        run_cmd cp /etc/pacman.conf "$backup_dir/"
        run_cmd cp /etc/pacman.d/mirrorlist "$backup_dir/"
    else
        mkdir -p "$backup_dir"
        cp /etc/pacman.conf "$backup_dir/"
        cp /etc/pacman.d/mirrorlist "$backup_dir/"
        # Store backup location for potential restore
        echo "$backup_dir" >/tmp/arch-upgrade-backup-location
    fi

    print_success "Backup saved to $backup_dir"
}

# Restore pacman configuration on failure
restore_pacman_config() {
    if [[ -f /tmp/arch-upgrade-backup-location ]]; then
        local backup_dir
        backup_dir=$(cat /tmp/arch-upgrade-backup-location)
        if [[ -d "$backup_dir" ]]; then
            print_warning "Restoring pacman configuration from backup..."
            cp "$backup_dir/pacman.conf" /etc/pacman.conf
            cp "$backup_dir/mirrorlist" /etc/pacman.d/mirrorlist
            pacman -Sy
            print_success "Configuration restored from $backup_dir"
        fi
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
    if command -v curl &>/dev/null; then
        echo ""
        echo "Recent Arch Linux News (check archlinux.org/news for details):"
        echo "---"
        curl -s "https://archlinux.org/feeds/news/" 2>/dev/null |
            sed -n 's/.*<title>\([^<]*\)<\/title>.*/\1/p' |
            head -5 || echo "  Unable to fetch news. Check archlinux.org/news manually."
        echo "---"
        echo ""
    fi
}

# Sync package databases
sync_databases() {
    print_status "Syncing package databases..."
    log "Running pacman -Syy"

    if [[ "$DRY_RUN" == true ]]; then
        if [[ "$REFRESH_MIRRORS" == true ]]; then
            run_cmd pacman -Syy
        else
            run_cmd pacman -Sy
        fi
    else
        if [[ "$REFRESH_MIRRORS" == true ]]; then
            # Force refresh all databases
            pacman -Syy 2>&1 | tee -a "$LOG_FILE"
        else
            # Normal sync
            pacman -Sy 2>&1 | tee -a "$LOG_FILE"
        fi
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

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd pacman -Syu --noconfirm
    else
        pacman -Syu --noconfirm 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "System packages upgraded"
}

# Clean package cache
clean_cache() {
    if [[ "$CLEAN_CACHE" == true ]]; then
        print_status "Cleaning package cache..."
        log "Running pacman -Sc"

        if [[ "$DRY_RUN" == true ]]; then
            run_cmd pacman -Sc --noconfirm
        else
            # Remove old package versions, keep only latest
            pacman -Sc --noconfirm 2>&1 | tee -a "$LOG_FILE"
        fi

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
        read -rp "Reboot now? [y/N]: " reboot_choice

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
    # Track if any options were provided
    local has_options=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --refresh)
                REFRESH_MIRRORS=true
                has_options=true
                shift
                ;;
            --clean)
                CLEAN_CACHE=true
                has_options=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-checks)
                SKIP_CHECKS=true
                shift
                ;;
            --version | -V)
                show_version
                exit 0
                ;;
            --help | -h)
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

    # Set trap to restore config on failure
    trap restore_pacman_config ERR

    # Pre-flight checks
    check_root
    check_arch

    # Run pre-upgrade system checks
    if [[ "$SKIP_CHECKS" != true && "$DRY_RUN" != true ]]; then
        if type run_pre_upgrade_checks &>/dev/null; then
            if ! run_pre_upgrade_checks; then
                exit 1
            fi
        fi
    fi

    # Initialize log
    log "=== Arch Linux Upgrade Script Started ==="
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

    # Show menu if no options provided (excluding --dry-run)
    if [[ "$has_options" == false && "$DRY_RUN" == false ]]; then
        show_menu
    elif [[ "$has_options" == false && "$DRY_RUN" == true ]]; then
        # In dry-run mode without options, show what standard upgrade would do
        echo ""
        echo "=========================================="
        echo "    Arch Linux Upgrade Script v1.2.0"
        echo "=========================================="
        echo ""
    fi

    # Check Arch news
    check_arch_news

    # Confirm before proceeding
    read -rp "Continue with system upgrade? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        exit 0
    fi

    # Execute upgrade steps
    echo ""
    backup_pacman_config
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
