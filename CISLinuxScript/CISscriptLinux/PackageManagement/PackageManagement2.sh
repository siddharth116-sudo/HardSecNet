#!/usr/bin/env bash
# CIS Benchmark 1.2.2.1
# Ensure updates, patches, and additional security software are installed

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"

log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" | tee -a "$LOGFILE"
}

OS="$(. /etc/os-release && echo $ID)"
OS_VER="$(. /etc/os-release && echo $VERSION_ID)"

log "Starting CIS 1.2.2.1 audit on $OS $OS_VER ..."

check_updates_debian() {
  log "Checking available updates (APT) ..."
  apt-get update -qq
  UPDATES=$(apt list --upgradable 2>/dev/null | tail -n +2 || true)

  if [[ -n "$UPDATES" ]]; then
    log "FAIL: The following packages have updates available:"
    echo "$UPDATES" | tee -a "$LOGFILE"
  else
    log "PASS: All packages are up to date"
  fi
}

check_updates_rhel() {
  log "Checking available updates (YUM/DNF) ..."
  if command -v dnf >/dev/null 2>&1; then
    UPDATES=$(dnf check-update || true)
  else
    UPDATES=$(yum check-update || true)
  fi

  if echo "$UPDATES" | grep -q '^[[:alnum:]]'; then
    log "FAIL: Updates are available:"
    echo "$UPDATES" | tee -a "$LOGFILE"
  else
    log "PASS: All packages are up to date"
  fi
}

check_updates_suse() {
  log "Checking available updates (Zypper) ..."
  UPDATES=$(zypper lu || true)
  if echo "$UPDATES" | grep -q '^v'; then
    log "FAIL: Updates are available:"
    echo "$UPDATES" | tee -a "$LOGFILE"
  else
    log "PASS: All packages are up to date"
  fi
}

check_security_packages() {
  log "Checking for essential security software..."
  local REQUIRED_PKGS=("aide" "auditd" "chrony" "fail2ban")

  for pkg in "${REQUIRED_PKGS[@]}"; do
    if command -v dpkg >/dev/null 2>&1; then
      dpkg -s "$pkg" >/dev/null 2>&1 && log "PASS: $pkg installed" || log "WARN: $pkg not installed"
    elif command -v rpm >/dev/null 2>&1; then
      rpm -q "$pkg" >/dev/null 2>&1 && log "PASS: $pkg installed" || log "WARN: $pkg not installed"
    fi
  done
}

case "$OS" in
  debian|ubuntu) check_updates_debian ;;
  rhel|centos|rocky|almalinux|fedora) check_updates_rhel ;;
  sles|opensuse*) check_updates_suse ;;
  *)
    log "WARNING: Unsupported OS ($OS). Please verify updates manually."
    ;;
esac

check_security_packages

log "Audit completed. Review above PASS/FAIL/WARN messages."
