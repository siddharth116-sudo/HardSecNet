<#
.SYNOPSIS
Audits CIS Benchmark 9.2.1: Checks if the 'Windows Firewall: Private: Firewall state' is set to 'On (recommended)'.

.DESCRIPTION
This script reads the actual active firewall state for the Private Profile using netsh command.
This verifies that the host firewall is actively running on private networks in real-time.

.NOTES
Run this script with elevated privileges (Run as Administrator).
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "9.2.1 (L1)"
$CIS_NAME = "Windows Firewall: Private: Firewall state is set to 'On (recommended)'"
$REQUIRED_VALUE = "ON" # Expected state
$SETTING_NAME = "Private Firewall State (EnableFirewall)"
$REG_PROPERTY = "EnableFirewall"
$REG_PATH = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile"
$OUTPUT_FILE = "Audit_Private_Firewall_State.json"
$StatusSeparator = "----------------------------------------------------"
$REPORT_FOLDER = "report" # JSON report folder name

# --- Function to Format and Display Results ---
function Display-Audit-Result {
    param(
        [string]$CurrentValue,
        [string]$RegistryValue,
        [string]$Status,
        [string]$ComplianceText
    )
    
    # Define color based on compliance status
    $StatusColor = switch ($Status) {
        "Compliant" { "Green" }
        "Non-Compliant" { "Red" }
        default { "Red" }
    }

    # Clear and formatted output (TUI Style)
    Write-Host "`n#`n# CIS Benchmark Audit Results`n#`n" -ForegroundColor DarkCyan
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "CIS Benchmark ID: $($CIS_ID)" -ForegroundColor White
    Write-Host "CIS Benchmark Name: $($CIS_NAME)" -ForegroundColor White
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    
    Write-Host ("{0,-40} : {1}" -f "Policy Name", $SETTING_NAME) -ForegroundColor Cyan
    Write-Host ("{0,-40} : {1}" -f "Required Value", "On") -ForegroundColor Yellow
    Write-Host ("{0,-40} : {1}" -f "Current Active State (netsh)", $CurrentValue) -ForegroundColor Yellow
    Write-Host ("{0,-40} : {1}" -f "Registry Value (REG_DWORD)", $RegistryValue) -ForegroundColor Yellow
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host ("{0,-40} : {1}" -f "Compliance Status", $ComplianceText) -ForegroundColor $StatusColor
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
}

# --- Main Audit Logic ---
try {
    # 1. Setup report folder and file path
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $ReportPath = Join-Path $ScriptDir $REPORT_FOLDER
    $FullReportFilePath = Join-Path $ReportPath $OUTPUT_FILE
    
    if (-not (Test-Path $ReportPath)) {
        Write-Host "Creating report directory: $ReportPath" -ForegroundColor DarkYellow
        New-Item -Path $ReportPath -ItemType Directory | Out-Null
    }

    $CurrentValue = "UNKNOWN"
    $RegistryValue = "Not Set"
    $ComplianceStatus = "Error"
    $ComplianceText = "ERROR: Policy value could not be retrieved."

    # 2. Read the ACTUAL active firewall state using netsh (Real-time check)
    Write-Host "Attempting to read active firewall state using netsh..." -ForegroundColor Cyan
    
    try {
        $NetshOutput = (netsh advfirewall show privateprofile) 2>&1
        $StateLine = $NetshOutput | Select-String "State"
        
        # Extract the current state (ON or OFF)
        if ($StateLine -match '\s+(ON|OFF)\s*$') {
            $CurrentValue = $matches[1]
            Write-Host "Successfully read active firewall state: $CurrentValue" -ForegroundColor Green
        } else {
            $CurrentValue = "UNKNOWN"
            Write-Host "Could not parse firewall state from netsh output" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error reading firewall state: $($_.Exception.Message)" -ForegroundColor Red
        $CurrentValue = "ERROR"
    }

    # 3. Also read the Registry value for reference (Group Policy setting)
    Write-Host "Checking registry configuration..." -ForegroundColor Cyan
    
    $RegValue = Get-ItemProperty -Path $REG_PATH -Name $REG_PROPERTY -ErrorAction SilentlyContinue

    if ($RegValue -ne $null) {
        $RegistryValue = $RegValue.$REG_PROPERTY
        Write-Host "Registry value found: $RegistryValue" -ForegroundColor Green
    } else {
        $RegistryValue = "Not Configured"
        Write-Host "Registry policy key not found (using Windows default)" -ForegroundColor Yellow
    }
    
    # 4. Determine Compliance based on ACTUAL active state (not registry)
    if ($CurrentValue -eq "ON") {
        $ComplianceStatus = "Compliant"
        $ComplianceText = "COMPLIANT (Firewall is correctly set to On)"
    } elseif ($CurrentValue -eq "OFF") {
        $ComplianceStatus = "Non-Compliant"
        $ComplianceText = "NON-COMPLIANT (Firewall is currently OFF. Required: ON)"
    } else {
        $ComplianceStatus = "Error"
        $ComplianceText = "ERROR: Unable to determine firewall state"
    }
    
    # 5. Display Results
    Display-Audit-Result -CurrentValue $CurrentValue -RegistryValue $RegistryValue -Status $ComplianceStatus -ComplianceText $ComplianceText

    # 6. Create and save JSON output
    $auditResult = [PSCustomObject]@{
        Compliance_Status = $ComplianceStatus
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Active_State = $CurrentValue
        Registry_Value = $RegistryValue
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "On"
    }
    
    $auditResult | ConvertTo-Json -Depth 4 | Out-File -FilePath $FullReportFilePath -Encoding UTF8
    Write-Host ""
    Write-Host "JSON report saved to: $FullReportFilePath" -ForegroundColor Cyan
    
} catch {
    $errorMessage = "An unexpected error occurred during execution: $($_.Exception.Message)"
    Write-Host $errorMessage -ForegroundColor Red
    
    # Define error file path and save JSON
    $ErrorFile = Join-Path $ReportPath "Audit_Private_Firewall_State_Error.json"
    $auditResult = [PSCustomObject]@{
        Compliance_Status = "Error"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Active_State = "Error: $($_.Exception.Message)"
        Registry_Value = "Error"
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "On"
    }
    $auditResult | ConvertTo-Json -Depth 4 | Out-File -FilePath $ErrorFile -Encoding UTF8
    Write-Host "JSON report saved with error details to: $ErrorFile" -ForegroundColor Red
}
finally {
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "--- Audit complete. ---"
}