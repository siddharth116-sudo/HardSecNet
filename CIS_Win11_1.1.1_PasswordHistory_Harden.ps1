<#
.SYNOPSIS
Applies the CIS Benchmark 1.1.1 setting for "Enforce password history" to 24 or more passwords.

.DESCRIPTION
This script uses the built-in 'net accounts' command to set the password history size
to the required minimum of 24, as specified by the CIS Microsoft Windows 11
Standalone Benchmark v4.0.0 (Recommendation 1.1.1).

Note: This setting is instantly applied and primarily affects local non-domain accounts.
For domain-joined systems, this policy should typically be set via Group Policy
on a Domain Controller, where the minimum is 24 passwords.
#>

# CIS Benchmark: 1.1.1 (L1) Ensure 'Enforce password history' is set to '24 or more password(s)' (Automated)
$CIS_BENCHMARK_NAME = "1.1.1 (L1) Enforce password history"
$REQUIRED_VALUE = 24

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# 1. Check current setting (Optional, for logging/debugging)
Write-Host "Current maximum password age (Maximum Password Age must be > 0 for history to be effective):"
net accounts | Select-String "Maximum password age" | Write-Host
Write-Host "Current password history enforcement (this might not directly reflect the effective policy):"
net accounts | Select-String "Minimum password length" | Write-Host

# 2. Apply the setting using 'net accounts'
# /uniquepw:N sets the number of unique passwords to enforce (password history)
Write-Host "Setting password history to $REQUIRED_VALUE unique passwords..."

try {
    net accounts /uniquepw:$REQUIRED_VALUE
    
    # Check return code
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: Password history set to $REQUIRED_VALUE."
        Write-Host "Verify new setting:"
        net accounts | Select-String "unique passwords remembered" | Write-Host
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
# Computer Configuration\Policies\Windows Settings\Security Settings\Account Policies\Password Policy\Enforce password history
