#!/usr/bin/env bash
# CIS Benchmark 1.1.2.7.2
# Ensure nodev option set on /var/log/audit partition

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
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

log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" | tee -a "$LOGFILE"
}

MOUNTPOINT="/var/log/audit"

check_partition_exists() {
  if ! findmnt -n "$MOUNTPOINT" >/dev/null 2>&1; then
    log "FAIL: $MOUNTPOINT is not a separate partition (see CIS 1.1.2.7.1)"
    return 1
  fi
}

check_nodev_option() {
  if findmnt -no OPTIONS "$MOUNTPOINT" | grep -qw nodev; then
    log "PASS: $MOUNTPOINT is mounted with nodev"
    return 0
  else
    log "FAIL: $MOUNTPOINT is not mounted with nodev"
    return 1
  fi
}

remediate_nodev_option() {
  local fstab="/etc/fstab"

  if ! grep -qE "[[:space:]]$MOUNTPOINT[[:space:]]" "$fstab"; then
    log "FAIL: $MOUNTPOINT not found in $fstab. Cannot remediate automatically."
    log "ACTION REQUIRED: Add an fstab entry with nodev option."
    return 1
  fi

  if grep -qE "[[:space:]]$MOUNTPOINT[[:space:]]" "$fstab" && ! grep -qE "[[:space:]]$MOUNTPOINT[[:space:]].*nodev" "$fstab"; then
    log "Adding nodev option to $fstab entry for $MOUNTPOINT ..."
    cp "$fstab" "${fstab}.bak.$(date +%Y%m%d%H%M%S)"
    sed -i -r "s|(^.*[[:space:]]$MOUNTPOINT[[:space:]].*)defaults(.*)|\1defaults,nodev\2|" "$fstab"
  fi

  log "Remounting $MOUNTPOINT with nodev ..."
  mount -o remount,nodev "$MOUNTPOINT" || {
    log "ERROR: Failed to remount $MOUNTPOINT with nodev"
    return 1
  }

  log "SUCCESS: $MOUNTPOINT remounted with nodev"
  return 0
}

if [[ "$MODE" == "check" ]]; then
  check_partition_exists
  check_nodev_option
elif [[ "$MODE" == "apply" ]]; then
  check_partition_exists
  remediate_nodev_option
  check_nodev_option
fi
