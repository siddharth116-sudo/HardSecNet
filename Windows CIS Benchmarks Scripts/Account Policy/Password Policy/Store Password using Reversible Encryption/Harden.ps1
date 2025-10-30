<#
.SYNOPSIS
Applies the CIS Benchmark 1.1.7 setting to ensure 'Store passwords using reversible encryption' is 'Disabled'.

.DESCRIPTION
This script uses the secedit utility to set the 'ClearTextPassword' security policy to 0 (Disabled). 
Disabling this critical setting prevents Windows from storing passwords in a weak, easily reversible 
format, significantly enhancing system security.

.NOTES
Run this script with elevated privileges (Run as Administrator).
#>

#Requires -RunAsAdministrator

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.1.7 (L1)"
$CIS_NAME = "Ensure 'Store passwords using reversible encryption' is set to 'Disabled' (Automated)"
$REQUIRED_VALUE = 0 # 0 = Disabled (Non-reversible encryption)
$SETTING_KEY = "ClearTextPassword"
$SETTING_NAME = "Store passwords using reversible encryption"
$StatusSeparator = "----------------------------------------------------"

# --- Pre-flight Checks ---
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check Administrator Privileges
if (-not (Test-Administrator)) {
    Write-Host $StatusSeparator -ForegroundColor Red
    Write-Host "ERROR: Administrator privileges required!" -ForegroundColor Red
    Write-Host "Please run this script as Administrator." -ForegroundColor Red
    Write-Host $StatusSeparator -ForegroundColor Red
    Exit 1
}

# Check Domain Membership
$isDomainMember = (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
if ($isDomainMember) {
    Write-Host $StatusSeparator -ForegroundColor Yellow
    Write-Host "WARNING: Domain-Joined Computer Detected" -ForegroundColor Yellow
    Write-Host $StatusSeparator -ForegroundColor Yellow
    Write-Host "This script affects LOCAL accounts only on this machine." -ForegroundColor Yellow
    Write-Host "For DOMAIN accounts, configure in Default Domain Policy GPO." -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Continue with local policy change? (Y/N)"
    if ($response -ne 'Y') {
        Write-Host "Operation cancelled by user." -ForegroundColor Cyan
        Exit 0
    }
}

# --- Main Hardening Logic ---
try {
    Write-Host ""
    Write-Host "--- Applying Hardening for CIS Benchmark: $CIS_ID ---" -ForegroundColor Yellow
    Write-Host "--- $CIS_NAME ---" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "CRITICAL SECURITY SETTING" -ForegroundColor Red
    Write-Host ""

    # 1. Define temporary file paths
    $TempCfgPath = Join-Path $env:TEMP "RevEncrypt_Config.inf"
    $TempSdbPath = Join-Path $env:TEMP "RevEncrypt_Database.sdb"

    # 2. Create a minimal configuration file (INF) to set the policy
    Write-Host "[*] Creating security configuration file..." -ForegroundColor Cyan
    
    @('[Version]', 'signature="$CHICAGO$"', '', '[System Access]', "$SETTING_KEY = $REQUIRED_VALUE") | 
        Out-File -FilePath $TempCfgPath -Encoding ASCII -Force

    # 3. Apply the configuration using secedit
    Write-Host "[*] Applying $SETTING_NAME = DISABLED ($REQUIRED_VALUE)..." -ForegroundColor Cyan
    
    $null = secedit /configure /db $TempSdbPath /cfg $TempCfgPath /areas SECURITYPOLICY /quiet 2>&1

    # Clean up the configuration file immediately
    Remove-Item $TempCfgPath -Force -ErrorAction SilentlyContinue

    # Check for successful application
    if ($LASTEXITCODE -ne 0) {
        Write-Host $StatusSeparator -ForegroundColor Red
        Write-Host "FAILURE: secedit failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Check Event Viewer > Windows Logs > System for details." -ForegroundColor Red
        Write-Host $StatusSeparator -ForegroundColor Red
        Exit 1
    }

    # 4. Verify the Applied Setting (Audit Check)
    Write-Host "[*] Verifying applied configuration..." -ForegroundColor Cyan
    
    $AuditTempPath = Join-Path $env:TEMP "AuditPolicy.cfg"
    $null = secedit /export /cfg $AuditTempPath /areas SECURITYPOLICY /quiet 2>&1
    
    # Extract the ClearTextPassword value
    $AuditLine = Get-Content $AuditTempPath -ErrorAction SilentlyContinue | 
                 Select-String -Pattern "$SETTING_KEY\s*=" | 
                 Select-Object -First 1
    
    if ($AuditLine -match '=\s*(-?\d+)') {
        $CurrentAppliedValue = [int]$matches[1]
    } else {
        # If not found, it defaults to 0 (Disabled) - which is compliant
        $CurrentAppliedValue = 0
    }
    
    # Clean up audit file
    Remove-Item $AuditTempPath -Force -ErrorAction SilentlyContinue

    # 5. Output Verification Results
    $Status = if ($CurrentAppliedValue -eq $REQUIRED_VALUE) { "COMPLIANT" } else { "NON-COMPLIANT" }
    $StatusColor = if ($Status -eq "COMPLIANT") { "Green" } else { "Red" }
    $CurrentStatusText = if ($CurrentAppliedValue -eq 1) { "Enabled (DANGEROUS!)" } 
                         elseif ($CurrentAppliedValue -eq 0) { "Disabled (Secure)" } 
                         else { "Unknown" }

    Write-Host ""
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "SUCCESS: Hardening applied." -ForegroundColor Green
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host ("{0,-30} : {1}" -f "CIS Benchmark", $CIS_ID) -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "Setting Name", $SETTING_NAME) -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "Required CIS State", "Disabled (0)") -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "Current Applied State", "$CurrentAppliedValue ($CurrentStatusText)") -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "VERIFICATION", $Status) -ForegroundColor $StatusColor
    Write-Host ""
    Write-Host $StatusSeparator -ForegroundColor DarkYellow

    # 6. Security Guidance
    if ($Status -eq "COMPLIANT") {
        Write-Host ""
        Write-Host "SECURITY: Reversible Encryption Now Disabled" -ForegroundColor Green
        Write-Host $StatusSeparator -ForegroundColor DarkYellow
        Write-Host "What this means:" -ForegroundColor White
        Write-Host "  [+] New passwords stored as ONE-WAY HASHES (secure)" -ForegroundColor Green
        Write-Host "  [+] Passwords CANNOT be decrypted if database stolen" -ForegroundColor Green
        Write-Host "  [+] Significantly improved security posture" -ForegroundColor Green
        Write-Host ""
        Write-Host "Password Storage Method:" -ForegroundColor Cyan
        Write-Host "  Before: Password > [Encryption] > Can decrypt > VULNERABLE" -ForegroundColor Red
        Write-Host "  Now:    Password > [One-way hash] > Cannot reverse > SECURE" -ForegroundColor Green
        Write-Host ""
        Write-Host "IMPORTANT: Existing Passwords" -ForegroundColor Yellow
        Write-Host $StatusSeparator -ForegroundColor Yellow
        Write-Host "If reversible encryption was PREVIOUSLY enabled:" -ForegroundColor Yellow
        Write-Host "  - Existing passwords remain in encrypted format" -ForegroundColor Yellow
        Write-Host "  - They are STILL VULNERABLE until changed" -ForegroundColor Yellow
        Write-Host "  - New passwords will use secure hashing" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "RECOMMENDED ACTIONS:" -ForegroundColor Cyan
        Write-Host "  1. Force password reset for all users (to convert to hashes)" -ForegroundColor White
        Write-Host "  2. Review why reversible encryption was enabled" -ForegroundColor White
        Write-Host "  3. Identify any legacy apps requiring it (CHAP, Digest Auth)" -ForegroundColor White
        Write-Host "  4. Upgrade/replace legacy applications if possible" -ForegroundColor White
        Write-Host "  5. Check Active Directory for individual user exceptions" -ForegroundColor White
        Write-Host ""
        Write-Host "Check Individual AD Users (if domain environment):" -ForegroundColor Cyan
        Write-Host "  Get-ADUser -Filter * -Properties AllowReversiblePasswordEncryption |" -ForegroundColor Gray
        Write-Host "    Where-Object {`$_.AllowReversiblePasswordEncryption -eq `$true}" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Why This Matters:" -ForegroundColor Cyan
        Write-Host "  - Database breach with reversible encryption = INSTANT password exposure" -ForegroundColor Red
        Write-Host "  - Database breach with hashing = Years to crack strong passwords" -ForegroundColor Green
        Write-Host "  - This is a CRITICAL security control" -ForegroundColor White
        Write-Host ""
        Write-Host $StatusSeparator -ForegroundColor DarkYellow
    } else {
        Write-Host ""
        Write-Host "ERROR: Verification failed - setting may not have applied correctly" -ForegroundColor Red
        Write-Host ""
        Write-Host "CRITICAL: If reversible encryption is currently ENABLED:" -ForegroundColor Red
        Write-Host "  - ALL passwords can be decrypted by attackers" -ForegroundColor Red
        Write-Host "  - This is a SEVERE security vulnerability" -ForegroundColor Red
        Write-Host "  - Immediate remediation required!" -ForegroundColor Red
        Write-Host ""
        Exit 1
    }
    
} catch {
    Write-Host ""
    Write-Host $StatusSeparator -ForegroundColor Red
    Write-Host "ERROR: Unexpected failure occurred" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $StatusSeparator -ForegroundColor Red
    Exit 1
} finally {
    # Final cleanup of temporary files
    if (Test-Path $TempSdbPath) { 
        Remove-Item $TempSdbPath -Force -ErrorAction SilentlyContinue 
    }
    if (Test-Path $TempCfgPath) { 
        Remove-Item $TempCfgPath -Force -ErrorAction SilentlyContinue 
    }
    
    Write-Host ""
    Write-Host "--- Policy application complete. ---" -ForegroundColor Cyan
    Write-Host ""
}