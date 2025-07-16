#!/bin/bash
# Auto Mount Drive Deployment Script
# Run with: sudo ./deploy.sh

set -e

# Check root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use sudo." >&2
    exit 1
fi

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="auto_mount.conf"
MOUNT_SCRIPT="auto_mount.sh"
UNMOUNT_SCRIPT="auto_unmount.sh"
SERVICE_FILE="auto_mount.service"
CLI_COMMAND_MOUNT="wombat-mount"  # Name for terminal command
CLI_COMMAND_UNMOUNT="wombat-unmount"  # Name for terminal command

# Paths
TARGET_CONFIG="/etc/auto_mount.conf"
TARGET_SCRIPT="/usr/local/bin/auto_mount.sh"
TARGET_UNMOUNT_SCRIPT="/usr/local/bin/auto_unmount.sh"
TARGET_SERVICE="/etc/systemd/system/auto_mount.service"

# Verify required files exist
missing_files=()
for file in "$CONFIG_FILE" "$MOUNT_SCRIPT" "$UNMOUNT_SCRIPT" "$SERVICE_FILE"; do
    if [ ! -f "$SCRIPT_DIR/$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    echo "Missing required files:" >&2
    printf '  %s\n' "${missing_files[@]}" >&2
    exit 1
fi

# Validate configuration file format
echo "Validating configuration file..."
invalid_lines=0
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# || -z "$line" ]] && continue
    
    # Check format (UUID and name separated by space)
    if ! [[ "$line" =~ ^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[[:space:]]+[[:alnum:]_-]+$ ]]; then
        echo "  [ERROR] Invalid line: $line"
        echo "          Format must be: [UUID] [mount_name]"
        echo "          Example: 123e4567-e89b-12d3-a456-426614174000 my_drive"
        ((invalid_lines++))
    fi
done < "$SCRIPT_DIR/$CONFIG_FILE"

if [ $invalid_lines -gt 0 ]; then
    echo "Configuration validation failed with $invalid_lines errors" >&2
    exit 1
fi
echo "Configuration file is valid"

# Install files with backup
echo "Installing system files..."
install_with_no_backup() {
    local src=$1
    local dest=$2
    
    cp -f "$src" "$dest"
    echo "  Installed: $dest"
}

install_with_no_backup "$SCRIPT_DIR/$CONFIG_FILE" "$TARGET_CONFIG"
install_with_no_backup "$SCRIPT_DIR/$MOUNT_SCRIPT" "$TARGET_SCRIPT"
install_with_no_backup "$SCRIPT_DIR/$UNMOUNT_SCRIPT" "$TARGET_UNMOUNT_SCRIPT"
install_with_no_backup "$SCRIPT_DIR/$SERVICE_FILE" "$TARGET_SERVICE"

# Set permissions
chmod 0644 "$TARGET_CONFIG"
chmod 0755 "$TARGET_SCRIPT"
chmod 0755 "$TARGET_UNMOUNT_SCRIPT"
chmod 0644 "$TARGET_SERVICE"
echo "Permissions set"

# Create CLI command shortcut
create_symlink() {
    local script=$1
    local cli_command=$2
    local target_cli="/usr/local/bin/$cli_command"

    echo "Creating terminal command: $cli_command"
    if [ -L "$target_cli" ]; then
        # Remove existing symlink if it exists
        rm -f "$target_cli"
        echo "  Removed existing symlink"
    fi

    # Create new symlink
    ln -s "$script" "$target_cli"
    chmod 0755 "$target_cli"
    echo "  Created symlink: $target_cli → $script"
}

create_symlink "$TARGET_SCRIPT" "$CLI_COMMAND_MOUNT"
create_symlink "$TARGET_UNMOUNT_SCRIPT" "$CLI_COMMAND_UNMOUNT"



# Enable systemd service
echo "Enabling systemd service..."
systemctl daemon-reload
if systemctl enable auto_mount.service; then
    echo "Service enabled successfully"
else
    echo "Error enabling service" >&2
    exit 1
fi

echo "To start the service now use command systemctl start auto_mount.service or just reboot your system :P"
echo "Deployment complete!"