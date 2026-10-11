# ==============================================================================
# DAEMONS GATE BOOTSTRAPPER â€” REGRESSION TEST SUITE
# ==============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "RUNNING DAEMONS GATE BOOTSTRAPPER REGRESSION SUITE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$RepoRoot = Split-Path -Parent (Split-Path -Parent (Resolve-Path $MyInvocation.MyCommand.Path))
$InstallerPath = Join-Path $RepoRoot "install.ps1"
$ReadmePath = Join-Path $RepoRoot "README.md"
$DocPath = Join-Path $RepoRoot "docs\INSTALLATION.md"

if (!(Test-Path $InstallerPath)) {
    throw "Fatal: install.ps1 not found at $InstallerPath"
}

# Compile mock executable helpers
$TestWorkspace = Join-Path ([System.IO.Path]::GetTempPath()) "dg_tests_$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TestWorkspace | Out-Null

$ValidMockExe = Join-Path $TestWorkspace "valid_mock_dg.exe"
$FailingMockExe = Join-Path $TestWorkspace "failing_mock_dg.exe"

$validAppCode = @"
using System;
public class ValidApp {
    public static int Main(string[] args) {
        Console.WriteLine("daemons-gate version 0.1.0 (mock)");
        return 0;
    }
}
"@
Add-Type -TypeDefinition $validAppCode -OutputAssembly $ValidMockExe -OutputType ConsoleApplication

$failingAppCode = @"
using System;
public class FailingApp {
    public static int Main(string[] args) {
        Console.WriteLine("Fatal runtime panic during version check");
        return 42;
    }
}
"@
Add-Type -TypeDefinition $failingAppCode -OutputAssembly $FailingMockExe -OutputType ConsoleApplication

function Invoke-Installer {
    param([string[]]$ArgsList)
    $allArgs = @("-ExecutionPolicy", "Bypass", "-File", $InstallerPath) + $ArgsList
    $output = & powershell $allArgs 2>&1
    return @{ ExitCode = $LASTEXITCODE; Output = ($output | Out-String) }
}

$TestResults = @()

function Run-Test {
    param(
        [string]$Name,
        [scriptblock]$Block
    )
    Write-Host "`n[TEST] $Name" -ForegroundColor Cyan
    try {
        & $Block
        Write-Host "  -> PASS" -ForegroundColor Green
        $script:TestResults += @{ Name = $Name; Status = "PASS"; Error = $null }
    } catch {
        Write-Host "  -> FAIL: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults += @{ Name = $Name; Status = "FAIL"; Error = $_.Exception.Message }
    }
}

try {
    # --------------------------------------------------------------------------
    # TEST 1: Valid executable and matching manifest install successfully
    # --------------------------------------------------------------------------
    Run-Test "1. Valid executable and matching manifest install successfully" {
        $sandboxDir = Join-Path $TestWorkspace "test1_install"
        New-Item -ItemType Directory -Force -Path $sandboxDir | Out-Null
        
        $srcDir = Join-Path $TestWorkspace "test1_src"
        New-Item -ItemType Directory -Force -Path $srcDir | Out-Null
        $srcExe = Join-Path $srcDir "dg.exe"
        Copy-Item -Path $ValidMockExe -Destination $srcExe -Force
        $hash = (Get-FileHash $srcExe -Algorithm SHA256).Hash
        "$hash  dg.exe" | Set-Content (Join-Path $srcDir "SHA256SUMS.txt")
        
        $res = Invoke-Installer @("-UseLocalStaging", "-LocalSource", $srcExe, "-InstallDir", $sandboxDir, "-SkipPathRegistration")
        if ($res.ExitCode -ne 0) { throw "Installer failed with exit code $($res.ExitCode): $($res.Output)" }
        
        $target = Join-Path $sandboxDir "dg.exe"
        $alias = Join-Path $sandboxDir "daemons-gate.exe"
        if (!(Test-Path $target)) { throw "Installed binary dg.exe does not exist" }
        if (!(Test-Path $alias)) { throw "Installed alias daemons-gate.exe does not exist" }
        if ((Get-FileHash $target -Algorithm SHA256).Hash -ne $hash) { throw "Installed binary hash mismatch" }
    }

    # --------------------------------------------------------------------------
    # TEST 2: Corrupted executable (non-PE / HTML error) is rejected
    # --------------------------------------------------------------------------
    Run-Test "2. Corrupted executable (non-PE / HTML error payload) is rejected" {
        $sandboxDir = Join-Path $TestWorkspace "test2_install"
        New-Item -ItemType Directory -Force -Path $sandboxDir | Out-Null
        
        $srcDir = Join-Path $TestWorkspace "test2_src"
        New-Item -ItemType Directory -Force -Path $srcDir | Out-Null
        $srcExe = Join-Path $srcDir "dg.exe"
        "<html><body>404 Not Found</body></html>" | Set-Content $srcExe
        $hash = (Get-FileHash $srcExe -Algorithm SHA256).Hash
        "$hash  dg.exe" | Set-Content (Join-Path $srcDir "SHA256SUMS.txt")
        
        $res = Invoke-Installer @("-UseLocalStaging", "-LocalSource", $srcExe, "-InstallDir", $sandboxDir, "-SkipPathRegistration")
        if ($res.ExitCode -eq 0) { throw "Installer accepted non-PE HTML payload without error!" }
        if (Test-Path (Join-Path $sandboxDir "dg.exe")) { throw "Installer wrote invalid binary to target directory!" }
    }

    # --------------------------------------------------------------------------
    # TEST 3: Missing, malformed, or incorrect checksum entries are rejected
    # --------------------------------------------------------------------------
    Run-Test "3. Missing, malformed, or incorrect checksum entries are rejected" {
        $sandboxDir = Join-Path $TestWorkspace "test3_install"
        New-Item -ItemType Directory -Force -Path $sandboxDir | Out-Null
        
        # Subcase 3a: Empty manifest
        $srcDirA = Join-Path $TestWorkspace "test3a_src"
        New-Item -ItemType Directory -Force -Path $srcDirA | Out-Null
        $srcExeA = Join-Path $srcDirA "dg.exe"
        Copy-Item -Path $ValidMockExe -Destination $srcExeA -Force
        "" | Set-Content (Join-Path $srcDirA "SHA256SUMS.txt")
        
        $resA = Invoke-Installer @("-UseLocalStaging", "-LocalSource", $srcExeA, "-InstallDir", $sandboxDir, "-SkipPathRegistration")
        if ($resA.ExitCode -eq 0) { throw "Installer accepted empty manifest!" }

        # Subcase 3b: Malformed hash (not 64 hex characters)
        $srcDirB = Join-Path $TestWorkspace "test3b_src"
        New-Item -ItemType Directory -Force -Path $srcDirB | Out-Null
        $srcExeB = Join-Path $srcDirB "dg.exe"
        Copy-Item -Path $ValidMockExe -Destination $srcExeB -Force
        "12345badhash  dg.exe" | Set-Content (Join-Path $srcDirB "SHA256SUMS.txt")
        
        $resB = Invoke-Installer @("-UseLocalStaging", "-LocalSource", $srcExeB, "-InstallDir", $sandboxDir, "-SkipPathRegistration")
        if ($resB.ExitCode -eq 0) { throw "Installer accepted malformed hash in manifest!" }

        # Subcase 3c: Entry for another filename
        $srcDirC = Join-Path $TestWorkspace "test3c_src"
        New-Item -ItemType Directory -Force -Path $srcDirC | Out-Null
        $srcExeC = Join-Path $srcDirC "dg.exe"
        Copy-Item -Path $ValidMockExe -Destination $srcExeC -Force
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef  other.exe" | Set-Content (Join-Path $srcDirC "SHA256SUMS.txt")
        
        $resC = Invoke-Installer @("-UseLocalStaging", "-LocalSource", $srcExeC, "-InstallDir", $sandboxDir, "-SkipPathRegistration")
        if ($resC.ExitCode -eq 0) { throw "Installer accepted manifest missing entry for dg.exe!" }
    }

    # --------------------------------------------------------------------------
    # TEST 4: Hash mismatch is rejected
    # --------------------------------------------------------------------------
    Run-Test "4. Hash mismatch is rejected" {
        $sandboxDir = Join-Path $TestWorkspace "test4_install"
        New-Item -ItemType Directory -Force -Path $sandboxDir | Out-Null
        
        $srcDir = Join-Path $TestWorkspace "test4_src"
        New-Item -ItemType Directory -Force -Path $srcDir | Out-Null
        $srcExe = Join-Path $srcDir "dg.exe"
        Copy-Item -Path $ValidMockExe -Destination $srcExe -Force
        "0000000000000000000000000000000000000000000000000000000000000000  dg.exe" | Set-Content (Join-Path $srcDir "SHA256SUMS.txt")
        
        $res = Invoke-Installer @("-UseLocalStaging", "-LocalSource", $srcExe, "-InstallDir", $sandboxDir, "-SkipPathRegistration")
        if ($res.ExitCode -eq 0) { throw "Installer accepted binary with hash mismatch!" }
        if (Test-Path (Join-Path $sandboxDir "dg.exe")) { throw "Installer wrote mismatched binary to target directory!" }
    }

    # --------------------------------------------------------------------------
    # TEST 5: Existing valid executable remains unchanged after failed install
    # --------------------------------------------------------------------------
    Run-Test "5. Existing valid executable remains unchanged after failed candidate installation" {
        $sandboxDir = Join-Path $TestWorkspace "test5_install"
        New-Item -ItemType Directory -Force -Path $sandboxDir | Out-Null
        
        # Pre-populate working existing installation
        $existingExe = Join-Path $sandboxDir "dg.exe"
        Copy-Item -Path $ValidMockExe -Destination $existingExe -Force
        $originalHash = (Get-FileHash $existingExe -Algorithm SHA256).Hash

        # Attempt to install bad candidate (hash mismatch)
        $srcDir = Join-Path $TestWorkspace "test5_src"
        New-Item -ItemType Directory -Force -Path $srcDir | Out-Null
        $badExe = Join-Path $srcDir "dg.exe"
        "bad data payload" | Set-Content $badExe
        "0000000000000000000000000000000000000000000000000000000000000000  dg.exe" | Set-Content (Join-Path $srcDir "SHA256SUMS.txt")

        $res = Invoke-Installer @("-UseLocalStaging", "-LocalSource", $badExe, "-InstallDir", $sandboxDir, "-SkipPathRegistration")
        if ($res.ExitCode -eq 0) { throw "Installer reported success on bad candidate!" }

        # Verify existing installation was NOT deleted, corrupted, or modified
        if (!(Test-Path $existingExe)) {
            throw "Existing executable was deleted during failed candidate install!"
        }
        $currentHash = (Get-FileHash $existingExe -Algorithm SHA256).Hash
        if ($currentHash -ne $originalHash) {
            throw "Existing executable was modified or corrupted by failed candidate install!"
        }
    }

    # --------------------------------------------------------------------------
    # TEST 6: Temporary files are cleaned up after failures
    # --------------------------------------------------------------------------
    Run-Test "6. Temporary files are cleaned up after failures" {
        $tempPath = [System.IO.Path]::GetTempPath()
        $beforeDirs = @(Get-ChildItem -Path $tempPath -Filter "dg_install_*" -Directory | Select-Object -ExpandProperty FullName)

        $srcDir = Join-Path $TestWorkspace "test6_src"
        New-Item -ItemType Directory -Force -Path $srcDir | Out-Null
        $badExe = Join-Path $srcDir "dg.exe"
        "bad data" | Set-Content $badExe
        "0000000000000000000000000000000000000000000000000000000000000000  dg.exe" | Set-Content (Join-Path $srcDir "SHA256SUMS.txt")

        $null = Invoke-Installer @("-UseLocalStaging", "-LocalSource", $badExe, "-InstallDir", (Join-Path $TestWorkspace "test6_target"), "-SkipPathRegistration")

        $afterDirs = @(Get-ChildItem -Path $tempPath -Filter "dg_install_*" -Directory | Select-Object -ExpandProperty FullName)
        $leftovers = $afterDirs | Where-Object { $beforeDirs -notcontains $_ }
        if ($leftovers.Count -gt 0) {
            throw "Temporary workspaces were not cleaned up: $($leftovers -join ', ')"
        }
    }

    # --------------------------------------------------------------------------
    # TEST 7: Version-check failures cannot be reported as successful verification
    # --------------------------------------------------------------------------
    Run-Test "7. Version-check failures cannot be reported as successful verification" {
        $sandboxDir = Join-Path $TestWorkspace "test7_install"
        New-Item -ItemType Directory -Force -Path $sandboxDir | Out-Null
        
        $srcDir = Join-Path $TestWorkspace "test7_src"
        New-Item -ItemType Directory -Force -Path $srcDir | Out-Null
        $failExe = Join-Path $srcDir "dg.exe"
        Copy-Item -Path $FailingMockExe -Destination $failExe -Force
        $hash = (Get-FileHash $failExe -Algorithm SHA256).Hash
        "$hash  dg.exe" | Set-Content (Join-Path $srcDir "SHA256SUMS.txt")

        $res = Invoke-Installer @("-UseLocalStaging", "-LocalSource", $failExe, "-InstallDir", $sandboxDir, "-SkipPathRegistration")
        if ($res.ExitCode -eq 0) {
            throw "Installer returned exit code 0 on a binary that failed the version sanity check!"
        }
        if ($res.Output -match "Daemons Gate installation complete") {
            throw "Installer output reported installation complete despite version failure!"
        }
        if (!(Test-Path (Join-Path $sandboxDir "dg.exe"))) {
            # Note: since version check failed on candidate pre-flight, it should not be installed
        }
    }

    # --------------------------------------------------------------------------
    # TEST 8: Local staging and existing installer options continue to work
    # --------------------------------------------------------------------------
    Run-Test "8. Local staging and existing installer options continue to work" {
        $sandboxDir = Join-Path $TestWorkspace "test8_install"
        New-Item -ItemType Directory -Force -Path $sandboxDir | Out-Null
        
        $srcDir = Join-Path $TestWorkspace "test8_src"
        New-Item -ItemType Directory -Force -Path $srcDir | Out-Null
        $srcExe = Join-Path $srcDir "dg.exe"
        Copy-Item -Path $ValidMockExe -Destination $srcExe -Force
        $hash = (Get-FileHash $srcExe -Algorithm SHA256).Hash
        "$hash  dg.exe" | Set-Content (Join-Path $srcDir "SHA256SUMS.txt")

        $res = Invoke-Installer @("-UseLocalStaging", "-LocalSource", $srcExe, "-InstallDir", $sandboxDir, "-SkipPathRegistration")
        if ($res.ExitCode -ne 0) { throw "Installer failed with exit code $($res.ExitCode): $($res.Output)" }

        $target = Join-Path $sandboxDir "dg.exe"
        if (!(Test-Path $target)) { throw "Installed binary missing" }
        $ver = & $target --version
        if ($ver -notmatch "version") { throw "Version execution returned unexpected result: $ver" }
    }

    # --------------------------------------------------------------------------
    # TEST 9: Documentation contains no unsupported signature claims
    # --------------------------------------------------------------------------
    Run-Test "9. Documentation contains no unsupported signature claims" {
        $filesToCheck = @($ReadmePath, $DocPath, $InstallerPath)
        foreach ($file in $filesToCheck) {
            $content = Get-Content $file -Raw
            if ($content -match '\b(cryptographically signed|digitally signed|signed SHA-256|signed binary|signed manifest)\b') {
                throw "File $(Split-Path -Leaf $file) contains unsupported signature claim: '$($matches[1])'"
            }
        }
    }

    # --------------------------------------------------------------------------
    # TEST 10: Integrity and download endpoints verified
    # --------------------------------------------------------------------------
    Run-Test "10. Public installer contains canonical endpoints and strict manifest regex" {
        $installerContent = Get-Content $InstallerPath -Raw
        if (!$installerContent.Contains('https://arvindvincenzo.com/downloads')) {
            throw "Installer missing canonical distribution endpoint https://arvindvincenzo.com/downloads"
        }
        if (!$installerContent.Contains('^([A-Fa-f0-9]{64})\s+[*]?dg\.exe$')) {
            throw "Installer missing strict 64-character SHA-256 regex"
        }
    }

} finally {
    if (Test-Path $TestWorkspace) {
        Remove-Item -Recurse -Force $TestWorkspace -ErrorAction SilentlyContinue
    }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "REGRESSION TEST SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
$failedCount = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count
$passCount = ($TestResults | Where-Object { $_.Status -eq "PASS" }).Count

foreach ($t in $TestResults) {
    $col = "Green"
    if ($t.Status -ne "PASS") { $col = "Red" }
    Write-Host "$($t.Status): $($t.Name)" -ForegroundColor $col
}

$summaryColor = "Green"
if ($failedCount -gt 0) { $summaryColor = "Red" }
Write-Host "`nPassed: $passCount | Failed: $failedCount" -ForegroundColor $summaryColor
if ($failedCount -gt 0) {
    exit 1
}
