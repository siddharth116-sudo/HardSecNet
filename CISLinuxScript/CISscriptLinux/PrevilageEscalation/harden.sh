#!/usr/bin/env bash
# =============================================================================
# CIS 5.2.7: Ensure access to the su command is restricted
# Restricts 'su' to members of 'sugroup' only
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
BACKUP_DIR="/var/backups/${SCRIPT_NAME%.sh}_$(date +%Y%m%d_%H%M%S)"
PAM_FILE="/etc/pam.d/su"
GROUP="sugroup"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" | tee -a "$LOGFILE"; }
backup_file() { [[ -f "$1" ]] && cp -a "$1" "${BACKUP_DIR}/$(basename "$1").bak" && log "BACKUP: $1"; }

# Root check
[[ $EUID -eq 0 ]] || { log "ERROR: Run as root (sudo)"; exit 1; }

mkdir -p "$BACKUP_DIR"
log "=== STARTING CIS 5.2.7 HARDENING (su restriction) ==="
log "Backup: $BACKUP_DIR"

# Create group if not exists
if ! getent group "$GROUP" >/dev/null; then
    groupadd "$GROUP"
    log "CREATED group: $GROUP"
else
    log "Group $GROUP already exists"
fi

# Backup PAM file
backup_file "$PAM_FILE"

# Remove any old auth lines for su
sed -i '/^auth.*pam_wheel.so/d' "$PAM_FILE" 2>/dev/null || true

# Add required line (exact CIS format)
if ! grep -q "auth.*required.*pam_wheel.so.*use_uid.*group=$GROUP" "$PAM_FILE"; then
    echo "auth required pam_wheel.so use_uid group=$GROUP" >> "$PAM_FILE"
    log "ADDED: pam_wheel.so restriction for group=$GROUP"
else
    log "Already restricted to group=$GROUP"
fi

log "=== HARDENING COMPLETE ==="
log "Now only members of '$GROUP' can use 'su'"
log "Test: sudo ./audit_su.sh"
log "Log: $LOGFILE | Backups: $BACKUP_DIR"
