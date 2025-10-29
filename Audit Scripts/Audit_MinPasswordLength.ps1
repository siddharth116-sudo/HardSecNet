# =====================================================================
# CIS Benchmark 1.1.4 Audit Script - Minimum Password Length
# =====================================================================
# This script checks if the minimum password length is set to 14 or more
# and outputs the result as a JSON file.
# =====================================================================

param(
    [string]$OutputFileName = "C:\Users\Public\Audit_MinPasswordLength.json"
)

# --- Step 1: Fetch the current system value ---
$currentValue = (net accounts | Select-String "Minimum password length").ToString().Split(":")[1].Trim()

# --- Step 2: Define CIS benchmark details ---
$benchmark = @{
    "Benchmark_ID" = "1.1.4 (L1)"
    "Policy_Name" = "Ensure 'Minimum password length' is set to '14 or more character(s)'"
    "Current_Value" = $currentValue
    "Recommended_Value" = "14 or more characters"
    "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# --- Step 3: Determine Compliance ---
if ([int]$currentValue -ge 14) {
    $benchmark["Compliance_Status"] = "Compliant"
} else {
    $benchmark["Compliance_Status"] = "Non-Compliant"
}

# --- Step 4: Output to JSON file ---
$benchmark | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputFileName -Encoding UTF8

Write-Host "✅ Audit completed successfully."
Write-Host "📄 Output saved to: $OutputFileName"
