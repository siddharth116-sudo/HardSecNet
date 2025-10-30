<#
.SYNOPSIS
Audits CIS Benchmark 1.2.4: Checks if the 'Reset account lockout counter after' duration is set to 15 or more minutes.

.DESCRIPTION
This script reads the 'ResetLockoutCount' (Lockout Window) from the local security policy database to determine
compliance against the CIS requirement (Value: >= 15 minutes).

.NOTES
Run this script with elevated privileges (Run as Administrator).
This setting is only effective if 'Account lockout threshold' (CIS 1.2.2) is also set to a value other than 0.
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.2.4 (L1)"
$CIS_NAME = "Reset account lockout counter after is set to '15 or more minute(s)'"
$REQUIRED_MIN_VALUE = 15
$SETTING_KEY = "ResetLockoutCount"
$SETTING_NAME = "Reset Account Lockout Counter After"
$REPORT_FOLDER = "report"
$REPORT_FILENAME = "Audit_Lockout_Counter_Reset.json"
$StatusSeparator = "----------------------------------------------------"

# --- Function to Format and Display Results ---
function Display-Audit-Result {
    param(
        [int]$CurrentValue,
        [string]$Status,
        [string]$ComplianceText
    )
    
    # Define color based on compliance status
    $StatusColor = switch ($Status) {
        "Compliant" { "Green" }
        "Non-Compliant" { "Red" }
        default { "Yellow" }
    }

    # Clear and formatted output
    Write-Host "`n#`n# CIS Benchmark Audit Results`n#`n" -ForegroundColor DarkCyan
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "CIS Benchmark ID: $($CIS_ID)" -ForegroundColor White
    Write-Host "CIS Benchmark Name: $($CIS_NAME)" -ForegroundColor White
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    
    Write-Host ("{0,-40} : {1}" -f "Policy Name", $SETTING_NAME) -ForegroundColor Cyan
    Write-Host ("{0,-40} : {1}" -f "Required Value", "$REQUIRED_MIN_VALUE or more minutes") -ForegroundColor Yellow
    Write-Host ("{0,-40} : {1}" -f "Current Value", "$CurrentValue minutes") -ForegroundColor Yellow
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host ("{0,-40} : {1}" -f "Compliance Status", $ComplianceText) -ForegroundColor $StatusColor
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
}


# --- Main Audit Logic ---
try {
    # 1. Setup report folder and file path
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $ReportPath = Join-Path $ScriptDir $REPORT_FOLDER
    $FullReportFilePath = Join-Path $ReportPath $REPORT_FILENAME
    
    if (-not (Test-Path $ReportPath)) {
        Write-Host "Creating report directory: $ReportPath" -ForegroundColor DarkYellow
        New-Item -Path $ReportPath -ItemType Directory | Out-Null
    }

    $CurrentValue = -1
    $ComplianceStatus = "Error"
    $ComplianceText = "ERROR: Policy value could not be retrieved."

    # 2. Export the local security policy database settings for reliable parsing.
    $TempPath = Join-Path $env:TEMP "SecPolicy_ResetLockoutCount_Audit.cfg"
    $TempDbPath = Join-Path $env:TEMP "LocalDatabase.sdb"

    Write-Host "Attempting to read policy via secedit..." -ForegroundColor Cyan
    $null = secedit /export /cfg $TempPath /areas SECURITYPOLICY 2>&1
    
    if (Test-Path $TempPath) {
        # Reading content using ASCII encoding for reliable parsing
        $secEditContent = Get-Content $TempPath -Encoding ASCII -ErrorAction SilentlyContinue
        $ThresholdLine = $secEditContent | Select-String -Pattern "$SETTING_KEY\s*=" | Select-Object -First 1
        
        if ($ThresholdLine) {
            # Extract the numeric value (e.g., '15' from 'ResetLockoutCount = 15')
            if ($ThresholdLine.ToString() -match '=\s*(\d+)') {
                $CurrentValue = [int]$matches[1]
            }
        }
        
        Remove-Item $TempPath -Force -ErrorAction SilentlyContinue
    }
    
    # 3. Fallback to net accounts if secedit failed (less reliable but provides a value)
    if ($CurrentValue -eq -1) {
        Write-Host "secedit failed. Trying fallback method: net accounts..." -ForegroundColor Yellow
        $NetAccountsOutput = net accounts 2>&1
        $LockoutWindowLine = $NetAccountsOutput | Where-Object { $_ -match "Lockout observation window" } | Select-Object -First 1
        
        if ($LockoutWindowLine -match '\:\s*(\d+)') {
            $CurrentValue = [int]$matches[1]
        }
    }


    # 4. Determine Compliance
    if ($CurrentValue -ge $REQUIRED_MIN_VALUE) {
        $ComplianceStatus = "Compliant"
        $ComplianceText = "COMPLIANT (Current value is $CurrentValue, which is >= $REQUIRED_MIN_VALUE minutes.)"
    } elseif ($CurrentValue -gt 0 -and $CurrentValue -lt $REQUIRED_MIN_VALUE) {
        $ComplianceStatus = "Non-Compliant"
        $ComplianceText = "NON-COMPLIANT (Current value is $CurrentValue, which is less than the required $REQUIRED_MIN_VALUE minutes.)"
    } elseif ($CurrentValue -eq 0) {
        $ComplianceStatus = "Non-Compliant"
        $ComplianceText = "NON-COMPLIANT (Value is 0: Counter is immediately reset, increasing DoS/Brute Force risk.)"
    }
    
    # 5. Display Results
    Display-Audit-Result -CurrentValue $CurrentValue -Status $ComplianceStatus -ComplianceText $ComplianceText

    # 6. Create and save JSON output
    $auditResult = [PSCustomObject]@{
        Compliance_Status = $ComplianceStatus
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = "$CurrentValue minutes"
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "$REQUIRED_MIN_VALUE or more minute(s) (not 0)"
    }
    
    $auditResult | ConvertTo-Json | Out-File -FilePath $FullReportFilePath -Encoding UTF8
    Write-Host ""
    Write-Host "JSON report saved to: $FullReportFilePath" -ForegroundColor Cyan
    
} catch {
    # Fix 2: Quote the entire error file path string
    $FullReportFilePath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "report\Audit_Lockout_Counter_Reset_Error.json"
    $errorMessage = "An unexpected error occurred during execution: $($_.Exception.Message)"
    Write-Error $errorMessage -ForegroundColor Red; # Fix 3: Add semicolon to terminate Write-Error statement
    
    # Handle error case for JSON output
    $auditResult = [PSCustomObject]@{
        Compliance_Status = "Error"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = "Error: $($_.Exception.Message)"
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "$REQUIRED_MIN_VALUE or more minute(s) (not 0)"
    }
    $auditResult | ConvertTo-Json | Out-File -FilePath $FullReportFilePath -Encoding UTF8
    Write-Host "JSON report saved with error details to: $FullReportFilePath" -ForegroundColor Red
}
finally {
    # Ensure temporary files are cleaned up
    if (Test-Path $TempPath) { Remove-Item $TempPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $TempDbPath) { Remove-Item $TempDbPath -Force -ErrorAction SilentlyContinue }
    
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "--- Audit complete. ---"
}
