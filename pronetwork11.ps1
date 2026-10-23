<#
.SYNOPSIS
    ProNetwork11 - Windows 11 Network Operations, Benchmarks & Diagnostics Hub
    Author: diogeneslite (https://github.com/diogeneslite)
.DESCRIPTION
    A minimal, to-the-point PowerShell network intelligence toolkit engineered exclusively for Windows 11.
    Created by diogeneslite.
    Features:
    - Minimal, zero-scroll main dashboard with instant hardware, link speed & subnet overview
    - Live router downlink/uplink bandwidth meter with MAC OUI lookup
    - Path 1: Single-line network tests and benchmarks (Speed, jitter, latency, health score, DNS benchmarks, packet loss, gateway jitters)
    - Path 2: Local network device discovery (Router & clients, hostnames, vendors, port scan, hosted webpages & directories)
    - Path 3: Router health & security audit (Link speed, Wi-Fi encryption, WPS warnings, remote management exposure)
#>

[CmdletBinding()]
param(
    [Alias("Tests", "SpeedTest")]
    [switch]$Benchmark,

    [Alias("Discovery")]
    [switch]$ScanDevices,

    [Alias("Security", "Router")]
    [switch]$RouterHealth,

    [switch]$LiveBandwidth,
    [switch]$All
)

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$null = Import-Module (Join-Path $scriptDir "Modules\UI.psm1") -PassThru -Force -DisableNameChecking
$null = Import-Module (Join-Path $scriptDir "Modules\NetworkInfo.psm1") -PassThru -Force -DisableNameChecking
$null = Import-Module (Join-Path $scriptDir "Modules\NetworkBenchmarks.psm1") -PassThru -Force -DisableNameChecking
$null = Import-Module (Join-Path $scriptDir "Modules\DeviceScanner.psm1") -PassThru -Force -DisableNameChecking
$null = Import-Module (Join-Path $scriptDir "Modules\RouterSecurity.psm1") -PassThru -Force -DisableNameChecking






function Show-DashboardHeader {
    param([PSCustomObject]$NetInfo)

    Clear-Host
    Write-CompactHeader

    # Compact 3-line Network & Router Hardware Overview
    Write-Host "  ${global:C_BLUE}${global:C_BOLD}[*] NETWORK & ROUTER HARDWARE OVERVIEW${global:C_RESET}"
    Write-Host "     ${global:C_BLUE}Network Used :${global:C_RESET} ${global:C_BOLD}$($NetInfo.ConnectionType) ($($NetInfo.NetworkName))${global:C_RESET} ${global:C_GRAY}|${global:C_RESET} ${global:C_BLUE}Link Speed:${global:C_RESET} ${global:C_GREEN}$($NetInfo.LinkSpeed)${global:C_RESET} ${global:C_GRAY}|${global:C_RESET} ${global:C_BLUE}Tech:${global:C_RESET} $($NetInfo.MediaTechnology)"
    Write-Host "     ${global:C_BLUE}Router Info  :${global:C_RESET} ${global:C_GREEN}$($NetInfo.RouterName)${global:C_RESET} ${global:C_GRAY}[Gateway: $($NetInfo.GatewayIPv4) | MAC: $($NetInfo.GatewayMac)]${global:C_RESET}"
    Write-Host "     ${global:C_BLUE}IP & Subnet  :${global:C_RESET} IPv4: ${global:C_BOLD}$($NetInfo.LocalIPv4)$($NetInfo.SubnetPrefix)${global:C_RESET} ${global:C_GRAY}|${global:C_RESET} DNS: $($NetInfo.DnsServers -join ', ') ${global:C_GRAY}|${global:C_RESET} Public IP: $($NetInfo.PublicIP)"
    Write-CompactDivider

    $routerDisplayName = if ($NetInfo.RouterName) { $NetInfo.RouterName } else { "Gateway Router" }
    $gwIp = if ($NetInfo.GatewayIPv4) { $NetInfo.GatewayIPv4 } else { "192.168.1.1" }
    $gwMac = if ($NetInfo.GatewayMac) { $NetInfo.GatewayMac } else { "Unknown MAC" }

    Write-Host "  ${global:C_BLUE}${global:C_BOLD}[+] LIVE ROUTER BANDWIDTH CONNECTION: ${global:C_GREEN}$routerDisplayName${global:C_RESET} ${global:C_GRAY}[$gwIp | $gwMac]${global:C_RESET}"

    $downRow = -1
    $upRow = -1
    $waveRow = -1
    try { $downRow = [Console]::CursorTop } catch {}

    Write-Host "     ${global:C_BLUE}Downlink [Rx]${global:C_RESET} : ${global:C_GREEN}[>..................................]${global:C_RESET} ${global:C_BOLD}  0.00 Mbps${global:C_RESET} ${global:C_GRAY}(0.0 KB/s)${global:C_RESET}"
    try { $upRow = [Console]::CursorTop } catch {}

    Write-Host "     ${global:C_BLUE}Uplink   [Tx]${global:C_RESET} : ${global:C_BLUE}[>..................................]${global:C_RESET} ${global:C_BOLD}  0.00 Mbps${global:C_RESET} ${global:C_GRAY}(0.0 KB/s)${global:C_RESET}"
    try { $waveRow = [Console]::CursorTop } catch {}

    Write-Host "     ${global:C_BLUE}Activity Wave${global:C_RESET} : ${global:C_GREEN}[ | - = # * # = - | | - = # * # = - | ]${global:C_RESET} ${global:C_GRAY}Link: $($NetInfo.LinkSpeed) | Full Duplex | Live Throughput${global:C_RESET}"

    Write-CompactDivider

    return @{ DownRow = $downRow; UpRow = $upRow; WaveRow = $waveRow }
}

function Get-DashboardMenuChoice {
    param(
        [PSCustomObject]$NetInfo,
        [hashtable]$GraphRows
    )

    $canUseCursor = ($GraphRows.DownRow -ge 0 -and $GraphRows.UpRow -ge 0)
    $isInteractive = $false
    if ($canUseCursor) {
        try {
            $null = [Console]::KeyAvailable
            $null = [Console]::CursorTop
            $isInteractive = $true
        } catch {
            $isInteractive = $false
        }
    }

    if (-not $isInteractive) {
        return (Read-Host)
    }

    $barWidth = 35
    $scaleMax = 50.0
    if ($NetInfo.LinkSpeed -match '(\d+)') {
        $parsed = [double]$matches[1]
        if ($parsed -gt 10) { $scaleMax = [Math]::Min(100.0, $parsed) }
    }

    $waveFrames = @(
        "| - = # * # = - | | - = # * # = - |",
        "- = # * # = - | | - = # * # = - | -",
        "= # * # = - | | - = # * # = - | - =",
        "# * # = - | | - = # * # = - | - = #",
        "* # = - | | - = # * # = - | - = # *",
        "# = - | | - = # * # = - | | - = # =",
        "= - | | - = # * # = - | | - = # * -"
    )
    $frameIdx = 0
    $prevStats = Get-LiveDownUpBytes
    $lastUpdateSw = [System.Diagnostics.Stopwatch]::StartNew()

    while ($true) {
        try {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                $char = $key.KeyChar
                if ($char -in @('1', '2', '3', '0', 'q', 'Q')) {
                    Write-Host "$char"
                    return [string]$char
                }
            }
        } catch {
            return (Read-Host)
        }

        Start-Sleep -Milliseconds 100

        # Update live router bandwidth graph in-place without terminal refresh
        if ($lastUpdateSw.ElapsedMilliseconds -ge 500) {
            $dt = [Math]::Max(0.15, $lastUpdateSw.Elapsed.TotalSeconds)
            $lastUpdateSw.Restart()

            $currStats = Get-LiveDownUpBytes
            $rxDelta = [Math]::Max(0, ($currStats.Rx - $prevStats.Rx))
            $txDelta = [Math]::Max(0, ($currStats.Tx - $prevStats.Tx))
            $prevStats = $currStats

            $downMbps = [Math]::Round(($rxDelta * 8) / ($dt * 1000000), 2)
            $upMbps   = [Math]::Round(($txDelta * 8) / ($dt * 1000000), 2)

            $downFill = [Math]::Min($barWidth, [Math]::Max(1, [int](($downMbps / $scaleMax) * $barWidth)))
            $upFill   = [Math]::Min($barWidth, [Math]::Max(1, [int](($upMbps / $scaleMax) * $barWidth)))

            $downBar = ("=" * ($downFill - 1)) + ">" + ("." * ($barWidth - $downFill))
            $upBar   = ("=" * ($upFill - 1)) + ">" + ("." * ($barWidth - $upFill))

            $frameIdx = ($frameIdx + 1) % $waveFrames.Count
            $curFrame = $waveFrames[$frameIdx]

            try {
                $savedLeft = [Console]::CursorLeft
                $savedTop  = [Console]::CursorTop

                [Console]::SetCursorPosition(0, $GraphRows.DownRow)
                Write-Host "     ${global:C_BLUE}Downlink [Rx]${global:C_RESET} : ${global:C_GREEN}[$downBar]${global:C_RESET} ${global:C_BOLD}$($downMbps.ToString('0.00').PadLeft(6)) Mbps${global:C_RESET} ${global:C_GRAY}($(([Math]::Round($rxDelta / 1024 / $dt, 1)).ToString()) KB/s)${global:C_RESET}$($global:ESC)[K"

                [Console]::SetCursorPosition(0, $GraphRows.UpRow)
                Write-Host "     ${global:C_BLUE}Uplink   [Tx]${global:C_RESET} : ${global:C_BLUE}[$upBar]${global:C_RESET} ${global:C_BOLD}$($upMbps.ToString('0.00').PadLeft(6)) Mbps${global:C_RESET} ${global:C_GRAY}($(([Math]::Round($txDelta / 1024 / $dt, 1)).ToString()) KB/s)${global:C_RESET}$($global:ESC)[K"

                [Console]::SetCursorPosition(0, $GraphRows.WaveRow)
                Write-Host "     ${global:C_BLUE}Activity Wave${global:C_RESET} : ${global:C_GREEN}[ $curFrame ]${global:C_RESET} ${global:C_GRAY}Link: $($NetInfo.LinkSpeed) | Full Duplex | Live Throughput${global:C_RESET}$($global:ESC)[K"

                [Console]::SetCursorPosition($savedLeft, $savedTop)
            } catch {}
        }
    }
}

# 1. Fetch initial network telemetry
$netOverview = Get-ProNetworkOverview

# 2. Support non-interactive CLI flag workflows
if ($Benchmark) {
    [void](Show-DashboardHeader -NetInfo $netOverview)
    Invoke-AllNetworkBenchmarks -GatewayIp $netOverview.GatewayIPv4 -DnsServers $netOverview.DnsServers
    exit 0
}

if ($ScanDevices) {
    [void](Show-DashboardHeader -NetInfo $netOverview)
    Invoke-LocalNetworkDiscovery -LocalIp $netOverview.LocalIPv4 -GatewayIp $netOverview.GatewayIPv4
    exit 0
}

if ($RouterHealth) {
    [void](Show-DashboardHeader -NetInfo $netOverview)
    Invoke-RouterSecurityAudit -NetInfo $netOverview
    exit 0
}

if ($LiveBandwidth) {
    [void](Show-DashboardHeader -NetInfo $netOverview)
    Show-RouterBandwidthGraph -NetInfo $netOverview -SampleDurationMs 800 -Continuous
    exit 0
}

if ($All) {
    [void](Show-DashboardHeader -NetInfo $netOverview)
    Invoke-AllNetworkBenchmarks -GatewayIp $netOverview.GatewayIPv4 -DnsServers $netOverview.DnsServers
    Invoke-LocalNetworkDiscovery -LocalIp $netOverview.LocalIPv4 -GatewayIp $netOverview.GatewayIPv4
    Invoke-RouterSecurityAudit -NetInfo $netOverview
    exit 0
}

# 3. Interactive Main Loop - Clean, Minimal & Zero-Scroll
$userGreeting = Get-FriendlyUserName

do {
    $graphRows = Show-DashboardHeader -NetInfo $netOverview

    # Welcome Text using human language guessed from hostname / Windows account
    Write-Host "  ${global:C_BLUE}${global:C_BOLD}Welcome $userGreeting, what would you like to do?${global:C_RESET}`n"
    Write-Host "   ${global:C_GREEN}${global:C_BOLD}[1]${global:C_RESET} ${global:C_BOLD}Network tests and benchmarks${global:C_RESET}"
    Write-Host "       ${global:C_GRAY}Speed, jitter, latency, network health tests, dns benchmarks, packet loss, gateway jitters${global:C_RESET}`n"
    Write-Host "   ${global:C_BLUE}${global:C_BOLD}[2]${global:C_RESET} ${global:C_BOLD}Local network device discovery${global:C_RESET}"
    Write-Host "       ${global:C_GRAY}Router & connected devices, hostnames & vendors, port scan, hosted webpages & directories${global:C_RESET}`n"
    Write-Host "   ${global:C_AMBER}${global:C_BOLD}[3]${global:C_RESET} ${global:C_BOLD}Router health and potential issues${global:C_RESET}"
    Write-Host "       ${global:C_GRAY}Link speed diagnostics, Wi-Fi encryption audit, WPS PIN warnings, remote admin security${global:C_RESET}`n"
    Write-Host "   ${global:C_RED}${global:C_BOLD}[0]${global:C_RESET} ${global:C_GRAY}Exit${global:C_RESET}"
    Write-CompactDivider

    Write-Host "  Enter your choice [1-3, or 0 to exit]: " -NoNewline

    $rawChoice = Get-DashboardMenuChoice -NetInfo $netOverview -GraphRows $graphRows
    $choice = if ($rawChoice) { $rawChoice.Trim() } else { "0" }

    switch ($choice) {
        "1" {
            Invoke-AllNetworkBenchmarks -GatewayIp $netOverview.GatewayIPv4 -DnsServers $netOverview.DnsServers
            Write-Host "`n  Press Enter to return to the dashboard..." -ForegroundColor Gray
            [void][Console]::ReadLine()
            # Refresh network telemetry on return
            $netOverview = Get-ProNetworkOverview
        }
        "2" {
            Invoke-LocalNetworkDiscovery -LocalIp $netOverview.LocalIPv4 -GatewayIp $netOverview.GatewayIPv4
            Write-Host "`n  Press Enter to return to the dashboard..." -ForegroundColor Gray
            [void][Console]::ReadLine()
            $netOverview = Get-ProNetworkOverview
        }
        "3" {
            Invoke-RouterSecurityAudit -NetInfo $netOverview
            Write-Host "`n  Press Enter to return to the dashboard..." -ForegroundColor Gray
            [void][Console]::ReadLine()
            $netOverview = Get-ProNetworkOverview
        }
        { $_ -in @("0", "q", "Q") } {
            Write-Host "`n  ${global:C_GREEN}Thank you for using ProNetwork11. Goodbye, $userGreeting!${global:C_RESET}`n"
            break
        }
        Default {
            Write-Host "`n  ${global:C_RED}Invalid option selected. Please select 1, 2, 3, or 0.${global:C_RESET}"
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -notin @("0", "q", "Q"))
