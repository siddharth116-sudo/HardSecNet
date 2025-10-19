<#
.SYNOPSIS
Applies the CIS Benchmark 1.1.3 setting for "Minimum password age" to 1 day.

.DESCRIPTION
This script uses the built-in 'net accounts' command to enforce a minimum password
age of 1 day (or more), preventing users from changing their password multiple times
in rapid succession to bypass password history enforcement.

Note: This setting applies only to local accounts. For domain-joined systems, this
is managed via a Domain Group Policy Object (GPO).
#>

# CIS Benchmark: 1.1.3 (L1) Ensure 'Minimum password age' is set to '1 or more day(s)' (Automated)
$CIS_BENCHMARK_NAME = "1.1.3 (L1) Minimum password age"
$REQUIRED_VALUE = 1 # Setting it to the required minimum of 1 day.

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# 1. Display current setting before applying the change
Write-Host "Current minimum password age before update:"
net accounts | Select-String "Minimum password age" | Write-Host

# 2. Apply the setting using 'net accounts'
# /minpwage:N sets the minimum number of days before a password can be changed.
Write-Host "Setting minimum password age to $REQUIRED_VALUE day..."

try {
    # Ensure this value is 1 or higher (i.e., not 0, which allows immediate changes)
    net accounts /minpwage:$REQUIRED_VALUE

    # Check return code
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: Minimum password age successfully set to $REQUIRED_VALUE day."
        Write-Host "Verify new setting:"
        net accounts | Select-String "Minimum password age" | Write-Host
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
# Computer Configuration\Policies\Windows Settings\Security Settings\Account Policies\Password Policy\Minimum password age
