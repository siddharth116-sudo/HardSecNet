<#
.SYNOPSIS
Applies the CIS Benchmark 2.2.14 setting to ensure 'Create symbolic links' is set to 'Administrators' (and 'NT VIRTUAL MACHINE\Virtual Machines' if Hyper-V is installed).

.DESCRIPTION
This script configures the 'Create symbolic links' user right assignment to restrict symbolic link creation to Administrators only, 
with an exception for Hyper-V environments where NT VIRTUAL MACHINE\Virtual Machines also requires this privilege.

Symbolic links can expose security vulnerabilities in applications not designed to use them. This setting helps prevent 
symbolic link attacks that could be used to change file permissions, corrupt data, or perform Denial of Service attacks.

Note: This setting is effective immediately but may require a reboot for some applications to recognize the change.
#>

# CIS Benchmark: 2.2.14 (L1) Ensure 'Create symbolic links' is set to 'Administrators' (Automated)
$CIS_BENCHMARK_NAME = "2.2.14 (L1) Create symbolic links"
$PRIVILEGE_NAME = "SeCreateSymbolicLinkPrivilege"
$SETTING_NAME = "Create symbolic links"
$REQUIRED_SID_ADMINS = "S-1-5-32-544"  # BUILTIN\Administrators
$REQUIRED_SID_HYPERV = "S-1-5-83-0"    # NT VIRTUAL MACHINE\Virtual Machines
$StatusSeparator = "----------------------------------------------------"

Write-Host "--- Applying Hardening for CIS Benchmark: $CIS_BENCHMARK_NAME ---" -ForegroundColor Yellow

try {
    # 1. Check for Hyper-V feature presence
    Write-Host "Checking Hyper-V feature status..." -ForegroundColor Cyan
    $IsHyperVPresent = $false
    
    try {
        $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
        if ($hyperVFeature -and $hyperVFeature.State -eq "Enabled") { 
            $IsHyperVPresent = $true
        } else {
            # Alternative check via services
            $hyperVService = Get-Service -Name vmms -ErrorAction SilentlyContinue
            if ($hyperVService -and $hyperVService.Status -eq "Running") { 
                $IsHyperVPresent = $true
            }
        }
    }
    catch {
        Write-Warning "Hyper-V detection may be incomplete: $($_.Exception.Message)"
    }

    # 2. Determine required SIDs based on Hyper-V status
    $RequiredSids = @($REQUIRED_SID_ADMINS)
    if ($IsHyperVPresent) {
        $RequiredSids += $REQUIRED_SID_HYPERV
        Write-Host "Hyper-V detected. Including NT VIRTUAL MACHINE\Virtual Machines in privilege assignment." -ForegroundColor Yellow
    } else {
        Write-Host "Hyper-V not detected. Assigning privilege to Administrators only." -ForegroundColor Green
    }

    # 3. Export current security policy to temporary file
    Write-Host "Exporting current security policy..." -ForegroundColor Cyan
    $TempPath = Join-Path $env:TEMP "SecurityPolicy_$([System.Guid]::NewGuid().ToString().Substring(0,8)).cfg"
    $null = secedit /export /cfg $TempPath /areas USER_RIGHTS /quiet 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to export security policy. Exit code: $LASTEXITCODE. Ensure running as Administrator."
    }

    # 4. Read and modify the security policy
    $SecEditContent = Get-Content $TempPath -Encoding ASCII -ErrorAction Stop
    
    # Find the current privilege line
    $PrivilegeLineIndex = -1
    for ($i = 0; $i -lt $SecEditContent.Count; $i++) {
        if ($SecEditContent[$i] -match "^$PRIVILEGE_NAME\s*=") {
            $PrivilegeLineIndex = $i
            break
        }
    }

    # Build the new privilege assignment line
    $NewPrivilegeLine = "$PRIVILEGE_NAME = $($RequiredSids -join ',')"
    
    if ($PrivilegeLineIndex -ne -1) {
        # Replace existing line
        $SecEditContent[$PrivilegeLineIndex] = $NewPrivilegeLine
    } else {
        # Add new line at the end of [Privilege Rights] section or create section
        $PrivilegeRightsIndex = -1
        for ($i = 0; $i -lt $SecEditContent.Count; $i++) {
            if ($SecEditContent[$i] -match "^\[Privilege Rights\]") {
                $PrivilegeRightsIndex = $i
                break
            }
        }
        
        if ($PrivilegeRightsIndex -ne -1) {
            # Insert after [Privilege Rights] section header
            $SecEditContent = $SecEditContent[0..$PrivilegeRightsIndex] + @($NewPrivilegeLine) + $SecEditContent[($PrivilegeRightsIndex+1)..($SecEditContent.Count-1)]
        } else {
            # Create new [Privilege Rights] section
            $SecEditContent += ""
            $SecEditContent += "[Privilege Rights]"
            $SecEditContent += $NewPrivilegeLine
        }
    }

    # 5. Save modified policy and import it
    Write-Host "Applying new security policy..." -ForegroundColor Cyan
    $SecEditContent | Out-File $TempPath -Encoding ASCII -Force
    
    # Import the modified policy
    $ImportDB = Join-Path $env:TEMP "SecurityDatabase.sdb"
    $null = secedit /configure /db $ImportDB /cfg $TempPath /areas USER_RIGHTS /quiet 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to import security policy. Exit code: $LASTEXITCODE"
    }

    # 6. Verification
    Write-Host "Verifying applied settings..." -ForegroundColor Cyan
    
    # Re-export to verify
    $VerifyPath = Join-Path $env:TEMP "SecurityPolicy_Verify.cfg"
    $null = secedit /export /cfg $VerifyPath /areas USER_RIGHTS /quiet 2>&1
    
    $VerifyContent = Get-Content $VerifyPath -Encoding ASCII -ErrorAction Stop
    $VerifyLine = $VerifyContent | Select-String -Pattern "^$PRIVILEGE_NAME\s*=" | Select-Object -First 1
    
    $CurrentSids = @()
    if ($VerifyLine) {
        $SidString = $VerifyLine.ToString() -split '=' | Select-Object -Last 1
        $CurrentSids = @($SidString.Trim() -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
    }

    # 7. Check compliance
    $AllRequiredPresent = $true
    foreach ($RequiredSid in $RequiredSids) {
        if ($CurrentSids -notcontains $RequiredSid) {
            $AllRequiredPresent = $false
            break
        }
    }

    $Status = if ($AllRequiredPresent) { "COMPLIANT" } else { "NON-COMPLIANT" }
    $StatusColor = if ($Status -eq "COMPLIANT") { "Green" } else { "Red" }

    # 8. Display results
    Write-Host ""
    Write-Host "SUCCESS: Security policy applied successfully." -ForegroundColor Green
    
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host ("{0,-40} : {1}" -f "Required CIS Setting", "Administrators" + $(if($IsHyperVPresent) { " + Hyper-V" } else { "" })) -ForegroundColor Yellow
    Write-Host ("{0,-40} : {1}" -f "Hyper-V Feature Detected", ($IsHyperVPresent -as [string]).ToUpper()) -ForegroundColor Yellow
    
    # Display current assignments
    Write-Host -NoNewline ("{0,-40} : " -f "Current Assigned SIDs") -ForegroundColor Yellow
    if ($CurrentSids.Count -gt 0) {
        # Resolve SIDs to names for display
        function Resolve-SID {
            param([string]$Sid)
            try {
                $Account = (New-Object System.Security.Principal.SecurityIdentifier($Sid)).Translate([System.Security.Principal.NTAccount])
                return $Account.Value
            }
            catch {
                switch ($Sid) {
                    "S-1-5-32-544" { return "BUILTIN\Administrators" }
                    "S-1-5-83-0" { return "NT VIRTUAL MACHINE\Virtual Machines" }
                    default { return "Unknown SID ($Sid)" }
                }
            }
        }
        
        $AssignedNames = @($CurrentSids | ForEach-Object { Resolve-SID $_ })
        Write-Host $AssignedNames[0] -ForegroundColor White
        $AssignedNames[1..($AssignedNames.Count - 1)] | ForEach-Object {
            Write-Host ("{0,-42}{1}" -f "", $_) -ForegroundColor White
        }
    } else {
        Write-Host "None" -ForegroundColor Red
    }
    
    Write-Host ("{0,-40} : {1}" -f "VERIFICATION", $Status) -ForegroundColor $StatusColor

    # Cleanup temporary files
    Remove-Item $TempPath -Force -ErrorAction SilentlyContinue
    Remove-Item $VerifyPath -Force -ErrorAction SilentlyContinue
    Remove-Item $ImportDB -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Error "An unexpected error occurred during execution: $($_.Exception.Message)"
    
    # Cleanup on error
    $TempPath, $VerifyPath, $ImportDB | ForEach-Object {
        if ($_ -and (Test-Path $_)) {
            Remove-Item $_ -Force -ErrorAction SilentlyContinue
        }
    }
}
finally {
    Write-Host $StatusSeparator -ForegroundColor DarkYellow
    Write-Host "--- Policy application complete. ---"
    Write-Host "Note: Some applications may require a reboot to recognize the new privilege assignments." -ForegroundColor Yellow
}