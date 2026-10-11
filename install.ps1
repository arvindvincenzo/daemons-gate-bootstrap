# ==============================================================================
# DAEMONS GATE â€” OFFICIAL WINDOWS INSTALLER & BOOTSTRAPPER
#
# Canonical Product Website: https://arvindvincenzo.com/daemonsgate
# Official Download Mirror:  https://arvindvincenzo.com/downloads/
#
# Quick Install:
#   irm https://arvindvincenzo.com/install.ps1 | iex
#
# Manual / Advanced Options:
#   .\install.ps1 [-InstallDir <path>] [-SkipPathRegistration]
#   .\install.ps1 -UseLocalStaging -LocalSource <path\to\dg.exe>
# ==============================================================================
[CmdletBinding()]
param(
    [switch]$UseLocalStaging,
    [string]$LocalSource = "",
    [string]$CustomBaseUrl = "",
    [string]$InstallDir = "",
    [switch]$SkipPathRegistration
)

$ErrorActionPreference = "Stop"

Write-Host ">>> Daemons Gate Installer" -ForegroundColor Cyan
Write-Host ">>> Verified autonomous engineering. Controlled execution. Reliable releases." -ForegroundColor Gray
Write-Host ">>> Website: https://arvindvincenzo.com/daemonsgate" -ForegroundColor Gray
Write-Host ""

# Determine target installation directory
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = "$env:USERPROFILE\.daemons-gate\bin"
}

$TargetExe = Join-Path $InstallDir "dg.exe"
$TargetAlias = Join-Path $InstallDir "daemons-gate.exe"
$ChecksumFile = Join-Path $InstallDir "SHA256SUMS.txt"

# Isolated temporary workspace for candidate download and verification
$TempWorkspace = Join-Path ([System.IO.Path]::GetTempPath()) "dg_install_$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TempWorkspace | Out-Null

$CandidateExe = Join-Path $TempWorkspace "candidate_dg.exe"
$CandidateManifest = Join-Path $TempWorkspace "candidate_SHA256SUMS.txt"

try {
    $downloadSuccess = $false

    if ($UseLocalStaging) {
        Write-Host ">>> Developer mode enabled: using local staging binary..." -ForegroundColor Yellow
        if ([string]::IsNullOrWhiteSpace($LocalSource) -or !(Test-Path $LocalSource)) {
            Write-Host "FATAL: Local source binary not found at '$LocalSource'" -ForegroundColor Red
            exit 1
        }
        Copy-Item -Path $LocalSource -Destination $CandidateExe -Force

        # Look for matching SHA256SUMS.txt in local source directory
        $LocalDir = Split-Path -Parent (Resolve-Path $LocalSource)
        $LocalManifest = Join-Path $LocalDir "SHA256SUMS.txt"
        if (!(Test-Path $LocalManifest)) {
            Write-Host "FATAL: Local staging manifest missing at '$LocalManifest'. Rejecting unverified local staging." -ForegroundColor Red
            exit 1
        }
        Copy-Item -Path $LocalManifest -Destination $CandidateManifest -Force
        $downloadSuccess = $true
    } else {
        # Official Remote Distribution Endpoints
        $Endpoints = @()
        if ($CustomBaseUrl -ne "") {
            $Endpoints += $CustomBaseUrl.TrimEnd('/')
        }
        $Endpoints += "https://arvindvincenzo.com/downloads"

        foreach ($base in $Endpoints) {
            try {
                Write-Host ">>> Connecting to secure distribution mirror: $base..." -ForegroundColor Gray
                $exeUrl = "$base/dg.exe"
                $sumUrl = "$base/SHA256SUMS.txt"

                if (Test-Path $CandidateExe) { Remove-Item -Force $CandidateExe }
                if (Test-Path $CandidateManifest) { Remove-Item -Force $CandidateManifest }

                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "DaemonsGate-Installer/1.0 (Windows NT; x64)")

                Write-Host ">>> Downloading SHA-256 integrity manifest..." -ForegroundColor Gray
                $webClient.DownloadFile($sumUrl, $CandidateManifest)

                Write-Host ">>> Downloading Daemons Gate CLI executable (dg.exe)..." -ForegroundColor Gray
                $webClient.DownloadFile($exeUrl, $CandidateExe)

                $downloadSuccess = $true
                Write-Host ">>> Download succeeded from $base" -ForegroundColor Green
                break
            } catch {
                Write-Host ">>> Endpoint $base unavailable: $($_.Exception.Message)" -ForegroundColor Yellow
                if (Test-Path $CandidateExe) { Remove-Item -Force $CandidateExe -ErrorAction SilentlyContinue }
                if (Test-Path $CandidateManifest) { Remove-Item -Force $CandidateManifest -ErrorAction SilentlyContinue }
            }
        }
    }

    if (!$downloadSuccess) {
        Write-Host "FATAL: Unable to download verified Daemons Gate release assets from any published endpoint." -ForegroundColor Red
        Write-Host "  Checked endpoints:" -ForegroundColor Red
        foreach ($base in $Endpoints) {
            Write-Host "    - $base/dg.exe" -ForegroundColor Red
        }
        Write-Host "  Please verify your internet connection or visit https://arvindvincenzo.com/daemonsgate for support." -ForegroundColor Yellow
        exit 1
    }

    # --------------------------------------------------------------------------
    # CANDIDATE INTEGRITY VERIFICATION (Performed strictly on temporary files)
    # Existing working installations remain untouched if any check fails.
    # --------------------------------------------------------------------------

    # 1. Non-empty file validation
    if (!(Test-Path $CandidateExe) -or (Get-Item $CandidateExe).Length -lt 1024) {
        Write-Host "FATAL: Candidate executable is missing or truncated." -ForegroundColor Red
        exit 1
    }

    # 2. Portable Executable (PE) Magic Header Bytes: 'MZ' (0x4D, 0x5A)
    $fileStream = [System.IO.File]::OpenRead($CandidateExe)
    $b0 = $fileStream.ReadByte()
    $b1 = $fileStream.ReadByte()
    $fileStream.Close()

    if ($b0 -ne 0x4D -or $b1 -ne 0x5A) {
        Write-Host "FATAL: Downloaded artifact is not a valid Windows executable. Received non-binary payload (HTML or error page). Rejecting." -ForegroundColor Red
        exit 1
    }

    # 3. Strict SHA-256 manifest parsing
    if (!(Test-Path $CandidateManifest) -or (Get-Item $CandidateManifest).Length -eq 0) {
        Write-Host "FATAL: Checksum manifest is missing or empty! Rejecting candidate binary." -ForegroundColor Red
        exit 1
    }

    $ExpectedHash = $null
    $ManifestLines = Get-Content $CandidateManifest
    foreach ($line in $ManifestLines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^([A-Fa-f0-9]{64})\s+[*]?dg\.exe$') {
            $ExpectedHash = $matches[1].ToUpper()
            break
        }
    }

    if (!$ExpectedHash) {
        Write-Host "FATAL: Checksum manifest does not contain a valid 64-character SHA-256 entry for dg.exe!" -ForegroundColor Red
        exit 1
    }

    # 4. Hash verification against manifest
    $CalculatedHash = (Get-FileHash -Path $CandidateExe -Algorithm SHA256).Hash.ToUpper()
    if ($CalculatedHash -ne $ExpectedHash) {
        Write-Host "FATAL: SHA-256 checksum mismatch! Downloaded artifact may be corrupted or tampered." -ForegroundColor Red
        Write-Host "  Expected:   $ExpectedHash" -ForegroundColor Red
        Write-Host "  Calculated: $CalculatedHash" -ForegroundColor Red
        exit 1
    }

    Write-Host ">>> SHA-256 checksum verified: $CalculatedHash" -ForegroundColor Green

    # 5. Pre-flight execution sanity check on the candidate binary
    $candidateVersion = ""
    try {
        $candidateVersion = (& "$CandidateExe" --version 2>&1).ToString().Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($candidateVersion)) {
            Write-Host "FATAL: Candidate binary failed execution sanity check (Exit code $LASTEXITCODE)." -ForegroundColor Red
            if ($LASTEXITCODE -ne 0) {
                exit $LASTEXITCODE
            } else {
                exit 1
            }
        }
    } catch {
        Write-Host "FATAL: Could not execute candidate binary for pre-flight verification: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    # --------------------------------------------------------------------------
    # TRANSACTIONAL REPLACEMENT WITH SAFE ROLLBACK
    # All target files (dg.exe, daemons-gate.exe, SHA256SUMS.txt) are managed
    # as a single recoverable transaction. If file copying or post-installation
    # verification fails, the original state is restored.
    # --------------------------------------------------------------------------
    if (!(Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    }

    $TxBackupDir = Join-Path $TempWorkspace "tx_backup"
    New-Item -ItemType Directory -Force -Path $TxBackupDir | Out-Null

    $origState = @{
        TargetExeExists    = (Test-Path $TargetExe -PathType Leaf)
        TargetAliasExists  = (Test-Path $TargetAlias -PathType Leaf)
        ChecksumFileExists = (Test-Path $ChecksumFile -PathType Leaf)
    }

    $backupTargetExe = Join-Path $TxBackupDir "dg.exe.orig"
    $backupTargetAlias = Join-Path $TxBackupDir "daemons-gate.exe.orig"
    $backupChecksumFile = Join-Path $TxBackupDir "SHA256SUMS.txt.orig"

    if ($origState.TargetExeExists) {
        Copy-Item -Path $TargetExe -Destination $backupTargetExe -Force -ErrorAction Stop
    }
    if ($origState.TargetAliasExists) {
        Copy-Item -Path $TargetAlias -Destination $backupTargetAlias -Force -ErrorAction Stop
    }
    if ($origState.ChecksumFileExists) {
        Copy-Item -Path $ChecksumFile -Destination $backupChecksumFile -Force -ErrorAction Stop
    }

    $transactionSucceeded = $false

    try {
        # 1. Deploy candidate files into target directory
        if (Test-Path $TargetExe -PathType Container) {
            throw "Target executable destination is an existing directory: $TargetExe"
        }
        Copy-Item -Path $CandidateExe -Destination $TargetExe -Force -ErrorAction Stop

        if (Test-Path $ChecksumFile -PathType Container) {
            throw "Target checksum destination is an existing directory: $ChecksumFile"
        }
        Copy-Item -Path $CandidateManifest -Destination $ChecksumFile -Force -ErrorAction Stop

        if (Test-Path $TargetAlias -PathType Container) {
            throw "Target alias destination is an existing directory: $TargetAlias"
        }
        Copy-Item -Path $CandidateExe -Destination $TargetAlias -Force -ErrorAction Stop

        # 2. Run post-installation verification on the installed binary
        $installedVersion = ""
        $postCheckFailed = $false
        $postCheckExitCode = 0

        try {
            $installedVersion = (& "$TargetExe" --version 2>&1).ToString().Trim()
            if ($LASTEXITCODE -ne 0) {
                $postCheckFailed = $true
                $postCheckExitCode = $LASTEXITCODE
            } elseif ([string]::IsNullOrWhiteSpace($installedVersion)) {
                $postCheckFailed = $true
                $postCheckExitCode = 1
            }
        } catch {
            $postCheckFailed = $true
            $postCheckExitCode = 1
        }

        if ($postCheckFailed) {
            throw "Installed executable failed post-installation verification (Exit code $postCheckExitCode)."
        }

        $transactionSucceeded = $true
        Write-Host ">>> Installed CLI verified: $installedVersion" -ForegroundColor Green

    } catch {
        $failureReason = $_.Exception.Message
        Write-Host "FATAL: Installation transaction failed: $failureReason" -ForegroundColor Red
        Write-Host ">>> Initiating safe transaction rollback..." -ForegroundColor Yellow

        $rollbackErrors = @()

        # Rollback TargetExe
        try {
            if ($origState.TargetExeExists) {
                Copy-Item -Path $backupTargetExe -Destination $TargetExe -Force -ErrorAction Stop
            } else {
                if (Test-Path $TargetExe -PathType Leaf) { Remove-Item -Force $TargetExe -ErrorAction SilentlyContinue }
            }
        } catch {
            $rollbackErrors += "Failed to restore dg.exe: $($_.Exception.Message)"
        }

        # Rollback TargetAlias
        try {
            if ($origState.TargetAliasExists) {
                Copy-Item -Path $backupTargetAlias -Destination $TargetAlias -Force -ErrorAction Stop
            } else {
                if (Test-Path $TargetAlias -PathType Leaf) { Remove-Item -Force $TargetAlias -ErrorAction SilentlyContinue }
            }
        } catch {
            $rollbackErrors += "Failed to restore daemons-gate.exe alias: $($_.Exception.Message)"
        }

        # Rollback ChecksumFile
        try {
            if ($origState.ChecksumFileExists) {
                Copy-Item -Path $backupChecksumFile -Destination $ChecksumFile -Force -ErrorAction Stop
            } else {
                if (Test-Path $ChecksumFile -PathType Leaf) { Remove-Item -Force $ChecksumFile -ErrorAction SilentlyContinue }
            }
        } catch {
            $rollbackErrors += "Failed to restore SHA256SUMS.txt: $($_.Exception.Message)"
        }

        if ($rollbackErrors.Count -gt 0) {
            Write-Host "FATAL: Rollback encountered errors:" -ForegroundColor Red
            $rollbackErrors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        } else {
            Write-Host ">>> Transaction successfully rolled back to original state." -ForegroundColor Yellow
        }

        exit 1
    }

    if (!$SkipPathRegistration) {
        $UserProfile = $env:USERPROFILE
        $CmdContent = "@echo off`r`n`"$TargetExe`" %*`r`n"
        Set-Content -Path (Join-Path $UserProfile "dg.cmd") -Value $CmdContent
        Set-Content -Path (Join-Path $UserProfile "daemons-gate.cmd") -Value $CmdContent

        $PsContent = "& `"$TargetExe`" `$args`r`n"
        Set-Content -Path (Join-Path $UserProfile "dg.ps1") -Value $PsContent
        Set-Content -Path (Join-Path $UserProfile "daemons-gate.ps1") -Value $PsContent

        # Register InstallDir into User PATH permanently in Registry
        $RegKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment", $true)
        $CurrentPath = $RegKey.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)

        $Parts = $CurrentPath -split ';' | Where-Object { $_ -ne "" }
        if ($Parts -notcontains $InstallDir) {
            $NewPath = ($Parts + $InstallDir) -join ';'
            $RegKey.SetValue("Path", $NewPath, [Microsoft.Win32.RegistryValueKind]::ExpandString)
            Write-Host ">>> Added $InstallDir to permanent User PATH." -ForegroundColor Green
        } else {
            Write-Host ">>> $InstallDir is already in User PATH." -ForegroundColor Gray
        }

        # Update current session PATH
        if ($env:Path -notlike "*$InstallDir*") {
            $env:Path = "$env:Path;$InstallDir"
        }
    } else {
        Write-Host ">>> Skipping PATH and root wrapper registration (-SkipPathRegistration enabled)." -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host ">>> Daemons Gate installation complete!" -ForegroundColor Green
    Write-Host ">>> Run 'dg' or 'daemons-gate' in any terminal to launch." -ForegroundColor Cyan
    Write-Host ">>> Documentation & access: https://arvindvincenzo.com/daemonsgate" -ForegroundColor Gray
} finally {
    # Ensure temporary workspace is completely cleaned up on success or failure
    if (Test-Path $TempWorkspace) {
        Remove-Item -Recurse -Force $TempWorkspace -ErrorAction SilentlyContinue
    }
}
