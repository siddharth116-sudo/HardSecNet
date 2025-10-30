<#
.SYNOPSIS
Audits CIS Benchmark 1.1.7: Checks if 'Store passwords using reversible encryption' is set to 'Disabled'.

.DESCRIPTION
This script reads the 'ClearTextPassword' setting from the local security policy database 
(secedit) to determine if reversible encryption is disabled (Required state: 0 = Disabled).

.NOTES
Run this script with elevated privileges (Run as Administrator).
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.1.7 (L1)"
$CIS_NAME = "Ensure 'Store passwords using reversible encryption' is set to 'Disabled' (Automated)"
$REQUIRED_VALUE = 0 # 0 = Disabled
$SETTING_KEY = "ClearTextPassword"
$SETTING_NAME = "Store passwords using reversible encryption"
$StatusSeparator = "----------------------------------------------------"

# --- Reporting Configuration ---
$ReportFolder = "report"
$ReportFileName = "Audit_Password_ReversibleEncryption_$($CIS_ID.Replace(' ', '_')).json"

# --- Function to Format and Display Results ---
function Display-Audit-Result {
    param(
        [string]$SettingName,
        [int]$CurrentValue,
        [int]$RequiredValue,
        [string]$Status
    )
    
    # Define compliance description based on binary 1/0 value
    $CurrentStatusValueText = if ($CurrentValue -eq 0) { "Disabled" } elseif ($CurrentValue -eq 1) { "Enabled" } else { "Unknown" }
    $RequiredStatusValueText = if ($RequiredValue -eq 0) { "Disabled" } else { "Enabled" }
    
    # Determine Status Display Strings
    if ($Status -eq "COMPLIANT") {
        $StatusColor = "Green"
        $CurrentStatusOutput = "COMPLIANT (Value: Disabled)"
    } else {
        $StatusColor = "Red"
        $CurrentStatusOutput = "NON-COMPLIANT (Expected: Disabled (0))"
    }

    # Clear and formatted console output
    Write-Host "`n#`n# CIS Benchmark Audit Results" -ForegroundColor DarkCyan
    Write-Host "# Policy ID: $($CIS_ID)" -ForegroundColor DarkCyan
    Write-Host "# Policy Name: $($CIS_NAME)" -ForegroundColor DarkCyan
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    
    Write-Host ("{0,-40} : {1}" -f "Policy Name", $SettingName) -ForegroundColor Cyan
    Write-Host ("{0,-40} : {1}" -f "Required CIS State", "$RequiredStatusValueText ($RequiredValue)") -ForegroundColor Yellow
    Write-Host ("{0,-40} : {1}" -f "Current Applied State (Numeric)", "$CurrentValue ($CurrentStatusValueText)") -ForegroundColor Yellow
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
    $TempPath = Join-Path $env:TEMP "SecPolicy_ReversibleEncrypt.cfg"
    
    # Export policy configuration to a temporary file
    $SecEditExitCode = (secedit /export /cfg $TempPath /areas SECURITYPOLICY) | Out-Null
    
    # If the export failed, throw an error.
    if ($LASTEXITCODE -ne 0) {
        Write-Error "secedit export failed with exit code $LASTEXITCODE."
        Exit 1
    }

    # 3. Find and extract the 'ClearTextPassword' value.
    $ReversibleLine = Get-Content $TempPath | Select-String -Pattern "$SETTING_KEY\s*=" | Select-Object -First 1
    
    $CurrentValue = 0 # Default is Disabled (0) if not explicitly set in local policy

    if ($ReversibleLine) {
        # Extract the numeric value (e.g., '0' from 'ClearTextPassword = 0')
        if ($ReversibleLine.ToString() -match '=\s*(\d+)') {
            $CurrentValue = [int]$matches[1]
        }
    }
    
    # 4. Determine Compliance
    if ($CurrentValue -eq $REQUIRED_VALUE) {
        $Status = "COMPLIANT"
    } else {
        $Status = "NON-COMPLIANT"
    }

    # 5. Display Results (Console Output)
    Display-Audit-Result -SettingName $SETTING_NAME -CurrentValue $CurrentValue -RequiredValue $REQUIRED_VALUE -Status $Status

    # 6. Generate and Save JSON Report
    $CurrentStateText = if ($CurrentValue -eq 0) { "Disabled" } elseif ($CurrentValue -eq 1) { "Enabled" } else { "Unknown" }
    
    $JsonResult = [PSCustomObject]@{
        Compliance_Status = $Status
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = $CurrentStateText
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "Disabled (0)"
    }
    
    $JsonResult | ConvertTo-Json -Depth 3 | Out-File -FilePath $FullReportFilePath -Encoding UTF8

    Write-Host "`nJSON audit report successfully saved to: $FullReportFilePath" -ForegroundColor Cyan

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    Write-Host "Please ensure you are running this script with elevated (Administrator) privileges." -ForegroundColor Red
    
    # Attempt to save the error report
    $ErrorJsonResult = [PSCustomObject]@{
        Compliance_Status = "Error"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = "Error: $($_.Exception.Message)"
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "Disabled (0)"
    }
    $ReportPath = Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) $ReportFolder

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
