#!/bin/bash
# =============================================================================
# Library:       hooks.sh
# Description:   Pre and post-upgrade hook functions for distup scripts
# Author:        Kris Armstrong
# Created:       2025-12-23
# Version:       1.2.0
# License:       MIT
#
# Hook Locations:
#   /etc/distup/hooks.d/pre-upgrade.d/   - Scripts run before upgrade
#   /etc/distup/hooks.d/post-upgrade.d/  - Scripts run after upgrade
#   ~/.config/distup/hooks.d/            - User-specific hooks
#
# Usage:
#   source lib/hooks.sh
#   run_pre_upgrade_hooks
#   # ... perform upgrade ...
#   run_post_upgrade_hooks
# =============================================================================

# Hook directories
SYSTEM_HOOKS_DIR="/etc/distup/hooks.d"
USER_HOOKS_DIR="${HOME}/.config/distup/hooks.d"

# Run hooks from a directory
run_hooks_from_dir() {
    local hook_dir="$1"
    local hook_type="$2"

    if [[ ! -d "$hook_dir" ]]; then
        return 0
    fi

    local hook_count=0
    local failed_count=0

    for hook in "$hook_dir"/*.sh; do
        [[ -f "$hook" ]] || continue
        [[ -x "$hook" ]] || continue

        hook_count=$((hook_count + 1))
        local hook_name
        hook_name=$(basename "$hook")

        echo -e "${BLUE}[HOOK]${NC} Running $hook_type hook: $hook_name"

        if "$hook"; then
            echo -e "${GREEN}[OK]${NC} $hook_name completed"
        else
            echo -e "${YELLOW}[WARNING]${NC} $hook_name failed (exit code: $?)"
            failed_count=$((failed_count + 1))
        fi
    done

    if [[ $hook_count -eq 0 ]]; then
        echo -e "${BLUE}[INFO]${NC} No $hook_type hooks found"
    elif [[ $failed_count -gt 0 ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $failed_count of $hook_count $hook_type hooks failed"
    else
        echo -e "${GREEN}[OK]${NC} All $hook_count $hook_type hooks completed"
    fi

    return 0
}

# Run pre-upgrade hooks
run_pre_upgrade_hooks() {
    echo ""
    echo -e "${BLUE}[INFO]${NC} Running pre-upgrade hooks..."

    # System hooks
    run_hooks_from_dir "$SYSTEM_HOOKS_DIR/pre-upgrade.d" "pre-upgrade"

    # User hooks
    if [[ -n "$SUDO_USER" ]]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        run_hooks_from_dir "$user_home/.config/distup/hooks.d/pre-upgrade.d" "pre-upgrade"
    fi

    echo ""
}

# Run post-upgrade hooks
run_post_upgrade_hooks() {
    echo ""
    echo -e "${BLUE}[INFO]${NC} Running post-upgrade hooks..."

    # System hooks
    run_hooks_from_dir "$SYSTEM_HOOKS_DIR/post-upgrade.d" "post-upgrade"

    # User hooks
    if [[ -n "$SUDO_USER" ]]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        run_hooks_from_dir "$user_home/.config/distup/hooks.d/post-upgrade.d" "post-upgrade"
    fi

    echo ""
}

# Check if hooks are configured
check_hooks_exist() {
    local hook_type="$1"
    local found=false

    if [[ -d "$SYSTEM_HOOKS_DIR/${hook_type}.d" ]]; then
        local count
        count=$(find "$SYSTEM_HOOKS_DIR/${hook_type}.d" -name "*.sh" -executable 2>/dev/null | wc -l)
        [[ $count -gt 0 ]] && found=true
    fi

    if [[ -n "$SUDO_USER" ]]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ -d "$user_home/.config/distup/hooks.d/${hook_type}.d" ]]; then
            local count
            count=$(find "$user_home/.config/distup/hooks.d/${hook_type}.d" -name "*.sh" -executable 2>/dev/null | wc -l)
            [[ $count -gt 0 ]] && found=true
        fi
    fi

    $found
}

# Initialize hook directories
init_hook_dirs() {
    mkdir -p "$SYSTEM_HOOKS_DIR/pre-upgrade.d"
    mkdir -p "$SYSTEM_HOOKS_DIR/post-upgrade.d"

    if [[ -n "$SUDO_USER" ]]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        sudo -u "$SUDO_USER" mkdir -p "$user_home/.config/distup/hooks.d/pre-upgrade.d"
        sudo -u "$SUDO_USER" mkdir -p "$user_home/.config/distup/hooks.d/post-upgrade.d"
    fi

    echo -e "${GREEN}[OK]${NC} Hook directories initialized"
    echo ""
    echo "System hooks:  $SYSTEM_HOOKS_DIR/"
    if [[ -n "$SUDO_USER" ]]; then
        echo "User hooks:    ~/.config/distup/hooks.d/"
    fi
    echo ""
    echo "Place executable .sh scripts in pre-upgrade.d/ or post-upgrade.d/"
}

# Display hook status
show_hook_status() {
    echo ""
    echo "Hook Directories:"
    echo "  System: $SYSTEM_HOOKS_DIR/"
    if [[ -n "$SUDO_USER" ]]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        echo "  User:   $user_home/.config/distup/hooks.d/"
    fi
    echo ""

    echo "Pre-upgrade hooks:"
    if check_hooks_exist "pre-upgrade"; then
        find "$SYSTEM_HOOKS_DIR/pre-upgrade.d" -name "*.sh" -executable 2>/dev/null | while read -r hook; do
            echo "  - $(basename "$hook")"
        done
    else
        echo "  (none configured)"
    fi

    echo ""
    echo "Post-upgrade hooks:"
    if check_hooks_exist "post-upgrade"; then
        find "$SYSTEM_HOOKS_DIR/post-upgrade.d" -name "*.sh" -executable 2>/dev/null | while read -r hook; do
            echo "  - $(basename "$hook")"
        done
    else
        echo "  (none configured)"
    fi
    echo ""
}
