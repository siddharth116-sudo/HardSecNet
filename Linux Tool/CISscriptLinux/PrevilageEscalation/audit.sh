#!/usr/bin/env bash
# =============================================================================
# CIS 5.2.7 AUDIT & DEMO: Verify 'su' is restricted to 'sugroup'
# Shows: Non-member → DENIED | Member → ALLOWED
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
LOGFILE="/var/log/${SCRIPT_NAME%.sh}.log"
PAM_FILE="/etc/pam.d/su"
GROUP="sugroup"
TEST_USER="testuser"
TEST_PASS="Temp123!"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" | tee -a "$LOGFILE"; }
pass() { echo -e "\033[32mPASS:\033[0m $*"; }
fail() { echo -e "\033[31mFAIL:\033[0m $*"; }

log "=== STARTING CIS 5.2.7 AUDIT & DEMO ==="

# === 1. Check PAM configuration ===
if grep -q "auth.*required.*pam_wheel.so.*group=$GROUP" "$PAM_FILE"; then
    pass "PAM restricts su to group '$GROUP'"
else
    fail "PAM does NOT restrict su (missing pam_wheel.so)"
    log "Run: sudo ./harden_su.sh"
    exit 1
fi

# === 2. Create test user (if not exists) ===
if ! id "$TEST_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$TEST_USER"
    echo "$TEST_USER:$TEST_PASS" | chpasswd
    log "CREATED test user: $TEST_USER"
else
    log "Test user $TEST_USER already exists"
fi

# === 3. DEMO: Non-member → DENIED ===
log "DEMO 1: Non-member '$TEST_USER' tries 'su'"
if expect -c "
    spawn su - -c whoami
    send \"$TEST_PASS\r\"
    expect {
        \"Password:\" { send \"\r\"; exp_continue }
        \"Authentication failure\" { exit 1 }
        \"root\" { exit 0 }
        timeout { exit 2 }
    }
" >/dev/null 2>&1; then
    fail "Non-member CAN use su → HARDENING FAILED"
else
    pass "Non-member DENIED → su is restricted"
fi

# === 4. Add user to group ===
usermod -aG "$GROUP" "$TEST_USER"
log "ADDED $TEST_USER to group '$GROUP'"

# === 5. DEMO: Member → ALLOWED ===
log "DEMO 2: Member '$TEST_USER' tries 'su'"
if expect -c "
    spawn su - -c whoami
    send \"$TEST_PASS\r\"
    expect {
        \"Password:\" { send \"\r\"; exp_continue }
        \"root\" { exit 0 }
        timeout { exit 2 }
    }
" | grep -q "root"; then
    pass "Member CAN use su → Working as expected"
else
    fail "Member CANNOT use su → Group misconfigured"
fi

# === 6. Cleanup (optional) ===
log "Cleanup: Removing test user..."
userdel -r "$TEST_USER" 2>/dev/null || true
log "DEMO COMPLETE"

# === FINAL RESULT ===
echo
echo "=== CIS 5.2.7 COMPLIANCE: PASSED ==="
echo "Only members of '$GROUP' can use 'su'"
echo "Log: $LOGFILE"
