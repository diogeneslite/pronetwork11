# ⚡ ProNetwork11

[![Author](https://img.shields.io/badge/Author-diogeneslite-blue.svg)](https://github.com/diogeneslite)
[![Platform](https://img.shields.io/badge/Platform-Windows%2011%20%7C%2010-0078D6.svg?logo=windows)](https://microsoft.com)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE.svg?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Dependencies](https://img.shields.io/badge/Dependencies-Zero%20External-success.svg)](#-dependencies--prerequisites)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **Zero-Scroll, In-Place Windows 11 Network Intelligence & Diagnostic Operations Toolkit**  
> *Crafted by [diogeneslite](https://github.com/diogeneslite)*

---

## 📖 What is ProNetwork11?

When you encounter network lag, Wi-Fi stutter, slow downloads, or suspicious devices on your local subnet, typical troubleshooting on Windows often feels frustrating: you run fragmented commands like `ping`, `tracert`, `netsh`, `ipconfig`, and `arp`, which spam your terminal with hundreds of lines of disjointed text.

**ProNetwork11** is an all-in-one network diagnostics suite created by **[diogeneslite](https://github.com/diogeneslite)** specifically for Windows 11 and Windows 10. It is engineered with a strict **"zero-scroll"** philosophy:

* **Compact, High-Density Dashboard**: Everything you need to know about your current network (connection type, Wi-Fi generation, negotiated link speed, router brand, local and public IP addresses) fits into a single, clean terminal view without scrolling away.
* **Flicker-Free In-Place Live Bandwidth Graph**: A real-time ASCII telemetry gauge shows live upload and download throughput between your PC and router. It updates dynamically using ANSI terminal cursor repositioning, completely eliminating annoying terminal flicker.
* **Three Focused Operational Paths**: Rather than confusing you with dozens of disconnected flags, ProNetwork11 organizes all diagnostics into three clean paths:
  1. **Performance & Benchmarks**: Statistical latency, jitter, packet loss, DNS resolution times, and sustained download speeds.
  2. **Device Discovery & Web Audit**: Subnet device scanning, hardware vendor classification, open admin ports, and web directory probing.
  3. **Router Security & Health Audit**: Wi-Fi cipher auditing, WPS brute-force risk detection, link speed bottleneck diagnosis, and exposed remote management services.

---

## 📦 Dependencies & Prerequisites

One of the greatest strengths of **ProNetwork11** is that it has **ZERO external dependencies**:

| Requirement | Details |
| :--- | :--- |
| **External Packages** | **None.** No Node.js/npm, no Python, no NuGet packages, and no third-party `.exe` downloads. |
| **Operating System** | **Windows 11** (recommended) or **Windows 10**. |
| **PowerShell Version** | **Windows PowerShell 5.1** (pre-installed on all modern Windows machines) or **PowerShell 7+ (Core)**. |
| **Runtimes Used** | Uses Windows native .NET APIs (`System.Net.Sockets`, `System.Net.NetworkInformation`, `System.Net.Dns`, `System.Net.WebClient`). |
| **Privileges** | Standard user permissions work for general diagnostics. **Administrator privileges** are recommended for comprehensive subnet ARP sweeps, raw packet probing, and querying protected Wi-Fi adapter security parameters. |
| **Execution Policy** | If PowerShell script execution is restricted on your machine, simply double-click **`pronetwork11.cmd`**, which safely launches the toolkit with `-ExecutionPolicy Bypass` for the current process without changing your system-wide security settings. |

---

## 🧩 The Modules: One by One

ProNetwork11 is designed modularly, separating terminal styling, hardware queries, benchmarking math, subnet scanners, and security rules into clean, reusable PowerShell modules.

Here is what each module does in plain human language:

### 1. `pronetwork11.ps1` (Main CLI & Dashboard Controller)
* **Author**: `diogeneslite`
* **What it does**: The central command center of the entire toolkit. It detects your environment, loads all sub-modules, displays the zero-scroll greeting and live bandwidth meter, and hosts the interactive single-key menu (`1`, `2`, `3`, `0`).
* **CLI Automation**: Also provides non-interactive command-line switches (`-Benchmark`, `-ScanDevices`, `-RouterHealth`, `-LiveBandwidth`, `-All`) for automation, scripting, and scheduled checks.

### 2. `pronetwork11.cmd` (Quick Launcher)
* **Author**: `diogeneslite`
* **What it does**: A lightweight Windows batch wrapper. It lets you launch the entire toolkit with a simple double-click from Windows Explorer or a standard terminal prompt, automatically configuring the execution policy bypass for the session.

### 3. `Modules/UI.psm1` (Terminal Presentation & Styling)
* **Author**: `diogeneslite`
* **What it does**: Controls how everything looks on screen. It implements a strict **tri-color visual system** using ANSI 24-bit color escapes:
  * 🟢 **Green**: Healthy state, excellent performance, secure configurations.
  * 🔴 **Red**: Failures, packet loss, open insecure ports, security risks.
  * 🔵 **Blue**: Informational headers, section banners, metric labels.
  * 🟡 **Amber**: Warnings, fair performance, cleartext protocols.
* **Key Functions**: `Write-CompactHeader`, `Write-CompactDivider`, `Write-SectionTitle`, `Write-BenchmarkRow`, and `Get-FriendlyUserName`.

### 4. `Modules/NetworkInfo.psm1` (Network & Hardware Telemetry)
* **Author**: `diogeneslite`
* **What it does**: Inspects your network interface, active Wi-Fi / Ethernet adapter, and default gateway. It looks up the router's hardware MAC address against a built-in **MAC OUI (Organizationally Unique Identifier) database** to identify the manufacturer of your router (FiberHome, Huawei, TP-Link, Netgear, Cisco, Asus, etc.).
* **Key Capabilities**: Computes CIDR subnet notation (`/24`), extracts local DNS resolvers, finds your public IP address with ISP details, and renders the in-place live router bandwidth meter.

### 5. `Modules/NetworkBenchmarks.psm1` (Path 1: Single-Line Benchmarks)
* **Author**: `diogeneslite`
* **What it does**: Orchestrates Path 1. Rather than running a quick single ping and guessing your connection quality, it performs **deep statistical sampling**:
  * **Router Gateway Latency & RF Jitter**: 35 rapid ICMP probes to evaluate local Wi-Fi / cable latency and variance.
  * **Internet Backbone Latency & Edge Jitter**: 35 ICMP probes to Cloudflare Anycast (`1.1.1.1`).
  * **Packet Loss Rate**: 70 total probes to test reliability.
  * **TCP Handshake Latency**: 5-sample HTTPS SYN/ACK latency on port 443.
  * **DNS Resolution Benchmarks**: Compares query response times between your local router, Cloudflare DNS (`1.1.1.1`), Google DNS (`8.8.8.8`), and Quad9 (`9.9.9.9`).
  * **Sustained Download Speed**: Measures sustained multi-chunk CDN throughput.
  * **Composite Health Score**: Calculates an overall network health score from 0 to 100 with clear diagnostic ratings.

### 6. `Modules/DeviceScanner.psm1` (Path 2: Subnet Discovery & Web Directory Audit)
* **Author**: `diogeneslite`
* **What it does**: Discovers what devices are sharing your local network and checks for open web administration panels.
* **Key Capabilities**:
  * **Multi-Protocol Discovery**: Combines ARP cache analysis, NetBIOS node queries (`Query-NetBiosNodeStatus`), mDNS broadcast listeners (`Collect-SubnetMdnsMap`), and Apple Lockdown protocol probing (`Probe-AppleDeviceLockdown`) to accurately resolve hostnames and identify devices (smartphones, smart TVs, PCs, IoT).
  * **Port Scanning**: Audits standard administrative ports (80, 443, 8080, 22, 23, 445, 53).
  * **Web Service & Directory Audit**: If an HTTP/HTTPS service is running on any device or router, it captures the page title and web server header, then recursively tests common admin endpoints (`/admin`, `/login`, `/api`, `/status`, `/setup`, `/config`, `/portal`, `/ui`, etc.) and reports detected routes.

### 7. `Modules/RouterSecurity.psm1` (Path 3: Router Health & Configuration Audit)
* **Author**: `diogeneslite`
* **What it does**: Evaluates your router's configuration against modern cybersecurity standards.
* **Key Checks**:
  * **Wi-Fi Cipher & Protocol Audit**: Verifies WPA3-SAE / WPA2-AES CCMP vs legacy insecure protocols (WPA, TKIP, Open).
  * **WPS Vulnerability Notice**: Explains the risks of Wi-Fi Protected Setup PIN brute-forcing (Pixie-Dust, Reaver).
  * **Link Speed Saturation**: Compares negotiated Wi-Fi PHY speed against adapter theoretical capacity.
  * **Web Admin Encryption**: Flags whether router management runs over unencrypted HTTP (Port 80) or secure HTTPS (Port 443).
  * **Remote Protocol Exposure**: Warns if unencrypted Telnet (Port 23) is enabled versus secure OpenSSH (Port 22).
  * **Predictable Subnets**: Flags common target subnets (`192.168.1.1` / `192.168.0.1`) vulnerable to automated cross-site scripting attacks.
  * **Actionable Advice**: Provides straightforward recommendations in plain language on how to fix detected issues.

### 8. `Modules/DeviceDiscovery.psm1` (Real-Time Bandwidth Monitor)
* **Author**: `diogeneslite`
* **What it does**: A standalone real-time monitor that displays a continuous in-terminal moving ASCII bandwidth waveform graph (`Render-BandwidthMovementGraph`) alongside an active table of discovered network clients and their estimated throughput.

### 9. `Modules/RouterTools.psm1` (Router Utilities & Remote Management)
* **Author**: `diogeneslite`
* **What it does**: Provides helper tools for router testing: fast TCP port verification (`Test-PortOpen`), router status overview (`Get-RouterOverview`), hop-by-hop latency traceroutes (`Invoke-RouterTraceroute`), and direct terminal launcher (`Connect-DeviceTerminal`) for SSH, Telnet, or browser sessions.

### 10. `Modules/SpeedTest.psm1` (Multi-Provider Speed Engine)
* **Author**: `diogeneslite`
* **What it does**: A dedicated network throughput testing engine that tests transfer speeds against multiple high-bandwidth edge CDNs (Cloudflare, Fastly, AWS, Node.js distribution mirrors).

### 11. `Modules/StabilityAudit.psm1` (Deep Stability & Long-Run Ping Suite)
* **Author**: `diogeneslite`
* **What it does**: Performs extended latency testing (`Test-GatewayStability`) and multi-resolver DNS benchmarking (`Test-DnsBenchmark`) for deep diagnostic drill-downs.

### 12. `diag_network.ps1` (Diagnostic & Protocol Probing Helper)
* **Author**: `diogeneslite`
* **What it does**: A developer diagnostic script used to test router APIs (such as Huawei HiLink endpoints), SSDP/UPnP M-SEARCH discovery, and NetBIOS / reverse DNS name resolution behavior across subnet devices.

---

## 🚀 How to Run ProNetwork11

### Option 1: One-Click Launch (Interactive Dashboard)
Double-click **`pronetwork11.cmd`** in Windows Explorer, or run:
```powershell
.\pronetwork11.cmd
```

Or directly from PowerShell:
```powershell
.\pronetwork11.ps1
```

### Option 2: Direct CLI Switches (Automated & Scriptable)
Run specific diagnostic paths directly without entering the interactive menu:

```powershell
# Run Path 1: Statistical Benchmarks, Jitter, DNS & Speed Tests
.\pronetwork11.ps1 -Benchmark

# Run Path 2: Subnet Device Discovery, Hardware Vendors & Web Audit
.\pronetwork11.ps1 -ScanDevices

# Run Path 3: Router Health, Wi-Fi Security & Configuration Audit
.\pronetwork11.ps1 -RouterHealth

# Run continuous live router bandwidth monitor
.\pronetwork11.ps1 -LiveBandwidth

# Run all three paths sequentially
.\pronetwork11.ps1 -All
```

---

## 📂 Repository Layout

```
pronetwork11/
├── pronetwork11.ps1                 # Main zero-scroll interactive CLI entry point
├── pronetwork11.cmd                 # Windows one-click batch launcher
├── diag_network.ps1                 # Router API & hostname resolution diagnostic script
├── LICENSE                          # MIT License (diogeneslite)
├── README.md                        # Documentation
├── .gitignore                       # Git ignore configuration
└── Modules/
    ├── UI.psm1                      # ANSI Tri-Color styling, headers & row formatters
    ├── NetworkInfo.psm1             # Network & router overview, MAC OUI & bandwidth graph
    ├── NetworkBenchmarks.psm1       # Path 1: Statistical benchmarks, jitter & health score
    ├── DeviceScanner.psm1           # Path 2: Subnet device discovery & web directory audit
    ├── RouterSecurity.psm1          # Path 3: Router health, Wi-Fi ciphers & WPS security
    ├── DeviceDiscovery.psm1         # Live continuous bandwidth & device traffic monitor
    ├── RouterTools.psm1             # Fast port tester, traceroute & terminal launcher
    ├── SpeedTest.psm1               # Multi-provider CDN download throughput engine
    └── StabilityAudit.psm1          # Deep gateway stability & DNS benchmark suite
```

---

## 👤 Author

Developed and maintained by **[diogeneslite](https://github.com/diogeneslite)**.  
Feedback, issues, and contributions are welcome on GitHub!

---

## 📜 License

This project is licensed under the [MIT License](LICENSE) &copy; 2026 **diogeneslite**.
