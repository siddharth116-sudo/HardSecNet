<#
.SYNOPSIS
Applies the CIS Benchmark 1.1.4 setting for "Minimum password length" to 14 characters.

.DESCRIPTION
This script uses the built-in 'net accounts' command to enforce a minimum password
length of 14 characters, significantly increasing protection against brute-force attacks.

Note: This setting applies only to local accounts. For domain-joined systems, this
is managed via a Domain Group Policy Object (GPO).
#>

# CIS Benchmark: 1.1.4 (L1) Ensure 'Minimum password length' is set to '14 or more character(s)' (Automated)
$CIS_BENCHMARK_NAME = "1.1.4 (L1) Minimum password length"
$REQUIRED_VALUE = 14 # Setting the minimum required length of 14 characters.

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# 1. Display current setting before applying the change
Write-Host "Current minimum password length before update:"
net accounts | Select-String "Minimum password length" | Write-Host

# 2. Apply the setting using 'net accounts'
# /minpwlen:N sets the minimum number of characters required for a password.
Write-Host "Setting minimum password length to $REQUIRED_VALUE characters..."

try {
    # Attempt to set the minimum password length
    net accounts /minpwlen:$REQUIRED_VALUE

    # Check return code
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: Minimum password length successfully set to $REQUIRED_VALUE characters."
        Write-Host "Verify new setting:"
        net accounts | Select-String "Minimum password length" | Write-Host
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
# Computer Configuration\Policies\Windows Settings\Security Settings\Account Policies\Password Policy\Minimum password length
