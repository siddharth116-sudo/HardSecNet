#!/usr/bin/env bash
#
# HARDEN Script
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

# --- Check Functions (for post-apply verification) ---

run_check_1_6_2() {
  log "--- Starting Post-Check CIS 1.6.2 (motd) ---"
  local fail_flag=0
  if [[ ! -f "$MOTD_FILE" ]]; then fail_flag=1; fi
  if [[ "$(stat -c "%u:%g" "$MOTD_FILE")" != "0:0" ]]; then fail_flag=1; fi
  local perms; perms=$(stat -c "%a" "$MOTD_FILE")
  if [[ "$perms" != "644" ]]; then fail_flag=1; fi
  if [[ ! -s "$MOTD_FILE" ]]; then fail_flag=1; fi

  if [[ $fail_flag -eq 0 ]]; then
    log "--- Post-Check CIS 1.6.2 Result: PASS ---"
    return 0
  else
    log "--- Post-Check CIS 1.6.2 Result: FAIL ---"
    return 1
  fi
}

run_check_1_6_3() {
  log "--- Starting Post-Check CIS 1.6.3 (issue.net) ---"
  local fail_flag=0
  if [[ ! -f "$ISSUE_NET_FILE" ]]; then fail_flag=1; fi
  if [[ "$(stat -c "%u:%g" "$ISSUE_NET_FILE")" != "0:0" ]]; then fail_flag=1; fi
  local perms; perms=$(stat -c "%a" "$ISSUE_NET_FILE")
  if [[ "$perms" != "644" ]]; then fail_flag=1; fi
  if [[ ! -s "$ISSUE_NET_FILE" ]]; then fail_flag=1; fi
  if ! grep -qE "^\s*Banner\s+$ISSUE_NET_FILE" "$SSHD_CONFIG"; then fail_flag=1; fi

  if [[ $fail_flag -eq 0 ]]; then
    log "--- Post-Check CIS 1.6.3 Result: PASS ---"
    return 0
  else
    log "--- Post-Check CIS 1.6.3 Result: FAIL ---"
    return 1
  fi
}

# --- Apply Functions ---

run_apply_1_6_2() {
  log "--- Starting CIS 1.6.2 Remediation (motd) ---"
  read -r -d '' BANNER_TEXT << 'EOM'
*******************************************************************************
* This system is for the use of authorized users only. Activities on this     *
* system are monitored and recorded. Anyone using this system expressly       *
* consents to such monitoring and is advised that if it reveals possible      *
* evidence of criminal activity, system personnel may provide the evidence    *
* of such monitoring to law enforcement officials.                            *
*******************************************************************************
EOM

  log "1. Writing banner to $MOTD_FILE..."
  echo "$BANNER_TEXT" > "$MOTD_FILE"
  log "2. Setting ownership to root:root..."
  chown root:root "$MOTD_FILE"
  log "3. Setting permissions to 644..."
  chmod 644 "$MOTD_FILE"
  log "--- CIS 1.6.2 Remediation Complete ---"
}

run_apply_1_6_3() {
  log "--- Starting CIS 1.6.3 Remediation (issue.net) ---"
  read -r -d '' BANNER_TEXT << 'EOM'
*******************************************************************************
* This system is for the use of authorized users only. Activities on this     *
* system are monitored and recorded. Anyone using this system expressly       *
* consents to such monitoring and is advised that if it reveals possible      *
* evidence of criminal activity, system personnel may provide the evidence    *
* of such monitoring to law enforcement officials.                            *
*******************************************************************************
EOM

  log "1. Writing banner to $ISSUE_NET_FILE..."
  echo "$BANNER_TEXT" > "$ISSUE_NET_FILE"
  log "2. Setting ownership to root:root..."
  chown root:root "$ISSUE_NET_FILE"
  log "3. Setting permissions to 644..."
  chmod 644 "$ISSUE_NET_FILE"
  log "4. Configuring SSH daemon..."
  sed -i -E 's/^\s*#?\s*Banner\s+.*//' "$SSHD_CONFIG"
  echo "Banner $ISSUE_NET_FILE" >> "$SSHD_CONFIG"
  
  log "5. Restarting SSH service..."
  if command -v systemctl &> /dev/null; then
    # Handle different service names
    if systemctl list-units --type=service --all | grep -q 'ssh.service'; then
        systemctl restart ssh.service
    elif systemctl list-units --type=service --all | grep -q 'sshd.service'; then
        systemctl restart sshd.service
    fi
  elif command -v service &> /dev/null; then
    service sshd restart || service ssh restart
  else
    log "WARNING: Could not restart SSH service. Please restart manually."
  fi
  
  log "--- CIS 1.6.3 Remediation Complete ---"
}

# --- Ensure root ---
if [[ $EUID -ne 0 ]]; then
   log "ERROR: This script must be run as root."
   exit 1
fi

# --- Main Execution ---
log "--- Starting Warning Banners Remediation ---"
run_apply_1_6_2
run_apply_1_6_3
log "---"
log "--- Running Post-Remediation Checks ---"
sleep 2 # Give services time to restart
run_check_1_6_2
run_check_1_6_3
log "--- Remediation & Post-Checks Complete ---"
