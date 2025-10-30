<#
.SYNOPSIS
Audits CIS Benchmark 1.1.5: Checks if 'Password must meet complexity requirements' is set to 'Enabled'.

.DESCRIPTION
This script reads the current local policy setting (PasswordComplexity) from the 
security database, determines compliance (1 for Enabled/Compliant), and exports 
the findings to a JSON file in a 'report' folder.

.NOTES
Run this script with elevated privileges (Run as Administrator).
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.1.5 (L1)"
$CIS_NAME = "Password must meet complexity requirements is set to 'Enabled' (Automated)"
$REQUIRED_VALUE = 1 # 1 = Enabled (Compliant)
$SETTING_KEY = "PasswordComplexity"
$SETTING_NAME = "Password Complexity Requirements"
$StatusSeparator = "----------------------------------------------------"

# --- Reporting Configuration ---
$ReportFolder = "report"
$ReportFileName = "Audit_Password_Complexity_$($CIS_ID.Replace(' ', '_')).json"

# --- Function to Format and Display Results ---
function Display-Audit-Result {
    param(
        [string]$SettingName,
        [int]$CurrentValue,
        [int]$RequiredValue,
        [string]$Status
    )
    
    # Define compliance description based on binary 1/0 value
    $CurrentStatusValueText = if ($CurrentValue -eq 1) { "Enabled" } elseif ($CurrentValue -eq 0) { "Disabled" } else { "Unknown" }
    
    # Determine Status Display Strings
    if ($Status -eq "COMPLIANT") {
        $StatusColor = "Green"
        $CurrentStatusText = "COMPLIANT (Value: Enabled)"
    } else {
        $StatusColor = "Red"
        $CurrentStatusText = "NON-COMPLIANT (Value: Disabled)"
    }

    # Clear and formatted console output
    Write-Host "`n#`n# CIS Benchmark Audit Results" -ForegroundColor DarkCyan
    Write-Host "# Policy ID: $($CIS_ID)" -ForegroundColor DarkCyan
    Write-Host "# Policy Name: $($CIS_NAME)" -ForegroundColor DarkCyan
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    
    Write-Host ("{0,-30} : {1}" -f "Policy Name", $SettingName) -ForegroundColor Cyan
    Write-Host ("{0,-30} : {1}" -f "Required CIS State", "Enabled (1)") -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "Current State (Numeric)", "$CurrentValue ($CurrentStatusValueText)") -ForegroundColor Yellow
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host ("{0,-30} : {1}" -f "Compliance Status", $CurrentStatusText) -ForegroundColor $StatusColor
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
}


# --- Main Audit Logic ---
try {
    # 1. Setup Report Folder and Paths
    $CurrentScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $ReportPath = Join-Path $CurrentScriptDir $ReportFolder
    if (-not (Test-Path $ReportPath)) {
        New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
    }
    $FullReportFilePath = Join-Path $ReportPath $ReportFileName

    # 2. Export the local security policy database settings.
    $TempPath = Join-Path $env:TEMP "Complexity_SecurityPolicy.cfg"
    
    Write-Host "Exporting local security database..."
    $SecEditExitCode = (secedit /export /cfg $TempPath /areas SECURITYPOLICY) | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "secedit export failed with exit code $LASTEXITCODE."
        Exit 1
    }

    # 3. Find and extract the 'PasswordComplexity' value.
    $ComplexityLine = Get-Content $TempPath | Select-String -Pattern "$SETTING_KEY\s*=" | Select-Object -First 1
    
    # Initialize CurrentValue. Default for stand-alone is 0 (Disabled).
    $CurrentValue = 0
    
    if ($ComplexityLine) {
        if ($ComplexityLine -match '=\s*(-?\d+)') {
            $CurrentValue = [int]$matches[1]
        }
    }
    
    # Clean up audit temp file
    Remove-Item $TempPath -Force -ErrorAction SilentlyContinue

    # 4. Determine Compliance (Must be >= 1, since 1=Enabled, 0=Disabled)
    if ($CurrentValue -ge $REQUIRED_VALUE) {
        $Status = "COMPLIANT"
    } else {
        $Status = "NON-COMPLIANT"
    }

    # 5. Display Results (Console Output)
    Display-Audit-Result -SettingName $SETTING_NAME -CurrentValue $CurrentValue -RequiredValue $REQUIRED_VALUE -Status $Status

    # 6. Generate and Save JSON Report
    $JsonResult = [PSCustomObject]@{
        Compliance_Status = $Status
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        # Output "Enabled" or "Disabled" in JSON for clarity
        Current_Value = if ($CurrentValue -eq 1) { "Enabled" } elseif ($CurrentValue -eq 0) { "Disabled" } else { "Unknown" }
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "Enabled (1)"
    }
    
    $JsonResult | ConvertTo-Json -Depth 3 | Out-File -FilePath $FullReportFilePath -Encoding UTF8

    Write-Host "`nJSON audit report successfully saved to: $FullReportFilePath" -ForegroundColor Cyan

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    Write-Host "Please ensure you are running this script with elevated (Administrator) privileges." -ForegroundColor Red
    
    # Attempt to save the error report if possible
    $ErrorJsonResult = [PSCustomObject]@{
        Compliance_Status = "Error"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = "Error: $($_.Exception.Message)"
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "Enabled (1)"
    }
    
    try {
        $ErrorJsonResult | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $ReportPath $ReportFileName) -Encoding UTF8
        Write-Host "Error report saved to: $FullReportFilePath" -ForegroundColor Red
    } catch {
        # Silent failure if file write is impossible
    }
}
finally {
    # Final cleanup of temporary files
    $TempPathToCleanup = Join-Path $env:TEMP "Complexity_SecurityPolicy.cfg"
    if (Test-Path $TempPathToCleanup) { Remove-Item $TempPathToCleanup -Force -ErrorAction SilentlyContinue }
    
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "--- Audit complete. ---"
}
