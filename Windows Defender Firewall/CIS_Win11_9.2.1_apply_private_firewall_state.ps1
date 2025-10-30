<#
.SYNOPSIS
Applies the CIS Benchmark 9.2.1 setting to ensure the Windows Firewall Private Profile is 'On (recommended)'.

.DESCRIPTION
This script uses the netsh utility, an administrative command-line tool, to ensure the 
Windows Defender Firewall state for the Private Profile is set to 'On', which is the recommended
state to enforce all configured firewall rules and connection security rules.
#>

# CIS Benchmark: 9.2.1 (L1) Ensure 'Windows Firewall: Private: Firewall state' is set to 'On (recommended)' (Automated)
$CIS_BENCHMARK_NAME = "9.2.1 (L1) Windows Firewall: Private: Firewall state"
$REQUIRED_STATE = "on"

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# 1. Check and display current setting for the Private Profile
Write-Host "Current Firewall State for Private Profile:"
$current_state = netsh advfirewall show privateprofile | Select-String "State"
Write-Host $current_state

# 2. Apply the setting using 'netsh advfirewall'
Write-Host "Setting Firewall State for Private Profile to '$($REQUIRED_STATE)'..."

try {
    # Command to set the state of the private firewall profile
    # 'state on' enables the firewall.
    netsh advfirewall set privateprofile state $REQUIRED_STATE

    # 3. Verify the new setting
    Write-Host ""
    Write-Host "SUCCESS: Firewall state for Private Profile successfully set to '$($REQUIRED_STATE)'."
    Write-Host "Verify new setting:"
    netsh advfirewall show privateprofile | Select-String "State" | Write-Host
}
catch {
    Write-Error "An error occurred during execution: $($_.Exception.Message)"
    Write-Error "Ensure you are running the script with elevated privileges (Run as Administrator)."
}

Write-Host "--- Policy application complete. ---"

# Note on GPO Location: This setting is backed by the registry key at:
# HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile:EnableFirewall (DWORD=1)
# and can also be managed via Group Policy in:
# Computer Configuration\Policies\Windows Settings\Security Settings\Windows Defender Firewall with Advanced Security\Windows Defender Firewall Properties\Private Profile\Firewall state
