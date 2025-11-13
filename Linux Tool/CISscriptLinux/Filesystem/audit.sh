#!/usr/bin/env bash
# =============================================================================
# AUDIT: Filesystem & /var/log/audit Compliance (CIS 1.1.1.10 + 1.1.2.7.x)
# Checks only — NO changes made
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
MOUNTPOINT="/var/log/audit"
MODPROBE_DIR="/etc/modprobe.d"

PASS=0 FAIL=0
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" | tee -a "$LOGFILE"; }
pass() { echo "PASS: $*"; ((PASS++)); }
fail() { echo "FAIL: $*"; ((FAIL++)); }

log "=== STARTING AUDIT ==="

# === 1.1.1.10: Check disabled modules ===
log "=== Checking unused FS & usb-storage (1.1.1.10) ==="
for mod in cramfs freevxfs jffs2 hfs hfsplus squashfs udf vfat usb-storage; do
  conf="$MODPROBE_DIR/cis-disable-${mod}.conf"
  if lsmod | grep -q "^${mod} "; then
    fail "Module $mod is LOADED"
  elif [[ -f "$conf" ]] && grep -q "install $mod /bin/true" "$conf"; then
    pass "Module $mod is disabled"
  else
    fail "Module $mod is NOT disabled"
  fi
done

# === 1.1.2.7.1: Separate partition ===
log "=== Checking $MOUNTPOINT partition (1.1.2.7.1) ==="
if findmnt -n "$MOUNTPOINT" >/dev/null 2>&1; then
  pass "$MOUNTPOINT is a separate partition"
else
  fail "$MOUNTPOINT is NOT a separate partition"
fi

# === 1.1.2.7.2–4: Mount options ===
if findmnt -n "$MOUNTPOINT" >/dev/null 2>&1; then
  opts=$(findmnt -no OPTIONS "$MOUNTPOINT")
  for opt in nodev nosuid noexec; do
    echo "$opts" | grep -qw "$opt" && pass "$MOUNTPOINT has $opt" || fail "$MOUNTPOINT missing $opt"
  done
else
  fail "Cannot check mount options (no partition)"
  ((FAIL+=2))  # for nosuid, noexec
fi

# === Summary ===
log "=== AUDIT SUMMARY: $PASS PASS | $FAIL FAIL ==="
if (( FAIL == 0 )); then
  log "SYSTEM IS CIS COMPLIANT"
else
  log "Run: sudo harden_filesystem.sh"
fi
log "Log: $LOGFILE"
