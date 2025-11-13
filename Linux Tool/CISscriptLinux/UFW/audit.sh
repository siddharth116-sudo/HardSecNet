#!/bin/bash

# ---
# AUDIT Script for CIS 4.2.7
#
# This script checks the status of UFW and its default policies.
# It saves the current state to a JSON file.
#
# Usage: ./audit_4.2.7.sh <output_file.json>
# ---

# Check if an output file name was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output_file.json>"
    exit 1
fi

OUTPUT_FILE="$1"
echo "Starting audit for CIS 4.2.7... saving report to $OUTPUT_FILE"

# Check if ufw is installed
if ! command -v ufw &> /dev/null; then
    echo "ufw command not found. Reporting as Non-Compliant."
    UFW_STATUS="not_installed"
    POLICY_INPUT="unknown"
    POLICY_OUTPUT="unknown"
    POLICY_FORWARD="unknown"
else
    # Get the verbose status
    UFW_VERBOSE_OUTPUT=$(ufw status verbose)

    # Check if firewall is active
    if echo "$UFW_VERBOSE_OUTPUT" | grep -q "Status: active"; then
        UFW_STATUS="active"
        
        # Parse the 'Default:' line
        DEFAULT_LINE=$(echo "$UFW_VERBOSE_OUTPUT" | grep "Default:")
        
        # Use regex to find the policies
        POLICY_INPUT=$(echo "$DEFAULT_LINE" | grep -oP 'Default:\s*\K[a-z]+(?=\s*\(incoming\))')
        POLICY_OUTPUT=$(echo "$DEFAULT_LINE" | grep -oP '\s*\K[a-z]+(?=\s*\(outgoing\))')
        POLICY_FORWARD=$(echo "$DEFAULT_LINE" | grep -oP '\s*\K[a-z]+(?=\s*\(forwarding\))')
        
    else
        UFW_STATUS="inactive"
        # If inactive, the system is non-compliant. Policies are not enforced.
        POLICY_INPUT="N/A (Firewall Inactive)"
        POLICY_OUTPUT="N/A (Firewall Inactive)"
        POLICY_FORWARD="N/A (Firewall Inactive)"
    fi
fi

# Build the JSON output
JSON_OUTPUT=$(cat <<EOF
{
  "auditDetails": {
    "benchmarkId": "4.2.7",
    "title": "Ensure ufw default deny firewall policy",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "systemState": {
    "ufw_status": "$UFW_STATUS",
    "policy_input": "$POLICY_INPUT",
    "policy_output": "$POLICY_OUTPUT",
    "policy_forward": "$POLICY_FORWARD"
  }
}
EOF
)

# Save the JSON to the specified file
echo "$JSON_OUTPUT" > "$OUTPUT_FILE"

echo "Audit complete. Report saved to $OUTPUT_FILE"
