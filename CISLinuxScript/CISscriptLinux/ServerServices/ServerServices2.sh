#!/usr/bin/env bash

# CIS Benchmark 2.1.21
# Ensure mail transfer agent (Postfix) is configured for local-only mode

set -euo pipefail
IFS=$'\n\t'

# --- Script Configuration ---
SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
MODE="" # Default mode
POSTFIX_CONFIG="/etc/postfix/main.cf"

# --- Functions ---

# Print script usage
usage() {
  echo "Usage: $0 [--check|--apply]"
  exit 1
}

# Log messages to stdout and a log file
log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" | tee -a "$LOGFILE"
}

# --- Main Logic ---

# Parse command-line arguments
[[ $# -eq 0 ]] && usage
case "$1" in
  --check) MODE="check" ;;
  --apply) MODE="apply" ;;
  --help|-h) usage ;;
  *) usage ;;
esac


# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   log "ERROR: This script must be run as root."
   exit 1
fi

# Check if Postfix is installed. If not, this control is not applicable.
if [[ ! -f "$POSTFIX_CONFIG" ]]; then
    log "INFO: Postfix configuration file not found at $POSTFIX_CONFIG."
    log "--- CIS 2.1.21 Audit Result: NOT APPLICABLE (Postfix not installed) ---"
    exit 0
fi

run_check() {
  log "--- Starting CIS 2.1.21 Audit for Postfix ---"
  
  # postconf -n shows only non-default settings. If inet_interfaces is not
  # set, it defaults to 'all', so we check for that case.
  local current_setting
  current_setting=$(postconf -n inet_interfaces | awk -F' = ' '{print $2}' || echo "all")
  
  if [[ "$current_setting" == "localhost" || "$current_setting" == "loopback-only" ]]; then
    log "PASS: Postfix is correctly configured for local-only mode (inet_interfaces = $current_setting)."
    log "--- CIS 2.1.21 Audit Result: PASS ---"
    return 0
  else
    log "FAIL: Postfix is NOT configured for local-only mode. 'inet_interfaces' is set to '$current_setting'."
    log "--- CIS 2.1.21 Audit Result: FAIL ---"
    return 1
  fi
}

run_apply() {
  log "--- Starting CIS 2.1.21 Remediation for Postfix ---"

  log "1. Configuring 'inet_interfaces = localhost' using postconf..."
  # Use postconf to safely edit the main.cf file.
  postconf -e "inet_interfaces = localhost"

  log "2. Reloading Postfix service to apply changes..."
  if command -v systemctl &> /dev/null; then
    systemctl reload postfix
  elif command -v service &> /dev/null; then
    service postfix reload
  else
    log "WARNING: Could not reload Postfix service. Please reload it manually."
  fi
  
  log "--- CIS 2.1.21 Remediation Complete ---"
}

# --- Execution ---

if [[ "$MODE" == "check" ]]; then
  run_check
elif [[ "$MODE" == "apply" ]]; then
  run_apply
  run_check # Run a check after applying to verify success
fi
