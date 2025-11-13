#!/bin/bash

# ---
# CIS Benchmark: 1.8.3 Ensure remote login warning banner is configured properly
# Category: Warning Banners
# Description: Sets a static /etc/issue.net banner and configures SSH to
#              display it before login.
# ---

echo "Applying CIS 1.8.3: Configuring Remote Login Banner (/etc/issue.net)..."

# 1. Define the authorized access banner text.
#    !! IMPORTANT: This should be the *exact same* legal text used in 1.8.1/1.8.2.
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

# 5. Restart the SSH service to apply the configuration change
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
echo "CIS 1.8.3 hardening complete."
echo "Please verify by attempting a new SSH login (e.g., 'ssh localhost')."
echo "---"
