#!/bin/bash

# ---
# UNHARDEN Script for Warning Banners
# Reverts: 1.8.1 (motd), 1.8.2 (issue), 1.8.3 (issue.net)
# ---

echo "Reverting all Warning Banner hardening..."

# --- Define Files ---
MOTD_FILE="/etc/motd"
ISSUE_FILE="/etc/issue"
ISSUE_NET_FILE="/etc/issue.net"
SSHD_CONFIG_FILE="/etc/ssh/sshd_config"

# --- Revert 1.8.1: /etc/motd ---
echo "Reverting $MOTD_FILE..."
> "$MOTD_FILE" # Clear the file

# Re-enable dynamic MOTD scripts
if [ -d /etc/update-motd.d/ ]; then
    echo "Re-enabling executable permissions on dynamic MOTD scripts..."
    find /etc/update-motd.d/ -type f -exec chmod +x {} +
fi

# Revert PrintMotd in SSH config
echo "Configuring $SSHD_CONFIG_FILE to set 'PrintMotd yes'..."
sed -i -E 's/^[#\s]*PrintMotd\s+no/PrintMotd yes/' "$SSHD_CONFIG_FILE"

# --- Revert 1.8.2: /etc/issue ---
echo "Reverting $ISSUE_FILE..."
> "$ISSUE_FILE" # Clear the file
# (Optionally, restore symlink if you know the default)
# Example for Debian/Ubuntu: ln -s /var/run/motd /etc/issue

# --- Revert 1.8.3: /etc/issue.net ---
echo "Reverting $ISSUE_NET_FILE..."
> "$ISSUE_NET_FILE" # Clear the file

# Revert Banner in SSH config
echo "Removing Banner from $SSHD_CONFIG_FILE..."
sed -i -E "s|^\s*Banner\s+$ISSUE_NET_FILE|# Banner $ISSUE_NET_FILE (Disabled)|" "$SSHD_CONFIG_FILE"


# --- Final SSH Restart ---
echo "Restarting SSH service..."
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
