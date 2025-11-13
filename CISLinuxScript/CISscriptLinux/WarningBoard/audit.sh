#!/bin/bash

# ---
# AUDIT Script for Warning Banners
# Benchmarks:
#   - 1.8.1: Ensure /etc/motd is configured
#   - 1.8.2: Ensure /etc/issue is configured
#   - 1.8.3: Ensure /etc/issue.net is configured
#
# Usage: ./audit.sh <output_file.json>
# ---

# 1. Check for output file argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output_file.json>"
    exit 1
fi

OUTPUT_FILE="$1"
echo "Starting audit for Warning Banners... saving report to $OUTPUT_FILE"

# --- Define Files ---
MOTD_FILE="/etc/motd"
ISSUE_FILE="/etc/issue"
ISSUE_NET_FILE="/etc/issue.net"
SSHD_CONFIG_FILE="/etc/ssh/sshd_config"

# --- Variables for JSON Report ---
AUDIT_STATUS="Compliant"
declare -a checks

# --- Helper Function to Check File Permissions ---
# Usage: check_file "Benchmark" "File Name" "/path/to/file"
check_file_perms() {
    local benchmark=$1
    local name=$2
    local file=$3
    local status="Compliant"
    local details=""

    if [ ! -f "$file" ]; then
        status="Non-Compliant"
        details="File not found."
    elif [ "$(stat -c "%U:%G" "$file")" != "root:root" ]; then
        status="Non-Compliant"
        details="Owner is $(stat -c "%U:%G" "$file"), not root:root."
    elif [ "$(stat -c "%a" "$file")" != "644" ]; then
        status="Non-Compliant"
        details="Permissions are $(stat -c "%a" "$file"), not 644."
    fi

    checks+=("{\"benchmark\": \"$benchmark\", \"check\": \"$name File Permissions\", \"status\": \"$status\", \"details\": \"$details\"}")
    if [ "$status" == "Non-Compliant" ]; then AUDIT_STATUS="Non-Compliant"; fi
}

# --- Audit 1.8.1: /etc/motd ---
check_file_perms "1.8.1" "$MOTD_FILE" "$MOTD_FILE"

# Check for executable dynamic MOTD scripts
if [ -d /etc/update-motd.d/ ] && [ -n "$(find /etc/update-motd.d/ -type f -executable)" ]; then
    checks+=("{\"benchmark\": \"1.8.1\", \"check\": \"Dynamic MOTD\", \"status\": \"Non-Compliant\", \"details\": \"Executable scripts found in /etc/update-motd.d/\"}")
    AUDIT_STATUS="Non-Compliant"
else
    checks+=("{\"benchmark\": \"1.8.1\", \"check\": \"Dynamic MOTD\", \"status\": \"Compliant\", \"details\": \"No executable scripts found in /etc/update-motd.d/\"}")
fi

# Check SSHD config for PrintMotd
if grep -qE "^[#\s]*PrintMotd\s+yes" "$SSHD_CONFIG_FILE"; then
    checks+=("{\"benchmark\": \"1.8.1\", \"check\": \"SSHD PrintMotd\", \"status\": \"Non-Compliant\", \"details\": \"'PrintMotd no' is not set in $SSHD_CONFIG_FILE\"}")
    AUDIT_STATUS="Non-Compliant"
else
    checks+=("{\"benchmark\": \"1.8.1\", \"check\": \"SSHD PrintMotd\", \"status\": \"Compliant\", \"details\": \"'PrintMotd no' is set.\"}")
fi

# --- Audit 1.8.2: /etc/issue ---
check_file_perms "1.8.2" "$ISSUE_FILE" "$ISSUE_FILE"
if [ -L "$ISSUE_FILE" ]; then
    checks+=("{\"benchmark\": \"1.8.2\", \"check\": \"$ISSUE_FILE Type\", \"status\": \"Non-Compliant\", \"details\": \"File is a symbolic link.\"}")
    AUDIT_STATUS="Non-Compliant"
else
    checks+=("{\"benchmark\": \"1.8.2\", \"check\": \"$ISSUE_FILE Type\", \"status\": \"Compliant\", \"details\": \"File is a regular file.\"}")
fi

# --- Audit 1.8.3: /etc/issue.net ---
check_file_perms "1.8.3" "$ISSUE_NET_FILE" "$ISSUE_NET_FILE"

# Check SSHD config for Banner
if grep -qE "^\s*Banner\s+$ISSUE_NET_FILE" "$SSHD_CONFIG_FILE"; then
    checks+=("{\"benchmark\": \"1.8.3\", \"check\": \"SSHD Banner\", \"status\": \"Compliant\", \"details\": \"'Banner $ISSUE_NET_FILE' is set.\"}")
else
    checks+=("{\"benchmark\": \"1.8.3\", \"check\": \"SSHD Banner\", \"status\": \"Non-Compliant\", \"details\": \"'Banner $ISSUE_NET_FILE' is not set in $SSHD_CONFIG_FILE\"}")
    AUDIT_STATUS="Non-Compliant"
fi

# --- Build Final JSON ---
JSON_CHECKS=$(IFS=,; echo "${checks[*]}")

JSON_OUTPUT=$(cat <<EOF
{
  "auditDetails": {
    "benchmarkId": "1.8.1, 1.8.2, 1.8.3",
    "title": "Warning Banners (motd, issue, issue.net)",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "systemState": {
    "status": "$AUDIT_STATUS",
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
