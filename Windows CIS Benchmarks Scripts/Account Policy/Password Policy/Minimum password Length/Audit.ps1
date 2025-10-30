<#
.SYNOPSIS
Audits CIS Benchmark 1.1.4: Checks if Minimum password length is set to 14 or more characters.

.DESCRIPTION
This script reads the current local policy setting (MinimumPasswordLength) from the 
security database, determines compliance against the CIS requirement (>= 14), 
and exports the findings to a JSON file in a 'report' folder.

.NOTES
Run this script with elevated privileges (Run as Administrator).
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.1.4 (L1)"
$CIS_NAME = "Minimum password length is set to '14 or more character(s)' (Automated)"
$REQUIRED_MIN_VALUE = 14
$SETTING_NAME = "Minimum Password Length"
$STATUS_SEPARATOR = "----------------------------------------------------"

# --- Reporting Configuration ---
$ReportFolder = "report"
# Generate filename using the CIS_ID variable for consistency
$ReportFileName = "Audit_Password_MinLength_$($CIS_ID.Replace(' ', '_')).json"

# --- Function to Format and Display Results ---
function Display-Audit-Result {
    param(
        [string]$SettingName,
        [int]$CurrentValue,
        [int]$RequiredValue,
        [string]$Status
    )
    
    # Determine Status Display Strings
    if ($Status -eq "COMPLIANT") {
        $StatusColor = "Green"
        $CurrentStatusText = "COMPLIANT (Value is >= $RequiredValue characters)"
    } else {
        $StatusColor = "Red"
        $CurrentStatusText = "NON-COMPLIANT (Value is < $RequiredValue characters)"
    }

    # Clear and formatted console output
    Write-Host "`n#`n# CIS Benchmark Audit Results" -ForegroundColor DarkCyan
    Write-Host "# Policy ID: $($CIS_ID)" -ForegroundColor DarkCyan
    Write-Host "# Policy Name: $($CIS_NAME)" -ForegroundColor DarkCyan
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    
    Write-Host ("{0,-30} : {1}" -f "Policy Name", $SettingName) -ForegroundColor Cyan
    Write-Host ("{0,-30} : {1}" -f "Required CIS Minimum", "$RequiredValue characters") -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "Current Value", "$CurrentValue characters") -ForegroundColor Yellow
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    Write-Host ("{0,-30} : {1}" -f "Compliance Status", $CurrentStatusText) -ForegroundColor $StatusColor
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
}


# --- Main Audit Logic ---
try {
    # Create the report folder if it does not exist and define the full output path
    $CurrentScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $ReportPath = Join-Path $CurrentScriptDir $ReportFolder
    if (-not (Test-Path $ReportPath)) {
        New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
    }
    $FullReportFilePath = Join-Path $ReportPath $ReportFileName

    # 1. Export the local security policy database settings for reliable parsing.
    $TempPath = Join-Path $env:TEMP "MinLength_SecurityPolicy.cfg"
    
    Write-Host "Exporting local security database..."
    # /export exports the database to a text file. /cfg specifies the export path.
    $SecEditExitCode = (secedit /export /cfg $TempPath /areas SECURITYPOLICY) | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "secedit export failed with exit code $LASTEXITCODE."
        Exit 1
    }

    # 2. Find and extract the 'MinimumPasswordLength' value.
    # Note: Policy name in INF file is 'MinimumPasswordLength'
    $LengthLine = Get-Content $TempPath | Select-String -Pattern "MinimumPasswordLength\s*=" | Select-Object -First 1
    
    # Initialize CurrentValue before logic flow
    $CurrentValue = -1
    
    if (-not $LengthLine) {
        # Default value on stand-alone servers is 0 characters (Non-Compliant)
        $CurrentValue = 0 
    } else {
        # Extract the numeric value (e.g., '14' from 'MinimumPasswordLength = 14')
        if ($LengthLine -match '=\s*(-?\d+)') {
            $CurrentValue = [int]$matches[1]
        }
    }

    # 3. Determine Compliance (Must be >= 14 characters)
    if ($CurrentValue -ge $REQUIRED_MIN_VALUE) {
        $Status = "COMPLIANT"
    } else {
        $Status = "NON-COMPLIANT"
    }

    # 4. Display Results (Console Output)
    Display-Audit-Result -SettingName $SETTING_NAME -CurrentValue $CurrentValue -RequiredValue $REQUIRED_MIN_VALUE -Status $Status

    # 5. Generate and Save JSON Report
    $JsonResult = [PSCustomObject]@{
        Compliance_Status = $Status
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = if ($CurrentValue -eq -1) { "Unable to retrieve" } else { "$CurrentValue characters" }
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = ">= $REQUIRED_MIN_VALUE characters"
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
        Recommended_Value = ">= $REQUIRED_MIN_VALUE characters"
    }
    
    # Attempt to save the error report if possible (using the defined FullReportFilePath)
    try {
        $ErrorJsonResult | ConvertTo-Json -Depth 3 | Out-File -FilePath $FullReportFilePath -Encoding UTF8
        Write-Host "Error report saved to: $FullReportFilePath" -ForegroundColor Red
    } catch {
        # Silent failure if file write is impossible
    }
}
finally {
    # Clean up temporary files
    $TempPathToCleanup = Join-Path $env:TEMP "MinLength_SecurityPolicy.cfg"
    if (Test-Path $TempPathToCleanup) { Remove-Item $TempPathToCleanup -Force -ErrorAction SilentlyContinue }
    
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    Write-Host "--- Audit complete. ---"
}
