<#
.SYNOPSIS
Applies the CIS Benchmark 1.2.4 setting for "Reset account lockout counter after" to 15 minutes.

.DESCRIPTION
This script uses the built-in 'net accounts' command to enforce that the counter tracking
invalid logon attempts resets only after 15 minutes of successful login attempts (or inactivity).
This value must be less than or equal to the Lockout Duration (CIS 1.2.1).

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
# /lockoutwindow:N sets the maximum time (in minutes) that invalid login attempts are tracked.
Write-Host "Setting lockout counter reset time (window) to $REQUIRED_MINUTES minutes..."

try {
    # Attempt to set the lockout window
    # Note: net accounts uses /lockoutwindow for this setting.
    net accounts /lockoutwindow:$REQUIRED_MINUTES

    # Check return code
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: Lockout counter reset time successfully set to $REQUIRED_MINUTES minutes."
        Write-Host "Verify new setting:"
        net accounts | Select-String "Lockout observation window" | Write-Host

        # Final check: The system requires that Lockout Duration be >= Lockout Window.
        Write-Host "Ensure that 'Lockout duration' is set to equal or greater than $REQUIRED_MINUTES minutes (CIS 1.2.1)."
    } else {
        Write-Error "Failed to apply 'net accounts' command. Exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Error "An error occurred during execution: $($_.Exception.Message)"
}

Write-Host "--- Policy application complete. ---"

# Note on Domain Systems: For domain accounts, this setting must be enforced via a Group Policy Object (GPO)
# linked to the domain. The setting can be found in:
# Computer Configuration\Policies\Windows Settings\Security Settings\Account Lockout Policy\Reset account lockout counter after
