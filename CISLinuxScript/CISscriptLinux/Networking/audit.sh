#!/bin/bash

# ---
# AUDIT Script for CIS 3.1.2
#
# This script checks if all wireless interfaces are disabled (soft blocked)
# using the 'rfkill' command.
#
# Usage: ./audit_3.1.2.sh <output_file.json>
# ---

# Check if an output file name was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output_file.json>"
    echo "Example: ./audit_3.1.2.sh report_before.json"
    exit 1
fi

OUTPUT_FILE="$1"

# 1. Check if rfkill is installed
if ! command -v rfkill &> /dev/null; then
    echo "rfkill command not found. (Is rfkill installed?)"
    echo "Generating non-compliant report."
    
    JSON_OUTPUT=$(cat <<EOF
{
  "auditDetails": {
    "benchmarkId": "3.1.2",
    "title": "Ensure wireless interfaces are disabled",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "systemState": {
    "status": "Non-Compliant",
    "reason": "rfkill command not found. Cannot audit wireless status."
  }
}
EOF
)
    echo "$JSON_OUTPUT" > "$OUTPUT_FILE"
    echo "Audit complete. Report saved to $OUTPUT_FILE"
    exit 1
fi

echo "Starting audit for CIS 3.1.2... saving report to $OUTPUT_FILE"

# 2. Get the rfkill list output
RFKILL_OUTPUT=$(rfkill list all)

# 3. Check for any device that is "Soft blocked: no"
#    We ignore "Hard blocked" as that's a physical switch and we can't control it.
#    If we find *any* device that is not soft blocked, we are non-compliant.
if echo "$RFKILL_OUTPUT" | grep -q "Soft blocked: no"; then
    AUDIT_STATUS="Non-Compliant"
    SUMMARY="At least one wireless device is currently unblocked."
else
    AUDIT_STATUS="Compliant"
    SUMMARY="All wireless devices are soft blocked."
fi

# 4. Build the JSON output
#    We will capture the full rfkill list as base64 to avoid JSON formatting issues
ENCODED_RFKILL_LIST=$(echo "$RFKILL_OUTPUT" | base64 -w 0)

JSON_OUTPUT=$(cat <<EOF
{
  "auditDetails": {
    "benchmarkId": "3.1.2",
    "title": "Ensure wireless interfaces are disabled",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "systemState": {
    "status": "$AUDIT_STATUS",
    "summary": "$SUMMARY",
    "details": {
      "rfkill_list_output_base64": "$ENCODED_RFKILL_LIST"
    }
  }
}
EOF
)

# 5. Save the JSON to the specified file
echo "$JSON_OUTPUT" > "$OUTPUT_FILE"

echo "Audit complete. Report saved to $OUTPUT_FILE"
