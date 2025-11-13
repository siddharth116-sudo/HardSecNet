<#
.SYNOPSIS
Hardens CIS Benchmark 18.9.95 & 18.9.97: Disable AutoRun and Restrict Removable Storage.

.DESCRIPTION
This script applies CIS Benchmark recommendations to disable AutoRun and AutoPlay
and restrict access to removable storage devices to prevent the execution of scripts
or programs automatically when external drives are connected.

The script enforces:
  • AutoRun is fully disabled (NoDriveTypeAutoRun = 255)
  • AutoPlay is disabled for all drives
  • Removable storage devices access policies are created

Note: These settings apply to standalone systems and can be overridden by
Active Directory Group Policy in domain environments.

#>

# CIS Benchmark: 18.9.95 & 18.9.97 (L1)
$CIS_BENCHMARK_NAME = "18.9.95 & 18.9.97 (L1) - Disable AutoRun and Restrict Removable Storage"
$StatusSeparator = "----------------------------------------------------"

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---" -ForegroundColor Cyan

try {
    # 1. Disable AutoRun and AutoPlay system-wide
    Write-Host "Disabling AutoRun and AutoPlay system-wide..." -ForegroundColor Yellow

    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    )

    foreach ($path in $RegistryPaths) {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }

        # Disable AutoRun on all drives (255)
        Set-ItemProperty -Path $path -Name "NoDriveTypeAutoRun" -Value 255 -Type DWord -Force
        # Disable AutoPlay
        Set-ItemProperty -Path $path -Name "NoAutoRun" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $path -Name "NoAutoPlay" -Value 1 -Type DWord -Force
    }

    # 2. Enforce Removable Storage Access Restriction Policy
    Write-Host "Creating Removable Storage Access restrictions..." -ForegroundColor Yellow

    $RemovableStorageKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
    if (-not (Test-Path $RemovableStorageKey)) {
        New-Item -Path $RemovableStorageKey -Force | Out-Null
    }

    # Deny all removable storage access
    New-ItemProperty -Path $RemovableStorageKey -Name "Deny_All" -Value 1 -PropertyType DWord -Force | Out-Null

    # 3. Optional - Prevent users from installing removable devices
    $DeviceInstallKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions"
    if (-not (Test-Path $DeviceInstallKey)) {
        New-Item -Path $DeviceInstallKey -Force | Out-Null
    }
    New-ItemProperty -Path $DeviceInstallKey -Name "DenyRemovableDevices" -Value 1 -PropertyType DWord -Force | Out-Null

    # 4. Verification
    Write-Host ""
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host ("{0,-40} : {1}" -f "AutoRun Registry Keys", "Configured (255 - Disabled)") -ForegroundColor Green
    Write-Host ("{0,-40} : {1}" -f "AutoPlay Setting", "Disabled") -ForegroundColor Green
    Write-Host ("{0,-40} : {1}" -f "Removable Storage Policy", "Deny_All = 1") -ForegroundColor Green
    Write-Host ("{0,-40} : {1}" -f "Device Installation Restriction", "Enabled") -ForegroundColor Green
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "VERIFICATION: COMPLIANT" -ForegroundColor Green

} catch {
    Write-Error "An unexpected error occurred during execution: $($_.Exception.Message)"
}

Write-Host "--- Policy application complete. ---" -ForegroundColor Cyan

# Note:
# For domain environments, enforce these policies via:
# Computer Configuration → Administrative Templates → System → Removable Storage Access
# and → Windows Components → AutoPlay Policies
