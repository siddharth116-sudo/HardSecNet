#!/bin/bash

# ---
# UNHARDENING Script for CIS 1.7.6
#
# This script reverts the hardening by removing the system-wide
# dconf settings and locks for media automount created by
# 'hardening_1.7.6.sh'.
# ---

echo "Reverting CIS 1.7.6: Re-enabling automatic mounting of removable media..."

# 1. Define the exact file paths created by the hardening script
SETTINGS_FILE_PATH="/etc/dconf/db/local.d/10-cis-automount"
LOCK_FILE_PATH="/etc/dconf/db/local.d/locks/10-cis-automount"

# 2. Remove the settings file
if [ -f "$SETTINGS_FILE_PATH" ]; then
    echo "Removing settings file: $SETTINGS_FILE_PATH"
    rm -f "$SETTINGS_FILE_PATH"
else
    echo "Settings file not found (already removed): $SETTINGS_FILE_PATH"
fi

# 3. Remove the lock file
if [ -f "$LOCK_FILE_PATH" ]; then
    echo "Removing lock file: $LOCK_FILE_PATH"
    rm -f "$LOCK_FILE_PATH"
else
    echo "Lock file not found (already removed): $LOCK_FILE_PATH"
fi

# 4. Update the system-wide dconf database to apply the changes
#    This re-compiles the database without the hardening files.
if command -v dconf &> /dev/null; then
    echo "Updating system dconf database..."
    dconf update
else
    echo "WARNING: 'dconf' command not found. Database not updated."
    echo "Please ensure 'dconf-cli' is installed and run 'sudo dconf update' manually."
fi

echo "---"
echo "CIS 1.7.6 unhardening complete."
echo "!! IMPORTANT: You must LOG OUT and LOG BACK IN for this change to take effect."
echo "After logging in, the system will revert to its default behavior (automounting)."
echo "---"
