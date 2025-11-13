#!/bin/bash

# ---
# HARDEN Script for Network Services
# Benchmarks:
#   - 2.1.8:   Uninstall Dovecot
#   - 2.1.21:  Configure Postfix for local-only
# ---

echo "Applying Network Service Hardening..."

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

# --- Harden 2.1.8: Uninstall Dovecot ---
DOVECOT_PKG="dovecot" # This may need to be "dovecot-core" etc.
if is_package_installed "$DOVECOT_PKG"; then
    echo "Hardening 2.1.8: Uninstalling '$DOVECOT_PKG'..."
    if command -v apt-get &> /dev/null; then
        apt-get purge -y "$DOVECOT_PKG"
    elif command -v dnf &> /dev/null; then
        dnf remove -y "$DOVECOT_PKG"
    elif command -v yum &> /dev/null; then
        yum remove -y "$DOVECOT_PKG"
    else
        echo "WARNING (2.1.8): Cannot find a package manager to remove '$DOVECOT_PKG'."
    fi
else
    echo "Hardening 2.1.8: '$DOVECOT_PKG' is not installed. (Skipping)"
fi

# --- Harden 2.1.21: Configure Postfix ---
POSTFIX_CONFIG="/etc/postfix/main.cf"
if [ ! -f "$POSTFIX_CONFIG" ]; then
    echo "Hardening 2.1.21: Postfix not installed. (Skipping)"
else
    echo "Hardening 2.1.21: Configuring Postfix for local-only mode..."
    # Use postconf to safely edit the main.cf file.
    postconf -e "inet_interfaces = localhost"

    echo "Reloading Postfix service..."
    if command -v systemctl &> /dev/null; then
        systemctl reload postfix
    elif command -v service &> /dev/null; then
        service postfix reload
    else
        echo "WARNING (2.1.21): Could not reload Postfix. Please reload it manually."
    fi
fi

echo "--- Network Service Hardening Complete ---"
