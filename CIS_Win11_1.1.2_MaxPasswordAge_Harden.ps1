<#
.SYNOPSIS
Applies the CIS Benchmark 1.1.2 setting for "Maximum password age" to 365 days.

.DESCRIPTION
This script uses the built-in 'net accounts' command to set the maximum password age
to 365 days (or fewer, as required by CIS). This ensures passwords expire regularly
to enhance security.

Note: This setting primarily affects local non-domain accounts. For domain-joined
systems, this policy should typically be set via Group Policy on a Domain Controller.
#>

# CIS Benchmark: 1.1.2 (L1) Ensure 'Maximum password age' is set to '365 or fewer days, but not 0' (Automated)
$CIS_BENCHMARK_NAME = "1.1.2 (L1) Maximum password age"
$REQUIRED_VALUE = 365 # Setting it to the maximum allowed value of 365 days.

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# 1. Display current setting before applying the change
Write-Host "Current maximum password age before update:"
net accounts | Select-String "Maximum password age" | Write-Host

# 2. Apply the setting using 'net accounts'
# /maxpwage:N sets the maximum number of days a password is valid.
Write-Host "Setting maximum password age to $REQUIRED_VALUE days..."

try {
    net accounts /maxpwage:$REQUIRED_VALUE

    # Check return code
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: Maximum password age successfully set to $REQUIRED_VALUE days."
        Write-Host "Verify new setting:"
        net accounts | Select-String "Maximum password age" | Write-Host
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
# Computer Configuration\Policies\Windows Settings\Security Settings\Account Policies\Password Policy\Maximum password age
