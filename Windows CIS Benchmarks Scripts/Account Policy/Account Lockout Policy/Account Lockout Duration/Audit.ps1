<#
.SYNOPSIS
Audits CIS Benchmark 1.2.1: Checks if 'Account lockout duration' is set to '15 or more minute(s)'.

.DESCRIPTION
This script reads the 'LockoutDuration' setting from the local security policy database 
(secedit) to determine if the lockout period is compliant (Required state: >= 15 minutes).

.NOTES
Run this script with elevated privileges (Run as Administrator).
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.2.1 (L1)"
$CIS_NAME = "Account lockout duration is set to '15 or more minute(s)' (Automated)"
$REQUIRED_MIN_VALUE = 15 # Minimum required minutes (15)
$SETTING_KEY = "LockoutDuration"
$SETTING_NAME = "Account Lockout Duration"
$StatusSeparator = "----------------------------------------------------"

# --- Reporting Configuration ---
$ReportFolder = "report"
$ReportFileName = "Audit_Account_Lockout_Duration_$($CIS_ID.Replace(' ', '_')).json"

# --- Function to Format and Display Results ---
function Display-Audit-Result {
    param(
        [string]$SettingName,
        [int]$CurrentValue,
        [int]$RequiredValue,
        [string]$Status
    )
    
    # Define compliance description 
    $CurrentStatusValueText = "$CurrentValue minutes"
    $RequiredStatusValueText = "$RequiredValue or more minutes"
    
    # Determine Status Display Strings
    if ($Status -eq "COMPLIANT") {
        $StatusColor = "Green"
        $CurrentStatusOutput = "COMPLIANT (Current value >= Required minimum)"
    } else {
        $StatusColor = "Red"
        # Since 0 is usually the default/non-compliant state, and anything < 15 is non-compliant.
        $CurrentStatusOutput = "NON-COMPLIANT (Expected: >= $RequiredValue minutes)"
    }

    # Clear and formatted console output
    Write-Host "`n#`n# CIS Benchmark Audit Results" -ForegroundColor DarkCyan
    Write-Host "# Policy ID: $($CIS_ID)" -ForegroundColor DarkCyan
    Write-Host "# Policy Name: $($CIS_NAME)" -ForegroundColor DarkCyan
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    
    Write-Host ("{0,-40} : {1}" -f "Policy Name", $SettingName) -ForegroundColor Cyan
    Write-Host ("{0,-40} : {1}" -f "Required CIS Minimum", $RequiredStatusValueText) -ForegroundColor Yellow
    Write-Host ("{0,-40} : {1}" -f "Current Applied Value", $CurrentStatusValueText) -ForegroundColor Yellow
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host ("{0,-40} : {1}" -f "Compliance Status", $CurrentStatusOutput) -ForegroundColor $StatusColor
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

    # 2. Export the local security policy database settings for reliable parsing.
    Write-Host "Attempting to read value using secedit..." -ForegroundColor Cyan
    $TempPath = Join-Path $env:TEMP "SecPolicy_LockoutDuration_Audit.cfg"
    
    # Export policy configuration to a temporary file
    $SecEditExitCode = (secedit /export /cfg $TempPath /areas SECURITYPOLICY) | Out-Null
    
    # Check for secedit failure
    if ($LASTEXITCODE -ne 0) {
        Write-Error "secedit export failed with exit code $LASTEXITCODE."
        Exit 1
    }

    # 3. Find and extract the 'LockoutDuration' value.
    $DurationLine = Get-Content $TempPath | Select-String -Pattern "$SETTING_KEY\s*=" | Select-Object -First 1
    
    # Default value if policy isn't explicitly defined in the local store, it defaults to Not Defined/None (0)
    # The actual Windows default when threshold is set is 30 mins, but for robustness, we parse the configured value.
    $CurrentValue = 0 

    if ($DurationLine) {
        # Extract the numeric value (e.g., '30' from 'LockoutDuration = 30')
        if ($DurationLine.ToString() -match '=\s*(\d+)') {
            $CurrentValue = [int]$matches[1]
        }
    }
    
    # 4. Determine Compliance
    # Compliance: Value must be >= 15. The range is 1 to 99,999. 0 means manual reset.
    if ($CurrentValue -ge $REQUIRED_MIN_VALUE) {
        $Status = "COMPLIANT"
    } else {
        $Status = "NON-COMPLIANT"
    }

    # 5. Display Results (Console Output)
    Display-Audit-Result -SettingName $SETTING_NAME -CurrentValue $CurrentValue -RequiredValue $REQUIRED_MIN_VALUE -Status $Status

    # 6. Generate and Save JSON Report
    $CurrentStateText = if ($CurrentValue -eq 0) { "0 minutes (Manual Reset)" } else { "$CurrentValue minutes" }
    
    $JsonResult = [PSCustomObject]@{
        Compliance_Status = $Status
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = $CurrentStateText
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "$REQUIRED_MIN_VALUE or more minute(s) (not 0)"
    }
    
    $JsonResult | ConvertTo-Json -Depth 3 | Out-File -FilePath $FullReportFilePath -Encoding UTF8

    Write-Host "`nJSON audit report successfully saved to: $FullReportFilePath" -ForegroundColor Cyan

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    Write-Host "Please ensure you are running this script with elevated (Administrator) privileges." -ForegroundColor Red
    
    # Attempt to save the error report
    $FullReportFilePath = Join-Path (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) $ReportFolder) $ReportFileName
    $ErrorJsonResult = [PSCustomObject]@{
        Compliance_Status = "Error"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = "Error: $($_.Exception.Message)"
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "$REQUIRED_MIN_VALUE or more minute(s) (not 0)"
    }
    
    try {
        if (-not (Test-Path $ReportPath)) { New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null }
        $ErrorJsonResult | ConvertTo-Json -Depth 3 | Out-File -FilePath $FullReportFilePath -Encoding UTF8
        Write-Host "Error report saved to: $FullReportFilePath" -ForegroundColor Red
    } catch {
        # Silent failure if file write is impossible
    }
}
finally {
    # Clean up temporary files
    if (Test-Path $TempPath) { Remove-Item $TempPath -Force -ErrorAction SilentlyContinue }
    
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "--- Audit complete. ---"
}
