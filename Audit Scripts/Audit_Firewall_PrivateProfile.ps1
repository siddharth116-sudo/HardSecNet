# =====================================================================
# CIS Benchmark 9.2.1 Audit Script - Windows Firewall: Private Profile
# =====================================================================
# Checks if Windows Firewall for the Private network profile is enabled.
# Outputs the result as a JSON file.
# =====================================================================

param(
    [string]$OutputFileName = "C:\Users\Public\Audit_Firewall_PrivateProfile.json"
)

# --- Step 1: Get current firewall state for Private profile ---
try {
    $firewallState = (Get-NetFirewallProfile -Profile Private).Enabled
}
catch {
    Write-Error "❌ Error retrieving firewall status: $($_.Exception.Message)"
    exit
}

# --- Step 2: Define CIS benchmark details ---
$benchmark = @{
    "Benchmark_ID"       = "9.2.1 (L1)"
    "Policy_Name"        = "Ensure 'Windows Firewall: Private: Firewall state' is set to 'On (recommended)'"
    "Current_Value"      = if ($firewallState -eq 1) { "On" } else { "Off" }
    "Recommended_Value"  = "On (recommended)"
    "Timestamp"          = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# --- Step 3: Determine Compliance ---
if ($firewallState -eq 1) {
    $benchmark["Compliance_Status"] = "Compliant"
} else {
    $benchmark["Compliance_Status"] = "Non-Compliant"
}

# --- Step 4: Output to JSON file ---
$benchmark | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputFileName -Encoding UTF8

Write-Host "✅ Audit completed successfully."
Write-Host "📄 Output saved to: $OutputFileName"
