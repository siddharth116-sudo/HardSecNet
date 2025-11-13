#!/usr/bin/env bash
# CIS Benchmark 1.1.1.10
# Ensure unused filesystems and usb-storage kernel modules are not available

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
BACKUP_DIR="/var/backups/${SCRIPT_NAME%.sh}"
MODE="check"   # default

usage() {
  echo "Usage: $SCRIPT_NAME [--check|--apply]"
  exit 1
}

[[ $# -eq 0 ]] && usage
case "$1" in
  --check) MODE="check" ;;
  --apply) MODE="apply" ;;
  --help|-h) usage ;;
  *) usage ;;
esac

mkdir -p "$BACKUP_DIR"

log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" | tee -a "$LOGFILE"
}

disable_module() {
  local mod="$1"
  local conf="/etc/modprobe.d/cis-disable-${mod}.conf"

  if lsmod | grep -q "^${mod}"; then
    if [[ "$MODE" == "apply" ]]; then
      log "Unloading module $mod ..."
      modprobe -r "$mod" || log "Could not remove module $mod (maybe in use)"
    else
      log "Module $mod is currently loaded"
    fi
  fi

  if [[ -f "$conf" ]] && grep -q "install ${mod} /bin/true" "$conf"; then
    log "Module $mod already disabled in $conf"
  else
    if [[ "$MODE" == "apply" ]]; then
      log "Disabling module $mod via $conf"
      echo "install ${mod} /bin/true" > "$conf"
    else
      log "Would disable module $mod via $conf"
    fi
  fi
}

# === CIS 1.1.1.10: Disable unused FS kernel modules ===
FILESYSTEM_MODS=(cramfs freevxfs jffs2 hfs hfsplus squashfs udf vfat)

# === Additional subcategory: Disable usb-storage ===
DEVICE_MODS=(usb-storage)

ALL_MODS=("${FILESYSTEM_MODS[@]}" "${DEVICE_MODS[@]}")

log "[$MODE] Checking/disabling unused filesystem and device kernel modules..."

for mod in "${ALL_MODS[@]}"; do
  disable_module "$mod"
done

log "[$MODE] Completed CIS 1.1.1.10 compliance check"
