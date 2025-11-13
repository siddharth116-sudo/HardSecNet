#!/usr/bin/env bash
# =============================================================================
# UNHARDEN: CIS 5.2.7 - Remove su command restriction
# Reverts: pam_wheel.so + sugroup
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
BACKUP_DIR="/var/backups/harden_su.sh_*"  # Find latest backup
PAM_FILE="/etc/pam.d/su"
GROUP="sugroup"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" | tee -a "$LOGFILE"; }

# Root check
[[ $EUID -eq 0 ]] || { log "ERROR: Run as root (sudo)"; exit 1; }

log "=== STARTING UNHARDEN CIS 5.2.7 (su) ==="

# === 1. Find latest backup of /etc/pam.d/su ===
LATEST_BACKUP=$(ls -t $BACKUP_DIR/$(basename "$PAM_FILE").bak* 2>/dev/null | head -1)

if [[ -n "$LATEST_BACKUP" && -f "$LATEST_BACKUP" ]]; then
    cp -a "$PAM_FILE" "${PAM_FILE}.unharden.$(date +%s)"  # Final backup
    cp -a "$LATEST_BACKUP" "$PAM_FILE"
    log "RESTORED: $PAM_FILE from $LATEST_BACKUP"
else
    log "WARN: No backup found. Manually removing restriction..."
    sed -i '/^auth.*pam_wheel\.so.*group=sugroup/d' "$PAM_FILE"
    log "REMOVED: pam_wheel.so line from $PAM_FILE"
fi

# === 2. Remove sugroup (if empty) ===
if getent group "$GROUP" >/dev/null; then
    if ! getent passwd | cut -d: -f4 | tr ',' '\n' | grep -q "^$(getent group "$GROUP" | cut -d: -f3)$"; then
        groupdel "$GROUP"
        log "DELETED group: $GROUP (empty)"
    else
        log "SKIP: Group $GROUP has users — not deleting"
    fi
else
    log "Group $GROUP already gone"
fi

# === 3. Final verification ===
if ! grep -q "pam_wheel\.so" "$PAM_FILE"; then
    log "SUCCESS: su is now UNRESTRICTED"
else
    log "WARN: Some pam_wheel lines may remain (non-sugroup)"
fi

log "=== UNHARDEN COMPLETE ==="
log "Now ANY user with password can use 'su'"
log "Test: su - (as normal user) → should work"
log "Log: $LOGFILE"
