#!/usr/bin/env bash

# CIS Benchmark 2.1.8
# Ensure message access server services (dovecot) are not in use

set -euo pipefail
IFS=$'\n\t'

# --- Script Configuration ---
SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
MODE="" # Default mode
PACKAGE_NAME="dovecot" # Common IMAP/POP3 server package

# --- Functions ---

# Print script usage
usage() {
  echo "Usage: $0 [--check|--apply]"
  echo "  --check: Audit the system for compliance."
  echo "  --apply: Remediate the system by uninstalling the package."
  exit 1
}

# Log messages to stdout and a log file
log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" | tee -a "$LOGFILE"
}

# --- Main Logic ---

# Parse command-line arguments
[[ $# -gt 1 ]] && usage
if [[ $# -eq 1 ]]; then
  case "$1" in
    --check) MODE="check" ;;
    --apply) MODE="apply" ;;
    --help|-h) usage ;;
    *) usage ;;
  esac
fi

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   log "ERROR: This script must be run as root."
   exit 1
fi

# Function to check if a package is installed
is_package_installed() {
    if command -v dpkg &> /dev/null; then
        # Debian-based systems (Ubuntu, Debian)
        dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
    elif command -v rpm &> /dev/null; then
        # Red Hat-based systems (CentOS, RHEL, Fedora)
        rpm -q "$1" &> /dev/null
    else
        log "WARNING: Cannot determine package manager. Skipping check for $1."
        return 1 # Assume not installed if manager is unknown
    fi
}

run_check() {
  log "--- Starting CIS 2.1.8 Audit ---"
  log "Checking if '$PACKAGE_NAME' package is installed..."

  if is_package_installed "$PACKAGE_NAME"; then
    log "FAIL: Message access server package '$PACKAGE_NAME' is installed."
    log "--- CIS 2.1.8 Audit Result: FAIL ---"
    return 1
  else
    log "PASS: Message access server package '$PACKAGE_NAME' is not installed."
    log "--- CIS 2.1.8 Audit Result: PASS ---"
    return 0
  fi
}

run_apply() {
  log "--- Starting CIS 2.1.8 Remediation ---"

  if ! is_package_installed "$PACKAGE_NAME"; then
      log "INFO: '$PACKAGE_NAME' is not installed. No action needed."
      return 0
  fi
  
  log "Uninstalling '$PACKAGE_NAME' package..."
  if command -v apt-get &> /dev/null; then
      apt-get purge -y "$PACKAGE_NAME"
  elif command -v dnf &> /dev/null; then
      dnf remove -y "$PACKAGE_NAME"
  elif command -v yum &> /dev/null; then
      yum remove -y "$PACKAGE_NAME"
  else
      log "ERROR: Could not find a supported package manager (apt/dnf/yum) to remove the package."
      return 1
  fi
  
  log "--- CIS 2.1.8 Remediation Complete ---"
}

# --- Execution ---

if [[ "$MODE" == "check" ]]; then
  run_check
elif [[ "$MODE" == "apply" ]]; then
  run_apply
  run_check # Run a check after applying to verify success
fi
#!/usr/bin/env bash

# CIS Benchmark 2.1.21
# Ensure mail transfer agent (Postfix) is configured for local-only mode

set -euo pipefail
IFS=$'\n\t'

# --- Script Configuration ---
SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
MODE="" # Default mode
POSTFIX_CONFIG="/etc/postfix/main.cf"

# --- Functions ---

# Print script usage
usage() {
  echo "Usage: $0 [--check|--apply]"
  exit 1
}

# Log messages to stdout and a log file
log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" | tee -a "$LOGFILE"
}

# --- Main Logic ---

# Parse command-line arguments
[[ $# -eq 0 ]] && usage
case "$1" in
  --check) MODE="check" ;;
  --apply) MODE="apply" ;;
  --help|-h) usage ;;
  *) usage ;;
esac


# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   log "ERROR: This script must be run as root."
   exit 1
fi

# Check if Postfix is installed. If not, this control is not applicable.
if [[ ! -f "$POSTFIX_CONFIG" ]]; then
    log "INFO: Postfix configuration file not found at $POSTFIX_CONFIG."
    log "--- CIS 2.1.21 Audit Result: NOT APPLICABLE (Postfix not installed) ---"
    exit 0
fi

run_check() {
  log "--- Starting CIS 2.1.21 Audit for Postfix ---"
  
  # postconf -n shows only non-default settings. If inet_interfaces is not
  # set, it defaults to 'all', so we check for that case.
  local current_setting
  current_setting=$(postconf -n inet_interfaces | awk -F' = ' '{print $2}' || echo "all")
  
  if [[ "$current_setting" == "localhost" || "$current_setting" == "loopback-only" ]]; then
    log "PASS: Postfix is correctly configured for local-only mode (inet_interfaces = $current_setting)."
    log "--- CIS 2.1.21 Audit Result: PASS ---"
    return 0
  else
    log "FAIL: Postfix is NOT configured for local-only mode. 'inet_interfaces' is set to '$current_setting'."
    log "--- CIS 2.1.21 Audit Result: FAIL ---"
    return 1
  fi
}

run_apply() {
  log "--- Starting CIS 2.1.21 Remediation for Postfix ---"

  log "1. Configuring 'inet_interfaces = localhost' using postconf..."
  # Use postconf to safely edit the main.cf file.
  postconf -e "inet_interfaces = localhost"

  log "2. Reloading Postfix service to apply changes..."
  if command -v systemctl &> /dev/null; then
    systemctl reload postfix
  elif command -v service &> /dev/null; then
    service postfix reload
  else
    log "WARNING: Could not reload Postfix service. Please reload it manually."
  fi
  
  log "--- CIS 2.1.21 Remediation Complete ---"
}

# --- Execution ---

if [[ "$MODE" == "check" ]]; then
  run_check
elif [[ "$MODE" == "apply" ]]; then
  run_apply
  run_check # Run a check after applying to verify success
fi
#!/usr/bin/env bash

# CIS Benchmark 2.1.22
# Information gathering script to list all listening network services.

set -euo pipefail
IFS=$'\n\t'

# --- Script Configuration ---
SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"

# --- Functions ---

# Log messages to stdout and a log file
log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" | tee -a "$LOGFILE"
}

# --- Main Logic ---

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   log "ERROR: This script must be run as root to identify all processes."
   exit 1
fi

log "--- Starting CIS 2.1.22 Information Gathering ---"
log "Listing all listening TCP and UDP sockets and the processes using them..."
log "Use this output to manually verify against your list of approved services."
echo # for spacing

# ss is the modern tool to investigate sockets.
# -l: listening sockets
# -n: numeric ports (faster, no DNS lookups)
# -t: TCP sockets
# -u: UDP sockets
# -p: show process using socket
ss -lntup

echo # for spacing
log "--- MANUAL ACTION REQUIRED ---"
log "Review the list of services above in the 'Local Address:Port' and 'Users' columns."
log "Compare this list against your organization's approved services for this server."
log "Any service not on the approved list should be disabled or uninstalled."
log "--- End of CIS 2.1.22 Information Gathering ---"

exit 0
