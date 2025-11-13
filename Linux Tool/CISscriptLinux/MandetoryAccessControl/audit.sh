#!/bin/bash

# ---
# AUDIT Script for AppArmor Boot Config (CIS 1.3.1.2)
#
# Usage: ./audit.sh <output_file.json>
# ---

# 1. Check for output file argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output_file.json>"
    exit 1
fi

OUTPUT_FILE="$1"
echo "Starting audit for AppArmor Boot Config... saving report to $OUTPUT_FILE"

# --- Define Files ---
GRUB_FILE="/etc/default/grub"

# --- Variables for JSON Report ---
AUDIT_STATUS="Compliant"
declare -a settings

# 1. Check if AppArmor is installed
if command -v apparmor_status &> /dev/null; then
    settings+=("{\"check\": \"AppArmor Installed\", \"status\": \"Compliant\"}")
else
    settings+=("{\"check\": \"AppArmor Installed\", \"status\": \"Non-Compliant\"}")
    AUDIT_STATUS="Non-Compliant"
fi

# 2. Check GRUB config for 'apparmor=1'
if grep -qE "apparmor=1" "$GRUB_FILE"; then
    settings+=("{\"check\": \"GRUB apparmor=1\", \"status\": \"Compliant\"}")
else
    settings+=("{\"check\": \"GRUB apparmor=1\", \"status\": \"Non-Compliant\"}")
    AUDIT_STATUS="Non-Compliant"
fi

# 3. Check GRUB config for 'security=apparmor'
if grep -qE "security=apparmor" "$GRUB_FILE"; then
    settings+=("{\"check\": \"GRUB security=apparmor\", \"status\": \"Compliant\"}")
else
    settings+=("{\"check\": \"GRUB security=apparmor\", \"status\": \"Non-Compliant\"}")
    AUDIT_STATUS="Non-Compliant"
fi

# --- Build Final JSON ---
JSON_SETTINGS=$(IFS=,; echo "${settings[*]}")

JSON_OUTPUT=$(cat <<EOF
{
  "auditDetails": {
    "benchmarkId": "1.3.1.2",
    "title": "Ensure AppArmor is enabled in the bootloader configuration",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "systemState": {
    "status": "$AUDIT_STATUS",
    "grub_config_file": "$GRUB_FILE",
    "checks": [
      $JSON_SETTINGS
    ]
  }
}
EOF
)

# Save the JSON to the specified file
echo "$JSON_OUTPUT" > "$OUTPUT_FILE"

echo "Audit complete. Report saved to $OUTPUT_FILE"
