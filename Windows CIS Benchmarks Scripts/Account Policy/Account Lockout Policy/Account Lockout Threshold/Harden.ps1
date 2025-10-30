<#
.SYNOPSIS
Applies the CIS Benchmark 1.2.2 setting for "Account lockout threshold" to 5 invalid logon attempts.

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
Write-Host "Setting lockout threshold to $REQUIRED_ATTEMPTS invalid attempts..."

try {
    # Attempt to set the lockout threshold
    net accounts /lockoutthreshold:$REQUIRED_ATTEMPTS

    # 3. Verification of applied policy (using a similar style as the initial check)
    $NetAccountsOutput = net accounts
    $AppliedLine = $NetAccountsOutput | Select-String "Lockout threshold"
    $FinalValueMatch = $AppliedLine.ToString() -match '\:\s*(\d+)'
    $FinalValue = if ($FinalValueMatch) { [int]$matches[1] } else { -1 }

    $Status = if ($FinalValue -le $REQUIRED_ATTEMPTS -and $FinalValue -gt 0) { "COMPLIANT" } else { "NON-COMPLIANT" }
    $StatusColor = if ($Status -eq "COMPLIANT") { "Green" } else { "Red" }
    $FinalValueDisplay = if ($FinalValue -ne -1) { "$FinalValue attempts" } else { "ERROR (Value not found)" }
    
    # 4. Display Verification Output (TUI format)
    Write-Host ""
    Write-Host "SUCCESS: Account lockout threshold policy applied." -ForegroundColor Green
    Write-Host ""
    
    Write-Host "----------------------------------------------------" -ForegroundColor DarkYellow
    Write-Host ("{0,-35} : {1} attempts" -f "Required CIS Value (Max)", $REQUIRED_ATTEMPTS) -ForegroundColor Yellow
    Write-Host ("{0,-35} : {1}" -f "Current Applied Value (Verification)", $FinalValueDisplay) -ForegroundColor Yellow
    Write-Host ("{0,-35} : {1}" -f "VERIFICATION", $Status) -ForegroundColor $StatusColor
    Write-Host "----------------------------------------------------" -ForegroundColor DarkYellow

    # Note: Setting the threshold automatically enables the lockout feature, which is the desired outcome.
}
catch {
    Write-Error "An unrecoverable error occurred during execution: $($_.Exception.Message)"
}

Write-Host "--- Policy application complete. ---"
