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

# Determine target directory
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = "$env:USERPROFILE\.daemons-gate\bin"
}

if (!(Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

$TargetExe = Join-Path $InstallDir "dg.exe"
$TargetAlias = Join-Path $InstallDir "daemons-gate.exe"
$ChecksumFile = Join-Path $InstallDir "SHA256SUMS.txt"

$downloadSuccess = $false

if ($UseLocalStaging) {
    Write-Host ">>> Developer mode enabled: using local staging binary..." -ForegroundColor Yellow
    if ([string]::IsNullOrWhiteSpace($LocalSource) -or !(Test-Path $LocalSource)) {
        Write-Host "FATAL: Local source binary not found at '$LocalSource'" -ForegroundColor Red
        exit 1
    }
    Copy-Item -Path $LocalSource -Destination $TargetExe -Force
    $LocalChecksum = Join-Path (Split-Path $LocalSource) "SHA256SUMS.txt"
    if (Test-Path $LocalChecksum) {
        Copy-Item -Path $LocalChecksum -Destination $ChecksumFile -Force
    }
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

            $tmpExe = "$TargetExe.tmp"
            $tmpSum = "$ChecksumFile.tmp"

            if (Test-Path $tmpExe) { Remove-Item -Force $tmpExe }
            if (Test-Path $tmpSum) { Remove-Item -Force $tmpSum }

            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "DaemonsGate-Installer/1.0 (Windows NT; x64)")

            Write-Host ">>> Downloading SHA-256 integrity manifest..." -ForegroundColor Gray
            $webClient.DownloadFile($sumUrl, $tmpSum)

            Write-Host ">>> Downloading Daemons Gate CLI executable (dg.exe)..." -ForegroundColor Gray
            $webClient.DownloadFile($exeUrl, $tmpExe)

            # Validate Portable Executable (PE) Magic Header Bytes: 'MZ' (0x4D, 0x5A)
            $fileStream = [System.IO.File]::OpenRead($tmpExe)
            $b0 = $fileStream.ReadByte()
            $b1 = $fileStream.ReadByte()
            $fileStream.Close()

            if ($b0 -ne 0x4D -or $b1 -ne 0x5A) {
                Write-Host ">>> Remote endpoint returned non-binary payload (HTML or error page). Rejecting." -ForegroundColor Yellow
                Remove-Item -Force $tmpExe -ErrorAction SilentlyContinue
                Remove-Item -Force $tmpSum -ErrorAction SilentlyContinue
                continue
            }

            Move-Item -Path $tmpExe -Destination $TargetExe -Force
            Move-Item -Path $tmpSum -Destination $ChecksumFile -Force
            $downloadSuccess = $true
            Write-Host ">>> Download succeeded from $base" -ForegroundColor Green
            break
        } catch {
            Write-Host ">>> Endpoint $base unavailable: $($_.Exception.Message)" -ForegroundColor Yellow
            if (Test-Path "$TargetExe.tmp") { Remove-Item -Force "$TargetExe.tmp" -ErrorAction SilentlyContinue }
            if (Test-Path "$ChecksumFile.tmp") { Remove-Item -Force "$ChecksumFile.tmp" -ErrorAction SilentlyContinue }
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

# Strict SHA-256 verification against the signed manifest
if (!(Test-Path $ChecksumFile)) {
    Write-Host "FATAL: Checksum manifest missing! Rejecting unverified binary." -ForegroundColor Red
    Remove-Item -Force $TargetExe -ErrorAction SilentlyContinue
    exit 1
}

$CalculatedHash = (Get-FileHash -Path $TargetExe -Algorithm SHA256).Hash.ToUpper()
$ExpectedHash = $null

$ManifestLines = Get-Content $ChecksumFile
foreach ($line in $ManifestLines) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^([A-Fa-f0-9]{64})\s+[*]?dg\.exe$') {
        $ExpectedHash = $matches[1].ToUpper()
        break
    }
}

if (!$ExpectedHash) {
    Write-Host "FATAL: Checksum manifest does not contain a valid entry for dg.exe!" -ForegroundColor Red
    Remove-Item -Force $TargetExe -ErrorAction SilentlyContinue
    exit 1
}

if ($CalculatedHash -ne $ExpectedHash) {
    Write-Host "FATAL: Checksum mismatch! Downloaded artifact may be corrupted or tampered." -ForegroundColor Red
    Write-Host "  Expected:   $ExpectedHash" -ForegroundColor Red
    Write-Host "  Calculated: $CalculatedHash" -ForegroundColor Red
    Remove-Item -Force $TargetExe -ErrorAction SilentlyContinue
    exit 1
}

Write-Host ">>> Cryptographic integrity verified (SHA-256: $CalculatedHash)" -ForegroundColor Green

# Duplicate alias so user can invoke either 'dg' or 'daemons-gate'
Copy-Item -Path $TargetExe -Destination $TargetAlias -Force

# Environment & PATH Configuration
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

# Run final sanity check: execute CLI version
try {
    $verOutput = (& "$TargetExe" --version 2>&1).Trim()
    Write-Host ">>> Verification check passed: $verOutput" -ForegroundColor Green
} catch {
    Write-Warning "Could not execute installed binary for version verification: $($_.Exception.Message)"
}

Write-Host ""
Write-Host ">>> Daemons Gate installation complete!" -ForegroundColor Green
Write-Host ">>> Run 'dg' or 'daemons-gate' in any terminal to launch." -ForegroundColor Cyan
Write-Host ">>> Documentation & access: https://arvindvincenzo.com/daemonsgate" -ForegroundColor Gray
