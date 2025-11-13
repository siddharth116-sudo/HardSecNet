#!/usr/bin/env bash
# =============================================================================
# HARDEN: Filesystem & /var/log/audit (CIS 1.1.1.10 + 1.1.2.7.x)
# Applies: Disable unused FS, usb-storage, secure /var/log/audit mount
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
BACKUP_DIR="/var/backups/${SCRIPT_NAME%.sh}_$(date +%Y%m%d_%H%M%S)"
MOUNTPOINT="/var/log/audit"
FSTAB="/etc/fstab"
MODPROBE_DIR="/etc/modprobe.d"

# Modules to disable
FILESYSTEM_MODS=(cramfs freevxfs jffs2 hfs hfsplus squashfs udf vfat)
DEVICE_MODS=(usb-storage)
ALL_MODS=("${FILESYSTEM_MODS[@]}" "${DEVICE_MODS[@]}")
REQ_OPTIONS=("nodev" "nosuid" "noexec")

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" | tee -a "$LOGFILE"; }
backup_file() { [[ -f "$1" ]] && cp -a "$1" "${BACKUP_DIR}/$(basename "$1").bak.$(date +%s)" && log "BACKUP: $1"; }

# Root check
[[ $EUID -eq 0 ]] || { log "ERROR: Run as root (sudo)"; exit 1; }

mkdir -p "$BACKUP_DIR"
log "=== STARTING HARDENING ==="
log "Backup: $BACKUP_DIR"

# === 1.1.1.10: Disable unused modules ===
log "=== Disabling unused FS & usb-storage (1.1.1.10) ==="
for mod in "${ALL_MODS[@]}"; do
  conf="$MODPROBE_DIR/cis-disable-${mod}.conf"
  if lsmod | grep -q "^${mod} "; then
    log "Unloading $mod..."
    modprobe -r "$mod" || log "WARN: $mod in use, will disable on reboot"
  fi
  mkdir -p "$MODPROBE_DIR"
  backup_file "$conf"
  echo "install $mod /bin/true" > "$conf"
  log "DISABLED: $mod → $conf"
done

# === 1.1.2.7.1–4: Secure /var/log/audit ===
log "=== Securing $MOUNTPOINT partition (1.1.2.7.x) ==="
if ! findmnt -n "$MOUNTPOINT" >/dev/null 2>&1; then
  log "ERROR: $MOUNTPOINT is NOT a separate partition"
  log "ACTION: Create partition + add to $FSTAB with nodev,nosuid,noexec"
else
  backup_file "$FSTAB"
  for opt in "${REQ_OPTIONS[@]}"; do
    if ! grep -q "[[:space:]]$MOUNTPOINT[[:space:]].*${opt}" "$FSTAB"; then
      sed -i -r "s|([[:space:]]$MOUNTPOINT[[:space:]].*)defaults(.*)|\1defaults,${opt}\2|" "$FSTAB"
      log "ADDED: $opt to $FSTAB"
    fi
    mount -o "remount,$opt" "$MOUNTPOINT" 2>/dev/null && log "REMOUNTED with $opt" || log "ERROR: Failed remount $opt"
  done
fi

log "=== HARDENING COMPLETE ==="
log "Reboot recommended. Verify with: audit_filesystem.sh"
log "Log: $LOGFILE | Backups: $BACKUP_DIR"
