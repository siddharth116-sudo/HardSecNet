<#
.SYNOPSIS
Applies the CIS Benchmark 1.1.6 setting to enable relaxation of minimum password length limits.

.DESCRIPTION
This script sets a registry value to enable support for minimum password lengths greater
than the legacy Windows limit of 14 characters (up to 127 characters). This change
must be applied before setting a higher minimum password length (see CIS 1.1.4).

Note: This setting applies to local accounts and systems not managed by a domain GPO.
#>

# CIS Benchmark: 1.1.6 (L1) Ensure 'Relax minimum password length limits' is set to 'Enabled' (Automated)
$CIS_BENCHMARK_NAME = "1.1.6 (L1) Relax minimum password length limits"
$REQUIRED_VALUE = 1 # 1 = Enabled (i.e., relax the limit)
$REGISTRY_PATH = "HKLM:\System\CurrentControlSet\Control\SAM"
$REGISTRY_NAME = "RelaxMinimumPasswordLengthLimits"

Write-Host "--- Applying CIS Benchmark Policy: $CIS_BENCHMARK_NAME ---"

# Ensure the registry path exists
if (-not (Test-Path $REGISTRY_PATH)) {
    Write-Host "Creating registry path: $REGISTRY_PATH"
    New-Item -Path $REGISTRY_PATH -Force | Out-Null
}

# Set the registry value to enable the feature
Write-Host "Setting registry value '$REGISTRY_NAME' to $REQUIRED_VALUE (Enabled)..."

try {
    Set-ItemProperty -Path $REGISTRY_PATH -Name $REGISTRY_NAME -Value $REQUIRED_VALUE -Type DWord -Force -ErrorAction Stop

    # Verification
    $CurrentValue = (Get-ItemProperty -Path $REGISTRY_PATH -Name $REGISTRY_NAME).$REGISTRY_NAME

    if ($CurrentValue -eq $REQUIRED_VALUE) {
        Write-Host ""
        Write-Host "SUCCESS: Registry setting '$REGISTRY_NAME' successfully set to $REQUIRED_VALUE."
        Write-Host "This ensures Windows supports setting minimum password lengths above 14 characters."
    } else {
        Write-Error "Policy applied, but registry verification failed. Current value: $CurrentValue"
    }
}
catch {
    Write-Error "An error occurred during execution: $($_.Exception.Message)"
}

Write-Host "--- Policy application complete. ---"
