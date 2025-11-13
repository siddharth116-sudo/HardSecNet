#!/usr/bin/env bash
#
# AUDIT Script
# Category: Warning Banners
# Benchmarks:
#   - 1.6.2: Ensure /etc/motd is configured properly
#   - 1.6.3: Ensure remote login warning banner is configured properly
#

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
MOTD_FILE="/etc/motd"
ISSUE_NET_FILE="/etc/issue.net"
SSHD_CONFIG="/etc/ssh/sshd_config"

# --- Functions ---

log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" | tee -a "$LOGFILE"
}

run_check_1_6_2() {
  log "--- Starting CIS 1.6.2 Audit (motd) ---"
  local fail_flag=0

  if [[ -f "$MOTD_FILE" ]]; then
    log "PASS: $MOTD_FILE exists."
  else
    log "FAIL: $MOTD_FILE does not exist."
    return 1
  fi

  if [[ "$(stat -c "%u:%g" "$MOTD_FILE")" == "0:0" ]]; then
    log "PASS: Ownership is root:root."
  else
    log "FAIL: Ownership is NOT root:root. Current: $(stat -c "%U:%G" "$MOTD_FILE")."
    fail_flag=1
  fi

  local perms
  perms=$(stat -c "%a" "$MOTD_FILE")
  local owner_perm=${perms:0:1}
  local group_perm=${perms:1:1}
  local other_perm=${perms:2:1}

  if [[ "$owner_perm" -le 6 && "$group_perm" -le 4 && "$other_perm" -le 4 ]]; then
    log "PASS: Permissions ($perms) are compliant (644 or stricter)."
  else
    log "FAIL: Permissions ($perms) are NOT compliant."
    fail_flag=1
  fi

  if [[ -s "$MOTD_FILE" ]]; then
    log "PASS: $MOTD_FILE is not empty."
  else
    log "FAIL: $MOTD_FILE is empty."
    fail_flag=1
  fi

  if [[ $fail_flag -eq 0 ]]; then
    log "--- CIS 1.6.2 Audit Result: PASS ---"
    return 0
  else
    log "--- CIS 1.6.2 Audit Result: FAIL ---"
    return 1
  fi
}

run_check_1_6_3() {
  log "--- Starting CIS 1.6.3 Audit (issue.net) ---"
  local fail_flag=0

  if [[ -f "$ISSUE_NET_FILE" ]]; then
    log "PASS: $ISSUE_NET_FILE exists."
  else
    log "FAIL: $ISSUE_NET_FILE does not exist."
    fail_flag=1 # Can't check perms if it doesn't exist
  fi

  if [[ $fail_flag -eq 0 ]]; then
    if [[ "$(stat -c "%u:%g" "$ISSUE_NET_FILE")" == "0:0" ]]; then
      log "PASS: Ownership of $ISSUE_NET_FILE is root:root."
    else
      log "FAIL: Ownership is NOT root:root. Current: $(stat -c "%U:%G" "$ISSUE_NET_FILE")."
      fail_flag=1
    fi

    local perms
    perms=$(stat -c "%a" "$ISSUE_NET_FILE")
    local owner_perm=${perms:0:1}
    local group_perm=${perms:1:1}
    local other_perm=${perms:2:1}

    if [[ "$owner_perm" -le 6 && "$group_perm" -le 4 && "$other_perm" -le 4 ]]; then
      log "PASS: Permissions ($perms) for $ISSUE_NET_FILE are compliant (644 or stricter)."
    else
      log "FAIL: Permissions ($perms) for $ISSUE_NET_FILE are NOT compliant."
      fail_flag=1
    fi

    if [[ -s "$ISSUE_NET_FILE" ]]; then
      log "PASS: $ISSUE_NET_FILE is not empty."
    else
      log "FAIL: $ISSUE_NET_FILE is empty."
      fail_flag=1
    fi
  fi

  if grep -qE "^\s*Banner\s+$ISSUE_NET_FILE" "$SSHD_CONFIG"; then
    log "PASS: SSH is configured to use the banner file in $SSHD_CONFIG."
  else
    log "FAIL: SSH is NOT configured. 'Banner $ISSUE_NET_FILE' missing in $SSHD_CONFIG."
    fail_flag=1
  fi

  if [[ $fail_flag -eq 0 ]]; then
    log "--- CIS 1.6.3 Audit Result: PASS ---"
    return 0
  else
    log "--- CIS 1.6.3 Audit Result: FAIL ---"
    return 1
  fi
}

# --- Ensure root ---
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root." | tee -a "$LOGFILE"
   exit 1
fi

# --- Main Execution ---
log "--- Starting Warning Banners Audit ---"
FINAL_STATUS=0

run_check_1_6_2 || FINAL_STATUS=1
log "---"
run_check_1_6_3 || FINAL_STATUS=1
log "---"

if [[ $FINAL_STATUS -eq 0 ]]; then
  log "Overall Audit Status: PASS"
else
  log "Overall Audit Status: FAIL"
fi

exit $FINAL_STATUS
