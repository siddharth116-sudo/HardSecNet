<#
.SYNOPSIS
Applies CIS Benchmark 9.3.1: Sets 'Windows Firewall: Public: Firewall state' to 'On (recommended)'.

.DESCRIPTION
This script sets the registry key that controls the firewall state for the Public Profile to '1' (On).
This ensures that the host-based firewall is always running when connected to a public network,
enforcing all configured rules.

.NOTES
Run this script with elevated privileges (Run as Administrator).
This configuration writes directly to the Group Policy registry key.
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "9.3.1 (L1)"
$CIS_NAME = "Windows Firewall: Public: Firewall state"
$REQUIRED_VALUE = 1
$SETTING_NAME = "Public Profile Firewall State"
$REG_PATH = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile"
$REG_PROPERTY = "EnableFirewall"
$StatusSeparator = "----------------------------------------------------"

Write-Host "--- Applying Hardening for CIS Benchmark: $CIS_ID - $CIS_NAME ---" -ForegroundColor Yellow

try {
    # 1. Ensure the registry path exists before attempting to set the property
    if (-not (Test-Path $REG_PATH)) {
        Write-Host "Creating registry path: $REG_PATH" -ForegroundColor Yellow
        New-Item -Path $REG_PATH -Force | Out-Null
    }

    # 2. Apply the setting using Set-ItemProperty (Set EnableFirewall = 1)
    Write-Host "Setting registry key '$REG_PROPERTY' to $REQUIRED_VALUE (On)..." -ForegroundColor Cyan
    Set-ItemProperty -Path $REG_PATH -Name $REG_PROPERTY -Value $REQUIRED_VALUE -Type DWORD -Force
    
    # Optional: Apply change immediately using netsh, though the registry key usually takes effect soon.
    # We use netsh to verify the change immediately below.
    # Note: netsh command to set state is less direct than registry but confirms active status.
    netsh advfirewall set publicprofile state on | Out-Null

    # 3. Verification of applied policy using netsh
    $NetshOutput = (netsh advfirewall show publicprofile) 2>&1
    $StateLine = $NetshOutput | Select-String "State"
    
    # Extract the current state (ON or OFF)
    $CurrentState = if ($StateLine -match '\s+(ON|OFF)\s*$') { $matches[1] } else { "ERROR" }
    
    # Check compliance based on string match for 'ON'
    $Status = if ($CurrentState -eq "ON") { "COMPLIANT" } else { "NON-COMPLIANT" }
    $StatusColor = if ($Status -eq "COMPLIANT") { "Green" } else { "Red" }

    # 4. Display Verification Output (TUI format)
    Write-Host ""
    Write-Host "SUCCESS: Policy applied. Verifying current state." -ForegroundColor Green
    Write-Host ""
    
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host ("{0,-35} : {1}" -f "Required CIS State", "On (1)") -ForegroundColor Yellow
    Write-Host ("{0,-35} : {1}" -f "Current Applied State (Verification)", $CurrentState) -ForegroundColor Yellow
    Write-Host ("{0,-35} : {1}" -f "VERIFICATION", $Status) -ForegroundColor $StatusColor
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    
}
catch {
    Write-Host "An error occurred during execution: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please ensure you are running this script with elevated (Administrator) privileges." -ForegroundColor Red
}
finally {
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "--- Policy application complete. ---"
}