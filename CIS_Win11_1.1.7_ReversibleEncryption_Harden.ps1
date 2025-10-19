<#
.SYNOPSIS
CIS Windows 11 Benchmark 1.1.7 - Hardening Script
Ensures passwords are NOT stored using reversible encryption.

.DESCRIPTION
According to CIS Benchmark for Windows 11:
Policy: "Store passwords using reversible encryption for all users"
Recommended Setting: Disabled (0)

This script:
1. Checks the current registry value.
2. Creates or updates it to be compliant.
3. Outputs both JSON (for audit/compliance) and a human-readable summary.
#>

# -------------------------
# Configuration
# -------------------------
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$regName = "ClearTextPassword"  # Correct Windows registry key for reversible encryption
$expectedValue = 0
$outputFile = "$PSScriptRoot\CIS_Win11_1.1.7_ReversibleEncryption_Result.json"

# -------------------------
# Result Object
# -------------------------
$result = [PSCustomObject]@{
    Control = "1.1.7"
    Policy = "Store passwords using reversible encryption"
    RegistryPath = $regPath
    RegistryKey = $regName
    ExpectedValue = $expectedValue
    CurrentValue = $null
    Status = $null
    ActionTaken = $null
    TimeStamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

# -------------------------
# Hardening Logic
# -------------------------
try {
    if (Test-Path $regPath) {
        $currentValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName

        if ($null -eq $currentValue) {
            # Key missing — create it
            New-ItemProperty -Path $regPath -Name $regName -Value $expectedValue -PropertyType DWord -Force | Out-Null
            $result.CurrentValue = "Not Found"
            $result.Status = "Hardened"
            $result.ActionTaken = "Created and set to Disabled (0)"
            Write-Host "[+] Key created and hardened." -ForegroundColor Green
        }
        elseif ($currentValue -ne $expectedValue) {
            # Wrong value — correct it
            Set-ItemProperty -Path $regPath -Name $regName -Value $expectedValue -Force
            $result.CurrentValue = $currentValue
            $result.Status = "Hardened"
            $result.ActionTaken = "Updated from $currentValue to $expectedValue"
            Write-Host "[+] Policy updated to match CIS recommendation." -ForegroundColor Cyan
        }
        else {
            # Already compliant
            $result.CurrentValue = $currentValue
            $result.Status = "Compliant"
            $result.ActionTaken = "No change"
            Write-Host "[OK] Already compliant with CIS Benchmark 1.1.7." -ForegroundColor Green
        }
    }
    else {
        # Registry path missing — create it and apply setting
        New-Item -Path $regPath -Force | Out-Null
        New-ItemProperty -Path $regPath -Name $regName -Value $expectedValue -PropertyType DWord -Force | Out-Null
        $result.CurrentValue = "Path Not Found"
        $result.Status = "Hardened"
        $result.ActionTaken = "Registry path created and value set"
        Write-Host "[+] Registry path created and policy hardened." -ForegroundColor Yellow
    }
}
catch {
    $result.Status = "Error"
    $result.ActionTaken = $_.Exception.Message
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
}

# -------------------------
# Save JSON Output
# -------------------------
$result | ConvertTo-Json -Depth 4 | Out-File -FilePath $outputFile -Encoding utf8

# -------------------------
# Human-Readable Summary
# -------------------------
Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CIS Windows 11 - Password Policy Hardening"
Write-Host "Control       : $($result.Control)"
Write-Host "Policy        : $($result.Policy)"
Write-Host "Current Value : $($result.CurrentValue)"
Write-Host "Expected Value: $($result.ExpectedValue)"
Write-Host "Status        : $($result.Status)"
Write-Host "Action Taken  : $($result.ActionTaken)"
Write-Host "JSON Output   : $outputFile"
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
