#!/bin/bash

# ---
# AUDIT Script for Network Services
# Benchmarks:
#   - 2.1.8:   Ensure Dovecot is not in use
#   - 2.1.21:  Ensure Postfix is in local-only mode
#   - 2.1.22:  List all listening services
#
# Usage: ./audit.sh <output_file.json>
# ---

# 1. Check for output file argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output_file.json>"
    exit 1
fi

OUTPUT_FILE="$1"
echo "Starting audit for Network Services... saving report to $OUTPUT_FILE"

# --- Variables for JSON Report ---
AUDIT_STATUS="Compliant"
declare -a checks

# --- Helper: Check if package is installed ---
is_package_installed() {
    if command -v dpkg &> /dev/null; then
        dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
    elif command -v rpm &> /dev/null; then
        rpm -q "$1" &> /dev/null
    else
        return 1 # Cannot determine
    fi
}

# --- Audit 2.1.8: Dovecot ---
echo "Auditing: 2.1.8 (Dovecot)..."
if is_package_installed "dovecot"; then
    checks+=("{\"benchmark\": \"2.1.8\", \"check\": \"Dovecot Installed\", \"status\": \"Non-Compliant\"}")
    AUDIT_STATUS="Non-Compliant"
else
    checks+=("{\"benchmark\": \"2.1.8\", \"check\": \"Dovecot Installed\", \"status\": \"Compliant\"}")
fi

# --- Audit 2.1.21: Postfix ---
echo "Auditing: 2.1.21 (Postfix)..."
POSTFIX_CONFIG="/etc/postfix/main.cf"
if [ ! -f "$POSTFIX_CONFIG" ]; then
    checks+=("{\"benchmark\": \"2.1.21\", \"check\": \"Postfix Config\", \"status\": \"Not Applicable (Postfix not installed)\"}")
else
    # postconf -n shows non-default settings. Default is 'all'.
    current_setting=$(postconf -n inet_interfaces | awk -F' = ' '{print $2}' || echo "all")
    if [[ "$current_setting" == "localhost" || "$current_setting" == "loopback-only" ]]; then
        checks+=("{\"benchmark\": \"2.1.21\", \"check\": \"Postfix inet_interfaces\", \"status\": \"Compliant\", \"value\": \"$current_setting\"}")
    else
        checks+=("{\"benchmark\": \"2.1.21\", \"check\": \"Postfix inet_interfaces\", \"status\": \"Non-Compliant\", \"value\": \"$current_setting\"}")
        AUDIT_STATUS="Non-Compliant"
    fi
fi

# --- Audit 2.1.22: List Listening Services ---
echo "Auditing: 2.1.22 (Listening Services)..."
# ss -lntup: listening, numeric, tcp, udp, processes
service_list=$(ss -lntup)
service_list_base64=$(echo "$service_list" | base64 -w 0)

checks+=("{\"benchmark\": \"2.1.22\", \"check\": \"Listening Services\", \"status\": \"Informational\", \"details\": \"See 'ss_lntup_base64' for output.\", \"ss_lntup_base64\": \"$service_list_base64\"}")

# --- Build Final JSON ---
JSON_CHECKS=$(IFS=,; echo "${checks[*]}")

JSON_OUTPUT=$(cat <<EOF
{
  "auditDetails": {
    "benchmarkId": "2.1.8, 2.1.21, 2.1.22",
    "title": "Network Service Configuration",
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
