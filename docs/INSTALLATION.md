# Daemons Gate — Installation & Verification Guide

This guide covers installing, cryptographically verifying, troubleshooting, and uninstalling the **Daemons Gate** command-line interface (`dg`).

- **Official Product Website:** [https://arvindvincenzo.com/daemonsgate](https://arvindvincenzo.com/daemonsgate)
- **Official Download Mirror:** [https://arvindvincenzo.com/downloads/](https://arvindvincenzo.com/downloads/)

---

## 1. Supported Platforms & Requirements

| Platform | Architecture | Status | Minimum OS |
| :--- | :---: | :---: | :--- |
| **Windows** | x86_64 / AMD64 | **Supported (GA)** | Windows 10, Windows 11, Windows Server 2019+ |
| **Linux** | x86_64, ARM64 | Coming Soon | Ubuntu 20.04+, Debian 11+, Fedora 36+ |
| **macOS** | Apple Silicon, Intel | Coming Soon | macOS 12 Monterey or later |

### Prerequisites
- **Shell:** Windows PowerShell 5.1 or PowerShell 7 Core (`pwsh`).
- **Network:** HTTPS outbound access (port 443) to `arvindvincenzo.com`.
- **Permissions:** Standard user privileges (administrative rights are **not** required).

---

## 2. Quick Installation (Recommended)

To install Daemons Gate using the official PowerShell bootstrapper, run the following command in PowerShell:

```powershell
irm https://arvindvincenzo.com/install.ps1 | iex
```

### What the bootstrapper does:
1. Connects to the secure Cloudflare-backed distribution endpoint (`https://arvindvincenzo.com/downloads`).
2. Downloads the official `dg.exe` binary and signed `SHA256SUMS.txt` manifest.
3. Validates Portable Executable (`MZ`) magic header bytes to ensure complete transmission.
4. Cryptographically verifies the SHA-256 hash of the downloaded binary against the official manifest.
5. Installs the binary into `$HOME\.daemons-gate\bin\dg.exe` and sets up `daemons-gate.exe` alias.
6. Adds the installation directory to your permanent user `PATH` environment variable.
7. Executes `dg --version` as a final verification check.

---

## 3. Alternative: Clone and Run the Bootstrapper

If you prefer to inspect and run the bootstrapper locally from this repository:

```powershell
# 1. Clone the public bootstrap repository
git clone https://github.com/arvindvincenzo/daemons-gate-bootstrap.git
cd daemons-gate-bootstrap

# 2. Run the bootstrapper
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### Advanced Bootstrapper Options

| Option | Description | Example |
| :--- | :--- | :--- |
| `-InstallDir <path>` | Installs to a custom target directory. | `.\install.ps1 -InstallDir C:\tools\dg` |
| `-SkipPathRegistration` | Skips updating the User `PATH` registry key. | `.\install.ps1 -SkipPathRegistration` |
| `-CustomBaseUrl <url>` | Uses an alternate authorized mirror. | `.\install.ps1 -CustomBaseUrl https://mirror.example.com` |

---

## 4. Manual Download & Cryptographic Verification

If you prefer to download the binary manually without running an installer script:

### Step 1: Download the binary and manifest
In PowerShell:
```powershell
# Download binary
Invoke-WebRequest -Uri "https://arvindvincenzo.com/downloads/dg.exe" -OutFile "$HOME\dg.exe"

# Download checksum manifest
Invoke-WebRequest -Uri "https://arvindvincenzo.com/downloads/SHA256SUMS.txt" -OutFile "$HOME\SHA256SUMS.txt"
```

### Step 2: Compute and verify the SHA-256 hash
```powershell
# Compute local hash
$CalculatedHash = (Get-FileHash "$HOME\dg.exe" -Algorithm SHA256).Hash

# Read manifest entry
$Manifest = Get-Content "$HOME\SHA256SUMS.txt"

Write-Host "Calculated: $CalculatedHash"
Write-Host "Manifest:   $Manifest"

if ($Manifest -match $CalculatedHash) {
    Write-Host "PASS: Checksum verification succeeded!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Checksum mismatch! Do not execute the binary." -ForegroundColor Red
}
```

### Step 3: Move to your desired directory
Move `dg.exe` to any folder on your system `PATH` (such as `C:\Windows\System32` or `$HOME\.local\bin`).

---

## 5. Verification & First Launch

Once installed, restart your terminal or open a new PowerShell prompt and run:

```powershell
dg --version
```
Expected output:
```
daemons-gate version 0.1.0
```

To display available commands and model customization controls:
```powershell
dg --help
```

To initialize your local workspace and runtime configuration:
```powershell
dg setup
```

---

## 6. Authentication & License Verification

Daemons Gate enforces scoped licensing and entitlement checks for private workspace operations via Google OAuth and Supabase:

```powershell
# Authenticate your license
dg auth login
```

- A browser window will open for secure Google OAuth single sign-on.
- Upon completion, your entitlement token is verified against your Whop customer plan.
- Entitlement status can be inspected at any time with:
  ```powershell
  dg status
  ```

---

## 7. Troubleshooting

### 1. `Execution_Policies` restriction
If running `.\install.ps1` gives an `UnauthorizedAccess` error:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

### 2. Command `'dg'` not recognized after installation
If typing `dg` reports `The term 'dg' is not recognized`:
- Close and reopen your terminal session so the updated user `PATH` takes effect.
- Alternatively, refresh the current session's PATH:
  ```powershell
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + [System.Environment]::GetEnvironmentVariable("Path","Machine")
  ```

### 3. Corporate Proxy or Firewall Blocks
Ensure your network allows outbound TLS connections to:
- `arvindvincenzo.com` (port 443)
- `agdruziwupgyoyafbjcs.supabase.co` (port 443)

---

## 8. Uninstallation

To cleanly remove Daemons Gate from your system:

```powershell
# 1. Remove binary directory
$InstallDir = "$env:USERPROFILE\.daemons-gate"
if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force $InstallDir
}

# 2. Remove user wrappers
Remove-Item -Force "$env:USERPROFILE\dg.cmd", "$env:USERPROFILE\daemons-gate.cmd", "$env:USERPROFILE\dg.ps1", "$env:USERPROFILE\daemons-gate.ps1" -ErrorAction SilentlyContinue

# 3. Remove from User PATH registry
$RegKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment", $true)
$CurrentPath = $RegKey.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
$NewPath = ($CurrentPath -split ';' | Where-Object { $_ -ne "$env:USERPROFILE\.daemons-gate\bin" -and $_ -ne "" }) -join ';'
$RegKey.SetValue("Path", $NewPath, [Microsoft.Win32.RegistryValueKind]::ExpandString)

Write-Host "Daemons Gate has been completely uninstalled." -ForegroundColor Green
```
