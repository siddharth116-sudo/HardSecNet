#!/bin/bash

# ---
# AUDIT Script for Package Management
# Benchmarks:
#   - 1.2.1.2: Check GPG key configuration
#   - 1.2.2.1: Check for updates and security software
#
# Usage: ./audit.sh <output_file.json>
# ---

# 1. Check for output file argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output_file.json>"
    exit 1
fi

OUTPUT_FILE="$1"
echo "Starting audit for Package Management... saving report to $OUTPUT_FILE"

# --- Detect OS ---
if [ ! -f /etc/os-release ]; then
    echo "ERROR: /etc/os-release not found. Cannot detect OS."
    exit 1
fi
OS="$(. /etc/os-release && echo $ID)"
OS_VER="$(. /etc/os-release && echo $VERSION_ID)"

# --- Variables for JSON Report ---
AUDIT_STATUS="Compliant"
declare -a checks

# --- 1.2.1.2: GPG Key Checks ---

check_gpg_keys_debian() {
    echo "Auditing: APT GPG keys..."
    if apt-cache policy | grep -q "signed-by"; then
        checks+=("{\"benchmark\": \"1.2.1.2\", \"check\": \"APT GPG Keys\", \"status\": \"Compliant\", \"details\": \"Repositories use 'signed-by'.\"}")
    else
        checks+=("{\"benchmark\": \"1.2.1.2\", \"check\": \"APT GPG Keys\", \"status\": \"Non-Compliant\", \"details\": \"Repositories may not enforce GPG signing.\"}")
        AUDIT_STATUS="Non-Compliant"
    fi
}

check_gpg_keys_rhel() {
    echo "Auditing: YUM/DNF GPG keys..."
    local gpg_fail=0
    for repo in /etc/yum.repos.d/*.repo; do
        if ! grep -q "^gpgcheck=1" "$repo"; then
            checks+=("{\"benchmark\": \"1.2.1.2\", \"check\": \"$repo\", \"status\": \"Non-Compliant\", \"details\": \"gpgcheck=1 is not set.\"}")
            gpg_fail=1
        fi
    done
    if [ $gpg_fail -eq 0 ]; then
        checks+=("{\"benchmark\": \"1.2.1.2\", \"check\": \"YUM/DNF GPG Keys\", \"status\": \"Compliant\", \"details\": \"All repos have gpgcheck=1.\"}")
    else
        AUDIT_STATUS="Non-Compliant"
    fi
}

check_gpg_keys_suse() {
    echo "Auditing: Zypper GPG keys..."
    if zypper lr -d | awk 'NR>2 {print $9}' | grep -qvi "Yes"; then
        checks+=("{\"benchmark\": \"1.2.1.2\", \"check\": \"Zypper GPG Keys\", \"status\": \"Non-Compliant\", \"details\": \"One or more repos do not enforce GPG check.\"}")
        AUDIT_STATUS="Non-Compliant"
    else
        checks+=("{\"benchmark\": \"1.2.1.2\", \"check\": \"Zypper GPG Keys\", \"status\": \"Compliant\", \"details\": \"All repos enforce GPG check.\"}")
    fi
}

# --- 1.2.2.1: Update Checks ---

check_updates_debian() {
    echo "Auditing: Pending APT updates..."
    apt-get update -qq
    local UPDATES
    UPDATES=$(apt list --upgradable 2>/dev/null | tail -n +2)
    if [[ -n "$UPDATES" ]]; then
        checks+=("{\"benchmark\": \"1.2.2.1\", \"check\": \"Pending Updates\", \"status\": \"Non-Compliant\", \"details\": \"Updates are available. Run 'apt list --upgradable'.\"}")
        AUDIT_STATUS="Non-Compliant"
    else
        checks+=("{\"benchmark\": \"1.2.2.1\", \"check\": \"Pending Updates\", \"status\": \"Compliant\", \"details\": \"System is up to date.\"}")
    fi
}

check_updates_rhel() {
    echo "Auditing: Pending YUM/DNF updates..."
    local UPDATES
    if command -v dnf &> /dev/null; then
        UPDATES=$(dnf check-update)
    else
        UPDATES=$(yum check-update)
    fi
    if echo "$UPDATES" | grep -q '^[[:alnum:]]'; then
        checks+=("{\"benchmark\": \"1.2.2.1\", \"check\": \"Pending Updates\", \"status\": \"Non-Compliant\", \"details\": \"Updates are available. Run 'dnf check-update'.\"}")
        AUDIT_STATUS="Non-Compliant"
    else
        checks+=("{\"benchmark\": \"1.2.2.1\", \"check\": \"Pending Updates\", \"status\": \"Compliant\", \"details\": \"System is up to date.\"}")
    fi
}

check_updates_suse() {
    echo "Auditing: Pending Zypper updates..."
    local UPDATES
    UPDATES=$(zypper lu)
    if echo "$UPDATES" | grep -q '^v'; then
        checks+=("{\"benchmark\": \"1.2.2.1\", \"check\": \"Pending Updates\", \"status\": \"Non-Compliant\", \"details\": \"Updates are available. Run 'zypper lu'.\"}")
        AUDIT_STATUS="Non-Compliant"
    else
        checks+=("{\"benchmark\": \"1.2.2.1\", \"check\": \"Pending Updates\", \"status\": \"Compliant\", \"details\": \"System is up to date.\"}")
    fi
}

# --- 1.2.2.1: Security Software Check ---

REQUIRED_PKGS=("aide" "auditd" "chrony" "fail2ban")

check_security_packages() {
    echo "Auditing: Security package installation..."
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if command -v dpkg &> /dev/null; then
            if dpkg -s "$pkg" &> /dev/null; then
                checks+=("{\"benchmark\": \"1.2.2.1\", \"check\": \"$pkg installed\", \"status\": \"Compliant\"}")
            else
                checks+=("{\"benchmark\": \"1.2.2.1\", \"check\": \"$pkg installed\", \"status\": \"Non-Compliant\"}")
                AUDIT_STATUS="Non-Compliant"
            fi
        elif command -v rpm &> /dev/null; then
            if rpm -q "$pkg" &> /dev/null; then
                checks+=("{\"benchmark\": \"1.2.2.1\", \"check\": \"$pkg installed\", \"status\": \"Compliant\"}")
            else
                checks+=("{\"benchmark\": \"1.2.2.1\", \"check\": \"$pkg installed\", \"status\": \"Non-Compliant\"}")
                AUDIT_STATUS="Non-Compliant"
            fi
        fi
    done
}

# --- Main Audit Execution ---

case "$OS" in
  debian|ubuntu)
    check_gpg_keys_debian
    check_updates_debian
    ;;
  rhel|centos|rocky|almalinux|fedora)
    check_gpg_keys_rhel
    check_updates_rhel
    ;;
  sles|opensuse*)
    check_gpg_keys_suse
    check_updates_suse
    ;;
  *)
    checks+=("{\"benchmark\": \"N/A\", \"check\": \"OS Support\", \"status\": \"Non-Compliant\", \"details\": \"Unsupported OS ($OS).\"}")
    AUDIT_STATUS="Non-Compliant"
    ;;
esac

check_security_packages

# --- Build Final JSON ---
JSON_CHECKS=$(IFS=,; echo "${checks[*]}")

JSON_OUTPUT=$(cat <<EOF
{
  "auditDetails": {
    "benchmarkId": "1.2.1.2 & 1.2.2.1",
    "title": "Package Manager Configuration",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "systemState": {
    "status": "$AUDIT_STATUS",
    "os_id": "$OS",
    "os_version": "$OS_VER",
    "checks": [
      $JSON_CHECKS
    ]
  }
}
EOF
)

# Save the JSON to the specified file
echo "$JSON_OUTPUT" > "$OUTPUT_FILE"
echo "Audit complete. Report saved to $OUTPUT_FILE"
