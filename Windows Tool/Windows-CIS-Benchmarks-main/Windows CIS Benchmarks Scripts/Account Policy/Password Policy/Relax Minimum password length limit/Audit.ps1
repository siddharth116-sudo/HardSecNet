<#
.SYNOPSIS
Audits CIS Benchmark 1.1.6: Checks if 'Relax minimum password length limits' is set to 'Enabled'.

.DESCRIPTION
This script reads the 'RelaxMinimumPasswordLengthLimits' registry value directly from 
HKLM\System\CurrentControlSet\Control\SAM to determine if the system is configured to allow 
password lengths greater than 14 characters (Required state: 1 = Enabled).

.NOTES
Run this script with elevated privileges (Run as Administrator).
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.1.6 (L1)"
$CIS_NAME = "Ensure 'Relax minimum password length limits' is set to 'Enabled' (Automated)"
$REQUIRED_VALUE = 1 # 1 = Enabled
$SETTING_KEY = "RelaxMinimumPasswordLengthLimits"
$SETTING_NAME = "Relax Minimum Password Length Limits"
$REGISTRY_PATH = "HKLM:\System\CurrentControlSet\Control\SAM"
$StatusSeparator = "----------------------------------------------------"

# --- Reporting Configuration ---
$ReportFolder = "report"
$ReportFileName = "Audit_Password_RelaxLength_$($CIS_ID.Replace(' ', '_')).json"

# --- Function to Format and Display Results ---
function Display-Audit-Result {
    param(
        [string]$SettingName,
        [int]$CurrentValue,
        [int]$RequiredValue,
        [string]$Status
    )
    
    # Define compliance description based on binary 1/0 value
    $CurrentStatusValueText = if ($CurrentValue -eq 1) { "Enabled" } elseif ($CurrentValue -eq 0) { "Disabled" } else { "Not Found (Default Disabled)" }
    
    # Determine Status Display Strings
    if ($Status -eq "COMPLIANT") {
        $StatusColor = "Green"
        $CurrentStatusOutput = "COMPLIANT (Value: Enabled)"
    } else {
        $StatusColor = "Red"
        $CurrentStatusOutput = "NON-COMPLIANT (Expected: Enabled (1))"
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
    Write-Host ("{0,-30} : {1}" -f "Compliance Status", $CurrentStatusOutput) -ForegroundColor $StatusColor
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

    # 2. Read Registry Value Directly
    Write-Host "Reading registry value for '$SETTING_KEY' from '$REGISTRY_PATH'..." -ForegroundColor Cyan
    
    # Default value if registry key/value is missing (Disabled/0)
    $CurrentValue = 0 
    
    try {
        $RegistryValue = Get-ItemProperty -Path $REGISTRY_PATH -Name $SETTING_KEY -ErrorAction Stop
        $CurrentValue = [int]$RegistryValue.$SETTING_KEY
        Write-Host "Registry Value Found: $CurrentValue" -ForegroundColor Green
    }
    catch {
        # Catch failure if the entire 'SAM' key path or value is missing (Default is 0/Disabled)
        Write-Host "Registry value not found. Assuming default: $CurrentValue (Disabled)" -ForegroundColor Yellow
    }

    # 3. Determine Compliance
    if ($CurrentValue -eq $REQUIRED_VALUE) {
        $Status = "COMPLIANT"
    } else {
        $Status = "NON-COMPLIANT"
    }

    # 4. Display Results (Console Output)
    Display-Audit-Result -SettingName $SETTING_NAME -CurrentValue $CurrentValue -RequiredValue $REQUIRED_VALUE -Status $Status

    # 5. Generate and Save JSON Report
    $CurrentStateText = if ($CurrentValue -eq 1) { "Enabled" } elseif ($CurrentValue -eq 0) { "Disabled" } else { "Unknown" }
    
    $JsonResult = [PSCustomObject]@{
        Compliance_Status = $Status
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = $CurrentStateText
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "Enabled (1)"
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
        Recommended_Value = "Enabled (1)"
    }
    $ReportPath = Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) $ReportFolder
    $FullReportFilePath = Join-Path $ReportPath $ReportFileName

    try {
        if (-not (Test-Path $ReportPath)) { New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null }
        $ErrorJsonResult | ConvertTo-Json -Depth 3 | Out-File -FilePath $FullReportFilePath -Encoding UTF8
        Write-Host "Error report saved to: $FullReportFilePath" -ForegroundColor Red
    } catch {
        # Silent failure if file write is impossible
    }
}
finally {
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "--- Audit complete. ---"
}
