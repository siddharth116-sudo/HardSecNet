<#
.SYNOPSIS
Applies the CIS Benchmark 1.1.5 setting to enable password complexity requirements.

.DESCRIPTION
This script configures the local security policy to require complex passwords (e.g., mixing
uppercase, lowercase, numbers, and symbols). It achieves this by creating a temporary
security policy configuration file and applying it via secedit.

Note: This setting applies only to local accounts. For domain-joined systems, this
is managed via a Domain Group Policy Object (GPO).
#>

# CIS Benchmark: 1.1.5 (L1) Ensure 'Password must meet complexity requirements' is set to 'Enabled' (Automated)
$CIS_BENCHMARK_NAME = "1.1.5 (L1) Password must meet complexity requirements"
$REQUIRED_VALUE = 1 # 1 = Enabled, 0 = Disabled
$TEMP_DIR = "$env:TEMP"
$INF_FILE = "$TEMP_DIR\password_complexity.inf"
$DB_FILE = "$TEMP_DIR\password_complexity.sdb"

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# 1. Create a temporary .inf file with the desired security setting
Write-Host "Creating temporary security configuration file..."

$Content = @"
[Unicode]
Unicode=yes
[System Access]
PasswordComplexity = $REQUIRED_VALUE
"@

Set-Content -Path $INF_FILE -Value $Content -Encoding Unicode

# 2. Apply the configuration using secedit
Write-Host "Applying password complexity policy via secedit..."

try {
    # Configure the system access area (local security policy)
    secedit /configure /db $DB_FILE /cfg $INF_FILE /areas USER_RIGHTS, SECURITYPOLICY /log $TEMP_DIR\secedit.log

    # Check the actual applied setting (Registry check for verification only)
    $RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
    $RegistryName = "PasswordComplexity"
    
    # Check if the registry key exists and matches the required value
    if (Test-Path $RegistryPath) {
        $CurrentValue = (Get-ItemProperty -Path $RegistryPath -Name $RegistryName -ErrorAction SilentlyContinue).$RegistryName
        
        if ($CurrentValue -eq $REQUIRED_VALUE) {
            Write-Host ""
            Write-Host "SUCCESS: Password complexity successfully set to Enabled."
            Write-Host "Verify new setting (Registry HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters:$RegistryName): $CurrentValue"
        } else {
            Write-Warning "Policy applied, but registry verification failed. Current value: $CurrentValue"
        }
    } else {
        Write-Warning "Cannot verify setting. Registry path not found: $RegistryPath"
    }

}
catch {
    Write-Error "An error occurred during execution: $($_.Exception.Message)"
}
finally {
    # 3. Clean up temporary files
    Write-Host "Cleaning up temporary files..."
    Remove-Item -Path $INF_FILE -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $DB_FILE -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$TEMP_DIR\secedit.log" -Force -ErrorAction SilentlyContinue
}

Write-Host "--- Policy application complete. ---"

# Note on Domain Systems: For domain accounts, this setting must be enforced via a Group Policy Object (GPO)
# linked to the domain. The setting can be found in:
# Computer Configuration\Policies\Windows Settings\Security Settings\Account Policies\Password Policy\Password must meet complexity requirements
