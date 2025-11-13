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
#!/usr/bin/env bash
# CIS Benchmark 1.1.2.7.3
# Ensure nosuid option set on /var/log/audit partition

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

check_nosuid_option() {
  if findmnt -no OPTIONS "$MOUNTPOINT" | grep -qw nosuid; then
    log "PASS: $MOUNTPOINT is mounted with nosuid"
    return 0
  else
    log "FAIL: $MOUNTPOINT is not mounted with nosuid"
    return 1
  fi
}

remediate_nosuid_option() {
  local fstab="/etc/fstab"

  if ! grep -qE "[[:space:]]$MOUNTPOINT[[:space:]]" "$fstab"; then
    log "FAIL: $MOUNTPOINT not found in $fstab. Cannot remediate automatically."
    log "ACTION REQUIRED: Add an fstab entry with nosuid option."
    return 1
  fi

  if grep -qE "[[:space:]]$MOUNTPOINT[[:space:]]" "$fstab" && ! grep -qE "[[:space:]]$MOUNTPOINT[[:space:]].*nosuid" "$fstab"; then
    log "Adding nosuid option to $fstab entry for $MOUNTPOINT ..."
    cp "$fstab" "${fstab}.bak.$(date +%Y%m%d%H%M%S)"
    sed -i -r "s|(^.*[[:space:]]$MOUNTPOINT[[:space:]].*)defaults(.*)|\1defaults,nosuid\2|" "$fstab"
  fi

  log "Remounting $MOUNTPOINT with nosuid ..."
  mount -o remount,nosuid "$MOUNTPOINT" || {
    log "ERROR: Failed to remount $MOUNTPOINT with nosuid"
    return 1
  }

  log "SUCCESS: $MOUNTPOINT remounted with nosuid"
  return 0
}

if [[ "$MODE" == "check" ]]; then
  check_partition_exists
  check_nosuid_option
elif [[ "$MODE" == "apply" ]]; then
  check_partition_exists
  remediate_nosuid_option
  check_nosuid_option
fi
#!/usr/bin/env bash
# CIS Benchmark 1.1.2.7.4
# Ensure noexec option set on /var/log/audit partition

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
MODE="check"

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

check_noexec_option() {
  if findmnt -no OPTIONS "$MOUNTPOINT" | grep -qw noexec; then
    log "PASS: $MOUNTPOINT is mounted with noexec"
    return 0
  else
    log "FAIL: $MOUNTPOINT is not mounted with noexec"
    return 1
  fi
}

remediate_noexec_option() {
  local fstab="/etc/fstab"

  if ! grep -qE "[[:space:]]$MOUNTPOINT[[:space:]]" "$fstab"; then
    log "FAIL: $MOUNTPOINT not found in $fstab. Cannot remediate automatically."
    log "ACTION REQUIRED: Add an fstab entry with noexec option."
    return 1
  fi

  if grep -qE "[[:space:]]$MOUNTPOINT[[:space:]]" "$fstab" && ! grep -qE "[[:space:]]$MOUNTPOINT[[:space:]].*noexec" "$fstab"; then
    log "Adding noexec option to $fstab entry for $MOUNTPOINT ..."
    cp "$fstab" "${fstab}.bak.$(date +%Y%m%d%H%M%S)"
    sed -i -r "s|(^.*[[:space:]]$MOUNTPOINT[[:space:]].*)defaults(.*)|\1defaults,noexec\2|" "$fstab"
  fi

  log "Remounting $MOUNTPOINT with noexec ..."
  mount -o remount,noexec "$MOUNTPOINT" || {
    log "ERROR: Failed to remount $MOUNTPOINT with noexec"
    return 1
  }

  log "SUCCESS: $MOUNTPOINT remounted with noexec"
  return 0
}

if [[ "$MODE" == "check" ]]; then
  check_partition_exists
  check_noexec_option
elif [[ "$MODE" == "apply" ]]; then
  check_partition_exists
  remediate_noexec_option
  check_noexec_option
fi
