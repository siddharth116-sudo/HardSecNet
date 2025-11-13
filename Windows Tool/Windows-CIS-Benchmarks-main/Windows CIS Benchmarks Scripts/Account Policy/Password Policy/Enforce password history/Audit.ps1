<#
.SYNOPSIS
Audits CIS Benchmark 1.1.1: Enforce password history.

.DESCRIPTION
This script checks the 'Enforce password history' setting on a local Windows system 
using the local security policy database, provides a robust console audit status, and 
exports the findings to a JSON file in a 'report' folder.

.NOTES
Run this script with elevated privileges (Run as Administrator).
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.1.1 (L1)"
$CIS_NAME = "Ensure 'Enforce password history' is set to '24 or more password(s)' (Automated)"
$REQUIRED_VALUE = 24
$SETTING_NAME = "Password History Size"
$STATUS_SEPARATOR = "----------------------------------------------------"

# --- Reporting Configuration ---
$ReportFolder = "report"
$ReportFileName = "Audit_Password_History_$($CIS_ID.Replace(' ', '_')).json"

# --- Function to Format and Display Results ---
function Display-Audit-Result {
    param(
        [string]$SettingName,
        [int]$CurrentValue,
        [int]$RequiredValue,
        [string]$Status
    )
    
    # Define color based on compliance status
    if ($Status -eq "COMPLIANT") {
        $StatusColor = "Green"
        $CurrentStatus = "COMPLIANT (Current value >= Required value)"
    } else {
        $StatusColor = "Red"
        $CurrentStatus = "NON-COMPLIANT (Current value < Required value)"
    }

    # Clear and formatted console output
    Write-Host "`n#`n# CIS Benchmark Audit Results" -ForegroundColor DarkCyan
    Write-Host "# Policy ID: $($CIS_ID)" -ForegroundColor DarkCyan
    Write-Host "# Policy Name: $($CIS_NAME)" -ForegroundColor DarkCyan
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    
    Write-Host ("{0,-30} : {1}" -f "Policy Name", $SettingName) -ForegroundColor Cyan
    Write-Host ("{0,-30} : {1}" -f "Required Value", "$RequiredValue passwords") -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "Current Value", "$CurrentValue passwords") -ForegroundColor Yellow
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    Write-Host ("{0,-30} : {1}" -f "Compliance Status", $CurrentStatus) -ForegroundColor $StatusColor
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
}

# --- Main Audit Logic ---
try {
    # Create the report folder if it does not exist
    $CurrentScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $ReportPath = Join-Path $CurrentScriptDir $ReportFolder
    if (-not (Test-Path $ReportPath)) {
        New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
    }
    $FullReportFilePath = Join-Path $ReportPath $ReportFileName

    # 1. Export the local security policy database settings for reliable parsing.
    $TempPath = Join-Path $env:TEMP "SecurityPolicy.cfg"
    
    Write-Host "Exporting local security database..."
    # The output is suppressed as secedit may output warnings to stderr
    $SecEditExitCode = (secedit /export /cfg $TempPath /areas SECURITYPOLICY) | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "secedit export failed with exit code $LASTEXITCODE."
        Exit 1
    }

    # 2. Find and extract the 'PasswordHistorySize' value.
    $HistoryLine = Get-Content $TempPath | Select-String -Pattern "PasswordHistorySize\s*=" | Select-Object -First 1
    
    if (-not $HistoryLine) {
        # Default value when policy is undefined is usually 0 on standalone systems
        $CurrentValue = 0
    } else {
        # Extract the numeric value (e.g., '24' from 'PasswordHistorySize = 24')
        $CurrentValueStr = $HistoryLine -split '=' | Select-Object -Last 1
        $CurrentValue = [int]($CurrentValueStr.Trim())
    }

    # 3. Determine Compliance
    if ($CurrentValue -ge $REQUIRED_VALUE) {
        $Status = "COMPLIANT"
    } else {
        $Status = "NON-COMPLIANT"
    }

    # 4. Display Results (Console Output)
    Display-Audit-Result -SettingName $SETTING_NAME -CurrentValue $CurrentValue -RequiredValue $REQUIRED_VALUE -Status $Status

    # 5. Generate and Save JSON Report
    $JsonResult = [PSCustomObject]@{
        Compliance_Status = $Status
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = "$CurrentValue passwords"
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "$REQUIRED_VALUE or more passwords"
    }
    
    $JsonResult | ConvertTo-Json -Depth 3 | Out-File -FilePath $FullReportFilePath -Encoding UTF8

    Write-Host "`nJSON audit report successfully saved to: $FullReportFilePath" -ForegroundColor Cyan

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    Write-Host "Please ensure you are running this script with elevated (Administrator) privileges." -ForegroundColor Red
    
    # Handle JSON generation failure during a critical error
    $ErrorJsonResult = [PSCustomObject]@{
        Compliance_Status = "Error"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = "Error: $($_.Exception.Message)"
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "$REQUIRED_VALUE or more passwords"
    }
    
    # Attempt to save the error report if possible
    try {
        $ErrorJsonResult | ConvertTo-Json -Depth 3 | Out-File -FilePath $FullReportFilePath -Encoding UTF8
        Write-Host "Error report saved to: $FullReportFilePath" -ForegroundColor Red
    } catch {
        # Silent failure if file write is impossible
    }
}
finally {
    # Clean up temporary files
    if (Test-Path $TempPath) { Remove-Item $TempPath -Force -ErrorAction SilentlyContinue }
    
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    Write-Host "--- Audit complete. ---"
}
