#!/usr/bin/env bash

# CIS Benchmark 2.1.22
# Information gathering script to list all listening network services.

set -euo pipefail
IFS=$'\n\t'

# --- Script Configuration ---
SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"

# --- Functions ---

# Log messages to stdout and a log file
log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" | tee -a "$LOGFILE"
}

# --- Main Logic ---

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   log "ERROR: This script must be run as root to identify all processes."
   exit 1
fi

log "--- Starting CIS 2.1.22 Information Gathering ---"
log "Listing all listening TCP and UDP sockets and the processes using them..."
log "Use this output to manually verify against your list of approved services."
echo # for spacing

# ss is the modern tool to investigate sockets.
# -l: listening sockets
# -n: numeric ports (faster, no DNS lookups)
# -t: TCP sockets
# -u: UDP sockets
# -p: show process using socket
ss -lntup

echo # for spacing
log "--- MANUAL ACTION REQUIRED ---"
log "Review the list of services above in the 'Local Address:Port' and 'Users' columns."
log "Compare this list against your organization's approved services for this server."
log "Any service not on the approved list should be disabled or uninstalled."
log "--- End of CIS 2.1.22 Information Gathering ---"

exit 0
