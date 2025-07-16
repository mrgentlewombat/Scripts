#!/bin/bash
CONFIG="/etc/auto_mount.conf"
LOG="/var/log/auto_mount.log"

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}

log "=== Starting drive mount ==="
user="${SUDO_USER:-$(whoami)}"


while read -r uuid name; do
    # Skip comments and empty lines
    [[ "$uuid" =~ ^#|^$ ]] && continue
    [[ -z "$name" ]] && continue
    
    dev_path="/dev/disk/by-uuid/$uuid"
    mount_point="/media/$user/$name"
    
    # Verify device exists
    if [[ ! -e "$dev_path" ]]; then
        log "Device not found: $uuid"
        continue
    fi
    
    # Create mount directory
    if [[ ! -d "$mount_point" ]]; then
        mkdir -p "$mount_point"
        chmod 0755 "$mount_point"
    fi
    
    # Check if already mounted
    if mountpoint -q "$mount_point"; then
        log "Already mounted: $uuid at $mount_point"
        continue
    fi
    
    # Mount device
    if mount -t auto -o defaults,noatime,nofail "$dev_path" "$mount_point" 2>&1 | tee -a "$LOG"; then
        log "Mounted $uuid to $mount_point"
    else
        log "FAILED to mount $uuid to $mount_point"
    fi
done < <(grep -vE '^\s*#|^$' "$CONFIG")

log "=== Mount operation completed ==="