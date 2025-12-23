#!/bin/bash
# =============================================================================
# Library:       snapshot.sh
# Description:   Pre-upgrade snapshot functions for distup scripts
# Author:        Kris Armstrong
# Created:       2025-12-23
# Version:       1.2.0
# License:       MIT
#
# Supported Tools:
#   - Timeshift (preferred for desktop systems)
#   - Snapper (preferred for openSUSE/server systems)
#   - btrfs native snapshots (fallback)
#   - LVM snapshots (for LVM-based systems)
#
# Usage:
#   source lib/snapshot.sh
#   if create_pre_upgrade_snapshot; then
#       echo "Snapshot created successfully"
#   fi
# =============================================================================

# Snapshot configuration
SNAPSHOT_DESCRIPTION="distup pre-upgrade snapshot"
SNAPSHOT_TYPE="pre-upgrade"

# Detect available snapshot tool
detect_snapshot_tool() {
    if command -v timeshift &>/dev/null; then
        echo "timeshift"
    elif command -v snapper &>/dev/null; then
        echo "snapper"
    elif command -v btrfs &>/dev/null && mount | grep -q "type btrfs"; then
        echo "btrfs"
    elif command -v lvcreate &>/dev/null && lvs &>/dev/null 2>&1; then
        echo "lvm"
    else
        echo "none"
    fi
}

# Create snapshot with Timeshift
create_timeshift_snapshot() {
    local comment="${1:-$SNAPSHOT_DESCRIPTION}"

    echo -e "${BLUE}[INFO]${NC} Creating Timeshift snapshot..."

    if timeshift --create --comments "$comment" --tags D; then
        echo -e "${GREEN}[OK]${NC} Timeshift snapshot created"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Failed to create Timeshift snapshot"
        return 1
    fi
}

# Create snapshot with Snapper
create_snapper_snapshot() {
    local description="${1:-$SNAPSHOT_DESCRIPTION}"
    local config="${2:-root}"

    echo -e "${BLUE}[INFO]${NC} Creating Snapper snapshot..."

    # Check if config exists
    if ! snapper -c "$config" list &>/dev/null; then
        echo -e "${YELLOW}[WARNING]${NC} Snapper config '$config' not found"
        return 1
    fi

    local snapshot_id
    snapshot_id=$(snapper -c "$config" create --type pre --print-number --description "$description" 2>/dev/null)

    if [[ -n "$snapshot_id" ]]; then
        echo -e "${GREEN}[OK]${NC} Snapper snapshot #$snapshot_id created"
        # Store snapshot ID for post-upgrade cleanup
        echo "$snapshot_id" > /tmp/distup-snapper-snapshot-id
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Failed to create Snapper snapshot"
        return 1
    fi
}

# Create snapshot with native btrfs
create_btrfs_snapshot() {
    local description="${1:-$SNAPSHOT_DESCRIPTION}"
    local source_subvol="${2:-/}"
    local snapshot_dir="/snapshots"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local snapshot_name="distup-pre-upgrade-$timestamp"

    echo -e "${BLUE}[INFO]${NC} Creating btrfs snapshot..."

    # Ensure snapshot directory exists
    if [[ ! -d "$snapshot_dir" ]]; then
        mkdir -p "$snapshot_dir"
    fi

    # Create read-only snapshot
    if btrfs subvolume snapshot -r "$source_subvol" "$snapshot_dir/$snapshot_name"; then
        echo -e "${GREEN}[OK]${NC} btrfs snapshot created: $snapshot_dir/$snapshot_name"
        echo "$snapshot_dir/$snapshot_name" > /tmp/distup-btrfs-snapshot-path
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Failed to create btrfs snapshot"
        return 1
    fi
}

# Create LVM snapshot
create_lvm_snapshot() {
    local description="${1:-$SNAPSHOT_DESCRIPTION}"
    local snapshot_size="${2:-5G}"

    echo -e "${BLUE}[INFO]${NC} Creating LVM snapshot..."

    # Find root LV
    local root_lv
    root_lv=$(findmnt -n -o SOURCE / | head -1)

    if [[ -z "$root_lv" ]] || [[ ! "$root_lv" =~ /dev/mapper/ ]]; then
        echo -e "${YELLOW}[WARNING]${NC} Root filesystem is not on LVM"
        return 1
    fi

    # Parse VG and LV names
    local vg_name lv_name
    # Handle /dev/mapper/vg-lv format
    if [[ "$root_lv" =~ /dev/mapper/(.+)-(.+) ]]; then
        vg_name="${BASH_REMATCH[1]}"
        lv_name="${BASH_REMATCH[2]}"
    else
        echo -e "${YELLOW}[WARNING]${NC} Could not parse LVM volume"
        return 1
    fi

    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local snapshot_name="${lv_name}_distup_snap_$timestamp"

    if lvcreate -L "$snapshot_size" -s -n "$snapshot_name" "/dev/$vg_name/$lv_name"; then
        echo -e "${GREEN}[OK]${NC} LVM snapshot created: /dev/$vg_name/$snapshot_name"
        echo "/dev/$vg_name/$snapshot_name" > /tmp/distup-lvm-snapshot-path
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Failed to create LVM snapshot"
        return 1
    fi
}

# Main function to create pre-upgrade snapshot
create_pre_upgrade_snapshot() {
    local description="${1:-$SNAPSHOT_DESCRIPTION}"
    local tool
    tool=$(detect_snapshot_tool)

    echo ""
    echo -e "${BLUE}[INFO]${NC} Detected snapshot tool: $tool"

    case "$tool" in
        timeshift)
            create_timeshift_snapshot "$description"
            ;;
        snapper)
            create_snapper_snapshot "$description"
            ;;
        btrfs)
            create_btrfs_snapshot "$description"
            ;;
        lvm)
            create_lvm_snapshot "$description"
            ;;
        none)
            echo -e "${YELLOW}[WARNING]${NC} No snapshot tool available"
            echo "  Consider installing one of: timeshift, snapper"
            echo "  Or ensure btrfs/LVM is configured for snapshots"
            return 1
            ;;
    esac
}

# Check if snapshots are available
check_snapshot_support() {
    local tool
    tool=$(detect_snapshot_tool)

    if [[ "$tool" == "none" ]]; then
        return 1
    fi
    return 0
}

# Prompt user for snapshot creation
prompt_create_snapshot() {
    local description="${1:-$SNAPSHOT_DESCRIPTION}"

    if ! check_snapshot_support; then
        echo -e "${YELLOW}[WARNING]${NC} No snapshot tool detected - skipping snapshot"
        return 0
    fi

    echo ""
    echo -e "${BLUE}[INFO]${NC} Snapshot support detected ($(detect_snapshot_tool))"
    read -rp "Create pre-upgrade snapshot? [Y/n]: " create_snap

    if [[ ! "$create_snap" =~ ^[Nn]$ ]]; then
        create_pre_upgrade_snapshot "$description"
        return $?
    fi

    echo -e "${YELLOW}[WARNING]${NC} Proceeding without snapshot"
    return 0
}
