#!/bin/bash

# ---
# HARDEN Script for Package Management
# Benchmark:
#   - 1.2.2.1: Install additional security software
# ---

echo "Applying Package Management Hardening (1.2.2.1)..."

# --- Detect OS ---
if [ ! -f /etc/os-release ]; then
    echo "ERROR: /etc/os-release not found. Cannot detect OS."
    exit 1
fi
OS="$(. /etc/os-release && echo $ID)"

# --- Define Packages ---
# You can add or remove packages from this list
REQUIRED_PKGS=("aide" "auditd" "chrony" "fail2ban")

echo "Ensuring security packages are installed: ${REQUIRED_PKGS[*]}"

# --- Main Hardening Execution ---
case "$OS" in
  debian|ubuntu)
    echo "Updating APT cache..."
    apt-get update -qq
    echo "Installing packages..."
    apt-get install -y "${REQUIRED_PKGS[@]}"
    ;;
  rhel|centos|rocky|almalinux|fedora)
    echo "Installing packages..."
    if command -v dnf &> /dev/null; then
        dnf install -y "${REQUIRED_PKGS[@]}"
    else
        yum install -y "${REQUIRED_PKGS[@]}"
    fi
    ;;
  sles|opensuse*)
    echo "Installing packages..."
    zypper install -y "${REQUIRED_PKGS[@]}"
    ;;
  *)
    echo "WARNING: Unsupported OS ($OS). Cannot install packages."
    echo "--- Hardening FAILED ---"
    exit 1
    ;;
esac

echo "--- Package Management Hardening Complete ---"
echo "NOTE: This script does NOT apply system updates. Run your package manager's update command manually."
