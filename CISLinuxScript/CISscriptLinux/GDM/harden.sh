#!/bin/bash

# ---
# Hardening Script: Disable USB Storage to Prevent Use of Removable Media
# Description: Disables the usb-storage kernel module to prevent detection and use of USB pendrives and similar removable storage devices.
#              This goes beyond just disabling automount by preventing the system from loading the module required for USB storage.
#              Note: This will disable all USB mass storage devices system-wide.
# ---

echo "Applying hardening: Disabling USB storage..."

# 1. Define the path for modprobe configuration
MODPROBE_DIR="/etc/modprobe.d"
CONFIG_FILE="$MODPROBE_DIR/disable-usb-storage.conf"

# 2. Ensure the directory exists
echo "Ensuring modprobe directory exists..."
mkdir -p "$MODPROBE_DIR"

# 3. Create the configuration file to disable usb-storage
echo "Creating modprobe config file: $CONFIG_FILE"
cat > "$CONFIG_FILE" << EOF
# Disable USB storage per hardening requirements
install usb_storage /bin/true
blacklist usb_storage
EOF

# 4. Unload the module if it's currently loaded
if lsmod | grep -q usb_storage; then
    echo "Unloading usb_storage module..."
    modprobe -r usb_storage
    if [ $? -eq 0 ]; then
        echo "usb_storage module unloaded successfully."
    else
        echo "Failed to unload usb_storage module. It may be in use."
    fi
else
    echo "usb_storage module is not loaded."
fi

# 5. Update initramfs if necessary (for persistence across reboots)
if command -v update-initramfs >/dev/null 2>&1; then
    echo "Updating initramfs..."
    update-initramfs -u
elif command -v dracut >/dev/null 2>&1; then
    echo "Running dracut to update initramfs..."
    dracut -f
fi

echo "---"
echo "USB storage disabling complete."
echo "!! IMPORTANT: Reboot the system for changes to fully take effect if the module was unloaded."
echo "After reboot, insert a USB drive to verify it is not detected or mountable."
echo "Note: This script assumes a Debian/Ubuntu or Red Hat based system. Adjust for other distros if needed."
echo "---"
