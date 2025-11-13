#!/bin/bash

# ---
# CIS Benchmark: 1.8.1 Ensure message of the day is configured properly
# Category: Warning Banners
# Description: Sets a static MOTD banner, sets correct permissions,
#              and disables dynamic MOTD scripts that may leak OS info.
# ---

echo "Applying CIS 1.8.1: Configuring Message of the Day..."

# 1. Define the authorized access banner text.
#    !! IMPORTANT: Replace this with text approved by your organization's legal department.
BANNER_TEXT="********************************************************************
* *
* This system is for the use of authorized users only. Individuals   *
* using this computer system without authority, or in excess of    *
* their authority, are subject to having all of their activities   *
* on this system monitored and recorded by system personnel.       *
* *
* In the course of monitoring individuals improperly using this    *
* system, or in the course of system maintenance, the activities   *
* of authorized users may also be monitored.                       *
* *
* Anyone using this system expressly consents to such monitoring   *
* and is advised that if such monitoring reveals possible          *
* evidence of criminal activity, system personnel may provide the  *
* evidence of such monitoring to law enforcement officials.        *
* *
********************************************************************"

# 2. Write the static banner text to /etc/motd
echo "Setting static MOTD in /etc/motd..."
cat > /etc/motd << EOF
$BANNER_TEXT
EOF

# 3. Set the correct ownership and permissions for /etc/motd
echo "Setting permissions for /etc/motd (owner: root:root, perms: 644)..."
chown root:root /etc/motd
chmod 644 /etc/motd

# 4. Disable dynamic MOTD scripts (to prevent OS info leaks)
#    This specifically addresses the "(error OS links removed)" part.
if [ -d /etc/update-motd.d/ ]; then
    echo "Disabling executable permissions on dynamic MOTD scripts in /etc/update-motd.d/..."
    # Find all files in the directory and remove their execute bit
    find /etc/update-motd.d/ -type f -exec chmod -x {} +
else
    echo "/etc/update-motd.d/ directory not found, skipping dynamic MOTD disabling."
fi

# 5. Configure sshd to let PAM handle the MOTD display
#    This prevents the banner from being shown twice.
echo "Configuring /etc/ssh/sshd_config to set 'PrintMotd no'..."
# This command finds 'PrintMotd yes' (even if commented) and changes it to 'PrintMotd no'
sed -i -E 's/^[#\s]*PrintMotd\s+yes/PrintMotd no/' /etc/ssh/sshd_config

# ---
# CIS Benchmark: 1.8.2 Ensure local login warning banner is configured properly
# ---

echo "Applying CIS 1.8.2: Configuring Local Login Banner (/etc/issue)..."

# 2. Check if /etc/issue is a symlink (common on modern systems)
#    If it is, it's likely linked to a dynamic file. We must remove it.
if [ -L /etc/issue ]; then
    echo "Found symlink at /etc/issue. Removing it to create static file..."
    rm -f /etc/issue
fi

# 3. Write the static banner text to /etc/issue
echo "Setting static banner in /etc/issue..."
cat > /etc/issue << EOF
$BANNER_TEXT

EOF
# Note: A blank line is added at the end for clean formatting before the login prompt.

# 4. Set the correct ownership and permissions for /etc/issue
echo "Setting permissions for /etc/issue (owner: root:root, perms: 644)..."
chown root:root /etc/issue
chmod 644 /etc/issue

# ---
# CIS Benchmark: 1.8.3 Ensure remote login warning banner is configured properly
# ---

echo "Applying CIS 1.8.3: Configuring Remote Login Banner (/etc/issue.net)..."

# 2. Write the static banner text to /etc/issue.net
echo "Setting static banner in /etc/issue.net..."
cat > /etc/issue.net << EOF
$BANNER_TEXT
EOF

# 3. Set the correct ownership and permissions for /etc/issue.net
echo "Setting permissions for /etc/issue.net (owner: root:root, perms: 644)..."
chown root:root /etc/issue.net
chmod 644 /etc/issue.net

# 4. Configure sshd to display the banner
SSHD_CONFIG_FILE="/etc/ssh/sshd_config"

echo "Configuring $SSHD_CONFIG_FILE to set 'Banner /etc/issue.net'..."

# Check if the 'Banner' line already exists (commented or not)
if grep -qE '^[#\s]*Banner' "$SSHD_CONFIG_FILE"; then
    # It exists, so we'll replace it to ensure it's uncommented and correct
    sed -i -E 's/^[#\s]*Banner\s+.*/Banner \/etc\/issue.net/' "$SSHD_CONFIG_FILE"
else
    # It doesn't exist, so we'll add it to the end of the file
    echo "Banner /etc/issue.net" >> "$SSHD_CONFIG_FILE"
fi

# ---
# Final SSH Restart for all changes
# ---
echo "Restarting SSH service..."

# Use the improved logic that works for Kali (ssh.service)
if command -v systemctl &> /dev/null; then
    if systemctl list-units --type=service --all | grep -q 'ssh.service'; then
        echo "Found 'ssh.service', restarting..."
        systemctl restart ssh.service
    elif systemctl list-units --type=service --all | grep -q 'sshd.service'; then
        echo "Found 'sshd.service', restarting..."
        systemctl restart sshd.service
    else
        echo "Could not find 'ssh.service' or 'sshd.service'. Please restart the SSH service manually."
    fi
else
    echo "Could not find 'systemctl'. Please restart the SSH service manually."
fi

echo "---"
echo "All Warning Banner hardening (1.8.1, 1.8.2, 1.8.3) complete."
echo "---"
