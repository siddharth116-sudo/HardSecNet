<#
.SYNOPSIS
Applies the CIS Benchmark 1.1.5 setting to ensure 'Password must meet complexity requirements' is 'Enabled'.

.DESCRIPTION
This script sets the PasswordComplexity to 1 (Enabled) using secedit.exe to enforce 
password complexity rules (e.g., mixing characters, minimum length, etc.) for local accounts.

.NOTES
Run this script with elevated privileges (Run as Administrator).
This is the correct method for local security policy hardening.
#>

#Requires -RunAsAdministrator

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.1.5 (L1)"
$CIS_NAME = "Ensure 'Password must meet complexity requirements' is set to 'Enabled' (Automated)"
$REQUIRED_VALUE = 1 # 1 = Enabled
$SETTING_KEY = "PasswordComplexity"
$SETTING_NAME = "Password Complexity Requirements"
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

    # 1. Define Temporary File Paths
    $TempCfgPath = Join-Path $env:TEMP "Complexity_Config.inf"
    $TempSdbPath = Join-Path $env:TEMP "Complexity_Database.sdb"

    # 2. Create Minimal .inf Configuration File
    Write-Host "[*] Creating security configuration file..." -ForegroundColor Cyan
    @('[Version]', 'signature="$CHICAGO$"', '', '[System Access]', "$SETTING_KEY = $REQUIRED_VALUE") | 
        Out-File -FilePath $TempCfgPath -Encoding ASCII -Force

    # 3. Apply the New Security Policy
    Write-Host "[*] Applying $SETTING_NAME to ENABLED ($REQUIRED_VALUE)..." -ForegroundColor Cyan
    $null = secedit /configure /db $TempSdbPath /cfg $TempCfgPath /areas SECURITYPOLICY /quiet 2>&1
    
    # Clean up the configuration file immediately
    Remove-Item $TempCfgPath -Force -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -ne 0) {
        Write-Host $StatusSeparator -ForegroundColor Red
        Write-Host "FAILURE: secedit failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Check Event Viewer > Windows Logs > System for details." -ForegroundColor Red
        Write-Host $StatusSeparator -ForegroundColor Red
        Exit 1
    }

    # 4. Verify the Applied Setting
    Write-Host "[*] Verifying applied configuration..." -ForegroundColor Cyan
    
    $AuditTempPath = Join-Path $env:TEMP "AuditPolicy.cfg"
    $null = secedit /export /cfg $AuditTempPath /areas SECURITYPOLICY /quiet 2>&1
    
    # Extract the PasswordComplexity value
    $AuditLine = Get-Content $AuditTempPath -ErrorAction SilentlyContinue | 
                 Select-String -Pattern "$SETTING_KEY\s*=" | 
                 Select-Object -First 1
    
    if ($AuditLine -match '=\s*(-?\d+)') {
        $CurrentAppliedValue = [int]$matches[1]
    } else {
        $CurrentAppliedValue = -1
    }
    
    # Clean up audit file
    Remove-Item $AuditTempPath -Force -ErrorAction SilentlyContinue

    # 5. Output Verification Results
    $Status = if ($CurrentAppliedValue -eq $REQUIRED_VALUE) { "COMPLIANT" } else { "NON-COMPLIANT" }
    $StatusColor = if ($Status -eq "COMPLIANT") { "Green" } else { "Red" }
    $CurrentStatusText = if ($CurrentAppliedValue -eq 1) { "Enabled" } 
                         elseif ($CurrentAppliedValue -eq 0) { "Disabled" } 
                         else { "Unknown" }

    Write-Host ""
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "SUCCESS: Hardening applied." -ForegroundColor Green
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host ("{0,-30} : {1}" -f "CIS Benchmark", $CIS_ID) -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "Setting Name", $SETTING_NAME) -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "Required CIS State", "Enabled (1)") -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "Current Applied State", "$CurrentAppliedValue ($CurrentStatusText)") -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "VERIFICATION", $Status) -ForegroundColor $StatusColor
    Write-Host ""
    Write-Host $StatusSeparator -ForegroundColor DarkYellow

    # 6. User Guidance (only if successful)
    if ($Status -eq "COMPLIANT") {
        Write-Host ""
        Write-Host "IMPORTANT: Password Complexity Requirements Now Enabled" -ForegroundColor Cyan
        Write-Host $StatusSeparator -ForegroundColor DarkYellow
        Write-Host "New passwords must meet these requirements:" -ForegroundColor White
        Write-Host "  • Minimum 6 characters in length"
        Write-Host "  • Cannot contain username or parts of full name"
        Write-Host "  • Must contain 3 of these 4 character types:"
        Write-Host "    - Uppercase letters (A-Z)"
        Write-Host "    - Lowercase letters (a-z)"
        Write-Host "    - Numbers (0-9)"
        Write-Host "    - Special characters (!, @, #, $, %, etc.)"
        Write-Host ""
        Write-Host "NOTE: Existing passwords remain valid until changed." -ForegroundColor Yellow
        Write-Host "      Users need compliant passwords when:" -ForegroundColor Yellow
        Write-Host "      - Password expires (based on max password age)" -ForegroundColor Yellow
        Write-Host "      - User voluntarily changes password" -ForegroundColor Yellow
        Write-Host "      - Administrator resets password" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Example compliant passwords: P@ssw0rd123, Welcome2024!, MyDog#2023" -ForegroundColor Green
        Write-Host $StatusSeparator -ForegroundColor DarkYellow
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