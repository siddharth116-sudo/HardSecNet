#!/bin/bash

# ---
# UNHARDEN Script for Network Services
# Reverts:
#   - 2.1.8:   Install Dovecot
#   - 2.1.21:  Configure Postfix for 'all' interfaces
# ---

echo "Reverting Network Service Hardening..."

# --- Helper: Check if package is installed ---
is_package_installed() {
    if command -v dpkg &> /dev/null; then
        dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
    elif command -v rpm &> /dev/null; then
        rpm -q "$1" &> /dev/null
    else
        return 1
    fi
}

# --- Unharden 2.1.8: Install Dovecot ---
DOVECOT_PKG="dovecot" # This may need to be more specific, e.g., "dovecot-imapd"
if is_package_installed "$DOVECOT_PKG"; then
    echo "Unharden 2.1.8: '$DOVECOT_PKG' is already installed. (Skipping)"
else
    echo "Unharden 2.1.8: Installing '$DOVECOT_PKG'..."
    if command -v apt-get &> /dev/null; then
        apt-get install -y "$DOVECOT_PKG"
    elif command -v dnf &> /dev/null; then
        dnf install -y "$DOVECOT_PKG"
    elif command -v yum &> /dev/null; then
        yum install -y "$DOVECOT_PKG"
    else
        echo "WARNING (2.1.8): Cannot find a package manager to install '$DOVECOT_PKG'."
    fi
fi

# --- Unharden 2.1.21: Configure Postfix ---
POSTFIX_CONFIG="/etc/postfix/main.cf"
if [ ! -f "$POSTFIX_CONFIG" ]; then
    echo "Unharden 2.1.21: Postfix not installed. (Skipping)"
else
    echo "Unharden 2.1.21: Configuring Postfix for 'all' interfaces..."
    # Use postconf to set to the default
    postconf -e "inet_interfaces = all"

    echo "Reloading Postfix service..."
    if command -v systemctl &> /dev/null; then
        systemctl reload postfix
    elif command -v service &> /dev/null; then
        service postfix reload
    else
        echo "WARNING (2.1.21): Could not reload Postfix. Please reload it manually."
    fi
fi

echo "--- Network Service Unhardening Complete ---"
