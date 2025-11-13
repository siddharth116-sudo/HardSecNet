#!/usr/bin/env bash
#
# UNHARDEN Script
# Category: Warning Banners
# Benchmarks:
#   - 1.6.2: Revert /etc/motd
#   - 1.6.3: Revert /etc/issue.net and SSH config
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

# --- Ensure root ---
if [[ $EUID -ne 0 ]]; then
   log "ERROR: This script must be run as root."
   exit 1
fi

# --- Main Execution ---
log "--- Starting Warning Banners Unhardening ---"

# 1. Revert 1.6.2
log "Reverting 1.6.2: Clearing $MOTD_FILE..."
# We just clear the file, as it's safer than deleting.
# And ensure it's writable by dynamic MOTD scripts if needed.
> "$MOTD_FILE"
chmod 644 "$MOTD_FILE"
chown root:root "$MOTD_FILE"

# 2. Revert 1.6.3
log "Reverting 1.6.3: Clearing $ISSUE_NET_FILE..."
> "$ISSUE_NET_FILE"
chmod 644 "$ISSUE_NET_FILE"
chown root:root "$ISSUE_NET_FILE"

log "Reverting 1.6.3: Removing Banner from $SSHD_CONFIG..."
# This comments out the Banner line
sed -i -E "s/^\s*Banner\s+$ISSUE_NET_FILE/# Banner $ISSUE_NET_FILE (Disabled)/" "$SSHD_CONFIG"

log "Restarting SSH service to apply changes..."
if command -v systemctl &> /dev/null; then
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

log "--- Unhardening Complete ---"
