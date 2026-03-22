#!/bin/bash

set -e

# -------- COLOR CONSTANTS --------

COLOR_SUCCESS='\033[0;32m'  # Green
COLOR_ERROR='\033[0;31m'    # Red
COLOR_WARN='\033[0;33m'     # Yellow
COLOR_INFO='\033[0;34m'     # Blue
COLOR_RESET='\033[0m'       # Reset

# Disable colors if --no-color flag is set
if [[ "$*" == *"--no-color"* ]]; then
    COLOR_SUCCESS=''
    COLOR_ERROR=''
    COLOR_WARN=''
    COLOR_INFO=''
    COLOR_RESET=''
fi

# -------- COLOR HELPER FUNCTIONS --------

print_success() {
    echo -e "${COLOR_SUCCESS}[✔]${COLOR_RESET} $*"
}

print_error() {
    echo -e "${COLOR_ERROR}[✗]${COLOR_RESET} $*"
}

print_warn() {
    echo -e "${COLOR_WARN}[⚠]${COLOR_RESET} $*"
}

print_info() {
    echo -e "${COLOR_INFO}[ℹ]${COLOR_RESET} $*"
}

# -------- FUNCTIONS --------

print_header() {
    # Bold and bright cyan
    local BOLD="\e[1m"
    local CYAN="\e[96m"
    local RESET="\e[0m"

    echo -e "${BOLD}${CYAN}============================================"
    echo -e "   Proxmox CIFS → LXC Bind Mount Wizard   "
    echo -e "============================================${RESET}"
    echo ""
}

ask() {
    local prompt="$1"
    local var
    read -rp "$prompt: " var
    echo "$var"
}

confirm() {
    local prompt="$1"
    read -rp "$prompt (y/n): " choice
    [[ "$choice" == "y" || "$choice" == "Y" ]]
}

get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

check_cifs_utils() {
    if ! command -v mount.cifs &> /dev/null; then
        print_error "cifs-utils is required but not installed."
        if confirm "Would you like to install cifs-utils now?"; then
            apt update -qq && apt install -y -qq cifs-utils
            if command -v mount.cifs &> /dev/null; then
                print_success "cifs-utils installed successfully"
            else
                print_error "Failed to install cifs-utils"
                exit 1
            fi
        else
            print_error "cifs-utils is required to continue. Aborting."
            exit 1
        fi
    fi
}

check_jq() {
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed."
        if confirm "Would you like to install jq now?"; then
            apt update -qq && apt install -y -qq jq
            if command -v jq &> /dev/null; then
                print_success "jq installed successfully"
            else
                print_error "Failed to install jq"
                exit 1
            fi
        else
            print_error "jq is required to continue. Aborting."
            exit 1
        fi
    fi
}

init_manifest() {
    local manifest_file="/mnt/lxc_shares/.wizard-manifest.json"
    
    if [ ! -f "$manifest_file" ]; then
        mkdir -p /mnt/lxc_shares
        cat > "$manifest_file" <<EOF
{
  "wizard_version": "2.0",
  "created": "$(get_timestamp)",
  "operations": []
}
EOF
        print_success "Manifest file created: $manifest_file"
    fi
}

load_manifest() {
    local manifest_file="/mnt/lxc_shares/.wizard-manifest.json"
    if [ ! -f "$manifest_file" ]; then
        init_manifest
    fi
    cat "$manifest_file"
}

save_manifest() {
    local manifest_data="$1"
    local manifest_file="/mnt/lxc_shares/.wizard-manifest.json"
    echo "$manifest_data" | jq . > "$manifest_file"
}

add_operation() {
    local manifest_file="/mnt/lxc_shares/.wizard-manifest.json"
    local operation_json="$1"
    
    local manifest=$(load_manifest)
    manifest=$(echo "$manifest" | jq ".operations += [$operation_json]")
    save_manifest "$manifest"
}

remove_operations_from_manifest() {
    local manifest_file="/mnt/lxc_shares/.wizard-manifest.json"
    
    if [ ! -f "$manifest_file" ]; then
        return 1
    fi
    
    if [ $# -eq 0 ]; then
        return 0  # Nothing to remove
    fi
    
    local manifest=$(load_manifest)
    
    # Remove each operation matching the provided mount names
    for mount_name in "$@"; do
        manifest=$(echo "$manifest" | jq ".operations |= map(select(.mount_name != \"$mount_name\"))")
    done
    
    save_manifest "$manifest"
}

build_operation_json() {
    local timestamp="$1"
    local lxc_id="$2"
    local mount_name="$3"
    local share_ip="$4"
    local share_path="$5"
    local mount_point="$6"
    local target_path="$7"
    local creds_file="$8"
    local username="$9"
    local domain="${10}"
    local host_uid="${11}"
    local host_gid="${12}"
    local container_uid="${13}"
    local container_gid="${14}"
    local read_only="${15}"
    local fstab_comment="${16}"
    local fstab_entry="${17}"
    local lxc_conf_entry="${18}"
    
    jq -n \
        --arg timestamp "$timestamp" \
        --arg lxc_id "$lxc_id" \
        --arg mount_name "$mount_name" \
        --arg share_ip "$share_ip" \
        --arg share_path "$share_path" \
        --arg mount_point "$mount_point" \
        --arg target_path "$target_path" \
        --arg creds_file "$creds_file" \
        --arg username "$username" \
        --arg domain "$domain" \
        --argjson host_uid "$host_uid" \
        --argjson host_gid "$host_gid" \
        --argjson container_uid "$container_uid" \
        --argjson container_gid "$container_gid" \
        --argjson read_only "$read_only" \
        --arg fstab_comment "$fstab_comment" \
        --arg fstab_entry "$fstab_entry" \
        --arg lxc_conf_entry "$lxc_conf_entry" \
        '{
            timestamp: $timestamp,
            lxc_id: $lxc_id,
            mount_name: $mount_name,
            share_ip: $share_ip,
            share_path: $share_path,
            mount_point: $mount_point,
            target_path: $target_path,
            creds_file: $creds_file,
            username: $username,
            domain: $domain,
            host_uid: $host_uid,
            host_gid: $host_gid,
            container_uid: $container_uid,
            container_gid: $container_gid,
            read_only: $read_only,
            fstab_comment: $fstab_comment,
            fstab_entry: $fstab_entry,
            lxc_conf_entry: $lxc_conf_entry,
            status: "success"
        }'
}

list_credentials() {
    local cred_dir="/mnt/Creds"
    if [ ! -d "$cred_dir" ]; then
        return 1
    fi
    find "$cred_dir" -maxdepth 1 -name ".creds-*" -type f 2>/dev/null | sort
}

parse_credential_file() {
    local cred_file="$1"
    if [ ! -f "$cred_file" ]; then
        return 1
    fi
    
    local username=""
    local domain=""
    
    username=$(grep "^username=" "$cred_file" 2>/dev/null | cut -d= -f2- | tr -d '\r')
    domain=$(grep "^domain=" "$cred_file" 2>/dev/null | cut -d= -f2- | tr -d '\r')
    domain=${domain:-"(none)"}
    
    echo "$username|$domain"
}

# -------- MODE FUNCTIONS --------

list_mounts() {
    local manifest_file="/mnt/lxc_shares/.wizard-manifest.json"
    
    if [ ! -f "$manifest_file" ]; then
        print_warn "No mount operations found"
        return 0
    fi
    
    local op_count=$(jq '.operations | length' "$manifest_file" 2>/dev/null || echo 0)
    
    if [ "$op_count" -eq 0 ]; then
        print_info "No configured mounts"
        return 0
    fi
    
    print_info "Configured mounts:"
    echo ""
    echo "Index | LXC | Mount Name          | Share Path                    | Status"
    echo "------|-----|---------------------|-----------| ---------"
    
    local i=1
    jq -r '.operations[] | 
        "\($ENV.i) | \(.lxc_id) | \(.mount_name) | \(.share_ip)/\(.share_path) | \(.status)"' \
        --arg i "" "$manifest_file" 2>/dev/null | while read -r line; do
        echo "[$i] $line"
        ((i++))
    done
    
    echo ""
}

rollback_mounts() {
    local manifest_file="/mnt/lxc_shares/.wizard-manifest.json"
    
    if [ ! -f "$manifest_file" ]; then
        print_error "No mount operations found to rollback"
        return 1
    fi
    
    local op_count=$(jq '.operations | length' "$manifest_file" 2>/dev/null || echo 0)
    
    if [ "$op_count" -eq 0 ]; then
        print_warn "No configured mounts to rollback"
        return 0
    fi
    
    print_info "Available mounts for rollback:"
    echo ""
    
    # Array to store mount info for selection
    declare -a MOUNT_INDICES
    declare -a MOUNT_NAMES
    declare -a MOUNT_POINTS
    declare -a MOUNT_LXC_IDS
    declare -a MOUNT_FSTAB_ENTRIES
    declare -a MOUNT_LXC_CONF_ENTRIES
    
    # Array to collect mount names for manifest cleanup
    declare -a MOUNTS_TO_REMOVE=()
    
    local idx=1
    while IFS= read -r mount_info; do
        local mount_name=$(echo "$mount_info" | jq -r '.mount_name')
        local lxc_id=$(echo "$mount_info" | jq -r '.lxc_id')
        local mount_point=$(echo "$mount_info" | jq -r '.mount_point')
        local fstab_entry=$(echo "$mount_info" | jq -r '.fstab_entry')
        local lxc_conf_entry=$(echo "$mount_info" | jq -r '.lxc_conf_entry')
        local status=$(echo "$mount_info" | jq -r '.status')
        
        MOUNT_INDICES+=("$idx")
        MOUNT_NAMES+=("$mount_name")
        MOUNT_POINTS+=("$mount_point")
        MOUNT_LXC_IDS+=("$lxc_id")
        MOUNT_FSTAB_ENTRIES+=("$fstab_entry")
        MOUNT_LXC_CONF_ENTRIES+=("$lxc_conf_entry")
        
        echo "[$idx] $mount_name (LXC $lxc_id) - $mount_point [$status]"
        ((idx++))
    done < <(jq -c '.operations[]' "$manifest_file" 2>/dev/null)
    
    echo ""
    read -rp "Select mount(s) to rollback (comma/space-separated, e.g. 1,3): " selection
    
    if [ -z "$selection" ]; then
        print_warn "No selection made"
        return 0
    fi
    
    # Parse selection
    local selected_indices=()
    for sel in ${selection//,/ }; do
        sel=${sel/ /}  # Remove whitespace
        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -lt "$idx" ]; then
            selected_indices+=("$sel")
        fi
    done
    
    if [ ${#selected_indices[@]} -eq 0 ]; then
        print_error "Invalid selection"
        return 1
    fi
    
    # Perform rollback for each selected mount
    for sel_idx in "${selected_indices[@]}"; do
        local array_idx=$((sel_idx - 1))
        local mount_name="${MOUNT_NAMES[$array_idx]}"
        local mount_point="${MOUNT_POINTS[$array_idx]}"
        local lxc_id="${MOUNT_LXC_IDS[$array_idx]}"
        local fstab_entry="${MOUNT_FSTAB_ENTRIES[$array_idx]}"
        local lxc_conf_entry="${MOUNT_LXC_CONF_ENTRIES[$array_idx]}"
        
        print_info "Rolling back: $mount_name"
        
        # Remove from fstab (also removes comment line)
        if grep -q "$mount_point" /etc/fstab 2>/dev/null; then
            # Remove the mount point line and the preceding comment
            sed -i "\|${fstab_entry}|d" /etc/fstab 2>/dev/null || true
            sed -i "*${mount_point}*d" /etc/fstab 2>/dev/null || true
            print_success "Removed from /etc/fstab"
        fi
        
        # Remove from LXC config
        local lxc_conf="/etc/pve/lxc/${lxc_id}.conf"
        if [ -f "$lxc_conf" ] && grep -q "$mount_point" "$lxc_conf" 2>/dev/null; then
            sed -i "\|${lxc_conf_entry}|d" "$lxc_conf" 2>/dev/null || true
            # Also remove the preceding comment
            sed -i "*${mount_point}*d" "$lxc_conf" 2>/dev/null || true
            print_success "Removed from LXC config ($lxc_id.conf)"
        fi
        
        # Unmount the share
        if mountpoint -q "$mount_point" 2>/dev/null; then
            umount "$mount_point" 2>/dev/null || true
            print_success "Unmounted $mount_point"
        fi
        
        # Optionally remove the mount point directory
        if [ -d "$mount_point" ]; then
            if confirm "Remove mount point directory ($mount_point)?"; then
                rmdir "$mount_point" 2>/dev/null || print_warn "Could not remove directory (may contain files)"
            fi
        fi
        
        # Collect mount name for manifest removal
        MOUNTS_TO_REMOVE+=("$mount_name")
    done
    
    # Remove operations from manifest
    if [ ${#MOUNTS_TO_REMOVE[@]} -gt 0 ]; then
        print_info "Updating manifest..."
        remove_operations_from_manifest "${MOUNTS_TO_REMOVE[@]}"
        print_success "Removed entries from manifest"
    fi
    
    echo ""
    print_success "Rollback complete"
}

diff_rollback() {
    local manifest_file="/mnt/lxc_shares/.wizard-manifest.json"
    
    if [ ! -f "$manifest_file" ]; then
        print_error "No mount operations found"
        return 1
    fi
    
    local op_count=$(jq '.operations | length' "$manifest_file" 2>/dev/null || echo 0)
    
    if [ "$op_count" -eq 0 ]; then
        print_warn "No configured mounts"
        return 0
    fi
    
    print_info "Available mounts for diff preview:"
    echo ""
    echo "Index | LXC | Mount Name          | Mount Point"
    echo "------|-----|---------------------|-------------------"
    
    # Array to store mount info for selection
    declare -a MOUNT_INDICES
    declare -a MOUNT_NAMES
    declare -a MOUNT_POINTS
    declare -a MOUNT_LXC_IDS
    declare -a MOUNT_FSTAB_ENTRIES
    declare -a MOUNT_LXC_CONF_ENTRIES
    
    local idx=1
    while IFS= read -r mount_info; do
        local mount_name=$(echo "$mount_info" | jq -r '.mount_name')
        local lxc_id=$(echo "$mount_info" | jq -r '.lxc_id')
        local mount_point=$(echo "$mount_info" | jq -r '.mount_point')
        local fstab_entry=$(echo "$mount_info" | jq -r '.fstab_entry')
        local lxc_conf_entry=$(echo "$mount_info" | jq -r '.lxc_conf_entry')
        
        MOUNT_INDICES+=("$idx")
        MOUNT_NAMES+=("$mount_name")
        MOUNT_POINTS+=("$mount_point")
        MOUNT_LXC_IDS+=("$lxc_id")
        MOUNT_FSTAB_ENTRIES+=("$fstab_entry")
        MOUNT_LXC_CONF_ENTRIES+=("$lxc_conf_entry")
        
        echo "[$idx] $lxc_id | $mount_name | $mount_point"
        ((idx++))
    done < <(jq -c '.operations[]' "$manifest_file" 2>/dev/null)
    
    echo ""
    read -rp "Select mount(s) to preview (comma/space-separated): " selection
    
    if [ -z "$selection" ]; then
        print_warn "No selection made"
        return 0
    fi
    
    # Parse selection
    local selected_indices=()
    for sel in ${selection//,/ }; do
        sel=${sel/ /}  # Remove whitespace
        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -lt "$idx" ]; then
            selected_indices+=("$sel")
        fi
    done
    
    if [ ${#selected_indices[@]} -eq 0 ]; then
        print_error "Invalid selection"
        return 1
    fi
    
    # Show dry-run preview
    echo ""
    print_info "[DRY RUN] Preview of changes:"
    echo ""
    
    for sel_idx in "${selected_indices[@]}"; do
        local array_idx=$((sel_idx - 1))
        local mount_name="${MOUNT_NAMES[$array_idx]}"
        local mount_point="${MOUNT_POINTS[$array_idx]}"
        local lxc_id="${MOUNT_LXC_IDS[$array_idx]}"
        local fstab_entry="${MOUNT_FSTAB_ENTRIES[$array_idx]}"
        local lxc_conf_entry="${MOUNT_LXC_CONF_ENTRIES[$array_idx]}"
        
        echo "Mount: $mount_name"
        echo "  - Will remove from /etc/fstab:"
        echo "    $fstab_entry"
        echo "  - Will remove from /etc/pve/lxc/${lxc_id}.conf:"
        echo "    $lxc_conf_entry"
        echo "  - Will execute: umount $mount_point"
        echo "  - Will update manifest"
        echo ""
    done
    
    print_warn "No changes were made (dry run only)"
}

# -------- ARGUMENT PARSING --------

SCRIPT_MODE="setup"
SCRIPT_VERSION="2.0"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --setup)
            SCRIPT_MODE="setup"
            shift
            ;;
        --rollback)
            SCRIPT_MODE="rollback"
            shift
            ;;
        --list)
            SCRIPT_MODE="list"
            shift
            ;;
        --diff)
            SCRIPT_MODE="diff"
            shift
            ;;
        --no-color)
            shift
            ;;
        --version)
            echo "ProxmoxBindMountWizard v${SCRIPT_VERSION}"
            exit 0
            ;;
        --help)
            cat <<EOF
ProxmoxBindMountWizard v${SCRIPT_VERSION}

Usage: $0 [MODE] [OPTIONS]

Modes:
  --setup       Interactive setup of bind mounts (default)
  --rollback    Remove previously created mounts
  --list        List all configured mounts
  --diff        Preview rollback changes without applying
  --version     Show version

Options:
  --no-color    Disable colored output
  --help        Show this help message

EOF
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check jq availability
check_jq

# Initialize manifest directory
mkdir -p /mnt/lxc_shares 2>/dev/null || true

# -------- ROUTE NON-SETUP MODES --------

if [ "$SCRIPT_MODE" != "setup" ]; then
    print_header
    case "$SCRIPT_MODE" in
        list)
            list_mounts
            ;;
        rollback)
            rollback_mounts
            ;;
        diff)
            diff_rollback
            ;;
    esac
    exit 0
fi

# -------- SETUP MODE FLOW (below this line only runs for --setup) --------

print_header

list_mounts() {
    local manifest_file="/mnt/lxc_shares/.wizard-manifest.json"
    
    if [ ! -f "$manifest_file" ]; then
        print_warn "No mount operations found"
        return 0
    fi
    
    local op_count=$(jq '.operations | length' "$manifest_file" 2>/dev/null || echo 0)
    
    if [ "$op_count" -eq 0 ]; then
        print_info "No configured mounts"
        return 0
    fi
    
    print_info "Configured mounts:"
    echo ""
    echo "Index | LXC | Mount Name          | Share Path                    | Status"
    echo "------|-----|---------------------|-----------| ---------"
    
    local i=1
    jq -r '.operations[] | 
        "\($ENV.i) | \(.lxc_id) | \(.mount_name) | \(.share_ip)/\(.share_path) | \(.status)"' \
        --arg i "" "$manifest_file" 2>/dev/null | while read -r line; do
        echo "[$i] $line"
        ((i++))
    done
    
    echo ""
}

rollback_mounts() {
    local manifest_file="/mnt/lxc_shares/.wizard-manifest.json"
    
    if [ ! -f "$manifest_file" ]; then
        print_error "No mount operations found to rollback"
        return 1
    fi
    
    local op_count=$(jq '.operations | length' "$manifest_file" 2>/dev/null || echo 0)
    
    if [ "$op_count" -eq 0 ]; then
        print_warn "No configured mounts to rollback"
        return 0
    fi
    
    print_info "Available mounts for rollback:"
    echo ""
    
    # Array to store mount info for selection
    declare -a MOUNT_INDICES
    declare -a MOUNT_NAMES
    declare -a MOUNT_POINTS
    declare -a MOUNT_LXC_IDS
    declare -a MOUNT_FSTAB_ENTRIES
    declare -a MOUNT_LXC_CONF_ENTRIES
    
    # Array to collect mount names for manifest cleanup
    declare -a MOUNTS_TO_REMOVE=()
    
    local idx=1
    while IFS= read -r mount_info; do
        local mount_name=$(echo "$mount_info" | jq -r '.mount_name')
        local lxc_id=$(echo "$mount_info" | jq -r '.lxc_id')
        local mount_point=$(echo "$mount_info" | jq -r '.mount_point')
        local fstab_entry=$(echo "$mount_info" | jq -r '.fstab_entry')
        local lxc_conf_entry=$(echo "$mount_info" | jq -r '.lxc_conf_entry')
        local status=$(echo "$mount_info" | jq -r '.status')
        
        MOUNT_INDICES+=("$idx")
        MOUNT_NAMES+=("$mount_name")
        MOUNT_POINTS+=("$mount_point")
        MOUNT_LXC_IDS+=("$lxc_id")
        MOUNT_FSTAB_ENTRIES+=("$fstab_entry")
        MOUNT_LXC_CONF_ENTRIES+=("$lxc_conf_entry")
        
        echo "[$idx] $mount_name (LXC $lxc_id) - $mount_point [$status]"
        ((idx++))
    done < <(jq -c '.operations[]' "$manifest_file" 2>/dev/null)
    
    echo ""
    read -rp "Select mount(s) to rollback (comma/space-separated, e.g. 1,3): " selection
    
    if [ -z "$selection" ]; then
        print_warn "No selection made"
        return 0
    fi
    
    # Parse selection
    local selected_indices=()
    for sel in ${selection//,/ }; do
        sel=${sel/ /}  # Remove whitespace
        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -lt "$idx" ]; then
            selected_indices+=("$sel")
        fi
    done
    
    if [ ${#selected_indices[@]} -eq 0 ]; then
        print_error "Invalid selection"
        return 1
    fi
    
    # Perform rollback for each selected mount
    for sel_idx in "${selected_indices[@]}"; do
        local array_idx=$((sel_idx - 1))
        local mount_name="${MOUNT_NAMES[$array_idx]}"
        local mount_point="${MOUNT_POINTS[$array_idx]}"
        local lxc_id="${MOUNT_LXC_IDS[$array_idx]}"
        local fstab_entry="${MOUNT_FSTAB_ENTRIES[$array_idx]}"
        local lxc_conf_entry="${MOUNT_LXC_CONF_ENTRIES[$array_idx]}"
        
        print_info "Rolling back: $mount_name"
        
        # Remove from fstab (also removes comment line)
        if grep -q "$mount_point" /etc/fstab 2>/dev/null; then
            # Remove the mount point line and the preceding comment
            sed -i "\|${fstab_entry}|d" /etc/fstab 2>/dev/null || true
            sed -i "*${mount_point}*d" /etc/fstab 2>/dev/null || true
            print_success "Removed from /etc/fstab"
        fi
        
        # Remove from LXC config
        local lxc_conf="/etc/pve/lxc/${lxc_id}.conf"
        if [ -f "$lxc_conf" ] && grep -q "$mount_point" "$lxc_conf" 2>/dev/null; then
            sed -i "\|${lxc_conf_entry}|d" "$lxc_conf" 2>/dev/null || true
            # Also remove the preceding comment
            sed -i "*${mount_point}*d" "$lxc_conf" 2>/dev/null || true
            print_success "Removed from LXC config ($lxc_id.conf)"
        fi
        
        # Unmount the share
        if mountpoint -q "$mount_point" 2>/dev/null; then
            umount "$mount_point" 2>/dev/null || true
            print_success "Unmounted $mount_point"
        fi
        
        # Optionally remove the mount point directory
        if [ -d "$mount_point" ]; then
            if confirm "Remove mount point directory ($mount_point)?"; then
                rmdir "$mount_point" 2>/dev/null || print_warn "Could not remove directory (may contain files)"
            fi
        fi
        
        # Collect mount name for manifest removal
        MOUNTS_TO_REMOVE+=("$mount_name")
    done
    
    # Remove operations from manifest
    if [ ${#MOUNTS_TO_REMOVE[@]} -gt 0 ]; then
        print_info "Updating manifest..."
        remove_operations_from_manifest "${MOUNTS_TO_REMOVE[@]}"
        print_success "Removed entries from manifest"
    fi
    
    echo ""
    print_success "Rollback complete"
}

diff_rollback() {
    local manifest_file="/mnt/lxc_shares/.wizard-manifest.json"
    
    if [ ! -f "$manifest_file" ]; then
        print_error "No mount operations found"
        return 1
    fi
    
    local op_count=$(jq '.operations | length' "$manifest_file" 2>/dev/null || echo 0)
    
    if [ "$op_count" -eq 0 ]; then
        print_warn "No configured mounts"
        return 0
    fi
    
    print_info "Available mounts for diff preview:"
    echo ""
    echo "Index | LXC | Mount Name          | Mount Point"
    echo "------|-----|---------------------|-------------------"
    
    # Array to store mount info for selection
    declare -a MOUNT_INDICES
    declare -a MOUNT_NAMES
    declare -a MOUNT_POINTS
    declare -a MOUNT_LXC_IDS
    declare -a MOUNT_FSTAB_ENTRIES
    declare -a MOUNT_LXC_CONF_ENTRIES
    
    local idx=1
    while IFS= read -r mount_info; do
        local mount_name=$(echo "$mount_info" | jq -r '.mount_name')
        local lxc_id=$(echo "$mount_info" | jq -r '.lxc_id')
        local mount_point=$(echo "$mount_info" | jq -r '.mount_point')
        local fstab_entry=$(echo "$mount_info" | jq -r '.fstab_entry')
        local lxc_conf_entry=$(echo "$mount_info" | jq -r '.lxc_conf_entry')
        
        MOUNT_INDICES+=("$idx")
        MOUNT_NAMES+=("$mount_name")
        MOUNT_POINTS+=("$mount_point")
        MOUNT_LXC_IDS+=("$lxc_id")
        MOUNT_FSTAB_ENTRIES+=("$fstab_entry")
        MOUNT_LXC_CONF_ENTRIES+=("$lxc_conf_entry")
        
        echo "[$idx] $lxc_id | $mount_name | $mount_point"
        ((idx++))
    done < <(jq -c '.operations[]' "$manifest_file" 2>/dev/null)
    
    echo ""
    read -rp "Select mount(s) to preview (comma/space-separated): " selection
    
    if [ -z "$selection" ]; then
        print_warn "No selection made"
        return 0
    fi
    
    # Parse selection
    local selected_indices=()
    for sel in ${selection//,/ }; do
        sel=${sel/ /}  # Remove whitespace
        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -lt "$idx" ]; then
            selected_indices+=("$sel")
        fi
    done
    
    if [ ${#selected_indices[@]} -eq 0 ]; then
        print_error "Invalid selection"
        return 1
    fi
    
    # Show dry-run preview
    echo ""
    print_info "[DRY RUN] Preview of changes:"
    echo ""
    
    for sel_idx in "${selected_indices[@]}"; do
        local array_idx=$((sel_idx - 1))
        local mount_name="${MOUNT_NAMES[$array_idx]}"
        local mount_point="${MOUNT_POINTS[$array_idx]}"
        local lxc_id="${MOUNT_LXC_IDS[$array_idx]}"
        local fstab_entry="${MOUNT_FSTAB_ENTRIES[$array_idx]}"
        local lxc_conf_entry="${MOUNT_LXC_CONF_ENTRIES[$array_idx]}"
        
        echo "Mount: $mount_name"
        echo "  - Will remove from /etc/fstab:"
        echo "    $fstab_entry"
        echo "  - Will remove from /etc/pve/lxc/${lxc_id}.conf:"
        echo "    $lxc_conf_entry"
        echo "  - Will execute: umount $mount_point"
        echo "  - Will update manifest"
        echo ""
    done
    
    print_warn "No changes were made (dry run only)"
}

# -------- INPUT --------

LXC_ID=$(ask "Enter LXC ID")

LXC_CONF="/etc/pve/lxc/${LXC_ID}.conf"

if [ ! -f "$LXC_CONF" ]; then
    print_error "LXC config not found"
    exit 1
fi

SHARE_IP=$(ask "Enter IP or hostname of your NAS or SMB Server (e.g. 192.168.1.100)")
SHARE_PATH=$(ask "Enter share path (e.g. MYShare/Documents/Taxes)")
MOUNT_NAME=$(ask "Enter local mount name (e.g. myshare_taxdocs)")

# -------- CREDENTIAL HANDLING --------

echo ""
print_info "Checking for existing credentials"

CREDS_ARRAY=()
while IFS= read -r cred_file; do
    if [ -n "$cred_file" ]; then
        CREDS_ARRAY+=("$cred_file")
    fi
done < <(list_credentials)

if [ ${#CREDS_ARRAY[@]} -gt 0 ]; then
    echo ""
    echo "Found existing credential files:"
    i=1
    for cred in "${CREDS_ARRAY[@]}"; do
        basename=$(basename "$cred")
        parsed=$(parse_credential_file "$cred")
        cred_user=$(echo "$parsed" | cut -d'|' -f1)
        cred_domain=$(echo "$parsed" | cut -d'|' -f2)
        echo "[$i] $basename (user: $cred_user, domain: $cred_domain)"
        ((i++))
    done
    echo "[$i] Create new credentials"
    echo ""
    read -rp "Select option [1-$i]: " cred_choice
    
    if [ "$cred_choice" -ge 1 ] && [ "$cred_choice" -lt $i ]; then
        SELECTED_CRED="${CREDS_ARRAY[$((cred_choice - 1))]}"
        parsed=$(parse_credential_file "$SELECTED_CRED")
        cred_user=$(echo "$parsed" | cut -d'|' -f1)
        cred_domain=$(echo "$parsed" | cut -d'|' -f2)
        
        if confirm "Reuse credentials (user: $cred_user, domain: $cred_domain)?"; then
            CREDS_FILE="$SELECTED_CRED"
            CREDENTIALS_PROVIDED=true
        else
            CREDENTIALS_PROVIDED=false
        fi
    else
        CREDENTIALS_PROVIDED=false
    fi
else
    print_info "No existing credentials found"
    CREDENTIALS_PROVIDED=false
fi

# Only ask for credentials if not reusing
if [ "$CREDENTIALS_PROVIDED" != true ]; then
    echo ""
    USERNAME=$(ask "Enter SMB username")
    read -rsp "Enter SMB password: " PASSWORD
    echo ""
    DOMAIN=$(ask "Enter domain (leave empty if not needed)")
    CREDS_FILE="/mnt/Creds/.creds-${MOUNT_NAME}"
else
    # Extract USERNAME and DOMAIN from the selected file for later use
    USERNAME=$(parse_credential_file "$CREDS_FILE" | cut -d'|' -f1)
    DOMAIN=$(parse_credential_file "$CREDS_FILE" | cut -d'|' -f2)
    [ "$DOMAIN" = "(none)" ] && DOMAIN=""
fi

TARGET_PATH=$(ask "Enter mount path inside container (default: /mnt/media)")
TARGET_PATH=${TARGET_PATH:-/mnt/media}

READ_ONLY=false
if confirm "Mount as read-only?"; then
    READ_ONLY=true
fi


# -------- DETECT UID OFFSET --------

echo ""
print_info "Detecting UID/GID mapping offset"

OFFSET_UID=$(grep "^root:" /etc/subuid | cut -d: -f2)
OFFSET_GID=$(grep "^root:" /etc/subgid | cut -d: -f2)

if [ -z "$OFFSET_UID" ] || [ -z "$OFFSET_GID" ]; then
    print_warn "Could not detect mapping automatically"
    OFFSET_UID=$(ask "Enter UID offset manually (default: 100000)")
    OFFSET_UID=${OFFSET_UID:-100000}
    OFFSET_GID=$(ask "Enter GID offset manually (default: 110000)")
    OFFSET_GID=${OFFSET_GID:-110000}
fi

echo "Detected UID offset: $OFFSET_UID"
echo "Detected GID offset: $OFFSET_GID"

# -------- USER DETECTION --------

echo ""
print_info "Detecting users inside container"

EXCLUDED_USERS=(
    daemon bin sys sync games man lp mail news uucp
    proxy www-data backup list irc _apt nobody
    systemd-network systemd-timesync messagebus
    sshd postfix redis postgres
    _rpc statd
)

EXCLUDE_REGEX=$(IFS="|"; echo "${EXCLUDED_USERS[*]}")

USER_LIST=$(pct exec "$LXC_ID" -- bash -c "cat /etc/passwd")

echo ""
print_info "Filtering users"
print_info "Excluded users: ${EXCLUDED_USERS[*]}"
echo ""

declare -a USERS
i=1

while IFS=: read -r username _ uid gid _ home shell; do

    if [[ "$username" =~ ^($EXCLUDE_REGEX)$ ]]; then
        continue
    fi

    if [[ "$shell" =~ (nologin|false) && "$username" =~ ^($EXCLUDE_REGEX)$ ]]; then
        continue
    fi

    echo "[$i] $username (UID=$uid GID=$gid)"
    USERS[$i]="$username:$uid:$gid"
    ((i++))

done <<< "$USER_LIST"

# -------- USER SELECTION --------

if [ ${#USERS[@]} -eq 0 ]; then
    print_warn "No users found after filtering"

    read -rp "Enter username manually: " manual_user

    USER_ENTRY=$(pct exec "$LXC_ID" -- getent passwd "$manual_user")

    if [ -z "$USER_ENTRY" ]; then
        print_error "User not found"
        exit 1
    fi

    CONTAINER_UID=$(echo "$USER_ENTRY" | cut -d: -f3)
    CONTAINER_GID=$(echo "$USER_ENTRY" | cut -d: -f4)
    SELECTED_USER="$manual_user"

else
    echo ""
    read -rp "Select user [1-$((i-1))] or press ENTER for manual input: " choice

    if [[ -z "$choice" ]]; then
        read -rp "Enter username manually: " manual_user

        USER_ENTRY=$(pct exec "$LXC_ID" -- getent passwd "$manual_user")

        if [ -z "$USER_ENTRY" ]; then
            print_error "User not found"
            exit 1
        fi

        CONTAINER_UID=$(echo "$USER_ENTRY" | cut -d: -f3)
        CONTAINER_GID=$(echo "$USER_ENTRY" | cut -d: -f4)
        SELECTED_USER="$manual_user"
    else
        SELECTED="${USERS[$choice]}"
        SELECTED_USER=$(echo "$SELECTED" | cut -d: -f1)
        CONTAINER_UID=$(echo "$SELECTED" | cut -d: -f2)
        CONTAINER_GID=$(echo "$SELECTED" | cut -d: -f3)
    fi
fi

# -------- UID MAPPING --------

HOST_UID=$((CONTAINER_UID + OFFSET_UID))
HOST_GID=$((CONTAINER_GID + OFFSET_GID))

echo ""
print_info "Selected user: $SELECTED_USER"
print_info "Container UID: $CONTAINER_UID"
print_info "Container GID: $CONTAINER_GID"
print_info "→ Host UID: $HOST_UID"
print_info "→ Host GID: $HOST_GID"

if ! confirm "Use these UID/GID values?"; then
    HOST_UID=$(ask "Enter HOST UID manually")
    HOST_GID=$(ask "Enter HOST GID manually")
fi

# -------- PATHS --------

MOUNT_POINT="/mnt/lxc_shares/${MOUNT_NAME}"

echo ""
print_info "======== SUMMARY ========"
print_info "Share: //$SHARE_IP/$SHARE_PATH"
print_info "Mount point: $MOUNT_POINT"
print_info "Container path: $TARGET_PATH"
print_info "UID/GID: $HOST_UID:$HOST_GID"
print_info "Read-only: $READ_ONLY"
print_info "========================="
echo ""

if ! confirm "Proceed?"; then
    print_warn "Aborted"
    exit 0
fi

# -------- EXECUTION --------

echo ""
print_info "Checking dependencies"
check_cifs_utils

print_info "Creating directories"
mkdir -p "$MOUNT_POINT"
mkdir -p /mnt/Creds

print_info "Writing credentials file"
if [ "$CREDENTIALS_PROVIDED" != true ]; then
    cat > "$CREDS_FILE" <<EOF
username=${USERNAME}
password=${PASSWORD}
domain=${DOMAIN}
EOF

    chmod 600 "$CREDS_FILE"
    print_success "New credentials file created: $CREDS_FILE"
else
    print_success "Using existing credentials file: $CREDS_FILE"
fi

print_info "Updating /etc/fstab"

# Generate fstab entry with comment
RO_MODE="rw"
if [ "$READ_ONLY" = true ]; then
    RO_MODE="ro"
fi

FSTAB_COMMENT="# Added share using Proxmox Bind Mount Wizard: $(get_timestamp) | Share: //${SHARE_IP}/${SHARE_PATH} | User: ${DOMAIN}\\${USERNAME} | Mode: ${RO_MODE}"
FSTAB_ENTRY="//${SHARE_IP}/${SHARE_PATH} ${MOUNT_POINT} cifs _netdev,x-systemd.automount,noatime,credentials=${CREDS_FILE},uid=${HOST_UID},gid=${HOST_GID},dir_mode=0770,file_mode=0770 0 0"

if grep -q "$MOUNT_POINT" /etc/fstab; then
    print_warn "Entry already exists. Skipping"
else
    echo "$FSTAB_COMMENT" >> /etc/fstab
    echo "$FSTAB_ENTRY" >> /etc/fstab
fi

print_info "Mounting"
systemctl daemon-reload
mount "$MOUNT_POINT" || true

print_info "Updating LXC config"

MP_INDEX=0
# Only match lines that start with mpX: (not commented lines)
while grep -q "^mp${MP_INDEX}:" "$LXC_CONF"; do
    ((MP_INDEX++))
done

# Generate LXC config entry with comment
LXC_CONF_COMMENT="# Added share using Proxmox Bind Mount Wizard: $(get_timestamp) | Share: //${SHARE_IP}/${SHARE_PATH} | User: ${DOMAIN}\\${USERNAME} | Mode: ${RO_MODE}"
BIND_ENTRY="mp${MP_INDEX}: ${MOUNT_POINT},mp=${TARGET_PATH},shared=1"

if $READ_ONLY; then
    BIND_ENTRY="${BIND_ENTRY},ro=1"
fi

if grep -q "$MOUNT_POINT" "$LXC_CONF"; then
    print_warn "Bind mount already exists. Skipping"
else
    echo "$LXC_CONF_COMMENT" >> "$LXC_CONF"
    echo "$BIND_ENTRY" >> "$LXC_CONF"
    print_success "Added as mp${MP_INDEX}"
fi

# -------- MANIFEST RECORDING --------

init_manifest

# Create operation JSON object using jq (safely escapes all variables)
OPERATION_JSON=$(build_operation_json \
    "$(get_timestamp)" \
    "$LXC_ID" \
    "$MOUNT_NAME" \
    "$SHARE_IP" \
    "$SHARE_PATH" \
    "$MOUNT_POINT" \
    "$TARGET_PATH" \
    "$CREDS_FILE" \
    "$USERNAME" \
    "$DOMAIN" \
    "$HOST_UID" \
    "$HOST_GID" \
    "$CONTAINER_UID" \
    "$CONTAINER_GID" \
    "$READ_ONLY" \
    "$FSTAB_COMMENT" \
    "$FSTAB_ENTRY" \
    "$BIND_ENTRY")

# Add operation to manifest
add_operation "$OPERATION_JSON"
print_success "Operation recorded in manifest"

echo ""
print_success "Setup complete"
echo "======================================"
echo ""
echo "What would you like to do next?"
echo "[1] Reboot container and verify mount"
echo "[2] Show manual verification commands"
echo "[3] Exit"
echo ""
read -rp "Select option [1-3]: " completion_choice

case "$completion_choice" in
    1)
        print_info "Restarting LXC container ${LXC_ID}..."
        pct shutdown "${LXC_ID}" || true
        sleep 2
        pct start "${LXC_ID}" || true
        sleep 3
        echo ""
        print_info "Container restarted. To verify the mount, run:"
        echo "  pct exec ${LXC_ID} -- ls -lah ${TARGET_PATH}"
        echo ""
        ;;
    2)
        echo ""
        print_info "Manual verification steps:"
        echo ""
        echo "1. Restart the LXC container:"
        echo "   pct restart ${LXC_ID}"
        echo ""
        echo "2. Verify the mount is accessible inside the container:"
        echo "   pct exec ${LXC_ID} -- ls -lah ${TARGET_PATH}"
        echo ""
        echo "3. (Optional) Check mount permissions and file listing:"
        echo "   pct exec ${LXC_ID} -- stat ${TARGET_PATH}"
        echo "   pct exec ${LXC_ID} -- ls -lah ${TARGET_PATH}/"
        echo ""
        ;;
    *)
        print_info "Exiting"
        ;;
esac

echo "======================================"
print_success "All done"
echo ""

