<#
.SYNOPSIS
Audits CIS Benchmark 2.2.14: Checks which groups/users have the "Create symbolic links" privilege.

.DESCRIPTION
This script retrieves the Security Identifiers (SIDs) assigned to the SeCreateSymbolicLinkPrivilege
using the local security policy database (secedit) and determines compliance based on the
presence of the required default security groups (Administrators) and optional groups
(NT VIRTUAL MACHINE\Virtual Machines) if the Hyper-V feature is detected.

.NOTES
Run this script with elevated privileges (Run as Administrator).
The JSON report will be saved to a 'report' folder in the script's directory.
#>

# --- Configuration and CIS Benchmark Details ---
$CIS_ID = "2.2.14 (L1)"
$CIS_NAME = "Ensure 'Create symbolic links' is set to 'Administrators'"
$PRIVILEGE_NAME = "SeCreateSymbolicLinkPrivilege" # Internal name used by secedit
$SETTING_NAME = "Create symbolic links (User Rights Assignment)"
$STATUS_SEPARATOR = "----------------------------------------------------"
$REPORT_FOLDER = "report"
$REPORT_FILENAME = "Audit_Create_Symbolic_Links.json"

# Required SIDs:
# S-1-5-32-544 (Administrators) - REQUIRED
# S-1-5-83-0 (NT VIRTUAL MACHINE\Virtual Machines) - REQUIRED IF HYPER-V IS PRESENT
$REQUIRED_SIDS = @(
    "S-1-5-32-544"
)
$HYPERV_SID = "S-1-5-83-0"

# Define explicitly non-compliant SIDs that should trigger warnings
$NON_COMPLIANT_SIDS = @(
    "S-1-1-0",      # Everyone
    "S-1-5-32-545", # Users
    "S-1-5-32-551", # Backup Operators
    "S-1-5-11"      # Authenticated Users
)

$ComplianceStatus = "Error"
$ComplianceText = "ERROR: Audit failed due to an unexpected issue."
$WarningMessages = @()

# --- Function to Resolve SID to Name ---
function Resolve-SID {
    param([string]$Sid)
    try {
        # Use .NET method to resolve SID to display name
        $Account = (New-Object System.Security.Principal.SecurityIdentifier($Sid)).Translate([System.Security.Principal.NTAccount])
        return $Account.Value
    }
    catch {
        # Fallback for well-known or non-localizable SIDs
        switch ($Sid) {
            "S-1-5-32-544" { return "BUILTIN\Administrators" }
            "S-1-5-83-0" { return "NT VIRTUAL MACHINE\Virtual Machines (Hyper-V)" }
            "S-1-1-0" { return "Everyone" }
            "S-1-5-32-545" { return "BUILTIN\Users" }
            "S-1-5-32-551" { return "BUILTIN\Backup Operators" }
            "S-1-5-11" { return "Authenticated Users" }
            default { return "Unknown SID ($Sid)" }
        }
    }
}

# --- Enhanced Hyper-V Detection Function ---
function Test-HyperVInstalled {
    try {
        # Method 1: Check Windows features (works on Windows 10/11 and Server)
        $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
        if ($hyperVFeature -and $hyperVFeature.State -eq "Enabled") { 
            return $true 
        }
        
        # Method 2: Check Hyper-V services as backup
        $hyperVService = Get-Service -Name vmms -ErrorAction SilentlyContinue
        if ($hyperVService -and $hyperVService.Status -eq "Running") { 
            return $true 
        }
        
        # Method 3: Check for Hyper-V PowerShell module
        $hyperVModule = Get-Module -ListAvailable -Name Hyper-V -ErrorAction SilentlyContinue
        if ($hyperVModule) {
            return $true
        }
        
        return $false
    }
    catch {
        Write-Warning "Hyper-V detection failed: $($_.Exception.Message)"
        return $false
    }
}

# --- Function to Display Results ---
function Display-Audit-Result {
    param(
        [array]$AssignedSids,
        [array]$MissingSids,
        [array]$ExtraNonCompliantSids,
        [array]$WarningMessages,
        [bool]$IsHyperVPresent,
        [string]$Status,
        [string]$ComplianceText
    )
    
    $StatusColor = switch ($Status) {
        "Compliant" { "Green" }
        "Non-Compliant" { "Red" }
        default { "Yellow" }
    }
    
    # Format SIDs for display
    $AssignedNames = @($AssignedSids | ForEach-Object { Resolve-SID $_ })
    $MissingNames = @($MissingSids | ForEach-Object { Resolve-SID $_ })
    $ExtraNonCompliantNames = @($ExtraNonCompliantSids | ForEach-Object { Resolve-SID $_ })

    Write-Host "`n#`n# CIS Benchmark Audit Results`n#`n" -ForegroundColor DarkCyan
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    Write-Host "CIS Benchmark ID: $($CIS_ID)" -ForegroundColor White
    Write-Host "CIS Benchmark Name: $($CIS_NAME)" -ForegroundColor White
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    
    Write-Host ("{0,-40} : {1}" -f "Policy Name", $SETTING_NAME) -ForegroundColor Cyan
    Write-Host ("{0,-40} : {1}" -f "Hyper-V Feature Detected", ($IsHyperVPresent -as [string]).ToUpper()) -ForegroundColor Yellow
    
    Write-Host ("{0,-40} : {1}" -f "Required SIDs (on compliant system)", "Administrators (and Hyper-V if applicable)") -ForegroundColor Yellow

    Write-Host -NoNewline ("{0,-40} : " -f "Current Assigned SIDs") -ForegroundColor Yellow
    if ($AssignedNames.Count -gt 0) {
        Write-Host $AssignedNames[0] -ForegroundColor White
        $AssignedNames[1..($AssignedNames.Count - 1)] | ForEach-Object {
            Write-Host ("{0,-42}{1}" -f "", $_) -ForegroundColor White
        }
    } else {
        Write-Host "None" -ForegroundColor Red
    }

    # Display warnings if any
    if ($WarningMessages.Count -gt 0) {
        Write-Host "`nWarnings:" -ForegroundColor Yellow
        foreach ($warning in $WarningMessages) {
            Write-Host ("  - {0}" -f $warning) -ForegroundColor Yellow
        }
    }

    # Display non-compliant SIDs if any
    if ($ExtraNonCompliantNames.Count -gt 0) {
        Write-Host "`nNon-Compliant SIDs Found:" -ForegroundColor Red
        foreach ($nonCompliant in $ExtraNonCompliantNames) {
            Write-Host ("  - {0}" -f $nonCompliant) -ForegroundColor Red
        }
    }
    
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    Write-Host ("{0,-40} : {1}" -f "Compliance Status", $ComplianceText) -ForegroundColor $StatusColor
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
}

# --- Main Audit Logic ---
try {
    # 1. Setup report folder and file path
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $ReportPath = Join-Path $ScriptDir $REPORT_FOLDER
    $FullReportFilePath = Join-Path $ReportPath $REPORT_FILENAME
    
    if (-not (Test-Path $ReportPath)) {
        New-Item -Path $ReportPath -ItemType Directory | Out-Null
    }

    # 2. Check for Hyper-V feature presence (needed to adjust compliance requirements)
    Write-Host "Checking Hyper-V feature status..." -ForegroundColor Gray
    $IsHyperVPresent = Test-HyperVInstalled

    # Adjust required SIDs if Hyper-V is installed
    if ($IsHyperVPresent) {
        Write-Host "Hyper-V detected. Adding NT VIRTUAL MACHINE\Virtual Machines to required SIDs." -ForegroundColor Green
        if ($REQUIRED_SIDS -notcontains $HYPERV_SID) {
            $REQUIRED_SIDS += $HYPERV_SID
        }
    } else {
        Write-Host "Hyper-V not detected." -ForegroundColor Gray
    }

    # 3. Export security policy and retrieve setting value
    Write-Host "Exporting security policy..." -ForegroundColor Gray
    $TempPath = Join-Path $env:TEMP "SecurityPolicy_$([System.Guid]::NewGuid().ToString().Substring(0,8)).cfg"
    
    try {
        $seceditResult = secedit /export /cfg $TempPath /areas USER_RIGHTS /quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "secedit export failed with exit code: $LASTEXITCODE. Ensure running as Administrator. Error: $seceditResult"
        }
    }
    catch [System.ComponentModel.Win32Exception] {
        throw "secedit command not found or access denied. Ensure running as Administrator and that secedit.exe is available."
    }

    if (-not (Test-Path $TempPath)) {
        throw "Security policy export file was not created. secedit may have failed silently."
    }

    $SecEditContent = Get-Content $TempPath -Encoding ASCII -ErrorAction Stop
    $PrivilegeLine = $SecEditContent | Select-String -Pattern "$PRIVILEGE_NAME\s*=" | Select-Object -First 1

    if (-not $PrivilegeLine) {
        Write-Host "Policy not explicitly defined. Using default value (Administrators only)." -ForegroundColor Yellow
        # Policy is not defined in local security database. Default is Administrators (S-1-5-32-544).
        $CurrentSids = @("S-1-5-32-544")
        $WarningMessages += "Policy setting not explicitly configured in local security policy."
    } else {
        # Extract comma-separated list of SIDs and normalize (trim whitespace)
        $SidString = $PrivilegeLine.ToString() -split '=' | Select-Object -Last 1
        $CurrentSids = @($SidString.Trim() -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
        Write-Host "Found $($CurrentSids.Count) SID(s) assigned to privilege." -ForegroundColor Gray
    }
    
    # Clean up temporary file
    Remove-Item $TempPath -Force -ErrorAction SilentlyContinue

    # 4. Normalize SIDs for comparison
    $CurrentSidsNormalized = @($CurrentSids | ForEach-Object { $_.Trim() })
    $RequiredSidsNormalized = @($REQUIRED_SIDS | ForEach-Object { $_.Trim() })

    # 5. Compare Current SIDs against Required SIDs
    $MissingSids = @()
    foreach ($RequiredSid in $RequiredSidsNormalized) {
        if ($CurrentSidsNormalized -notcontains $RequiredSid) {
            $MissingSids += $RequiredSid
        }
    }

    # 6. Check for non-compliant SIDs
    $ExtraNonCompliantSids = @($CurrentSidsNormalized | Where-Object { 
        $NON_COMPLIANT_SIDS -contains $_ -and $RequiredSidsNormalized -notcontains $_
    })

    if ($ExtraNonCompliantSids.Count -gt 0) {
        $WarningMessages += "Non-compliant SIDs found in assignment: $($ExtraNonCompliantSids -join ', ')"
    }
    
    # 7. Determine compliance status
    $CurrentSidCount = $CurrentSidsNormalized.Count
    $RequiredSidCount = $RequiredSidsNormalized.Count
    
    if ($MissingSids.Count -eq 0 -and $CurrentSidCount -eq $RequiredSidCount) {
        $ComplianceStatus = "Compliant"
        $ComplianceText = "COMPLIANT (All required SIDs are assigned, and no extra SIDs were explicitly configured.)"
    } elseif ($MissingSids.Count -eq 0 -and $CurrentSidCount -gt $RequiredSidCount -and $ExtraNonCompliantSids.Count -eq 0) {
        $ComplianceStatus = "Compliant"
        $ComplianceText = "COMPLIANT (All required SIDs are assigned. Note: Extra non-required SIDs found but they are not explicitly non-compliant.)"
    } elseif ($MissingSids.Count -eq 0 -and $ExtraNonCompliantSids.Count -gt 0) {
        $ComplianceStatus = "Compliant"
        $ComplianceText = "COMPLIANT (All required SIDs are assigned. WARNING: Extra non-compliant SIDs found.)"
    } else {
        $ComplianceStatus = "Non-Compliant"
        $ComplianceText = "NON-COMPLIANT (Missing Required SIDs: $($MissingSids.Count))"
    }

    # 8. Display Results
    Display-Audit-Result -AssignedSids $CurrentSidsNormalized -MissingSids $MissingSids -ExtraNonCompliantSids $ExtraNonCompliantSids -WarningMessages $WarningMessages -IsHyperVPresent $IsHyperVPresent -Status $ComplianceStatus -ComplianceText $ComplianceText

    # 9. Create and save JSON output
    $auditResult = [PSCustomObject]@{
        Compliance_Status = $ComplianceStatus
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = $CurrentSidsNormalized -join ','
        Assigned_SIDs = $CurrentSidsNormalized
        Assigned_SID_Names = @($CurrentSidsNormalized | ForEach-Object { Resolve-SID $_ })
        Missing_Required_SIDs = $MissingSids
        Non_Compliant_SIDs = $ExtraNonCompliantSids
        HyperV_Detected = $IsHyperVPresent
        Warnings = $WarningMessages
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "S-1-5-32-544 (Administrators)" + $(if($IsHyperVPresent) { " + S-1-5-83-0 (Hyper-V)" } else { "" })
    }
    
    $auditResult | ConvertTo-Json -Depth 4 | Out-File -FilePath $FullReportFilePath -Encoding UTF8
    Write-Host ""
    Write-Host "JSON report saved to: $FullReportFilePath" -ForegroundColor Cyan
    
} catch {
    $ReportPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) $REPORT_FOLDER
    $ErrorFile = Join-Path $ReportPath "Audit_Symbolic_Links_Error.json"
    $errorMessage = "An unexpected error occurred during execution: $($_.Exception.Message)"
    Write-Error $errorMessage -ForegroundColor Red
    
    # Handle error case for JSON output
    $auditResult = [PSCustomObject]@{
        Compliance_Status = "Error"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Current_Value = "Error: $($_.Exception.Message)"
        Benchmark_ID = $CIS_ID
        Policy_Name = $CIS_NAME
        Recommended_Value = "S-1-5-32-544 (Administrators) + S-1-5-83-0 (Hyper-V, if applicable)"
    }
    $auditResult | ConvertTo-Json -Depth 4 | Out-File -FilePath $ErrorFile -Encoding UTF8
    Write-Host "JSON report saved with error details to: $ErrorFile" -ForegroundColor Red
}
finally {
    Write-Host $STATUS_SEPARATOR -ForegroundColor DarkYellow
    Write-Host "--- Audit complete. ---"
}