#!/bin/bash

# ---
# AUDIT Script for CIS 1.7.6
#
# This script checks the effective dconf settings for media automount
# and whether those settings are locked.
#
# Usage: ./audit_1.7.6.sh <output_file.json>
#
# IMPORTANT: This script should be run as the regular user (not sudo)
#            to read the effective settings for the user's session.
# ---

# Check if an output file name was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output_file.json>"
    echo "Example: ./audit_1.7.6.sh report_before.json"
    exit 1
fi

OUTPUT_FILE="$1"

# 1. Check if dconf is installed
if ! command -v dconf &> /dev/null; then
    echo "dconf command not found. (Is dconf-cli installed?)"
    echo "Generating non-compliant report."
    
    JSON_OUTPUT=$(cat <<EOF
{
  "auditDetails": {
    "benchmarkId": "1.7.6",
    "title": "Ensure GDM automatic mounting of removable media is disabled",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "systemState": {
    "status": "Non-Compliant",
    "reason": "dconf command not found. Cannot audit settings."
  }
}
EOF
)
    echo "$JSON_OUTPUT" > "$OUTPUT_FILE"
    echo "Audit complete. Report saved to $OUTPUT_FILE"
    exit 1
fi

echo "Starting audit for CIS 1.7.6... saving report to $OUTPUT_FILE"

# 2. Define the dconf keys to check
KEY_AUTOMOUNT="/org/gnome/desktop/media-handling/automount"
KEY_AUTOOPEN="/org/gnome/desktop/media-handling/automount-open"

# 3. Read the current values
VALUE_AUTOMOUNT=$(dconf read "$KEY_AUTOMOUNT")
VALUE_AUTOOPEN=$(dconf read "$KEY_AUTOOPEN")

# 4. Check if the keys are locked
#    We check the list of all locked keys on this path
LOCKED_KEYS=$(dconf list -l "/org/gnome/desktop/media-handling/")

IS_LOCKED_AUTOMOUNT="false"
if echo "$LOCKED_KEYS" | grep -q "$(basename $KEY_AUTOMOUNT)"; then
    IS_LOCKED_AUTOMOUNT="true"
fi

IS_LOCKED_AUTOOPEN="false"
if echo "$LOCKED_KEYS" | grep -q "$(basename $KEY_AUTOOPEN)"; then
    IS_LOCKED_AUTOOPEN="true"
fi

# 5. Determine compliance
if [ "$VALUE_AUTOMOUNT" == "false" ] && [ "$VALUE_AUTOOPEN" == "false" ] && [ "$IS_LOCKED_AUTOMOUNT" == "true" ] && [ "$IS_LOCKED_AUTOOPEN" == "true" ]; then
    AUDIT_STATUS="Compliant"
else
    AUDIT_STATUS="Non-Compliant"
fi

# 6. Build the JSON output
JSON_OUTPUT=$(cat <<EOF
{
  "auditDetails": {
    "benchmarkId": "1.7.6",
    "title": "Ensure GDM automatic mounting of removable media is disabled",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "systemState": {
    "status": "$AUDIT_STATUS",
    "settings": [
      {
        "key": "$KEY_AUTOMOUNT",
        "value": "$VALUE_AUTOMOUNT",
        "is_locked": $IS_LOCKED_AUTOMOUNT
      },
      {
        "key": "$KEY_AUTOOPEN",
        "value": "$VALUE_AUTOOPEN",
        "is_locked": $IS_LOCKED_AUTOOPEN
      }
    ]
  }
}
EOF
)

# 7. Save the JSON to the specified file
echo "$JSON_OUTPUT" > "$OUTPUT_FILE"

echo "Audit complete. Report saved to $OUTPUT_FILE"
