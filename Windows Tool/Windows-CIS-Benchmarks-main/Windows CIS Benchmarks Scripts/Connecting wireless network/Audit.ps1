<#
.SYNOPSIS
Audits CIS Benchmark 18.9.67.1: Ensure "Turn off all wireless communications" is set to "Enabled".

.DESCRIPTION
This script audits the Windows registry policy that controls whether all wireless communications
(Wi-Fi, Bluetooth, Cellular, Infrared) are disabled system-wide.

The policy is located at:
Computer Configuration → Administrative Templates → Windows Components → Windows Mobility Center
Setting Name: Turn off all wireless communications
Registry Key: HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy
Value Name: fBlockAllWireless
Recommended CIS Value: 1 (Enabled)

If this value is not present or set to 0, the system is non-compliant.

#>

# CIS Benchmark: 18.9.67.1 (L1) Ensure "Turn off all wireless communications" is set to "Enabled"
$CIS_BENCHMARK_NAME = "18.9.67.1 (L1) Turn off all wireless communications"
$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy"
$ValueName = "fBlockAllWireless"
$StatusSeparator = "----------------------------------------------------"

Write-Host "--- Auditing CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# 1. Check if the registry key exists
if (Test-Path $RegistryPath) {
    try {
        $CurrentValue = (Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction Stop).$ValueName
    } catch {
        $CurrentValue = "Missing"
    }
} else {
    $CurrentValue = "Missing"
}

# 2. Evaluate compliance
if ($CurrentValue -eq 1) {
    $ComplianceStatus = "COMPLIANT"
    $WirelessStatus = "All wireless communications disabled (Compliant)"
} elseif ($CurrentValue -eq 0) {
    $ComplianceStatus = "NON-COMPLIANT"
    $WirelessStatus = "Wireless communications allowed (Non-Compliant)"
} else {
    $ComplianceStatus = "NON-COMPLIANT"
    $WirelessStatus = "Policy key missing or undefined (Non-Compliant)"
}

# 3. Print results
Write-Host ""
Write-Host "# CIS Benchmark Audit Results"
Write-Host "# Policy ID: 18.9.67.1 (L1)"
Write-Host "# Policy Name: Turn off all wireless communications"
Write-Host $StatusSeparator
Write-Host ("{0,-35} : {1}" -f "Policy Registry Path", $RegistryPath)
Write-Host ("{0,-35} : {1}" -f "Policy Value Name", $ValueName)
Write-Host ("{0,-35} : {1}" -f "Current Registry Value", $CurrentValue)
Write-Host ("{0,-35} : {1}" -f "Wireless Status", $WirelessStatus)
Write-Host $StatusSeparator
Write-Host ("{0,-35} : {1}" -f "Overall Compliance", $ComplianceStatus)
Write-Host $StatusSeparator

# 4. Generate JSON report
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Report = [PSCustomObject]@{
    Benchmark_ID      = "18.9.67.1 (L1)"
    Policy_Name       = "Turn off all wireless communications"
    Timestamp         = $Timestamp
    Registry_Path     = $RegistryPath
    Registry_Value    = $CurrentValue
    Wireless_Status   = $WirelessStatus
    Compliance_Status = $ComplianceStatus
}

$OutputDir = ".\Reports"
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
$OutputPath = Join-Path $OutputDir ("Audit_Wireless_Hardening_18.9.67.1_(L1).json")
$Report | ConvertTo-Json | Out-File -Encoding UTF8 $OutputPath

Write-Host ""
Write-Host "JSON audit report successfully saved to: $OutputPath" -ForegroundColor Cyan
Write-Host "--- Audit complete. ---"
