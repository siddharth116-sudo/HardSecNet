<#
.SYNOPSIS
Applies the CIS Benchmark 1.1.6 setting to ensure 'Relax minimum password length limits' is 'Enabled'.

.DESCRIPTION
This script sets the RelaxMinimumPasswordLengthLimits registry value to 1 (Enabled). 
Enabling this setting removes the legacy 14-character maximum for passwords, allowing 
longer, more secure passwords (up to 127 characters) to be configured via policy 1.1.4.

.NOTES
Run this script with elevated privileges (Run as Administrator).
Registry Path: HKLM\System\CurrentControlSet\Control\SAM
Key: RelaxMinimumPasswordLengthLimits (DWORD = 1)
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.1.6 (L1)"
$CIS_NAME = "Ensure 'Relax minimum password length limits' is set to 'Enabled' (Automated)"
$REQUIRED_VALUE = 1 # 1 = Enabled
$SETTING_KEY = "RelaxMinimumPasswordLengthLimits"
$SETTING_NAME = "Relax Minimum Password Length Limits"
$REGISTRY_PATH = "HKLM:\System\CurrentControlSet\Control\SAM"
$StatusSeparator = "----------------------------------------------------"

# --- Main Hardening Logic ---
Write-Host "--- Applying Hardening for CIS Benchmark: $CIS_ID - $SETTING_NAME ---" -ForegroundColor Yellow

try {
    # 1. Apply the Registry Setting
    Write-Host "Setting registry value for '$SETTING_KEY' to ENABLED (1)..." -ForegroundColor Cyan
    
    # Use Set-ItemProperty to create/update the REG_DWORD value
    Set-ItemProperty -Path $REGISTRY_PATH -Name $SETTING_KEY -Type DWORD -Value $REQUIRED_VALUE -Force -ErrorAction Stop
    
    # 2. Verify the Applied Setting (Audit Check)
    Write-Host "Verifying new setting applied successfully..." -ForegroundColor Yellow
    
    $CurrentAppliedValue = (Get-ItemProperty -Path $REGISTRY_PATH -Name $SETTING_KEY -ErrorAction Stop).$SETTING_KEY
    
    # 3. Output Verification
    $Status = if ($CurrentAppliedValue -eq $REQUIRED_VALUE) { "COMPLIANT" } else { "NON-COMPLIANT" }
    $StatusColor = if ($Status -eq "COMPLIANT") { "Green" } else { "Red" }
    $CurrentStatusText = if ($CurrentAppliedValue -eq 1) { "Enabled" } elseif ($CurrentAppliedValue -eq 0) { "Disabled" } else { "Unknown" }

    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "SUCCESS: Hardening applied." -ForegroundColor Green
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    
    # TUI output formatted to match required style
    Write-Host ("{0,-30} : {1}" -f "Required CIS State", "Enabled (1)") -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "Current Applied State", "$CurrentAppliedValue ($CurrentStatusText)") -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "VERIFICATION", $Status) -ForegroundColor $StatusColor
    
} catch {
    Write-Error "An error occurred during execution. Ensure script is run as Administrator." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "--- Policy application complete. ---"
}
