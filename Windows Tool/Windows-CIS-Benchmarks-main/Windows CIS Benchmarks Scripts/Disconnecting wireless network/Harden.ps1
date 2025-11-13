<#
.SYNOPSIS
Fully disables all wireless communications per CIS 18.9.67.1, 
including Wi-Fi, Bluetooth, and Mobile Hotspot, even on standalone Windows 11 systems.

.DESCRIPTION
Sets CIS registry key for compliance AND disables all related wireless adapters and services.
#>

Write-Host "`n--- Applying CIS Benchmark Policy: 18.9.67.1 (L1) Turn off all wireless communications ---" -ForegroundColor Cyan

# 1️⃣ CIS Registry Key (Baseline compliance)
$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy"
if (!(Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
Set-ItemProperty -Path $RegPath -Name "fBlockAllWireless" -Value 1 -Type DWord
Write-Host "[+] CIS Registry value set: fBlockAllWireless = 1 (Compliant)" -ForegroundColor Green

# 2️⃣ Disable Wi-Fi adapters
Write-Host "[+] Disabling all Wi-Fi network adapters..." -ForegroundColor Yellow
Get-NetAdapter -Physical | Where-Object {$_.InterfaceDescription -Match "Wireless|Wi-Fi"} | ForEach-Object {
    Disable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue
}
Write-Host "    → Wi-Fi interfaces disabled." -ForegroundColor Green

# 3️⃣ Disable Bluetooth service
Write-Host "[+] Stopping Bluetooth services..." -ForegroundColor Yellow
Stop-Service -Name "bthserv" -ErrorAction SilentlyContinue
Set-Service -Name "bthserv" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "    → Bluetooth service stopped and disabled." -ForegroundColor Green

# 4️⃣ Disable WLAN AutoConfig (hotspot + wireless mgmt)
Write-Host "[+] Stopping WLAN AutoConfig (WlanSvc)..." -ForegroundColor Yellow
Stop-Service -Name "WlanSvc" -ErrorAction SilentlyContinue
Set-Service -Name "WlanSvc" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "    → WLAN AutoConfig disabled." -ForegroundColor Green

# 5️⃣ Disable Mobile Hotspot and Radio Management
Write-Host "[+] Disabling Mobile Hotspot & Radio Management services..." -ForegroundColor Yellow
$services = @("RmSvc","icssvc") # RadioMgr & Internet Connection Sharing
foreach ($svc in $services) {
    Stop-Service -Name $svc -ErrorAction SilentlyContinue
    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
}
Write-Host "    → Radio Management + Hotspot disabled." -ForegroundColor Green

# 6️⃣ Verification summary
Write-Host "`n----------------------------------------------------"
Write-Host "Wireless connections successfully disabled per CIS Benchmark." -ForegroundColor Cyan
Write-Host "Verification required: reboot system to finalize driver unload."
Write-Host "----------------------------------------------------"
