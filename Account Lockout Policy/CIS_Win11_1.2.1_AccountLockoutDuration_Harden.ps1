<#
.SYNOPSIS
Applies the CIS Benchmark 1.2.1 setting for "Account lockout duration" to 15 minutes.

.DESCRIPTION
This script uses the built-in 'net accounts' command to enforce that an account, once
locked out, remains locked for a minimum of 15 minutes. This helps mitigate brute-force
attacks while limiting denial-of-service risks.

Note: This setting applies only to local accounts. For domain-joined systems, this
is managed via a Domain Group Policy Object (GPO). This setting is only effective
if the 'Account lockout threshold' (CIS 1.2.2) is also set to a value other than 0.
#>

# CIS Benchmark: 1.2.1 (L1) Ensure 'Account lockout duration' is set to '15 or more minute(s)' (Automated)
$CIS_BENCHMARK_NAME = "1.2.1 (L1) Account lockout duration"
$REQUIRED_MINUTES = 15 # Setting the minimum required lockout duration in minutes

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# 1. Display current setting before applying the change
Write-Host "Current account lockout duration before update (in minutes):"
net accounts | Select-String "Lockout duration" | Write-Host

# 2. Apply the setting using 'net accounts'
# /lockoutduration:N sets the number of minutes a locked account remains locked.
Write-Host "Setting account lockout duration to $REQUIRED_MINUTES minutes..."

try {
    # Attempt to set the lockout duration
    net accounts /lockoutduration:$REQUIRED_MINUTES

    # Check return code
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: Account lockout duration successfully set to $REQUIRED_MINUTES minutes."
        Write-Host "Verify new setting:"
        net accounts | Select-String "Lockout duration" | Write-Host
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
# Computer Configuration\Policies\Windows Settings\Security Settings\Account Lockout Policy\Account lockout duration
