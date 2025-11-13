<#
.SYNOPSIS
Hardens CIS Benchmark 1.1.1: Enforce password history to '24 passwords'.

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
$StatusSeparator = "----------------------------------------------------"

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# 1. Apply the setting using 'net accounts'
# /uniquepw:N sets the number of unique passwords to enforce (password history)
Write-Host "Setting password history to $REQUIRED_VALUE unique passwords..."

try {
    # Execute the command silently to capture only success/failure
    net accounts /uniquepw:$REQUIRED_VALUE 2>&1 | Out-Null
    
    # Check return code
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: Password history set to $REQUIRED_VALUE passwords." -ForegroundColor Green

        # 2. Verify new setting cleanly
        $NetAccountsOutput = net accounts
        $VerificationLine = $NetAccountsOutput | Select-String "Length of password history maintained"

        $CurrentValue = 0
        if ($VerificationLine) {
            $CurrentValueStr = $VerificationLine -split ':' | Select-Object -Last 1
            $CurrentValue = [int]($CurrentValueStr.Trim())
        }

        Write-Host ""
        Write-Host $StatusSeparator -ForegroundColor DarkYellow
        Write-Host ("{0,-35} : {1} passwords" -f "Required CIS Value", $REQUIRED_VALUE) -ForegroundColor Yellow
        Write-Host ("{0,-35} : {1} passwords" -f "Current Applied Value (Verification)", $CurrentValue) -ForegroundColor Yellow
        
        if ($CurrentValue -ge $REQUIRED_VALUE) {
            Write-Host "VERIFICATION: COMPLIANT" -ForegroundColor Green
        } else {
            Write-Host "VERIFICATION: NON-COMPLIANT" -ForegroundColor Red
        }
        Write-Host $StatusSeparator -ForegroundColor DarkYellow

    } else {
        Write-Error "Failed to apply 'net accounts' command. Exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Error "An unexpected error occurred during execution: $($_.Exception.Message)"
}

Write-Host "--- Policy application complete. ---"

# Note on Domain Systems: For domain accounts, this setting must be enforced via a Group Policy Object (GPO)
# linked to the domain. The setting can be found in:
# Computer Configuration\Policies\Windows Settings\Security Settings\Account Policies\Password Policy\Enforce password history
