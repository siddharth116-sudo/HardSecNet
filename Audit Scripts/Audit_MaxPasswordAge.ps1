# =====================================================================
# CIS Benchmark 1.1.2 Audit Script - Maximum Password Age
# =====================================================================
# This script checks if the maximum password age is set to 365 or fewer
# days, and not 0. Outputs result as a JSON file.
# =====================================================================

param(
    [string]$OutputFileName = "C:\Users\Public\Audit_MaxPasswordAge.json"
)

# --- Step 1: Fetch the current system value ---
$currentValue = (net accounts | Select-String "Maximum password age").ToString().Split(":")[1].Trim()

# Convert string like "42 days" → 42
$currentDays = [int]($currentValue -replace '[^\d]', '')

# --- Step 2: Define CIS benchmark details ---
$benchmark = @{
    "Benchmark_ID" = "1.1.2 (L1)"
    "Policy_Name" = "Ensure 'Maximum password age' is set to '365 or fewer days, but not 0'"
    "Current_Value" = "$currentDays days"
    "Recommended_Value" = "365 or fewer days, but not 0"
    "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# --- Step 3: Determine Compliance ---
if (($currentDays -le 365) -and ($currentDays -ne 0)) {
    $benchmark["Compliance_Status"] = "Compliant"
} else {
    $benchmark["Compliance_Status"] = "Non-Compliant"
}

# --- Step 4: Output to JSON file ---
$benchmark | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputFileName -Encoding UTF8

Write-Host "✅ Audit completed successfully."
Write-Host "📄 Output saved to: $OutputFileName"
