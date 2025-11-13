#!/bin/bash

# ---
# CIS Benchmark: 4.2.7 (and 4.2.6, 4.2.8)
# Category: UFW
# Description: Ensure ufw default deny firewall policy. This script sets
#              INPUT, OUTPUT, and FORWARD policies to 'deny'.
#
# !! IMPORTANT !!
# This script enables the firewall. To prevent you from being locked
# out, it automatically adds allow rules for SSH (port 22) and
# loopback (localhost) connections.
# ---

echo "Applying CIS 4.2.x: Setting UFW default deny policy..."

# 1. Install UFW if it's not already installed
if ! command -v ufw &> /dev/null; then
    echo "ufw command not found. Installing..."
    apt update
    apt install -y ufw
else
    echo "ufw is already installed."
fi

# 2. Set default policies to DENY
#    This is the core of a "default deny" stance.
echo "Setting default INPUT policy to DENY..."
ufw default deny incoming

echo "Setting default OUTPUT policy to DENY..."
ufw default deny outgoing

echo "Setting default FORWARD policy to DENY..."
ufw default deny forward

# 3. Allow essential services
#    If we don't do this, enabling the firewall will lock us out.
echo "Allowing essential loopback (localhost) traffic..."
ufw allow in on lo
ufw allow out on lo

echo "Allowing essential SSH traffic (port 22/tcp)..."
ufw allow ssh

# 4. Enable the firewall
#    The 'force' option is used to bypass the interactive prompt in a script.
echo "Enabling the firewall..."
yes | ufw enable
# Note: 'yes | ufw enable' or 'ufw --force enable' can be used.
# Using 'yes |' to pipe "y" to the prompt.

echo "---"
echo "CIS 4.2.7 hardening complete."
echo "Firewall is now active with a 'default deny' policy."
echo "Run 'sudo ufw status verbose' to see the new rules."
echo "---"
