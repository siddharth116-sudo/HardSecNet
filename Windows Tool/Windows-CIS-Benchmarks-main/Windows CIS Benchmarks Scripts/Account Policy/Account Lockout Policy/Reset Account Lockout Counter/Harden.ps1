<#
.SYNOPSIS
Applies the CIS Benchmark 1.2.4 setting for "Reset account lockout counter after" to 15 minutes.

.DESCRIPTION
This script uses the built-in 'net accounts' command to enforce that the counter tracking
invalid logon attempts resets only after 15 minutes of inactivity. This helps mitigate
denial-of-service risks by quickly clearing failed attempts.

Note: This setting applies only to local accounts. For domain-joined systems, this
is managed via a Domain Group Policy Object (GPO). This setting is only effective
if the 'Account lockout threshold' (CIS 1.2.2) is also set to a value other than 0.
#>

# CIS Benchmark: 1.2.4 (L1) Ensure 'Reset account lockout counter after' is set to '15 or more minute(s)' (Automated)
$CIS_BENCHMARK_NAME = "1.2.4 (L1) Reset account lockout counter after"
$REQUIRED_MINUTES = 15 # Setting the minimum required counter reset time in minutes

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# 1. Display current setting before applying the change
Write-Host "Current lockout window before update (in minutes):"
net accounts | Select-String "Lockout observation window" | Write-Host

# 2. Apply the setting using 'net accounts'
# /lockoutwindow:N sets the number of minutes that invalid login attempts are tracked before resetting.
Write-Host "Setting lockout counter reset time (window) to $REQUIRED_MINUTES minutes..."

try {
    # Attempt to set the lockout window
    # Note: net accounts uses /lockoutwindow for this setting.
    net accounts /lockoutwindow:$REQUIRED_MINUTES

    # 3. Verification of applied policy
    $NetAccountsOutput = net accounts
    $AppliedLine = $NetAccountsOutput | Select-String "Lockout observation window"
    $FinalValueMatch = $AppliedLine.ToString() -match '\:\s*(\d+)'
    $FinalValue = if ($FinalValueMatch) { [int]$matches[1] } else { -1 }

    $Status = if ($FinalValue -ge $REQUIRED_MINUTES) { "COMPLIANT" } else { "NON-COMPLIANT" }
    $StatusColor = if ($Status -eq "COMPLIANT") { "Green" } else { "Red" }
    $FinalValueDisplay = if ($FinalValue -ne -1) { "$FinalValue minutes" } else { "ERROR (Value not found)" }
    
    # 4. Display Verification Output (TUI format)
    Write-Host ""
    Write-Host "SUCCESS: Lockout counter reset policy applied." -ForegroundColor Green
    Write-Host ""
    
    Write-Host "----------------------------------------------------" -ForegroundColor DarkYellow
    Write-Host ("{0,-35} : {1} minutes" -f "Required CIS Value (Min)", $REQUIRED_MINUTES) -ForegroundColor Yellow
    Write-Host ("{0,-35} : {1}" -f "Current Applied Value (Verification)", $FinalValueDisplay) -ForegroundColor Yellow
    Write-Host ("{0,-35} : {1}" -f "VERIFICATION", $Status) -ForegroundColor $StatusColor
    Write-Host "----------------------------------------------------" -ForegroundColor DarkYellow

    Write-Host "NOTE: Ensure 'Lockout duration' (CIS 1.2.1) is also set to equal or greater than $REQUIRED_MINUTES minutes."
}
catch {
    Write-Error "An unrecoverable error occurred during execution: $($_.Exception.Message)"
}

Write-Host "--- Policy application complete. ---"
