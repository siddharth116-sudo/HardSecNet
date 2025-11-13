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

# 6. Restart the SSH service to apply the configuration change
# 6. Restart the SSH service to apply the configuration change
echo "Restarting SSH service..."

# Check for systemctl (modern systems)
if command -v systemctl &> /dev/null; then
    if systemctl list-units --type=service --all | grep -q 'ssh.service'; then
        # Found ssh.service (Debian, Ubuntu, Kali, etc.)
        echo "Found 'ssh.service', restarting..."
        systemctl restart ssh.service
    elif systemctl list-units --type=service --all | grep -q 'sshd.service'; then
        # Found sshd.service (RHEL, CentOS, Fedora, etc.)
        echo "Found 'sshd.service', restarting..."
        systemctl restart sshd.service
    else
        echo "Could not find 'ssh.service' or 'sshd.service'. Please restart the SSH service manually."
    fi
# Fallback for older systems using 'service'
elif command -v service &> /dev/null; then
    echo "Using 'service' command to restart..."
    # This is a less reliable guess, but covers common cases
    if service --status-all 2>&1 | grep -q 'ssh'; then
        service ssh restart
    else
        service sshd restart
    fi
else
    echo "Could not find 'systemctl' or 'service'. Please restart the SSH service manually."
fi

echo "---"
echo "CIS 1.8.1 hardening complete."
echo "Please log out and log back in to verify the new MOTD banner."
echo "---"
