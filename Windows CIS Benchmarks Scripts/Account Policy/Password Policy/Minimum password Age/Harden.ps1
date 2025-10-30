<#
.SYNOPSIS
Applies the CIS Benchmark 1.1.3 setting for "Minimum password age" to 1 day.

.DESCRIPTION
This script sets the MinimumPasswordAge to 1 day using secedit.exe to ensure 
passwords cannot be instantly changed and reused, enhancing password history effectiveness.

.NOTES
Run this script with elevated privileges (Run as Administrator).
This is the correct method for local security policy hardening.
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "1.1.3 (L1)"
$CIS_NAME = "Ensure 'Minimum password age' is set to '1 or more day(s)' (Automated)"
$REQUIRED_VALUE = 1 # 1 day or more
$SETTING_KEY = "MinimumPasswordAge"
$StatusSeparator = "----------------------------------------------------"

# --- Main Hardening Logic ---
try {
    Write-Host "--- Applying Hardening for CIS Benchmark: $CIS_ID - $SETTING_KEY ---" -ForegroundColor Yellow

    # 1. Define Temporary File Paths
    $CurrentScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $TempCfgPath = Join-Path $env:TEMP "MinAge_Config.inf"
    $TempSdbPath = Join-Path $env:TEMP "MinAge_Database.sdb"

    # 2. Create Minimal .inf Configuration File
    # The [System Access] section is used for MinimumPasswordAge
    Write-Host "Creating minimal security configuration file..." -ForegroundColor Cyan
    @('[Version]', 'signature="$CHICAGO$"', '', '[System Access]', "$SETTING_KEY = $REQUIRED_VALUE") | 
        Out-File -FilePath $TempCfgPath -Encoding ASCII -Force

    # 3. Apply the New Security Policy
    Write-Host "Applying new security policy via secedit (This may take a moment)..." -ForegroundColor Yellow
    # /configure applies the .inf file to the database. /db creates a temporary database.
    $SecEditExitCode = (secedit /configure /db $TempSdbPath /cfg $TempCfgPath /areas SECURITYPOLICY /quiet) | Out-Null
    
    # Clean up the minimal configuration file immediately after use
    Remove-Item $TempCfgPath -Force -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILURE: secedit application failed with exit code $LASTEXITCODE." -ForegroundColor Red
        Write-Host "Check event logs for policy application errors." -ForegroundColor Red
        Exit 1
    }

    # 4. Verify the Applied Setting (Audit Check)
    Write-Host "Verifying new setting applied successfully..." -ForegroundColor Yellow
    
    # Re-export the database to check the current applied value
    $AuditTempPath = Join-Path $env:TEMP "AuditPolicy.cfg"
    $null = secedit /export /cfg $AuditTempPath /areas SECURITYPOLICY /quiet 2>&1
    
    $AuditLine = Get-Content $AuditTempPath | Select-String -Pattern "$SETTING_KEY\s*=" | Select-Object -First 1
    
    if ($AuditLine -match '=\s*(-?\d+)') {
        $CurrentAppliedValue = [int]$matches[1]
    } else {
        $CurrentAppliedValue = -1
    }
    
    # Clean up audit temp file
    Remove-Item $AuditTempPath -Force -ErrorAction SilentlyContinue

    # 5. Output Verification
    $Status = if ($CurrentAppliedValue -ge $REQUIRED_VALUE) { "COMPLIANT" } else { "NON-COMPLIANT" }
    $StatusColor = if ($Status -eq "COMPLIANT") { "Green" } else { "Red" }
    $CurrentStatusText = if ($Status -eq "COMPLIANT") { "Value is >= $REQUIRED_VALUE day(s)" } else { "Value is NOT >= $REQUIRED_VALUE day(s)" }

    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "SUCCESS: Hardening applied." -ForegroundColor Green
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    
    # TUI output resembling the screenshot provided in the conversation history
    Write-Host ("{0,-30} : {1} day(s)" -f "Required CIS Minimum", $REQUIRED_VALUE) -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1} day(s)" -f "Current Applied Value", $CurrentAppliedValue) -ForegroundColor Yellow
    Write-Host ("{0,-30} : {1}" -f "VERIFICATION", $Status) -ForegroundColor $StatusColor
    
} catch {
    Write-Host "An unexpected error occurred during execution: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Final cleanup of temporary database file
    if (Test-Path $TempSdbPath) { Remove-Item $TempSdbPath -Force -ErrorAction SilentlyContinue }
    
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "--- Policy application complete. ---"
}
