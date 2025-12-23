#!/bin/bash
# =============================================================================
# Script Name:    upgrade-rhel-clone.sh
# Description:    Upgrade Rocky Linux or AlmaLinux to next major version
# Author:         Kris Armstrong
# Created:        2025-12-23
# Last Modified:  2025-12-23
# Version:        1.1.0
# License:        MIT
#
# Usage:          sudo ./upgrade-rhel-clone.sh
#                 sudo ./upgrade-rhel-clone.sh --check    # Pre-upgrade check only
#                 sudo ./upgrade-rhel-clone.sh --upgrade  # Perform upgrade
#                 sudo ./upgrade-rhel-clone.sh --dry-run  # Show what would be done
#
# Requirements:   - Rocky Linux 8+ or AlmaLinux 8+
#                 - Root/sudo privileges
#                 - Active internet connection
#                 - Sufficient disk space (~5GB recommended)
#
# Supported Paths:
#   EL8 → EL9:    Major version upgrade using ELevate project
#
# Notes:          - Major version upgrades require careful planning
#                 - Review /var/log/leapp/leapp-report.txt before proceeding
#                 - Back up all data before upgrading
#                 - Test in non-production environment first
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
LOG_FILE="/var/log/upgrade-rhel-clone-$(date +%Y%m%d-%H%M%S).log"

# Operation mode
CHECK_ONLY=false
UPGRADE_NOW=false
DRY_RUN=false

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
    echo "  --check      Run pre-upgrade check only (recommended first)"
    echo "  --upgrade    Perform the actual upgrade"
    echo "  --dry-run    Show what would be done without making changes"
    echo "  --version    Show version information"
    echo "  --help       Show this help message"
    echo ""
    echo "Recommended workflow:"
    echo "  1. sudo $0 --check      # Review the report"
    echo "  2. sudo $0 --upgrade    # Perform upgrade after review"
    echo ""
}

# Display version
show_version() {
    echo "upgrade-rhel-clone.sh version 1.1.0"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo "Usage: sudo $0 [--check|--upgrade]"
        exit 1
    fi
}

# Detect distribution (Rocky or Alma)
detect_distro() {
    if [[ -f /etc/rocky-release ]]; then
        DISTRO="rocky"
        DISTRO_NAME="Rocky Linux"
    elif [[ -f /etc/almalinux-release ]]; then
        DISTRO="alma"
        DISTRO_NAME="AlmaLinux"
    else
        print_error "This script supports Rocky Linux and AlmaLinux only"
        exit 1
    fi
}

# Get current EL version
get_current_version() {
    rpm -E %rhel
}

# Display current system information
show_system_info() {
    print_status "Current System Information:"
    echo "  Distribution: $DISTRO_NAME"
    echo "  Version:      EL$(get_current_version)"
    echo "  Kernel:       $(uname -r)"
    echo ""
}

# Backup repository configuration
backup_repos() {
    print_status "Backing up repository configuration..."
    log "Backing up /etc/yum.repos.d/"

    local backup_dir
    backup_dir="/etc/yum.repos.d.backup-$(date +%Y%m%d-%H%M%S)"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd cp -r /etc/yum.repos.d "$backup_dir"
    else
        cp -r /etc/yum.repos.d "$backup_dir"
        # Store backup location for potential restore
        echo "$backup_dir" >/tmp/rhel-clone-upgrade-backup-location
    fi

    print_success "Backup saved to $backup_dir"
}

# Restore repository configuration on failure
restore_repos() {
    if [[ -f /tmp/rhel-clone-upgrade-backup-location ]]; then
        local backup_dir
        backup_dir=$(cat /tmp/rhel-clone-upgrade-backup-location)
        if [[ -d "$backup_dir" ]]; then
            print_warning "Restoring repository configuration from backup..."
            rm -rf /etc/yum.repos.d
            mv "$backup_dir" /etc/yum.repos.d
            dnf clean all
            print_success "Repositories restored from $backup_dir"
        fi
    fi
}

# Update current system
update_current_system() {
    print_status "Updating current system packages..."
    log "Running dnf upgrade"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd dnf upgrade --refresh -y
    else
        dnf upgrade --refresh -y 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "System packages updated"
}

# Install ELevate tools
install_elevate() {
    local current_ver
    current_ver=$(get_current_version)

    print_status "Installing ELevate upgrade tools..."
    log "Installing elevate-release and leapp packages"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd dnf install -y "https://repo.almalinux.org/elevate/elevate-release-latest-el${current_ver}.noarch.rpm"
        run_cmd dnf install -y leapp-upgrade "leapp-data-${DISTRO}"
    else
        # Install ELevate repository
        dnf install -y "https://repo.almalinux.org/elevate/elevate-release-latest-el${current_ver}.noarch.rpm" 2>&1 | tee -a "$LOG_FILE"

        # Install leapp upgrade tools with distro-specific data
        dnf install -y leapp-upgrade "leapp-data-${DISTRO}" 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "ELevate tools installed"
}

# Run pre-upgrade check
run_preupgrade_check() {
    print_status "Running pre-upgrade check..."
    print_warning "This may take several minutes..."
    log "Running leapp preupgrade"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd leapp preupgrade
        echo ""
        echo "=========================================="
        echo "    Pre-upgrade Report (Dry Run)"
        echo "=========================================="
        echo ""
        print_status "In actual run, would display report from /var/log/leapp/leapp-report.txt"
        return
    fi

    # Run the preupgrade assessment
    if leapp preupgrade 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Pre-upgrade check completed successfully"
    else
        print_warning "Pre-upgrade check completed with warnings/errors"
    fi

    echo ""
    echo "=========================================="
    echo "    Pre-upgrade Report"
    echo "=========================================="
    echo ""

    if [[ -f /var/log/leapp/leapp-report.txt ]]; then
        print_status "Summary from /var/log/leapp/leapp-report.txt:"
        echo ""

        # Count issues by severity
        local high medium low
        high=$(grep -c "high" /var/log/leapp/leapp-report.txt 2>/dev/null || echo "0")
        medium=$(grep -c "medium" /var/log/leapp/leapp-report.txt 2>/dev/null || echo "0")
        low=$(grep -c "low" /var/log/leapp/leapp-report.txt 2>/dev/null || echo "0")

        echo "  High severity issues:   $high"
        echo "  Medium severity issues: $medium"
        echo "  Low severity issues:    $low"
        echo ""
        echo "  Full report: /var/log/leapp/leapp-report.txt"
        echo ""

        if [[ "$high" -gt 0 ]]; then
            print_error "High severity issues must be resolved before upgrading!"
            echo ""
            echo "High severity issues:"
            grep -A2 "high" /var/log/leapp/leapp-report.txt | head -20
        fi
    else
        print_warning "No report file found. Check leapp output above."
    fi
}

# Perform the actual upgrade
perform_upgrade() {
    print_status "Starting system upgrade..."

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "=========================================="
        print_warning "DRY RUN: Would display upgrade warnings here"
        print_warning "=========================================="
        echo ""
        run_cmd leapp upgrade
        run_cmd reboot
        return
    fi

    print_warning "=========================================="
    print_warning "WARNING: This will upgrade to the next major version!"
    print_warning "- System will reboot during upgrade"
    print_warning "- Process may take 30-60 minutes"
    print_warning "- Do NOT interrupt the upgrade"
    print_warning "=========================================="
    echo ""

    read -rp "Are you sure you want to proceed? [yes/NO]: " confirm

    if [[ "$confirm" != "yes" ]]; then
        echo "Upgrade cancelled. (Type 'yes' to confirm)"
        exit 0
    fi

    log "User confirmed upgrade - starting leapp upgrade"

    # Run the upgrade
    leapp upgrade 2>&1 | tee -a "$LOG_FILE"

    echo ""
    print_success "Upgrade preparation completed!"
    echo ""
    print_warning "System will now reboot to complete the upgrade."
    print_warning "DO NOT power off during the upgrade process."
    echo ""

    read -rp "Reboot now to complete upgrade? [y/N]: " reboot_choice

    if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
        log "User initiated reboot for upgrade"
        reboot
    else
        echo ""
        print_status "Run 'sudo reboot' when ready to complete the upgrade."
    fi
}

# Display final information
show_final_info() {
    echo ""
    echo "=========================================="
    echo "    Current System Status"
    echo "=========================================="
    echo ""
    echo "  Distribution: $DISTRO_NAME"
    echo "  Version:      EL$(get_current_version)"
    echo "  Kernel:       $(uname -r)"
    echo ""
    echo "  Log file:     $LOG_FILE"
    echo ""
}

# Interactive menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "    RHEL Clone Upgrade Script v1.1.0"
    echo "=========================================="
    echo ""
    echo "Detected: $DISTRO_NAME EL$(get_current_version)"
    echo "Target:   $DISTRO_NAME EL$(($(get_current_version) + 1))"
    echo ""
    echo "Select operation:"
    echo ""
    echo "  1) Pre-upgrade check (recommended first)"
    echo "     Analyzes system and reports potential issues"
    echo ""
    echo "  2) Perform upgrade"
    echo "     Upgrades to next major version"
    echo ""
    echo "  q) Quit"
    echo ""
    read -rp "Enter choice [1/2/q]: " choice

    case $choice in
        1) CHECK_ONLY=true ;;
        2) UPGRADE_NOW=true ;;
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

# -----------------------------------------------------------------------------
# MAIN EXECUTION
# -----------------------------------------------------------------------------

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                CHECK_ONLY=true
                shift
                ;;
            --upgrade)
                UPGRADE_NOW=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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

    # Set trap to restore repos on failure
    trap restore_repos ERR

    # Pre-flight checks
    check_root
    detect_distro

    # Initialize log
    log "=== RHEL Clone Upgrade Script Started ==="
    log "Detected: $DISTRO_NAME"
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

    # Show menu if no arguments provided
    if [[ "$CHECK_ONLY" == false && "$UPGRADE_NOW" == false && "$DRY_RUN" == false ]]; then
        show_menu
    fi

    # Execute requested operation
    echo ""
    backup_repos
    echo ""
    update_current_system
    echo ""
    install_elevate
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        run_preupgrade_check
        echo ""
        echo "=========================================="
        echo "    Dry Run Complete"
        echo "=========================================="
        echo ""
        print_success "Dry run completed - no changes were made"
        echo ""
        echo "  Log file:     $LOG_FILE"
        echo ""
        print_status "Run without --dry-run to perform actual operations"
    elif [[ "$CHECK_ONLY" == true ]]; then
        run_preupgrade_check
        echo ""
        print_status "Next step: Review the report, resolve issues, then run:"
        echo "  sudo $0 --upgrade"
    elif [[ "$UPGRADE_NOW" == true ]]; then
        run_preupgrade_check
        echo ""
        perform_upgrade
    fi

    log "=== RHEL Clone Upgrade Script Completed ==="
}

# Run main function with all arguments
main "$@"
