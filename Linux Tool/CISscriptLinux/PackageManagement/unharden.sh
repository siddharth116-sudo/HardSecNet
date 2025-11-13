#!/bin/bash

# ---
# UNHARDEN Script for Package Management
# Reverts:
#   - 1.2.2.1: Uninstall additional security software
# ---

echo "Reverting Package Management Hardening..."

# --- Detect OS ---
if [ ! -f /etc/os-release ]; then
    echo "ERROR: /etc/os-release not found. Cannot detect OS."
    exit 1
fi
OS="$(. /etc/os-release && echo $ID)"

# --- Define Packages ---
# This list must match the harden.sh script
REQUIRED_PKGS=("aide" "auditd" "chrony" "fail2ban")

echo "Removing security packages: ${REQUIRED_PKGS[*]}"

# --- Main Unhardening Execution ---
case "$OS" in
  debian|ubuntu)
    echo "Removing packages..."
    apt-get remove -y "${REQUIRED_PKGS[@]}"
    ;;
  rhel|centos|rocky|almalinux|fedora)
    echo "Removing packages..."
    if command -v dnf &> /dev/null; then
        dnf remove -y "${REQUIRED_PKGS[@]}"
    else
        yum remove -y "${REQUIRED_PKGS[@]}"
    fi
    ;;
  sles|opensuse*)
    echo "Removing packages..."
    zypper remove -y "${REQUIRED_PKGS[@]}"
    ;;
  *)
    echo "WARNING: Unsupported OS ($OS). Cannot remove packages."
    echo "--- Unhardening FAILED ---"
    exit 1
    ;;
esac

echo "--- Package Management Unhardening Complete ---"
