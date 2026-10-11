# Daemons Gate

**Verified autonomous engineering. Controlled execution. Reliable releases.**

> **Official Website:** [https://arvindvincenzo.com/daemonsgate](https://arvindvincenzo.com/daemonsgate)  
> **Documentation:** [docs/INSTALLATION.md](docs/INSTALLATION.md)  
> **Official Binary Mirror:** [https://arvindvincenzo.com/downloads/](https://arvindvincenzo.com/downloads/)

---

## 1. What is Daemons Gate?

**Daemons Gate** (`dg`) is a high-performance, proprietary command-line control center and execution harness built in Go for AI-assisted software engineering.

Modern autonomous agents frequently suffer from hallucinations, unbounded context windows, and unverified assumptions. Daemons Gate enforces strict operational boundaries around AI coding tools:
- **Structural Code Intelligence:** Inspect AST skeletons and focused symbol graphs instead of dumping thousands of raw source lines into model context.
- **Atomic Transactional Edits:** Package multi-file modifications into single atomic operations with syntax gating and isolated shadow worktrees.
- **Objective Verification Gates:** Demand compiler exit codes, passing unit tests, and runtime evidence before considering any modification complete.
- **Interactive TUI Control Plane:** Monitor local model runners (llama.cpp), manage Model Context Protocol (MCP) tool registrations, and observe active workflows through a rich terminal interface.

---

## 2. Why Developers Use Daemons Gate

1. **Eliminate Hallucinated Completions**  
   Autonomous agents cannot mark a task "complete" without producing demonstrable verification evidence (compiler output, passing tests, and runtime telemetry).
2. **Context Window Efficiency**  
   Replace multi-megabyte file dumps with targeted AST skeletons, symbol definitions, and targeted diffs, saving tokens and keeping agents focused.
3. **Shadow Worktree Isolation**  
   Edits are compiled and verified inside isolated shadow worktrees before ever touching your working branch or host repository.
4. **Deterministic Tool Harness**  
   Integrates seamlessly with any MCP-compatible coding agent or IDE (Claude Code, Cursor, Windsurf, Antigravity) to provide unified file reading, editing, terminal execution, and verification.

---

## 3. Core Capabilities

Daemons Gate exposes a coordinated tool system grounded in practical software engineering:

- **AST Code Intelligence (`scan`, `search`):** Explore package structures, function signatures, caller hierarchies, and semantic references without consuming token budgets.
- **Atomic Multi-File Patching (`change`):** Execute atomic transactional patches across multiple files simultaneously with automatic rollback on syntax or compile errors.
- **Evidence Verification (`verify`):** Execute builds, test runners, and static linters within protected execution timeouts, capturing process exit codes and compiler diagnostics.
- **Release & Distribution (`ship`):** Audit working trees, generate cryptographic release manifests, and coordinate multi-platform deployments.
- **Interactive Terminal Dashboard:** Run `dg` to open the full-screen Bubble Tea TUI dashboard to switch local model profiles, view runtime metrics, and manage external MCP server registrations.

---

## 4. Supported Platforms & Prerequisites

| Operating System | Architecture | Status | Binary Distribution |
| :--- | :---: | :---: | :--- |
| **Windows** | x86_64 / AMD64 | **Available (GA)** | Cloudflare R2 (`/downloads/dg.exe`) |
| **Linux** | x86_64, ARM64 | In Final Testing | Coming Soon |
| **macOS** | Apple Silicon, Intel | In Final Testing | Coming Soon |

### Prerequisites
- Windows 10, Windows 11, or Windows Server 2019+
- Windows PowerShell 5.1 or PowerShell 7+
- Active outbound HTTPS connection to `arvindvincenzo.com`

---

## 5. Quick Installation (Windows)

Install Daemons Gate in one command using the official PowerShell bootstrapper:

```powershell
irm https://arvindvincenzo.com/install.ps1 | iex
```

### What this does:
1. Connects securely to the Cloudflare distribution mirror at `https://arvindvincenzo.com/downloads`.
2. Downloads `dg.exe` and the `SHA256SUMS.txt` integrity manifest into a temporary staging area.
3. Validates Portable Executable (`MZ`) magic header bytes to ensure a valid binary was received.
4. Verifies the candidate binary's SHA-256 hash strictly against the manifest.
5. Performs a pre-flight execution check on the candidate before modifying any existing installation.
6. Safely deploys the CLI to `$HOME\.daemons-gate\bin\dg.exe` within a recoverable transaction (with automatic backup and rollback preservation) and creates the `daemons-gate.exe` alias.
7. Registers the binary in your permanent user `PATH`.
8. Executes `dg --version` to confirm successful installation.

For detailed instructions, manual verification, and advanced bootstrapper parameters, see the [Installation Guide](docs/INSTALLATION.md).

---

## 6. Launching and Authenticating

### Launch the Interactive Control Center
Open any terminal and run:
```powershell
dg
```
*(Or launch the full name: `daemons-gate`)*

### Check Version & Snapshot
```powershell
dg --version
# Output: daemons-gate version 0.1.0

dg status
```

### Authenticate Your Entitlement
Daemons Gate uses Google OAuth single sign-on connected to Supabase Auth and Whop licensing:
```powershell
dg auth login
```
Follow the browser prompt to log in with the Google account associated with your Daemons Gate membership. Your license entitlement will be cached locally with automatic background validation.

---

## 7. Artifact Verification & Security

Official Daemons Gate binary artifacts are published through Cloudflare R2 alongside SHA-256 integrity checksum manifests:

- **Primary Binary Mirror:** `https://arvindvincenzo.com/downloads/dg.exe`
- **Integrity Manifest:** `https://arvindvincenzo.com/downloads/SHA256SUMS.txt`
- **Versioned Archive:** `https://arvindvincenzo.com/downloads/releases/v0.1.0/dg.exe`

You can manually verify any downloaded binary at any time:
```powershell
(Get-FileHash "$HOME\.daemons-gate\bin\dg.exe" -Algorithm SHA256).Hash
```
Compare the output against the published hash in `https://arvindvincenzo.com/downloads/SHA256SUMS.txt`.

> **Note on Verification Scope:** SHA-256 checksum verification guarantees data integrity against transmission errors and incomplete downloads. Because the binary and manifest are hosted on the same official distribution infrastructure and delivered over HTTPS/TLS, this check verifies artifact completeness and consistency with the publisher's manifest, but does not represent an independent asymmetric digital signature (such as Windows Authenticode or GPG).

---

## 8. Proprietary Licensing & Terms

Daemons Gate is a proprietary commercial product developed by Arvind Vincenzo.

- **License:** Proprietary Commercial License. Unauthorized copying, decompilation, redistribution, or reverse engineering of the binary or source code is strictly prohibited.
- **Public Bootstrapper Repository:** The scripts, documentation, and configuration contained within this repository (`daemons-gate-bootstrap`) are released under the [MIT License](LICENSE) to allow open inspection, embedding, and customization of the installation process.
- **Terms of Service:** Access to the proprietary CLI and backend verification services requires an active subscription or perpetual license.

---

## 9. Official Product Links & Access

- **Official Product Website:** [https://arvindvincenzo.com/daemonsgate](https://arvindvincenzo.com/daemonsgate)
- **Purchase & Membership Access:** [https://arvindvincenzo.com/daemonsgate#pricing](https://arvindvincenzo.com/daemonsgate#pricing)
- **Support & Issues:** For bootstrapper or installation issues, please open an issue in this repository. For product support and license inquiries, contact support via [arvindvincenzo.com](https://arvindvincenzo.com/daemonsgate).
