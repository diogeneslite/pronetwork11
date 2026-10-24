# ⚡ ProNetwork11

[![Platform](https://img.shields.io/badge/Platform-Windows%2011%20%7C%2010-0078D6.svg?logo=windows)](https://microsoft.com)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE.svg?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Dependencies](https://img.shields.io/badge/Dependencies-Zero%20External-success.svg)](#-zero-installation--dependencies)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **Zero-Setup, In-Place Windows 11 Network Intelligence & Diagnostic Operations Toolkit**  
> An all-in-one, terminal-friendly dashboard to test speed, find connected devices, and secure your router.

---

## 🌟 What is ProNetwork11? (Beginner-Friendly Overview)

Have you ever experienced sudden lag spikes in an online game, wondered why your video stream is buffering, or asked yourself: *"Is someone else using my Wi-Fi?"*

Normally, finding answers on Windows requires digging through confusing settings menus or running clunky command-line tools (`ping`, `tracert`, `netsh`, `ipconfig`, `arp`) that flood your screen with hundreds of lines of technical jargon.

**ProNetwork11** simplifies all of this into a single, clean dashboard:
* **No installations needed**: It uses the built-in PowerShell and Windows tools already on your PC. No Python, no Node.js, and no shady third-party `.exe` downloads.
* **Zero-Scroll Dashboard**: Everything fits neatly on your terminal screen without scrolling away.
* **Live Speedometer**: Shows real-time upload and download throughput between your computer and router using a flicker-free in-place meter.
* **Easy-to-Read Colors**:
  * 🟢 **Green**: Everything is fast and secure.
  * 🟡 **Amber**: Minor warning or recommendation for improvement.
  * 🔴 **Red**: Problem found (packet loss, open insecure ports, outdated security).

---

## 🚀 Quick Start (Anyone Can Run This in 10 Seconds)

You don't need any programming or networking experience to use ProNetwork11:

### Step 1: Download or Clone
Download this repository as a ZIP (and extract it), or clone it:
```bash
git clone https://github.com/diogeneslite/pronetwork11.git
```

### Step 2: Launch with One Click
In Windows Explorer, open the `pronetwork11` folder and **double-click `pronetwork11.cmd`**.

*(Alternatively, open PowerShell in that folder and run `.\pronetwork11.ps1`)*

### Step 3: Choose What You Want to Do
When the dashboard opens, simply press **`1`**, **`2`**, or **`3`** on your keyboard:
* **Press `1`** to test your connection speed, ping, jitter, and gaming stability.
* **Press `2`** to see every device connected to your Wi-Fi / local network.
* **Press `3`** to check your router's security settings and get tips on fixing vulnerabilities.
* **Press `0`** to exit anytime.

---

## 🎛️ The 3 Modes: What They Do For You

### 1️⃣ Mode 1: Network Tests & Comprehensive Benchmarks
* **Who it's for**: Anyone experiencing slow internet, laggy games, or choppy Zoom/Discord calls.
* **What it checks**:
  * **Router Ping & Jitter**: Tests whether lag is coming from your Wi-Fi signal or your ISP.
  * **Internet Backbone Latency**: Measures the delay to global high-speed servers (Cloudflare Anycast).
  * **Packet Loss**: Tests whether your connection is dropping data packets.
  * **DNS Benchmark**: Tests the speed of your current DNS against popular secure alternatives (Cloudflare `1.1.1.1`, Google `8.8.8.8`, Quad9 `9.9.9.9`).
  * **Download Speed Test**: Measures your real-world download speed against reliable content delivery networks.
  * **Health Score**: Gives your connection an overall score from 0 to 100 with actionable feedback.

### 2️⃣ Mode 2: Local Network Device Discovery & Web Audit
* **Who it's for**: Anyone wanting to know what devices are sharing their Wi-Fi or looking for smart devices.
* **What it checks**:
  * **Device Scanner**: Scans your local subnet to find connected smartphones (iPhones, Android), smart TVs, laptops, and IoT devices.
  * **Name & Brand Recognition**: Automatically matches hardware addresses (MAC OUI) and network broadcasts (mDNS, NetBIOS) to show friendly device names and manufacturers (Apple, Samsung, Google Cast, etc.).
  * **Admin Port Scanner**: Checks if devices have open management ports (Web Port 80/443, SSH, Telnet).
  * **Web Page Probing**: If a router or smart device hosts a web page, it automatically discovers login portals and configuration directories (`/admin`, `/login`, `/api`, etc.).

### 3️⃣ Mode 3: Router Health & Security Audit
* **Who it's for**: Anyone who wants to make sure their home Wi-Fi and router are protected against intruders.
* **What it checks**:
  * **Wi-Fi Encryption Standard**: Verifies if your network is protected by modern WPA2/WPA3 encryption or vulnerable legacy ciphers (WEP/TKIP/Open).
  * **WPS Vulnerability Check**: Warns if Wi-Fi Protected Setup PIN features are active, which can allow attackers to brute-force your password in minutes.
  * **Connection Bottleneck Detection**: Compares your Wi-Fi link speed against your adapter's full capacity to tell you if you're too far from the router.
  * **Insecure Remote Access**: Alerts you if unencrypted remote management (such as Telnet) or exposed web administration is enabled.
  * **Plain-English Recommendations**: Explains exactly what settings to change in your router to keep your home network secure.

---

## ⚡ Power Users & Automation (Direct CLI Switches)

If you want to run specific tests automatically or incorporate them into scripts, scheduled tasks, or monitoring workflows, you can pass command-line arguments directly:

```powershell
# Run Mode 1: Statistical Benchmarks, Jitter, DNS & Speed Tests
.\pronetwork11.ps1 -Benchmark

# Run Mode 2: Subnet Device Discovery, Hardware Vendors & Web Audit
.\pronetwork11.ps1 -ScanDevices

# Run Mode 3: Router Health, Wi-Fi Security & Configuration Audit
.\pronetwork11.ps1 -RouterHealth

# Launch continuous live router bandwidth monitor
.\pronetwork11.ps1 -LiveBandwidth

# Run all diagnostic modes sequentially in one go
.\pronetwork11.ps1 -All
```

---

## 📦 Zero Installation & Dependencies

ProNetwork11 is designed to be completely lightweight and self-contained:

| Requirement | Details |
| :--- | :--- |
| **External Packages** | **None.** No Node.js/npm, no Python, no NuGet packages, and no third-party `.exe` downloads. |
| **Operating System** | **Windows 11** (recommended) or **Windows 10**. |
| **PowerShell Version** | **Windows PowerShell 5.1** (pre-installed on Windows) or **PowerShell 7+ (Core)**. |
| **APIs Used** | Native .NET networking libraries (`System.Net.Sockets`, `System.Net.NetworkInformation`, `System.Net.Dns`, `System.Net.WebClient`). |
| **Permissions** | Normal user accounts work for general diagnostics. **Administrator privileges** are recommended for full subnet ARP sweeps and protected Wi-Fi adapter queries. |
| **Execution Policy** | Launching via `pronetwork11.cmd` automatically uses `-ExecutionPolicy Bypass` for the running process without permanently altering your system configuration. |

---

## 🧩 Modular Architecture

The project is structured into modular components, making it clean, easy to read, and simple to extend:

* **`pronetwork11.ps1`**: Main entry point, zero-scroll terminal interface, and interactive menu loop.
* **`pronetwork11.cmd`**: One-click batch launcher for Windows Explorer.
* **`diag_network.ps1`**: Standalone diagnostic script to test router APIs, UPnP discovery, and device name resolution.
* **`Modules/UI.psm1`**: ANSI 24-bit tri-color rendering, headers, dividers, score badges, and user greeting formatters.
* **`Modules/NetworkInfo.psm1`**: Hardware network adapter telemetry, MAC OUI vendor matching, and live bandwidth meter calculations.
* **`Modules/NetworkBenchmarks.psm1`**: Mode 1 statistical ICMP probes, latency sampling, RF jitter math, DNS comparisons, and health scoring.
* **`Modules/DeviceScanner.psm1`**: Mode 2 ARP discovery, mDNS listeners, NetBIOS resolution, TCP port scanner, and web directory auditor.
* **`Modules/RouterSecurity.psm1`**: Mode 3 Wi-Fi cipher auditing, WPS vulnerability checks, link speed saturation analysis, and security advice.
* **`Modules/DeviceDiscovery.psm1`**: Live continuous moving ASCII bandwidth waveform graph and active client monitor.
* **`Modules/RouterTools.psm1`**: TCP port tester, router overview helper, hop-by-hop traceroute, and terminal connection launcher.
* **`Modules/SpeedTest.psm1`**: Multi-provider high-speed CDN throughput testing engine.
* **`Modules/StabilityAudit.psm1`**: Extended multi-sample ping stability and DNS benchmark test suite.

---

## 📂 Repository Layout

```
pronetwork11/
├── pronetwork11.ps1                 # Main zero-scroll interactive CLI entry point
├── pronetwork11.cmd                 # Windows one-click batch launcher
├── diag_network.ps1                 # Router API & hostname resolution diagnostic script
├── LICENSE                          # MIT License
├── README.md                        # Project documentation
├── .gitignore                       # Git ignore rules
├── .gitattributes                   # Cross-platform line ending normalization
└── Modules/
    ├── UI.psm1                      # ANSI Tri-Color styling, headers & row formatters
    ├── NetworkInfo.psm1             # Network & router overview, MAC OUI & bandwidth graph
    ├── NetworkBenchmarks.psm1       # Mode 1: Statistical benchmarks, jitter & health score
    ├── DeviceScanner.psm1           # Mode 2: Subnet device discovery & web directory audit
    ├── RouterSecurity.psm1          # Mode 3: Router health, Wi-Fi ciphers & WPS security
    ├── DeviceDiscovery.psm1         # Live continuous bandwidth & device traffic monitor
    ├── RouterTools.psm1             # Fast port tester, traceroute & terminal launcher
    ├── SpeedTest.psm1               # Multi-provider CDN download throughput engine
    └── StabilityAudit.psm1          # Deep gateway stability & DNS benchmark suite
```

---

## 👤 Author & License

Created and maintained by **[diogeneslite](https://github.com/diogeneslite)**. Contributions and feedback are welcome!

This project is open-source and released under the [MIT License](LICENSE).
