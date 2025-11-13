#!/bin/bash

# ---
# UNHARDEN Script for AppArmor Boot Config (CIS 1.3.1.2)
# ---

echo "Reverting AppArmor Boot Config Hardening..."

GRUB_FILE="/etc/default/grub"

# 1. Backup the GRUB config file
echo "Backing up $GRUB_FILE to ${GRUB_FILE}.bak..."
cp "$GRUB_FILE" "${GRUB_FILE}.bak.$(date +%Y%m%d%H%M%S)"

# 2. Remove parameters from GRUB_CMDLINE_LINUX
echo "Removing 'apparmor=1' and 'security=apparmor' from $GRUB_FILE..."
sed -i -E 's/apparmor=1//' "$GRUB_FILE"
sed -i -E 's/security=apparmor//' "$GRUB_FILE"
# Clean up extra spaces
sed -i -E 's/(\s)+/ /g' "$GRUB_FILE"

# 3. Rebuild GRUB
echo "Rebuilding GRUB configuration..."
if command -v update-grub &> /dev/null; then
    update-grub
elif command -v grub2-mkconfig &> /dev/null; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
else
    echo "WARNING: Could not find 'update-grub' or 'grub2-mkconfig'."
    echo "You must rebuild your GRUB configuration manually!"
fi

echo "--- AppArmor Unhardening Complete ---"
echo "!! IMPORTANT: A system REBOOT is required for these changes to take effect."
