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

# --- CIS Benchmark Details ---
$CIS_ID = "1.1.2 (L1)"
$CIS_BENCHMARK_NAME = "Maximum password age"
$REQUIRED_VALUE = 365 # Setting it to the maximum allowed value of 365 days.

Write-Host "--- Applying Hardening for CIS Benchmark: $CIS_ID $CIS_BENCHMARK_NAME ---"

# 1. Apply the setting using 'net accounts'
# /maxpwage:N sets the maximum number of days a password is valid.
Write-Host "Setting maximum password age to $REQUIRED_VALUE days..."

try {
    # Execute the command silently to control output
    net accounts /maxpwage:$REQUIRED_VALUE | Out-Null
    
    # Check return code
    if ($LASTEXITCODE -eq 0) {
        
        # --- Verification Section ---
        Write-Host ""
        Write-Host "SUCCESS: Maximum password age set to $REQUIRED_VALUE days." -ForegroundColor Green
        
        # Read the updated policy and extract the specific value
        $VerificationLine = net accounts | Select-String "Maximum password age"
        
        # Use RegEx to reliably extract the numerical value (e.g., '365')
        $match = [regex]::Match($VerificationLine, 'age \(days\):.*?\s*(\d+)')
        $AppliedValue = if ($match.Success) { [int]$match.Groups[1].Value } else { "N/A" }
        
        # Determine Compliance Status for Display
        $IsCompliant = ($AppliedValue -eq $REQUIRED_VALUE)
        $VerificationStatus = if ($IsCompliant) { "COMPLIANT" } else { "NON-COMPLIANT" }
        $StatusColor = if ($IsCompliant) { "Green" } else { "Red" }
        
        # Display results in the requested format
        Write-Host "--------------------------------------------------------"
        Write-Host ("{0,-35} : {1} days" -f "Required CIS Value", $REQUIRED_VALUE) 
        Write-Host ("{0,-35} : {1} days" -f "Current Applied Value (Verification)", $AppliedValue) 
        Write-Host ("{0,-35}" -f "VERIFICATION:$VerificationStatus") -ForegroundColor $StatusColor
        Write-Host "--------------------------------------------------------"
    } else {
        Write-Error "FAILURE: Failed to apply 'net accounts' command. Exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Error "An unrecoverable error occurred during execution: $($_.Exception.Message)"
}

Write-Host "--- Policy application complete. ---"
