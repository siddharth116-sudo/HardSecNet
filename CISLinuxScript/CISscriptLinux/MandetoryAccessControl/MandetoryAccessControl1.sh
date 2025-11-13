#!/usr/bin/env bash
# CIS Benchmark 1.3.1.2
# Ensure AppArmor is enabled in the bootloader configuration

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

check_apparmor_installed() {
  if command -v apparmor_status >/dev/null 2>&1; then
    log "PASS: AppArmor is installed"
    return 0
  else
    log "FAIL: AppArmor is not installed"
    return 1
  fi
}

check_grub_apparmor() {
  if grep -qE "apparmor=1" /etc/default/grub && grep -qE "security=apparmor" /etc/default/grub; then
    log "PASS: AppArmor kernel parameters are set in /etc/default/grub"
    return 0
  else
    log "FAIL: AppArmor kernel parameters missing in /etc/default/grub"
    return 1
  fi
}

remediate_grub_apparmor() {
  local grub_file="/etc/default/grub"
  log "Updating GRUB config to include AppArmor parameters..."
  cp "$grub_file" "${grub_file}.bak.$(date +%Y%m%d%H%M%S)"

  if grep -q '^GRUB_CMDLINE_LINUX=' "$grub_file"; then
    sed -i -E 's/^(GRUB_CMDLINE_LINUX=".*)"/\1 apparmor=1 security=apparmor"/' "$grub_file"
  else
    echo 'GRUB_CMDLINE_LINUX="apparmor=1 security=apparmor"' >> "$grub_file"
  fi

  log "Rebuilding GRUB configuration..."
  if command -v update-grub >/dev/null 2>&1; then
    update-grub
  elif command -v grub2-mkconfig >/dev/null 2>&1; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
  else
    log "WARNING: Could not rebuild GRUB automatically. Do it manually."
  fi

  log "AppArmor boot parameters have been applied. Reboot required."
}

if [[ "$MODE" == "check" ]]; then
  check_apparmor_installed
  check_grub_apparmor
elif [[ "$MODE" == "apply" ]]; then
  if check_apparmor_installed; then
    remediate_grub_apparmor
    check_grub_apparmor
  else
    log "ERROR: AppArmor not installed. Please install it first."
    exit 1
  fi
fi
