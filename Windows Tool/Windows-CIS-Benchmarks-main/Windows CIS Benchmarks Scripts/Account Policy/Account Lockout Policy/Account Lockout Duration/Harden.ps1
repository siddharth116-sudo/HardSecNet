<#
.SYNOPSIS
Applies the CIS Benchmark 1.2.1 setting to ensure 'Account lockout duration' is set to '15 or more minute(s)'.

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
$SETTING_KEY = "Lockout duration" # Key for verification output
$StatusSeparator = "----------------------------------------------------"

Write-Host "--- Applying Hardening for CIS Benchmark: $CIS_ID - $SETTING_NAME ---" -ForegroundColor Yellow

try {
    # 1. Apply the setting using 'net accounts'
    # /lockoutduration:N sets the number of minutes a locked account remains locked.
    Write-Host "Setting account lockout duration to $REQUIRED_MINUTES minutes..." -ForegroundColor Cyan

    # Execute net accounts and discard output to prevent TUI disruption
    net accounts /lockoutduration:$REQUIRED_MINUTES | Out-Null
    
    # 2. Check return code (net accounts runs instantly)
    if ($LASTEXITCODE -eq 0) {
        # 3. Verification & Output
        Write-Host ""
        Write-Host "SUCCESS: Account lockout duration successfully set to $REQUIRED_MINUTES minutes." -ForegroundColor Green
        
        # Capture the net accounts output for verification line only
        $NetAccountsOutput = net accounts 2>&1
        $DurationLine = $NetAccountsOutput | Select-String "$SETTING_KEY" | Select-Object -First 1
        
        $CurrentValue = -1
        # Use regex to extract the numerical value from the output line
        if ($DurationLine.ToString() -match ':\s*(\d+)') {
            $CurrentValue = [int]$matches[1]
        }
        
        $Status = if ($CurrentValue -ge $REQUIRED_MINUTES) { "COMPLIANT" } else { "NON-COMPLIANT" }
        $StatusColor = if ($Status -eq "COMPLIANT") { "Green" } else { "Red" }
        $CurrentStatusText = "$CurrentValue minutes"

        Write-Host $StatusSeparator -ForegroundColor DarkYellow
        # TUI output formatted to match required style
        Write-Host ("{0,-40} : {1}" -f "Required CIS Minimum", "$REQUIRED_MINUTES minutes") -ForegroundColor Yellow
        Write-Host ("{0,-40} : {1}" -f "Current Applied Value (Verification)", $CurrentStatusText) -ForegroundColor Yellow
        Write-Host ("{0,-40} : {1}" -f "VERIFICATION", $Status) -ForegroundColor $StatusColor

    } else {
        Write-Error "FAILURE: Failed to apply 'net accounts' command. Exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Error "An unexpected error occurred during execution: $($_.Exception.Message)"
}
finally {
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "--- Policy application complete. ---"
}
