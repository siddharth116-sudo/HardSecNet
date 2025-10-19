<#
.SYNOPSIS
Applies the CIS Benchmark 1.2.2 setting for "Account lockout threshold" to 5 invalid attempts.

.DESCRIPTION
This script uses the built-in 'net accounts' command to enforce that a local account
will be locked after 5 failed login attempts. This is a primary defense against automated
brute-force password guessing attacks.

Note: This setting applies only to local accounts. For domain-joined systems, this
is managed via a Domain Group Policy Object (GPO). Setting this to 0 disables the
lockout mechanism and is non-compliant.
#>

# CIS Benchmark: 1.2.2 (L1) Ensure 'Account lockout threshold' is set to '5 or fewer invalid logon attempt(s), but not 0' (Automated)
$CIS_BENCHMARK_NAME = "1.2.2 (L1) Account lockout threshold"
$REQUIRED_ATTEMPTS = 5 # Setting the maximum compliant threshold

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# 1. Display current setting before applying the change
Write-Host "Current account lockout threshold before update (in attempts):"
net accounts | Select-String "Threshold" | Write-Host

# 2. Apply the setting using 'net accounts'
# /lockoutthreshold:N sets the number of failed login attempts before lockout.
Write-Host "Setting account lockout threshold to $REQUIRED_ATTEMPTS invalid attempts..."

try {
    # Attempt to set the lockout threshold
    net accounts /lockoutthreshold:$REQUIRED_ATTEMPTS

    # Check return code
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: Account lockout threshold successfully set to $REQUIRED_ATTEMPTS attempts."
        Write-Host "Verify new setting:"
        net accounts | Select-String "Threshold" | Write-Host

        # Note: Setting the threshold automatically enables the lockout feature, which is the desired outcome.
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
# Computer Configuration\Policies\Windows Settings\Security Settings\Account Lockout Policy\Account lockout threshold
