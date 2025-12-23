#!/bin/bash
# =============================================================================
# Script Name:    upgrade-alpine.sh
# Description:    Upgrade Alpine Linux to latest stable release or Edge
# Author:         Kris Armstrong
# Created:        2025-12-23
# Last Modified:  2025-12-23
# Version:        1.2.0
# License:        MIT
#
# Usage:          sudo ./upgrade-alpine.sh [OPTIONS] [stable|edge]
#                 sudo ./upgrade-alpine.sh              # Interactive menu
#                 sudo ./upgrade-alpine.sh stable       # Upgrade to latest stable
#                 sudo ./upgrade-alpine.sh edge         # Upgrade to Edge
#                 sudo ./upgrade-alpine.sh --dry-run    # Show what would be done
#
# Requirements:   - Alpine Linux 3.15 or later
#                 - Root/sudo privileges
#                 - Active internet connection
#                 - Sufficient disk space (~500MB recommended)
#
# Supported Paths:
#   Stable:       Latest stable Alpine release
#                 e.g., 3.18 → 3.19 → 3.20
#   Edge:         Rolling release branch (bleeding edge)
#                 Continuously updated with latest packages
#
# Notes:          - Alpine upgrades are typically fast due to small size
#                 - Edge may have occasional instability
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
LOG_FILE="/var/log/upgrade-alpine-$(date +%Y%m%d-%H%M%S).log"

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

# Alpine mirror base URL
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"

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
        echo "Usage: sudo $0 [stable|edge]"
        exit 1
    fi
}

# Check if system is Alpine
check_alpine() {
    if [[ ! -f /etc/alpine-release ]]; then
        print_error "This script is designed for Alpine Linux only"
        exit 1
    fi
}

# Get current Alpine version
get_current_version() {
    cat /etc/alpine-release | cut -d. -f1,2
}

# Get system architecture
get_arch() {
    apk --print-arch
}

# Get latest stable Alpine version
get_latest_version() {
    local arch
    arch=$(get_arch)
    wget -qO- "${ALPINE_MIRROR}/latest-stable/releases/${arch}/latest-releases.yaml" |
        grep 'version:' |
        head -1 |
        sed 's/.*version: \([0-9]*\.[0-9]*\).*/\1/'
}

# Display current system information
show_system_info() {
    print_status "Current System Information:"
    echo "  Distribution: Alpine Linux $(cat /etc/alpine-release)"
    echo "  Architecture: $(get_arch)"
    echo "  Kernel:       $(uname -r)"
    echo ""
}

# Display interactive menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "    Alpine Upgrade Script v1.2.0"
    echo "=========================================="
    echo ""
    echo "Select upgrade path:"
    echo ""
    echo "  1) Stable - Latest stable Alpine release"
    echo "             (Recommended for production)"
    echo ""
    echo "  2) Edge   - Rolling release branch"
    echo "             (Latest packages, may be unstable)"
    echo ""
    echo "  q) Quit"
    echo ""
    read -rp "Enter choice [1/2/q]: " choice

    case $choice in
        1) MODE="stable" ;;
        2) MODE="edge" ;;
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

# Backup current repositories
backup_repositories() {
    print_status "Backing up current repositories..."
    log "Backing up /etc/apk/repositories"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd cp /etc/apk/repositories /etc/apk/repositories.bak
    else
        cp /etc/apk/repositories /etc/apk/repositories.bak
    fi

    print_success "Backup saved to /etc/apk/repositories.bak"
}

# Update repositories for stable release
configure_stable_repos() {
    local version=$1

    print_status "Configuring repositories for Alpine v$version..."
    log "Setting repositories to v$version"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would write to /etc/apk/repositories:"
        echo "  ${ALPINE_MIRROR}/v${version}/main"
        echo "  ${ALPINE_MIRROR}/v${version}/community"
    else
        cat >/etc/apk/repositories <<EOF
${ALPINE_MIRROR}/v${version}/main
${ALPINE_MIRROR}/v${version}/community
EOF
    fi

    print_success "Repositories configured for v$version"
}

# Update repositories for Edge
configure_edge_repos() {
    print_status "Configuring repositories for Edge..."
    log "Setting repositories to edge"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would write to /etc/apk/repositories:"
        echo "  ${ALPINE_MIRROR}/edge/main"
        echo "  ${ALPINE_MIRROR}/edge/community"
        echo "  ${ALPINE_MIRROR}/edge/testing"
    else
        cat >/etc/apk/repositories <<EOF
${ALPINE_MIRROR}/edge/main
${ALPINE_MIRROR}/edge/community
${ALPINE_MIRROR}/edge/testing
EOF
    fi

    print_success "Repositories configured for Edge"
}

# Update package index
update_index() {
    print_status "Updating package index..."
    log "Running apk update"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd apk update
    else
        apk update 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "Package index updated"
}

# Perform system upgrade
perform_upgrade() {
    print_status "Upgrading system packages..."
    print_warning "This may take a few minutes."
    log "Running apk upgrade --available"

    if [[ "$DRY_RUN" == true ]]; then
        run_cmd apk upgrade --available
    else
        apk upgrade --available 2>&1 | tee -a "$LOG_FILE"
    fi

    print_success "System packages upgraded"
}

# Sync filesystem
sync_filesystem() {
    print_status "Syncing filesystem..."
    sync
    print_success "Filesystem synced"
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
    echo "  Distribution: Alpine Linux $(cat /etc/alpine-release)"
    echo "  Architecture: $(get_arch)"
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
        echo "Run 'reboot' when ready"
    fi
}

# Restore repositories on failure
restore_repositories() {
    if [[ -f /etc/apk/repositories.bak ]]; then
        print_warning "Restoring original repositories..."
        cp /etc/apk/repositories.bak /etc/apk/repositories
        apk update
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
                echo "upgrade-alpine.sh version 1.2.0"
                exit 0
                ;;
            --help | -h)
                echo "Usage: sudo $0 [OPTIONS] [stable|edge]"
                echo ""
                echo "Options:"
                echo "  --dry-run      Show what would be done without making changes"
                echo "  --skip-checks  Skip pre-upgrade system checks"
                echo "  --version      Show version information"
                echo "  --help         Show this help message"
                echo ""
                echo "Modes:"
                echo "  stable       Upgrade to latest stable release"
                echo "  edge         Upgrade to Edge (rolling release)"
                exit 0
                ;;
            stable | edge)
                MODE=$1
                shift
                ;;
            *)
                print_error "Invalid argument: $1"
                echo "Usage: sudo $0 [--dry-run] [stable|edge]"
                exit 1
                ;;
        esac
    done

    # Set trap to restore repos on failure
    trap restore_repositories ERR

    # Pre-flight checks
    check_root
    check_alpine

    # Run pre-upgrade system checks
    if [[ "$SKIP_CHECKS" != true && "$DRY_RUN" != true ]]; then
        if type run_pre_upgrade_checks &>/dev/null; then
            if ! run_pre_upgrade_checks; then
                exit 1
            fi
        fi
    fi

    # Initialize log
    log "=== Alpine Upgrade Script Started ==="
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

    if [[ "$MODE" == "edge" ]]; then
        TARGET="edge"
        print_warning "Edge is a rolling release and may have occasional instability!"
    else
        TARGET=$(get_latest_version)

        # Check if already at latest
        if [[ "$CURRENT" == "$TARGET" ]]; then
            print_success "Already running Alpine $CURRENT (latest stable)"
            exit 0
        fi
    fi

    echo ""
    print_status "Upgrade Plan:"
    echo "  Current: Alpine $CURRENT"
    echo "  Target:  Alpine $TARGET"
    echo ""

    # Confirm before proceeding
    read -rp "Continue with upgrade? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        exit 0
    fi

    # Execute upgrade steps
    echo ""
    backup_repositories
    echo ""

    if [[ "$MODE" == "edge" ]]; then
        configure_edge_repos
    else
        configure_stable_repos "$TARGET"
    fi

    echo ""
    update_index
    echo ""
    perform_upgrade
    echo ""
    sync_filesystem

    # Show results
    show_final_info

    log "=== Alpine Upgrade Script Completed ==="
}

# Run main function with all arguments
main "$@"
