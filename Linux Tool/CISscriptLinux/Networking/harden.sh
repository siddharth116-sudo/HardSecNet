#!/usr/bin/env bash
#
# HARDEN Script
# Category: Networking & Warning Banners
# Benchmarks:
#   - 1.6.2: Ensure /etc/motd is configured properly
#   - 1.6.3: Ensure remote login warning banner is configured properly
#   - **NEW: DISABLE WiFi PERMANENTLY (user cannot re-enable)**
#

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
MOTD_FILE="/etc/motd"
ISSUE_NET_FILE="/etc/issue.net"
SSHD_CONFIG="/etc/ssh/sshd_config"
MODPROBE_DIR="/etc/modprobe.d"
WIFI_BLOCK_CONF="$MODPROBE_DIR/disable-wifi.conf"

# --- Functions ---

log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" | tee -a "$LOGFILE"
}

# --- Check Functions (for post-apply verification) ---

run_check_1_6_2() {
  log "--- Starting Post-Check CIS 1.6.2 (motd) ---"
  local fail_flag=0
  if [[ ! -f "$MOTD_FILE" ]]; then fail_flag=1; fi
  if [[ "$(stat -c "%u:%g" "$MOTD_FILE")" != "0:0" ]]; then fail_flag=1; fi
  local perms; perms=$(stat -c "%a" "$MOTD_FILE")
  if [[ "$perms" != "644" ]]; then fail_flag=1; fi
  if [[ ! -s "$MOTD_FILE" ]]; then fail_flag=1; fi

  if [[ $fail_flag -eq 0 ]]; then
    log "--- Post-Check CIS 1.6.2 Result: PASS ---"
    return 0
  else
    log "--- Post-Check CIS 1.6.2 Result: FAIL ---"
    return 1
  fi
}

run_check_1_6_3() {
  log "--- Starting Post-Check CIS 1.6.3 (issue.net) ---"
  local fail_flag=0
  if [[ ! -f "$ISSUE_NET_FILE" ]]; then fail_flag=1; fi
  if [[ "$(stat -c "%u:%g" "$ISSUE_NET_FILE")" != "0:0" ]]; then fail_flag=1; fi
  local perms; perms=$(stat -c "%a" "$ISSUE_NET_FILE")
  if [[ "$perms" != "644" ]]; then fail_flag=1; fi
  if [[ ! -s "$ISSUE_NET_FILE" ]]; then fail_flag=1; fi
  if ! grep -qE "^\s*Banner\s+$ISSUE_NET_FILE" "$SSHD_CONFIG"; then fail_flag=1; fi

  if [[ $fail_flag -eq 0 ]]; then
    log "--- Post-Check CIS 1.6.3 Result: PASS ---"
    return 0
  else
    log "--- Post-Check CIS 1.6.3 Result: FAIL ---"
    return 1
  fi
}

run_check_wifi_disabled() {
  log "--- Starting Post-Check: WiFi Permanently Disabled ---"
  local fail_flag=0

  # 1. Check blacklist file
  if [[ ! -f "$WIFI_BLOCK_CONF" ]]; then
    log "ERROR: WiFi block config missing: $WIFI_BLOCK_CONF"
    fail_flag=1
  fi

  # 2. Check key WiFi modules are blacklisted
  if ! grep -q "blacklist.*iwl" "$WIFI_BLOCK_CONF" 2>/dev/null; then
    log "ERROR: Intel WiFi modules not blacklisted"
    fail_flag=1
  fi

  # 3. Check no WiFi modules loaded
  if lsmod | grep -E "iwl|ath9k|rtw|wl|brcm" >/dev/null; then
    log "ERROR: WiFi kernel modules still loaded!"
    fail_flag=1
  fi

  # 4. Check rfkill (hardware switch)
  if rfkill list wifi 2>/dev/null | grep -q "Soft blocked: no"; then
    log "ERROR: WiFi is not soft-blocked!"
    fail_flag=1
  fi

  if [[ $fail_flag -eq 0 ]]; then
    log "--- Post-Check WiFi Disable: PASS (WiFi BLOCKED) ---"
    return 0
  else
    log "--- Post-Check WiFi Disable: FAIL ---"
    return 1
  fi
}

# --- Apply Functions ---

run_apply_1_6_2() {
  log "--- Starting CIS 1.6.2 Remediation (motd) ---"
  read -r -d '' BANNER_TEXT << 'EOM'
*******************************************************************************
* This system is for the use of authorized users only. Activities on this     *
* system are monitored and recorded. Anyone using this system expressly       *
* consents to such monitoring and is advised that if it reveals possible      *
* evidence of criminal activity, system personnel may provide the evidence    *
* of such monitoring to law enforcement officials.                            *
*******************************************************************************
EOM

  log "1. Writing banner to $MOTD_FILE..."
  echo "$BANNER_TEXT" > "$MOTD_FILE"
  log "2. Setting ownership to root:root..."
  chown root:root "$MOTD_FILE"
  log "3. Setting permissions to 644..."
  chmod 644 "$MOTD_FILE"
  log "--- CIS 1.6.2 Remediation Complete ---"
}

run_apply_1_6_3() {
  log "--- Starting CIS 1.6.3 Remediation (issue.net) ---"
  read -r -d '' BANNER_TEXT << 'EOM'
*******************************************************************************
* This system is for the use of authorized users only. Activities on this     *
* system are monitored and recorded. Anyone using this system expressly       *
* consents to such monitoring and is advised that if it reveals possible      *
* evidence of criminal activity, system personnel may provide the evidence    *
* of such monitoring to law enforcement officials.                            *
*******************************************************************************
EOM

  log "1. Writing banner to $ISSUE_NET_FILE..."
  echo "$BANNER_TEXT" > "$ISSUE_NET_FILE"
  log "2. Setting ownership to root:root..."
  chown root:root "$ISSUE_NET_FILE"
  log "3. Setting permissions to 644..."
  chmod 644 "$ISSUE_NET_FILE"
  log "4. Configuring SSH daemon..."
  sed -i -E 's/^\s*#?\s*Banner\s+.*//' "$SSHD_CONFIG"
  echo "Banner $ISSUE_NET_FILE" >> "$SSHD_CONFIG"
  
  log "5. Restarting SSH service..."
  if command -v systemctl &> /dev/null; then
    if systemctl list-units --type=service --all | grep -q 'ssh.service'; then
        systemctl restart ssh.service
    elif systemctl list-units --type=service --all | grep -q 'sshd.service'; then
        systemctl restart sshd.service
    fi
  elif command -v service &> /dev/null; then
    service sshd restart || service ssh restart
  else
    log "WARNING: Could not restart SSH service. Please restart manually."
  fi
  
  log "--- CIS 1.6.3 Remediation Complete ---"
}

# --- NEW: PERMANENTLY DISABLE WiFi ---
run_apply_disable_wifi() {
  log "--- Starting Permanent WiFi Disable ---"

  # Create modprobe.d config directory
  mkdir -p "$MODPROBE_DIR"

  log "1. Creating WiFi blacklist: $WIFI_BLOCK_CONF"
  cat > "$WIFI_BLOCK_CONF" << 'EOF'
# === PERMANENT WiFi DISABLE - HARDENING SCRIPT ===
# All common WiFi drivers blacklisted
blacklist ath9k
blacklist ath9k_pci
blacklist ath9k_htc
blacklist carl9170
blacklist iwlwifi
blacklist iwldvm
blacklist iwlagn
blacklist brcmsmac
blacklist brcmfmac
blacklist rtw88
blacklist rtw89
blacklist rtl818x
blacklist rtl8192cu
blacklist rtlwifi
blacklist b43
blacklist bcma
blacklist ssb
blacklist wl

# Prevent loading even if requested
install ath9k /bin/false
install iwlwifi /bin/false
install brcmsmac /bin/false
install brcmfmac /bin/false
install rtlwifi /bin/false
EOF

  chown root:root "$WIFI_BLOCK_CONF"
  chmod 644 "$WIFI_BLOCK_CONF"

  log "2. Unloading any loaded WiFi modules..."
  for module in iwlwifi ath9k brcmsmac brcmfmac rtlwifi; do
    if lsmod | grep -q "$module"; then
      modprobe -r "$module" || log "Warning: Could not unload $module (may be in use)"
    fi
  done

  log "3. Blocking WiFi via rfkill (soft block)"
  rfkill block wifi || log "Warning: rfkill failed (WiFi may already be off)"

  log "4. Updating initramfs to persist blacklist on boot"
  if command -v update-initramfs >/dev/null 2>&1; then
    update-initramfs -u
  elif command -v dracut >/dev/null 2>&1; then
    dracut -f
  fi

  log "--- WiFi Permanently Disabled (Kernel + rfkill) ---"
}

# --- Ensure root ---
if [[ $EUID -ne 0 ]]; then
   log "ERROR: This script must be run as root."
   exit 1
fi

# --- Main Execution ---
log "--- Starting Networking & WiFi Hardening ---"

run_apply_1_6_2
run_apply_1_6_3
run_apply_disable_wifi

log "---"
log "--- Running Post-Remediation Checks ---"
sleep 3

run_check_1_6_2
run_check_1_6_3
run_check_wifi_disabled

log "--- ALL HARDENING & VERIFICATION COMPLETE ---"
log "!! REBOOT REQUIRED for WiFi disable to fully take effect !!"
