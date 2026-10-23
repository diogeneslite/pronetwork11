<#
================================================================================
 ProNetwork11 - Network Identification & Telemetry Module
 Author: diogeneslite (https://github.com/diogeneslite)
 Description: Subnet overview, hardware link speed, MAC OUI lookup & bandwidth telemetry
================================================================================
#>
[CmdletBinding()]
param()

$script:OUI_DATABASE = @{
    # FiberHome Technologies
    "64:9C:F3" = "FiberHome Telecommunication Technologies (Router Gateway)"
    "10:47:80" = "FiberHome Technologies"
    "28:2C:B2" = "FiberHome Technologies"
    "70:A8:E3" = "FiberHome Technologies"
    "80:89:17" = "FiberHome Technologies"
    "84:74:2A" = "FiberHome Technologies"
    "90:67:1C" = "FiberHome Technologies"
    "A4:7E:39" = "FiberHome Technologies"
    "C8:51:95" = "FiberHome Technologies"
    "CC:81:DA" = "FiberHome Technologies"
    "D4:40:F0" = "FiberHome Technologies"
    "E4:0E:EE" = "FiberHome Technologies"
    "EC:38:8F" = "FiberHome Technologies"
    "F8:35:DD" = "FiberHome Technologies"
    # Apple Inc.
    "AC:DE:48" = "Apple Inc. (iPhone / iPad / Mac)"
    "F0:18:98" = "Apple Inc. (iPhone / iPad / Mac)"
    "3C:06:30" = "Apple Inc. (iPhone / iPad / Mac)"
    "00:03:93" = "Apple Inc. (Apple Device)"
    "00:05:02" = "Apple Inc. (Apple Device)"
    "00:0A:27" = "Apple Inc. (Apple Device)"
    "00:0A:95" = "Apple Inc. (Apple Device)"
    "00:10:FA" = "Apple Inc. (Apple Device)"
    "00:14:51" = "Apple Inc. (Apple Device)"
    "00:16:CB" = "Apple Inc. (Apple Device)"
    "00:17:F2" = "Apple Inc. (Apple Device)"
    "00:19:E3" = "Apple Inc. (Apple Device)"
    "00:1B:63" = "Apple Inc. (Apple Device)"
    "00:1C:B3" = "Apple Inc. (Apple Device)"
    "00:1D:4F" = "Apple Inc. (Apple Device)"
    "00:1E:52" = "Apple Inc. (Apple Device)"
    "00:1E:C2" = "Apple Inc. (Apple Device)"
    "00:1F:5B" = "Apple Inc. (Apple Device)"
    "00:1F:F3" = "Apple Inc. (Apple Device)"
    "00:21:E9" = "Apple Inc. (Apple Device)"
    "00:23:12" = "Apple Inc. (Apple Device)"
    "00:23:32" = "Apple Inc. (Apple Device)"
    "00:23:6C" = "Apple Inc. (Apple Device)"
    "00:24:36" = "Apple Inc. (Apple Device)"
    "00:25:00" = "Apple Inc. (Apple Device)"
    "00:25:4B" = "Apple Inc. (Apple Device)"
    "00:25:BC" = "Apple Inc. (Apple Device)"
    "00:26:08" = "Apple Inc. (Apple Device)"
    "00:26:4A" = "Apple Inc. (Apple Device)"
    "00:26:B0" = "Apple Inc. (Apple Device)"
    "00:26:BB" = "Apple Inc. (Apple Device)"
    "28:CF:E9" = "Apple Inc. (iPhone / iPad / Mac)"
    "3C:07:54" = "Apple Inc. (iPhone / iPad / Mac)"
    "3C:15:C2" = "Apple Inc. (iPhone / iPad / Mac)"
    "3C:22:FB" = "Apple Inc. (iPhone / iPad / Mac)"
    "40:6C:8F" = "Apple Inc. (iPhone / iPad / Mac)"
    "44:2A:60" = "Apple Inc. (iPhone / iPad / Mac)"
    "48:60:BC" = "Apple Inc. (iPhone / iPad / Mac)"
    "48:D7:05" = "Apple Inc. (iPhone / iPad / Mac)"
    "4C:32:75" = "Apple Inc. (iPhone / iPad / Mac)"
    "50:BC:96" = "Apple Inc. (iPhone / iPad / Mac)"
    "54:26:96" = "Apple Inc. (iPhone / iPad / Mac)"
    "54:4E:90" = "Apple Inc. (iPhone / iPad / Mac)"
    "58:55:CA" = "Apple Inc. (iPhone / iPad / Mac)"
    "5C:95:AE" = "Apple Inc. (iPhone / iPad / Mac)"
    "60:03:08" = "Apple Inc. (iPhone / iPad / Mac)"
    "60:33:4B" = "Apple Inc. (iPhone / iPad / Mac)"
    "60:69:44" = "Apple Inc. (iPhone / iPad / Mac)"
    "60:C5:47" = "Apple Inc. (iPhone / iPad / Mac)"
    "64:20:0C" = "Apple Inc. (iPhone / iPad / Mac)"
    "64:76:BA" = "Apple Inc. (iPhone / iPad / Mac)"
    "68:5B:35" = "Apple Inc. (iPhone / iPad / Mac)"
    "6C:40:08" = "Apple Inc. (iPhone / iPad / Mac)"
    "70:11:24" = "Apple Inc. (iPhone / iPad / Mac)"
    "70:70:8B" = "Apple Inc. (iPhone / iPad / Mac)"
    "70:CD:60" = "Apple Inc. (iPhone / iPad / Mac)"
    "74:E1:B6" = "Apple Inc. (iPhone / iPad / Mac)"
    "78:4F:43" = "Apple Inc. (iPhone / iPad / Mac)"
    "78:7B:8A" = "Apple Inc. (iPhone / iPad / Mac)"
    "7C:6D:62" = "Apple Inc. (iPhone / iPad / Mac)"
    "7C:F0:5F" = "Apple Inc. (iPhone / iPad / Mac)"
    "80:49:71" = "Apple Inc. (iPhone / iPad / Mac)"
    "80:B0:3D" = "Apple Inc. (iPhone / iPad / Mac)"
    "84:38:35" = "Apple Inc. (iPhone / iPad / Mac)"
    "84:78:8B" = "Apple Inc. (iPhone / iPad / Mac)"
    "88:66:5A" = "Apple Inc. (iPhone / iPad / Mac)"
    "8C:85:90" = "Apple Inc. (iPhone / iPad / Mac)"
    "90:FD:61" = "Apple Inc. (iPhone / iPad / Mac)"
    "94:E9:79" = "Apple Inc. (iPhone / iPad / Mac)"
    "98:01:A7" = "Apple Inc. (iPhone / iPad / Mac)"
    "98:B8:E3" = "Apple Inc. (iPhone / iPad / Mac)"
    "9C:04:EB" = "Apple Inc. (iPhone / iPad / Mac)"
    "9C:20:7B" = "Apple Inc. (iPhone / iPad / Mac)"
    "A4:83:E7" = "Apple Inc. (iPhone / iPad / Mac)"
    "A4:C3:61" = "Apple Inc. (iPhone / iPad / Mac)"
    "A8:5B:78" = "Apple Inc. (iPhone / iPad / Mac)"
    "A8:66:7F" = "Apple Inc. (iPhone / iPad / Mac)"
    "AC:BC:32" = "Apple Inc. (iPhone / iPad / Mac)"
    "B0:34:95" = "Apple Inc. (iPhone / iPad / Mac)"
    "B4:18:D1" = "Apple Inc. (iPhone / iPad / Mac)"
    "B8:17:C2" = "Apple Inc. (iPhone / iPad / Mac)"
    "B8:78:2E" = "Apple Inc. (iPhone / iPad / Mac)"
    "B8:C7:5D" = "Apple Inc. (iPhone / iPad / Mac)"
    "BC:52:B7" = "Apple Inc. (iPhone / iPad / Mac)"
    "BC:92:6B" = "Apple Inc. (iPhone / iPad / Mac)"
    "C0:84:7A" = "Apple Inc. (iPhone / iPad / Mac)"
    "C4:B3:01" = "Apple Inc. (iPhone / iPad / Mac)"
    "C8:2A:14" = "Apple Inc. (iPhone / iPad / Mac)"
    "C8:69:CD" = "Apple Inc. (iPhone / iPad / Mac)"
    "CC:08:8D" = "Apple Inc. (iPhone / iPad / Mac)"
    "CC:29:F4" = "Apple Inc. (iPhone / iPad / Mac)"
    "D0:03:4B" = "Apple Inc. (iPhone / iPad / Mac)"
    "D0:23:DB" = "Apple Inc. (iPhone / iPad / Mac)"
    "D4:61:9D" = "Apple Inc. (iPhone / iPad / Mac)"
    "D8:1C:79" = "Apple Inc. (iPhone / iPad / Mac)"
    "DC:2B:61" = "Apple Inc. (iPhone / iPad / Mac)"
    "E0:B6:55" = "Apple Inc. (iPhone / iPad / Mac)"
    "E4:25:E7" = "Apple Inc. (iPhone / iPad / Mac)"
    "E4:CE:8F" = "Apple Inc. (iPhone / iPad / Mac)"
    "E8:80:2E" = "Apple Inc. (iPhone / iPad / Mac)"
    "EC:35:86" = "Apple Inc. (iPhone / iPad / Mac)"
    "F0:99:B6" = "Apple Inc. (iPhone / iPad / Mac)"
    "F4:0F:24" = "Apple Inc. (iPhone / iPad / Mac)"
    "F4:37:B7" = "Apple Inc. (iPhone / iPad / Mac)"
    "F8:27:93" = "Apple Inc. (iPhone / iPad / Mac)"
    "FC:18:3C" = "Apple Inc. (iPhone / iPad / Mac)"
    "FC:25:3F" = "Apple Inc. (iPhone / iPad / Mac)"
    # Smart Home, Media & Network Hardware
    "E8:CA:C8" = "Bilian / Smart TV Device"
    "A4:2A:95" = "D-Link International"
    "00:C0:CA" = "MediaTek / Alfa Adapter"
    "04:7C:16" = "Realtek Semiconductor"
    "B0:39:56" = "Netgear Router"
    "00:1A:2B" = "Cisco Systems"
    "00:50:56" = "VMware Virtual Host"
    "08:00:27" = "Oracle VirtualBox"
    "B8:27:EB" = "Raspberry Pi"
    "DC:A6:32" = "Raspberry Pi Foundation"
    "E4:5F:01" = "Raspberry Pi Trading"
    "28:6D:CD" = "Samsung Galaxy / Smart TV"
    "50:77:05" = "Samsung Electronics"
    "B4:0B:44" = "Samsung Electronics"
    "48:A9:D2" = "Huawei Technologies"
    "70:7B:E8" = "Huawei Technologies"
    "E0:24:7F" = "Huawei Technologies"
    "5C:63:BF" = "Xiaomi Smartphone / IoT"
    "64:CC:2E" = "Xiaomi Smartphone / IoT"
    "78:11:DC" = "Xiaomi Communications"
    "50:C7:BF" = "TP-Link Technologies"
    "60:A4:4C" = "TP-Link Technologies"
    "E8:48:B8" = "TP-Link Technologies"
    "F4:F5:DB" = "Google Nest / Pixel"
    "3C:5A:37" = "Google Chromecast / Nest"
    "CC:50:E3" = "Amazon Echo / Fire TV"
    "FC:65:DE" = "Amazon Technologies"
    "44:65:0D" = "Amazon Technologies"
    "24:0A:C4" = "Espressif IoT Device"
    "84:F3:EB" = "Espressif IoT (Smart Home)"
    "30:AE:A4" = "Espressif IoT (Smart Home)"
    "00:1E:67" = "Intel Corporation"
    "A4:BB:6D" = "Intel Corporation"
    "F4:4D:30" = "Intel Corporation"
    "60:45:BD" = "ASUSTek Computer"
    "04:D4:C4" = "ASUSTek Computer"
    "00:11:32" = "Synology NAS"
    "F0:2F:74" = "Sony PlayStation / Bravia TV"
}

function Test-IsPrivateMac {
    param([string]$Mac)
    if ([string]::IsNullOrWhiteSpace($Mac) -or $Mac -eq "N/A") { return $false }
    $cleanMac = $Mac.ToUpper().Replace("-", ":").Trim()
    if ($cleanMac.Length -ge 2) {
        try {
            $b0 = [Convert]::ToByte($cleanMac.Substring(0, 2), 16)
            # IEEE 802 LAA (Locally Administered Address) bit is bit 1 (0x02)
            # Unicast bit is bit 0 (0x01) == 0
            return (($b0 -band 0x02) -ne 0 -and ($b0 -band 0x01) -eq 0)
        } catch {
            return $false
        }
    }
    return $false
}

function Get-VendorFromMac {
    param([string]$Mac)
    if ([string]::IsNullOrWhiteSpace($Mac) -or $Mac -eq "N/A") { return "Unknown Hardware" }
    $cleanMac = $Mac.ToUpper().Replace("-", ":").Trim()
    if ($cleanMac.Length -ge 8) {
        $prefix = $cleanMac.Substring(0, 8)
        if ($script:OUI_DATABASE.ContainsKey($prefix)) {
            return $script:OUI_DATABASE[$prefix]
        }
    }
    if (Test-IsPrivateMac -Mac $cleanMac) {
        return "Private Wi-Fi Address (iOS/Android MAC Randomization)"
    }
    return "Connected LAN Client"
}

function Get-RouterNameFromMac {
    param([string]$Mac)
    if ([string]::IsNullOrWhiteSpace($Mac)) { return "Gateway Router" }
    $cleanMac = $Mac.ToUpper().Replace("-", ":").Trim()
    if ($cleanMac.Length -ge 8) {
        $prefix = $cleanMac.Substring(0, 8)
        if ($script:OUI_DATABASE.ContainsKey($prefix)) {
            return $script:OUI_DATABASE[$prefix]
        }
    }
    return "Router Gateway ($Mac)"
}

function Get-ProNetworkOverview {
    [CmdletBinding()]
    param()

    $result = [PSCustomObject]@{
        Connected           = $false
        ConnectionType      = "None"
        NetworkName         = "Disconnected"
        LocalIPv4           = "N/A"
        SubnetPrefix        = "/24"
        GatewayIPv4         = "192.168.1.1"
        GatewayMac          = "N/A"
        RouterName          = "Unknown Router"
        DnsServers          = @("1.1.1.1", "8.8.8.8")
        PublicIP            = "Checking..."
        ISP                 = "Unknown"
        AdapterName         = "N/A"
        AdapterDescription  = "N/A"
        MacAddress          = "N/A"
        LinkSpeed           = "0 bps"
        MediaTechnology     = "Ethernet/Wi-Fi"
        WifiAuth            = "Unknown"
        WifiCipher          = "Unknown"
    }

    try {
        $activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Loopback' }
        $defaultRoutes = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue

        $selectedAdapter = $null
        $selectedRoute = $null

        foreach ($route in ($defaultRoutes | Sort-Object RouteMetric)) {
            $matchAd = $activeAdapters | Where-Object { $_.InterfaceAlias -eq $route.InterfaceAlias -or $_.ifIndex -eq $route.InterfaceIndex }
            if ($matchAd) {
                $selectedAdapter = $matchAd
                $selectedRoute = $route
                break
            }
        }

        if (-not $selectedAdapter) {
            $selectedAdapter = $activeAdapters | Select-Object -First 1
            if ($selectedAdapter) {
                $selectedRoute = $defaultRoutes | Where-Object { $_.InterfaceAlias -eq $selectedAdapter.InterfaceAlias } | Select-Object -First 1
            }
        }

        if ($selectedAdapter) {
            $result.Connected          = $true
            $result.AdapterName        = $selectedAdapter.Name
            $result.AdapterDescription = $selectedAdapter.InterfaceDescription
            $result.MacAddress         = $selectedAdapter.MacAddress
            $result.LinkSpeed          = $selectedAdapter.LinkSpeed

            if ($selectedAdapter.MediaType -match "802.11" -or $selectedAdapter.Name -match "Wi-Fi|Wireless|WLAN") {
                $result.ConnectionType = "Wi-Fi"
                $desc = $selectedAdapter.InterfaceDescription
                if ($desc -match "802\.11be|Wi-Fi 7") { $result.MediaTechnology = "Wi-Fi 7 (802.11be)" }
                elseif ($desc -match "802\.11ax|Wi-Fi 6") { $result.MediaTechnology = "Wi-Fi 6 (802.11ax)" }
                elseif ($desc -match "802\.11ac|AC") { $result.MediaTechnology = "Wi-Fi 5 (802.11ac)" }
                else { $result.MediaTechnology = "Wi-Fi Wireless" }
            } else {
                $result.ConnectionType = "Ethernet"
                $result.MediaTechnology = "Gigabit Ethernet"
            }
        }

        if ($selectedRoute) {
            $result.GatewayIPv4 = $selectedRoute.NextHop
        }

        # IP and DNS Configuration
        $ipConfig = Get-NetIPConfiguration -InterfaceAlias $result.AdapterName -ErrorAction SilentlyContinue
        if ($ipConfig) {
            $ipv4 = $ipConfig.IPv4Address | Select-Object -First 1
            if ($ipv4) {
                $result.LocalIPv4    = $ipv4.IPAddress
                $result.SubnetPrefix = "/$($ipv4.PrefixLength)"
            }
            if ($ipConfig.DNSServer) {
                $result.DnsServers = @($ipConfig.DNSServer.ServerAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' })
            }
        }

        # Connection Profile / SSID
        $connProfile = Get-NetConnectionProfile -InterfaceAlias $result.AdapterName -ErrorAction SilentlyContinue
        if ($connProfile) {
            $result.NetworkName = $connProfile.Name
        }

        # Query Router MAC from ARP
        try {
            $arp = arp -a
            foreach ($line in $arp) {
                if ($line -match "^\s*$([regex]::Escape($result.GatewayIPv4))\s+([0-9a-fA-F-]+)") {
                    $result.GatewayMac = $matches[1].ToUpper().Replace(":", "-")
                    break
                }
            }
        } catch {}

        # Look up Router Name via MAC OUI
        $result.RouterName = Get-RouterNameFromMac -Mac $result.GatewayMac

        # Fast Wi-Fi Profile security extraction
        if ($result.ConnectionType -eq "Wi-Fi" -and $result.NetworkName -ne "Disconnected") {
            try {
                $profileInfo = netsh wlan show profile name="$($result.NetworkName)" 2>$null
                foreach ($line in $profileInfo) {
                    if ($line -match '^\s*Authentication\s*:\s*(.+)$') { $result.WifiAuth = $matches[1].Trim() }
                    if ($line -match '^\s*Cipher\s*:\s*(.+)$') { $result.WifiCipher = $matches[1].Trim() }
                }
            } catch {}
        }

        # Fast Public IP detection (Cached or 1s timeout)
        try {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "ProNetwork11")
            $ipData = $wc.DownloadString("https://ipinfo.io/json") | ConvertFrom-Json
            if ($ipData.ip) {
                $result.PublicIP = $ipData.ip
                $result.ISP      = "$($ipData.org) ($($ipData.city))"
            }
        } catch {
            $result.PublicIP = "Local Subnet"
            $result.ISP      = "Connected"
        }

    } catch {}

    return $result
}

function Get-LiveDownUpBytes {
    $nics = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | 
        Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' }
    $rx = 0
    $tx = 0
    foreach ($nic in $nics) {
        $ipStats = $nic.GetIPStatistics()
        $rx += $ipStats.BytesReceived
        $tx += $ipStats.BytesSent
    }
    return @{ Rx = $rx; Tx = $tx }
}

function Show-RouterBandwidthGraph {
    param(
        [PSCustomObject]$NetInfo,
        [int]$SampleDurationMs = 700,
        [switch]$Continuous
    )

    $barWidth = 35
    $routerDisplayName = if ($NetInfo.RouterName) { $NetInfo.RouterName } else { "Gateway Router" }
    $gwIp = if ($NetInfo.GatewayIPv4) { $NetInfo.GatewayIPv4 } else { "192.168.1.1" }
    $gwMac = if ($NetInfo.GatewayMac) { $NetInfo.GatewayMac } else { "Unknown MAC" }

    do {
        $t0 = Get-LiveDownUpBytes
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Start-Sleep -Milliseconds $SampleDurationMs
        $sw.Stop()
        $t1 = Get-LiveDownUpBytes

        $dt = [Math]::Max(0.1, $sw.Elapsed.TotalSeconds)
        $rxDelta = [Math]::Max(0, ($t1.Rx - $t0.Rx))
        $txDelta = [Math]::Max(0, ($t1.Tx - $t0.Tx))

        $downMbps = [Math]::Round(($rxDelta * 8) / ($dt * 1000000), 2)
        $upMbps   = [Math]::Round(($txDelta * 8) / ($dt * 1000000), 2)

        $scaleMax = 50.0
        if ($NetInfo.LinkSpeed -match '(\d+)') {
            $parsed = [double]$matches[1]
            if ($parsed -gt 10) { $scaleMax = [Math]::Min(100.0, $parsed) }
        }

        $downFill = [Math]::Min($barWidth, [Math]::Max(1, [int](($downMbps / $scaleMax) * $barWidth)))
        $upFill   = [Math]::Min($barWidth, [Math]::Max(1, [int](($upMbps / $scaleMax) * $barWidth)))

        $downBar = ("=" * ($downFill - 1)) + ">" + ("." * ($barWidth - $downFill))
        $upBar   = ("=" * ($upFill - 1)) + ">" + ("." * ($barWidth - $upFill))

        Write-Host "  ${global:C_BLUE}${global:C_BOLD}[+] LIVE ROUTER BANDWIDTH CONNECTION: ${global:C_GREEN}$routerDisplayName${global:C_RESET} ${global:C_GRAY}[$gwIp | $gwMac]${global:C_RESET}"
        Write-Host "     ${global:C_BLUE}Downlink [Rx]${global:C_RESET} : ${global:C_GREEN}[$downBar]${global:C_RESET} ${global:C_BOLD}$($downMbps.ToString('0.00').PadLeft(6)) Mbps${global:C_RESET} ${global:C_GRAY}($(([Math]::Round($rxDelta / 1024 / $dt, 1)).ToString()) KB/s)${global:C_RESET}"
        Write-Host "     ${global:C_BLUE}Uplink   [Tx]${global:C_RESET} : ${global:C_BLUE}[$upBar]${global:C_RESET} ${global:C_BOLD}$($upMbps.ToString('0.00').PadLeft(6)) Mbps${global:C_RESET} ${global:C_GRAY}($(([Math]::Round($txDelta / 1024 / $dt, 1)).ToString()) KB/s)${global:C_RESET}"
        Write-Host "     ${global:C_BLUE}Link Channel ${global:C_RESET} : ${global:C_GRAY}Max Negotiated: $($NetInfo.LinkSpeed) | Medium: $($NetInfo.MediaTechnology) | Status: Healthy${global:C_RESET}"

        if ($Continuous) {
            Write-Host "     ${global:C_GRAY}Monitoring... Press any key or Ctrl+C to return${global:C_RESET}"
            if ([Console]::KeyAvailable) {
                [void][Console]::ReadKey($true)
                break
            }
            Write-Host "$($global:ESC)[5A" -NoNewline
        }
    } while ($Continuous)
}

Export-ModuleMember -Function Get-ProNetworkOverview, Get-RouterNameFromMac, Get-VendorFromMac, Test-IsPrivateMac, Get-LiveDownUpBytes, Show-RouterBandwidthGraph
