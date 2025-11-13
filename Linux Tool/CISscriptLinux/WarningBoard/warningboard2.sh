#!/bin/bash

# ---
# CIS Benchmark: 1.8.2 Ensure local login warning banner is configured properly
# Category: Warning Banners
# Description: Sets a static /etc/issue banner for local TTY logins and
#              removes dynamic (OS-leaking) information.
# ---

echo "Applying CIS 1.8.2: Configuring Local Login Banner (/etc/issue)..."

# 1. Define the authorized access banner text.
#    !! IMPORTANT: This should be the *exact same* legal text used in 1.8.1.
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

echo "---"
echo "CIS 1.8.2 hardening complete."
echo "Please verify by switching to a local TTY (e.g., Ctrl+Alt+F3)."
echo "---"
