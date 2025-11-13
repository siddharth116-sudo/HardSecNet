#!/bin/bash

# ---
# UNHARDEN Script for Warning Banners
# Reverts: 1.6.2 (/etc/motd) & 1.6.3 (/etc/issue.net)
# ---

echo "Reverting Warning Banner Hardening..."

# --- Define Files ---
MOTD_FILE="/etc/motd"
ISSUE_NET_FILE="/etc/issue.net"
SSHD_CONFIG="/etc/ssh/sshd_config"

# 1. Revert /etc/motd
echo "Clearing $MOTD_FILE..."
> "$MOTD_FILE" # Truncate file to zero bytes
# (We leave it with 644 perms, as this is standard)
chown root:root "$MOTD_FILE"
chmod 644 "$MOTD_FILE"

# 2. Revert /etc/issue.net
echo "Clearing $ISSUE_NET_FILE..."
> "$ISSUE_NET_FILE" # Truncate file to zero bytes
chown root:root "$ISSUE_NET_FILE"
chmod 644 "$ISSUE_NET_FILE"

# 3. Revert sshd_config
echo "Removing banner from $SSHD_CONFIG..."
# Find the specific banner line and comment it out
sed -i -E "s|^\s*Banner\s+$ISSUE_NET_FILE|# Banner $ISSUE_NET_FILE (Disabled)|" "$SSHD_CONFIG"

echo "Restarting SSH service to apply changes..."
# Use the robust restart logic
if command -v systemctl &> /dev/null; then
    if systemctl list-units --type=service --all | grep -q 'ssh.service'; then
        systemctl restart ssh.service
    elif systemctl list-units --type=service --all | grep -q 'sshd.service'; then
        systemctl restart sshd.service
    fi
else
    echo "Could not find 'systemctl'. Please restart SSH manually if needed."
fi

echo "--- Warning Banner Unhardening Complete ---"
