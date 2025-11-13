#!/bin/bash

# ---
# HARDEN Script for AppArmor Boot Config (CIS 1.3.1.2)
# ---

echo "Applying AppArmor Boot Config Hardening (1.3.1.2)..."

GRUB_FILE="/etc/default/grub"

# 1. Check if AppArmor is installed
if ! command -v apparmor_status &> /dev/null; then
    echo "ERROR: AppArmor is not installed."
    echo "Please install 'apparmor' and 'apparmor-utils' first."
    echo "e.g., sudo apt install apparmor apparmor-utils"
    echo "--- Hardening FAILED ---"
    exit 1
fi

# 2. Backup the GRUB config file
echo "Backing up $GRUB_FILE to ${GRUB_FILE}.bak..."
cp "$GRUB_FILE" "${GRUB_FILE}.bak.$(date +%Y%m%d%H%M%S)"

# 3. Add parameters to GRUB_CMDLINE_LINUX
# This adds the parameters if they are missing
echo "Adding 'apparmor=1 security=apparmor' to $GRUB_FILE..."
if grep -q '^GRUB_CMDLINE_LINUX=' "$GRUB_FILE"; then
    # Find the line, and add the parameters inside the quotes
    # This sed command is complex but robust:
    # 1. It finds the GRUB_CMDLINE_LINUX line
    # 2. It removes existing 'apparmor=1' or 'security=apparmor' (to avoid duplicates)
    # 3. It adds the new parameters to the end, just before the closing quote
    sed -i -E 's/^(GRUB_CMDLINE_LINUX=".*)"/\1"/' "$GRUB_FILE" | sed -i -E 's/apparmor=1//' "$GRUB_FILE" | sed -i -E 's/security=apparmor//' "$GRUB_FILE"
    sed -i -E 's/^(GRUB_CMDLINE_LINUX=".*)"/\1 apparmor=1 security=apparmor"/' "$GRUB_FILE"
else
    # If line doesn't exist at all, add it
    echo 'GRUB_CMDLINE_LINUX="apparmor=1 security=apparmor"' >> "$GRUB_FILE"
fi

# 4. Rebuild GRUB
echo "Rebuilding GRUB configuration..."
if command -v update-grub &> /dev/null; then
    update-grub
elif command -v grub2-mkconfig &> /dev/null; then
    # For RHEL/CentOS/Fedora systems
    grub2-mkconfig -o /boot/grub2/grub.cfg
else
    echo "WARNING: Could not find 'update-grub' or 'grub2-mkconfig'."
    echo "You must rebuild your GRUB configuration manually!"
fi

echo "--- AppArmor Hardening Complete ---"
echo "!! IMPORTANT: A system REBOOT is required for these changes to take effect."
