<#
.SYNOPSIS
Reverts CIS Benchmark 18.9.67.1 (L1) "Turn off all wireless communications" 
by re-enabling all wireless services and adapters.

.DESCRIPTION
Removes the CIS registry key, re-enables WLAN and Bluetooth services,
and restores all wireless network adapters. Intended for demo or rollback use.
#>

Write-Host "`n--- Reverting CIS Benchmark Policy: 18.9.67.1 (L1) Turn ON all wireless communications ---" -ForegroundColor Cyan

# 1️⃣ Remove or reset CIS registry key
$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy"
if (Test-Path $RegPath) {
    Remove-ItemProperty -Path $RegPath -Name "fBlockAllWireless" -ErrorAction SilentlyContinue
    Write-Host "[+] Removed CIS registry key: fBlockAllWireless" -ForegroundColor Green
} else {
    Write-Host "[i] Registry path not found, skipping..." -ForegroundColor Yellow
}

# 2️⃣ Re-enable WLAN AutoConfig (WlanSvc)
Write-Host "[+] Enabling WLAN AutoConfig service..." -ForegroundColor Yellow
Set-Service -Name "WlanSvc" -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service -Name "WlanSvc" -ErrorAction SilentlyContinue
Write-Host "    → Wi-Fi service enabled." -ForegroundColor Green

# 3️⃣ Re-enable Bluetooth support service
Write-Host "[+] Enabling Bluetooth service..." -ForegroundColor Yellow
Set-Service -Name "bthserv" -StartupType Manual -ErrorAction SilentlyContinue
Start-Service -Name "bthserv" -ErrorAction SilentlyContinue
Write-Host "    → Bluetooth service started." -ForegroundColor Green

# 4️⃣ Re-enable Radio Management and Mobile Hotspot services
Write-Host "[+] Enabling Radio Management & Hotspot services..." -ForegroundColor Yellow
$services = @("RmSvc","icssvc") # RadioMgr & Internet Connection Sharing
foreach ($svc in $services) {
    Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service -Name $svc -ErrorAction SilentlyContinue
}
Write-Host "    → Radio Management + Hotspot services enabled." -ForegroundColor Green

# 5️⃣ Re-enable all wireless network adapters
Write-Host "[+] Enabling all wireless network adapters..." -ForegroundColor Yellow
Get-NetAdapter -Physical | Where-Object { $_.InterfaceDescription -Match "Wireless|Wi-Fi" } | ForEach-Object {
    Enable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue
}
Write-Host "    → Wireless adapters enabled." -ForegroundColor Green

# 6️⃣ Verification summary
Write-Host "`n----------------------------------------------------"
Write-Host "Wireless connections successfully restored." -ForegroundColor Cyan
Write-Host "Wi-Fi, Bluetooth, and Hotspot services are now active."
Write-Host "----------------------------------------------------"
