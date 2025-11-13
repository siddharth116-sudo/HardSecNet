#!/usr/bin/env bash
# CIS Benchmark 1.2.1.2
# Ensure package manager repositories are configured with GPG keys

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"

log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" | tee -a "$LOGFILE"
}

OS="$(. /etc/os-release && echo $ID)"

check_gpg_keys_debian() {
  log "Checking APT repositories and GPG key configuration..."
  if apt-cache policy | grep -E "http|ftp" >/dev/null 2>&1; then
    if apt-cache policy | grep "signed-by" >/dev/null 2>&1; then
      log "PASS: APT repositories have GPG key signing configured"
    else
      log "FAIL: APT repositories may not enforce GPG signing (check /etc/apt/sources.list and /etc/apt/sources.list.d/)"
    fi
  fi
  log "Installed trusted keys:"
  apt-key list || true
}

check_gpg_keys_rhel() {
  log "Checking YUM/DNF repositories and GPG key configuration..."
  for repo in /etc/yum.repos.d/*.repo; do
    if grep -q "^gpgcheck=1" "$repo"; then
      log "PASS: $repo enforces GPG check"
    else
      log "FAIL: $repo does not enforce GPG check"
    fi
    if grep -q "^gpgkey=" "$repo"; then
      log "INFO: $repo specifies a GPG key"
    else
      log "FAIL: $repo missing gpgkey entry"
    fi
  done
  log "Installed trusted GPG keys:"
  rpm -qa gpg-pubkey* || true
}

check_gpg_keys_suse() {
  log "Checking Zypper repositories and GPG key configuration..."
  zypper lr -d | awk '{print $1,$2,$3,$9}' | while read -r id alias name gpgcheck; do
    if [[ "$gpgcheck" == "Yes" ]]; then
      log "PASS: Repo $alias enforces GPG check"
    else
      log "FAIL: Repo $alias does not enforce GPG check"
    fi
  done
  log "Installed trusted GPG keys:"
  rpm -qa gpg-pubkey* || true
}

log "Starting CIS 1.2.1.2 audit on $OS ..."

case "$OS" in
  debian|ubuntu) check_gpg_keys_debian ;;
  rhel|centos|rocky|almalinux|fedora) check_gpg_keys_rhel ;;
  sles|opensuse*) check_gpg_keys_suse ;;
  *)
    log "WARNING: Unsupported OS ($OS). Please verify repository GPG keys manually."
    ;;
esac

log "Audit completed. Review the above PASS/FAIL messages."
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
