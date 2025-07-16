#!/bin/bash
CONFIG="/etc/auto_mount.conf"
LOG="/var/log/auto_mount.log"

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}

log "=== Starting drive unmount ==="


while read -r uuid name; do
    # Skip comments and empty lines
    [[ "$uuid" =~ ^#|^$ ]] && continue
    [[ -z "$name" ]] && continue
    [[ -z "$mount_path" ]] && continue
    

    dev_path="/dev/disk/by-uuid/$uuid"

    if [[ "$mount_path" == "default" ]]; then
        mount_point="/media/wombat/$name"
    else
        mount_point="$mount_path/$name"
    done
    
    
    # Verify device exists
    if [[ ! -e "$mount_point" ]]; then
        log "Mount-point not found: $mount_point"
        continue
    fi
    
    # Check if already mounted
    if ! mountpoint -q "$mount_point"; then
        log "Skipping device, not mounted: $uuid at $mount_point"
        continue
    fi
    
    # Mount device
    if umount $mount_point 2>&1 | tee -a "$LOG"; then
        log "Unmounted $uuid from $mount_point"
    else
        log "FAILED to unmount $uuid from $mount_point"
    fi
done < <(grep -vE '^\s*#|^$' "$CONFIG")

log "=== Unmount operation completed ==="