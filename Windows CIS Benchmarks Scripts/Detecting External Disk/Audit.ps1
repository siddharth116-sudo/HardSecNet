<#
.SYNOPSIS
Audits CIS Benchmark 18.9.95 & 18.9.97: Removable Storage Access and AutoRun Settings.

.DESCRIPTION
This script checks whether external removable drives are currently connected
and audits critical AutoRun and AutoPlay settings to ensure compliance with
CIS Windows 11 Benchmark Level 1 recommendations.

It verifies that AutoRun is disabled system-wide and that no unauthorized
removable drives are active that could trigger automatic script execution.
The script does not modify system configurations.

.NOTES
Run this script with elevated privileges (Run as Administrator).
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "18.9.95 & 18.9.97 (L1)"
$CIS_NAME = "Ensure AutoRun is disabled and Removable Storage Access is restricted"
$STATUS_SEPARATOR = "----------------------------------------------------"

# --- Reporting Configuration ---
$ReportFolder = "report"
$ReportFileName = "Audit_USB_Hardening_$($CIS_ID.Replace(' ', '_')).json"

# --- Function to Format and Display Results ---
function Display-Audit-Result {
    param(
        [string]$AutoRunStatus,
        [string]$StoragePolicyStatus,
        [int]$ExternalDrivesCount,
        [string]$OverallStatus
    )

    $Color = if ($OverallStatus -eq "COMPLIANT") { "Green" } else { "Red" }

    Write-Host "`n#`n# CIS Benchmark Audit Results" -ForegroundColor DarkCyan
    Write-Host "# Policy ID: $($CIS_ID)" -ForegroundColor DarkCyan
    Write-Host "# Policy Name: $($CIS_NAME)" -ForegroundColor DarkCyan
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow

    Write-Host ("{0,-35} : {1}" -f "AutoRun Policy Status", $AutoRunStatus) -ForegroundColor Yellow
    Write-Host ("{0,-35} : {1}" -f "Removable Storage Policy", $StoragePolicyStatus) -ForegroundColor Yellow
    Write-Host ("{0,-35} : {1}" -f "External Drives Detected", $ExternalDrivesCount) -ForegroundColor Yellow

    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    Write-Host ("{0,-35} : {1}" -f "Overall Compliance", $OverallStatus) -ForegroundColor $Color
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
}

# --- Main Audit Logic ---
try {
    # Create report directory
    $CurrentScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $ReportPath = Join-Path $CurrentScriptDir $ReportFolder
    if (-not (Test-Path $ReportPath)) {
        New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
    }
    $FullReportFilePath = Join-Path $ReportPath $ReportFileName

    Write-Host "Auditing external drives and AutoRun protection..." -ForegroundColor Cyan

    # 1. Detect external removable drives
    $Drives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
    $ExternalDrivesCount = ($Drives | Measure-Object).Count

    # 2. Audit AutoRun registry keys
    $AutoRunPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    )

    $AutoRunCompliant = $true
    foreach ($path in $AutoRunPaths) {
        if (Test-Path $path) {
            $val = (Get-ItemProperty -Path $path -Name "NoDriveTypeAutoRun" -ErrorAction SilentlyContinue).NoDriveTypeAutoRun
            if (-not $val -or $val -ne 255) { $AutoRunCompliant = $false }
        } else {
            $AutoRunCompliant = $false
        }
    }

    $AutoRunStatus = if ($AutoRunCompliant) { "AutoRun fully disabled (Compliant)" } else { "AutoRun partially enabled or missing (Non-Compliant)" }

    # 3. Audit Removable Storage Access policy existence
    $PolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
    if (Test-Path $PolicyPath) {
        $StoragePolicyStatus = "Policy key exists (Compliant)"
        $StoragePolicyCompliant = $true
    } else {
        $StoragePolicyStatus = "Policy key missing (Non-Compliant)"
        $StoragePolicyCompliant = $false
    }

    # 4. Determine overall compliance
    if ($AutoRunCompliant -and $StoragePolicyCompliant -and ($ExternalDrivesCount -eq 0)) {
        $OverallStatus = "COMPLIANT"
    } else {
        $OverallStatus = "NON-COMPLIANT"
    }

    # 5. Display results
    Display-Audit-Result -AutoRunStatus $AutoRunStatus `
                         -StoragePolicyStatus $StoragePolicyStatus `
                         -ExternalDrivesCount $ExternalDrivesCount `
                         -OverallStatus $OverallStatus

    # 6. Generate JSON report
    $JsonResult = [PSCustomObject]@{
        Benchmark_ID        = $CIS_ID
        Policy_Name         = $CIS_NAME
        Timestamp           = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        External_Drives     = $ExternalDrivesCount
        AutoRun_Status      = $AutoRunStatus
        StoragePolicyStatus = $StoragePolicyStatus
        Compliance_Status   = $OverallStatus
    }

    $JsonResult | ConvertTo-Json -Depth 3 | Out-File -FilePath $FullReportFilePath -Encoding UTF8

    Write-Host "`nJSON audit report successfully saved to: $FullReportFilePath" -ForegroundColor Cyan

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"

    $ErrorJson = [PSCustomObject]@{
        Benchmark_ID      = $CIS_ID
        Policy_Name       = $CIS_NAME
        Compliance_Status = "Error"
        Error_Message     = $_.Exception.Message
        Timestamp         = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    try {
        $ErrorJson | ConvertTo-Json -Depth 3 | Out-File -FilePath $FullReportFilePath -Encoding UTF8
        Write-Host "Error report saved to: $FullReportFilePath" -ForegroundColor Red
    } catch {}
}
finally {
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    Write-Host "--- Audit complete. ---"
}
