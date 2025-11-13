<#
.SYNOPSIS
Audits CIS Benchmark 1.2.2: Checks if Account lockout threshold is set to 5 or fewer attempts (but not 0).

.DESCRIPTION
This script reads the 'LockoutThreshold' from the local security policy database to determine
compliance against the CIS requirement (Value: 1-5).

.NOTES
Run this script with elevated privileges (Run as Administrator).
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.2.2 (L1)"
$CIS_NAME = "Account lockout threshold is set to '5 or fewer invalid logon attempt(s), but not 0'"
$REQUIRED_MAX_VALUE = 5
$SETTING_KEY = "LockoutThreshold"
$SETTING_NAME = "Account Lockout Threshold"
$REPORT_FOLDER = "report"
$REPORT_FILENAME = "Audit_Account_Lockout_Threshold.json"
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
    Write-Host ("{0,-40} : {1}" -f "Required Value", "1 - $REQUIRED_MAX_VALUE attempts (not 0)") -ForegroundColor Yellow
    Write-Host ("{0,-40} : {1}" -f "Current Value", "$CurrentValue attempts") -ForegroundColor Yellow
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
    $TempPath = Join-Path $env:TEMP "SecPolicy_LockoutThreshold_Audit.cfg"
    $TempDbPath = Join-Path $env:TEMP "LocalDatabase.sdb"

    Write-Host "Attempting to read policy via secedit..." -ForegroundColor Cyan
    # Export using ASCII encoding for reliable Select-String/regex parsing
    $null = secedit /export /cfg $TempPath /areas SECURITYPOLICY 2>&1
    
    if (Test-Path $TempPath) {
        # Reading content using ASCII encoding
        $secEditContent = Get-Content $TempPath -Encoding ASCII -ErrorAction SilentlyContinue
        $ThresholdLine = $secEditContent | Select-String -Pattern "$SETTING_KEY\s*=" | Select-Object -First 1
        
        if ($ThresholdLine) {
            # Extract the numeric value (e.g., '5' from 'LockoutThreshold = 5')
            if ($ThresholdLine.ToString() -match '=\s*(\d+)') {
                $CurrentValue = [int]$matches[1]
            }
        }
        
        Remove-Item $TempPath -Force -ErrorAction SilentlyContinue
    }
    
    # Fallback/Debug note: If secedit fails or is unavailable, $CurrentValue remains -1.
    if ($CurrentValue -eq -1) {
        # Using net accounts as a final verification method (less precise, but useful for user feedback)
        Write-Host "secedit failed. Trying fallback method: net accounts..." -ForegroundColor Yellow
        $NetAccountsOutput = net accounts 2>&1
        $ThresholdLineNet = $NetAccountsOutput | Where-Object { $_ -match "Lockout threshold" } | Select-Object -First 1
        
        if ($ThresholdLineNet -match '\:\s*(\d+)') {
            $CurrentValue = [int]$matches[1]
            Write-Host "Fallback extracted value: $CurrentValue attempts" -ForegroundColor DarkYellow
        }
    }


    # 3. Determine Compliance
    if ($CurrentValue -eq 0) {
        $ComplianceStatus = "Non-Compliant"
        $ComplianceText = "NON-COMPLIANT (Value is 0: Lockout feature is disabled.)"
    } elseif ($CurrentValue -gt 0 -and $CurrentValue -le $REQUIRED_MAX_VALUE) {
        $ComplianceStatus = "Compliant"
        $ComplianceText = "COMPLIANT (Current value is within the required range of 1 to $REQUIRED_MAX_VALUE.)"
    } elseif ($CurrentValue -gt $REQUIRED_MAX_VALUE) {
        $ComplianceStatus = "Non-Compliant"
        $ComplianceText = "NON-COMPLIANT (Current value is $CurrentValue, which is higher than the maximum allowed $REQUIRED_MAX_VALUE.)"
    }
    
    # 4. Display Results
    Display-Audit-Result -CurrentValue $CurrentValue -Status $ComplianceStatus -ComplianceText $ComplianceText

    # 5. Create and save JSON output
    $auditResult = [PSCustomObject]@{
        Compliance_Status = $ComplianceStatus
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = "$CurrentValue attempts"
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "1-$REQUIRED_MAX_VALUE attempts (not 0)"
    }
    
    $auditResult | ConvertTo-Json | Out-File -FilePath $FullReportFilePath -Encoding UTF8
    Write-Host ""
    Write-Host "JSON report saved to: $FullReportFilePath" -ForegroundColor Cyan
    
} catch {
    $errorMessage = "An unexpected error occurred during execution: $($_.Exception.Message)"
    Write-Error $errorMessage -ForegroundColor Red
    
    # Handle error case for JSON output
    $auditResult = [PSCustomObject]@{
        Compliance_Status = "Error"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = "Error: $($_.Exception.Message)"
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "1-$REQUIRED_MAX_VALUE attempts (not 0)"
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
