#!/usr/bin/env bash
# CIS Benchmark 1.1.2.7.1
# Ensure separate partition exists for /var/log/audit

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

check_partition() {
  local mountpoint="/var/log/audit"

  # Check runtime mount
  if findmnt -n "$mountpoint" >/dev/null 2>&1; then
    log "PASS: $mountpoint has a separate partition (found in mount list)"
    return 0
  else
    log "FAIL: $mountpoint does not have a separate partition (not found in mount list)"
    return 1
  fi
}

remediate_partition() {
  local mountpoint="/var/log/audit"

  if findmnt -n "$mountpoint" >/dev/null 2>&1; then
    log "INFO: $mountpoint already has a separate partition, no remediation needed"
    return 0
  else
    log "ACTION REQUIRED: $mountpoint does not have a separate partition."
    log "To remediate, you must:"
    log "  1. Create a new partition or LVM volume (e.g., /dev/sdXn)."
    log "  2. Format it: mkfs.ext4 /dev/sdXn"
    log "  3. Create the directory if missing: mkdir -p /var/log/audit"
    log "  4. Update /etc/fstab with an entry like:"
    log "       /dev/sdXn   /var/log/audit   ext4   defaults,nodev,nosuid,noexec   0 2"
    log "  5. Mount it: mount /var/log/audit"
    log "  6. Restart auditd: systemctl restart auditd"
    log "NOTE: Automatic partition creation is not performed to avoid data loss."
    return 1
  fi
}

if [[ "$MODE" == "check" ]]; then
  check_partition
elif [[ "$MODE" == "apply" ]]; then
  remediate_partition
fi
