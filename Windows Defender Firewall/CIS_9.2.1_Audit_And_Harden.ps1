<#
.SYNOPSIS
Combined Audit and Hardening Script for CIS Benchmark 9.2.1
Ensures Windows Firewall: Private Profile is set to 'On (recommended)'.

.DESCRIPTION
This script performs three steps:
1. Audit current firewall state (Before Hardening)
2. Apply CIS Benchmark 9.2.1 configuration (Enable Firewall)
3. Audit firewall state again (After Hardening)

Both audits are logged with timestamps in the same directory where the script runs.
#>

# ===========================
# Initialization
# ===========================
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$beforeLog = Join-Path $scriptDir "Firewall_Audit_Before_$timestamp.log"
$afterLog  = Join-Path $scriptDir "Firewall_Audit_After_$timestamp.log"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " CIS Benchmark 9.2.1 - Windows Firewall: Private Profile" -ForegroundColor Yellow
Write-Host "============================================================`n"

# ===========================
# Function: Audit Firewall Private Profile
# ===========================
function Audit-FirewallPrivateProfile {
    param(
        [string]$logFile
    )

    Write-Host "Running Audit for Windows Firewall Private Profile..." -ForegroundColor Green
    Write-Host "Logging to: $logFile`n" -ForegroundColor DarkGray

    $auditOutput = netsh advfirewall show privateprofile
    $timestampNow = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $header = @"
============================================================
CIS 9.2.1 AUDIT - Windows Firewall: Private Profile
Timestamp: $timestampNow
============================================================
"@

    $footer = "`n============================================================`n"

    # Write to log file
    $header | Out-File -FilePath $logFile -Encoding UTF8
    $auditOutput | Out-File -FilePath $logFile -Append -Encoding UTF8
    $footer | Out-File -FilePath $logFile -Append -Encoding UTF8

    # Display on console
    Write-Host $auditOutput
    Write-Host "`nAudit results saved to: $logFile`n" -ForegroundColor Cyan
}

# ===========================
# Function: Apply Hardening (CIS 9.2.1)
# ===========================
function Apply-Hardening {
    Write-Host "Applying CIS 9.2.1 Hardening..." -ForegroundColor Yellow

    try {
        netsh advfirewall set privateprofile state on | Out-Null
        Write-Host "`n✅ Firewall Private Profile successfully set to 'On (recommended)'.`n" -ForegroundColor Green
    }
    catch {
        Write-Host "`n❌ Failed to apply hardening: $($_.Exception.Message)`n" -ForegroundColor Red
    }
}

# ===========================
# Step 1: Audit (Before)
# ===========================
Write-Host "=== [1] AUDIT: BEFORE HARDENING ===`n" -ForegroundColor White
Audit-FirewallPrivateProfile -logFile $beforeLog

# ===========================
# Step 2: Apply Hardening
# ===========================
Write-Host "=== [2] APPLYING HARDENING ===`n" -ForegroundColor White
Apply-Hardening

# ===========================
# Step 3: Audit (After)
# ===========================
Write-Host "=== [3] AUDIT: AFTER HARDENING ===`n" -ForegroundColor White
Audit-FirewallPrivateProfile -logFile $afterLog

# ===========================
# Summary
# ===========================
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Process Complete" -ForegroundColor Yellow
Write-Host " Logs saved as:" -ForegroundColor Cyan
Write-Host "  • $beforeLog" -ForegroundColor White
Write-Host "  • $afterLog"  -ForegroundColor White
Write-Host "============================================================`n" -ForegroundColor Cyan
