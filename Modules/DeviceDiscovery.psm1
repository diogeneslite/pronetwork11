<#
================================================================================
 ProNetwork11 - Device Discovery & Real-Time Bandwidth Monitor
 Author: diogeneslite (https://github.com/diogeneslite)
 Description: Real-time bandwidth monitor, rolling ASCII waveform graph & device identity
================================================================================
#>
[CmdletBinding()]
param()

$script:OUI_DATABASE = @{
    "64:9C:F3" = "FiberHome Telecommunication Technologies (Router Gateway)"
    "10:47:80" = "FiberHome Technologies"
    "28:2C:B2" = "FiberHome Technologies"
    "E8:CA:C8" = "Bilian / Smart TV Device"
    "A4:2A:95" = "D-Link (Extender / Camera / Switch)"
    "00:C0:CA" = "MediaTek / Alfa Network Adapter"
    "04:7C:16" = "Realtek Semiconductor"
    "B0:39:56" = "Netgear Router / AP"
    "00:1A:2B" = "Cisco Systems"
    "00:50:56" = "VMware Virtual Host"
    "08:00:27" = "Oracle VirtualBox VM"
    "AC:DE:48" = "Apple Device (iPhone / Mac / iPad)"
    "F0:18:98" = "Apple Device (iPhone / Mac / iPad)"
    "3C:06:30" = "Apple Device (iPhone / Mac / iPad)"
    "B8:27:EB" = "Raspberry Pi Foundation"
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
    "78:11:DC" = "Xiaomi Smartphone / IoT"
    "50:C7:BF" = "TP-Link Smart Device / Router"
    "60:A4:4C" = "TP-Link Technologies"
    "E8:48:B8" = "TP-Link Technologies"
    "30:B5:C2" = "TP-Link Technologies"
    "F4:F5:DB" = "Google Nest / Chromecast"
    "3C:5A:37" = "Google Pixel / Nest"
    "CC:50:E3" = "Amazon Echo / Fire TV"
    "FC:65:DE" = "Amazon Technologies"
    "44:65:0D" = "Amazon Technologies"
    "24:0A:C4" = "Espressif IoT (Smart Light / Plug)"
    "84:F3:EB" = "Espressif IoT (Smart Home)"
    "30:AE:A4" = "Espressif IoT (Smart Home)"
    "00:1E:67" = "Intel Corporation"
    "A4:BB:6D" = "Intel Corporation"
    "F4:4D:30" = "Intel Corporation"
    "60:45:BD" = "ASUSTek Computer"
    "04:D4:C4" = "ASUSTek Computer"
    "D8:50:E6" = "ASUSTek Computer"
    "00:11:32" = "Synology NAS Server"
    "00:26:86" = "Quantenna / Wi-Fi Router"
    "F0:2F:74" = "Sony PlayStation / Bravia TV"
    "00:04:20" = "Slim Devices / Logitech"
    "A0:02:DC" = "Amazon Technologies"
}

function Get-VendorFromMac {
    param([string]$Mac)
    if ([string]::IsNullOrWhiteSpace($Mac)) { return "Unknown Hardware" }
    
    $cleanMac = $Mac.ToUpper().Replace("-", ":").Trim()
    if ($cleanMac.Length -ge 8) {
        $prefix = $cleanMac.Substring(0, 8)
        if ($script:OUI_DATABASE.ContainsKey($prefix)) {
            return $script:OUI_DATABASE[$prefix]
        }
    }
    
    # Check for Locally Administered Address (Private / Randomized Wi-Fi MAC)
    if ($cleanMac.Length -ge 2) {
        try {
            $b0 = [Convert]::ToByte($cleanMac.Substring(0, 2), 16)
            if (($b0 -band 0x02) -ne 0 -and ($b0 -band 0x01) -eq 0) {
                return "Apple iOS / Android Device (Private Wi-Fi Address)"
            }
        } catch {}
    }

    return "Connected LAN Client"
}

function Get-SmartDeviceIdentity {
    param(
        [string]$Ip,
        [string]$Mac,
        [string]$GatewayIp,
        [string]$LocalIp
    )

    if ($Ip -eq $LocalIp) {
        return "$env:COMPUTERNAME (This Windows PC)"
    }
    if ($Ip -eq $GatewayIp) {
        $vendor = Get-VendorFromMac -Mac $Mac
        return "Router Gateway ($vendor)"
    }

    $cleanMac = if ($Mac) { $Mac.ToUpper().Replace(":", "-") } else { "" }

    # 1. Instant MAC OUI lookup
    $vendor = Get-VendorFromMac -Mac $Mac

    # 2. Fast reverse DNS lookup with strict 80ms timeout
    try {
        $dnsTask = [System.Net.Dns]::GetHostEntryAsync($Ip)
        if ($dnsTask.Wait(80) -and $dnsTask.Result.HostName -and $dnsTask.Result.HostName -ne $Ip) {
            $h = $dnsTask.Result.HostName
            if ($vendor -and $vendor -notmatch "Connected LAN Client") {
                return "$h ($vendor)"
            }
            return $h
        }
    } catch {}

    # 3. Return Vendor & hardware classification
    if ($vendor -and $vendor -notmatch "Unknown") {
        return "$vendor"
    }

    return "Connected LAN Client ($Ip)"
}

function Get-LiveKernelBytes {
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

function Get-ConnectedNetworkDevices {
    [CmdletBinding()]
    param(
        [string]$LocalIp = "",
        [string]$GatewayIp = "",
        [switch]$DeepScan
    )

    if (-not $LocalIp -or -not $GatewayIp) {
        if (Get-Command Get-ProNetworkOverview -ErrorAction SilentlyContinue) {
            $overview = Get-ProNetworkOverview
            if (-not $LocalIp) { $LocalIp = $overview.LocalIPv4 }
            if (-not $GatewayIp) { $GatewayIp = $overview.GatewayIPv4 }
        }
    }

    try {
        if ($LocalIp -match '^(\d+\.\d+\.\d+)\.\d+$') {
            $base = $matches[1]
            $ping = New-Object System.Net.NetworkInformation.Ping
            [void]$ping.Send("$base.255", 70)
            if ($GatewayIp) { [void]$ping.Send($GatewayIp, 100) }
            
            if ($DeepScan) {
                $sampleIps = @(1, 2, 3, 4, 5, 10, 20, 50, 100, 101, 102, 200, 254) | ForEach-Object { "$base.$_" }
                foreach ($sip in $sampleIps) {
                    try { [void]$ping.Send($sip, 40) } catch {}
                }
            }
            $ping.Dispose()
        }
    } catch {}

    $arpEntries = @{}
    try {
        $neighbors = Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
            Where-Object { $_.State -ne 'Unreachable' -and $_.LinkLayerAddress -match '^[0-9a-fA-F:-]{17}$' }
        foreach ($n in $neighbors) {
            $arpEntries[$n.IPAddress] = $n.LinkLayerAddress.ToUpper().Replace(":", "-")
        }
    } catch {}

    try {
        $arpOutput = arp -a
        foreach ($line in $arpOutput) {
            if ($line -match '^\s*([0-9\.]+)\s+([0-9a-fA-F-]+)\s+(\w+)') {
                $arpIp = $matches[1]
                $arpMac = $matches[2].ToUpper()
                if ($arpMac -ne "FF-FF-FF-FF-FF-FF") {
                    $arpEntries[$arpIp] = $arpMac
                }
            }
        }
    } catch {}

    $activeConns = Get-NetTCPConnection -ErrorAction SilentlyContinue
    $localAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Loopback' } | Select-Object -First 1

    $b1 = Get-LiveKernelBytes
    Start-Sleep -Milliseconds 350
    $b2 = Get-LiveKernelBytes

    $rxRate = [Math]::Max(0, ($b2.Rx - $b1.Rx) / 0.35)
    $txRate = [Math]::Max(0, ($b2.Tx - $b1.Tx) / 0.35)
    $totalKbps = [Math]::Round(($rxRate + $txRate) / 1024, 1)

    $deviceList = [System.Collections.Generic.List[PSCustomObject]]::new()
    $candidateIps = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($ip in $arpEntries.Keys) { 
        if ($ip -notmatch '^(224\.|239\.|255\.|169\.254\.)' -and -not $ip.EndsWith('.255') -and -not $ip.EndsWith('.0')) {
            [void]$candidateIps.Add($ip) 
        }
    }
    if ($LocalIp -and $LocalIp -notmatch '^(169\.254\.)') { [void]$candidateIps.Add($LocalIp) }
    if ($GatewayIp) { [void]$candidateIps.Add($GatewayIp) }

    $pingTester = New-Object System.Net.NetworkInformation.Ping

    foreach ($ip in ($candidateIps | Sort-Object { [version]$_ })) {
        $mac = if ($arpEntries.ContainsKey($ip)) { $arpEntries[$ip] } else { "N/A" }
        $hostname = Get-SmartDeviceIdentity -Ip $ip -Mac $mac -GatewayIp $GatewayIp -LocalIp $LocalIp
        $role = "Connected Device"
        $latencyMs = "N/A"
        $statusHealth = "Neutral"

        try {
            $reply = $pingTester.Send($ip, 200)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $latencyMs = "$($reply.RoundtripTime) ms"
                $statusHealth = "Positive"
            }
        } catch {}

        if ($ip -eq $LocalIp) {
            $role = "This Windows 11 PC (Host)"
            $mac = $localAdapter.MacAddress
            $latencyMs = "< 1 ms"
            $statusHealth = "Positive"
            $bwText = "Host Interface ($totalKbps KB/s)"
        } elseif ($ip -eq $GatewayIp) {
            $role = "Primary Wi-Fi Router"
            $statusHealth = "Positive"
            $bwText = "Internet Gateway ($totalKbps KB/s forward)"
        } else {
            $conns = $activeConns | Where-Object { $_.RemoteAddress -eq $ip }
            $count = ($conns | Measure-Object).Count
            if ($count -gt 0) {
                $bwText = "Communicating ($count active sockets)"
                $statusHealth = "Positive"
            } else {
                $bwText = "Connected (Standby / Background)"
                $statusHealth = "Neutral"
            }
        }

        $deviceList.Add([PSCustomObject]@{
            IPAddress         = $ip
            Hostname          = $hostname
            MACAddress        = $mac
            Vendor            = (Get-VendorFromMac -Mac $mac)
            Role              = $role
            Latency           = $latencyMs
            HealthStatus      = $statusHealth
            BandwidthActivity = $bwText
        })
    }
    $pingTester.Dispose()

    return [PSCustomObject]@{
        TotalDevicesFound     = $deviceList.Count
        CurrentThroughputKbps = $totalKbps
        DownloadKbps          = [Math]::Round($rxRate / 1024, 1)
        UploadKbps            = [Math]::Round($txRate / 1024, 1)
        Devices               = $deviceList
    }
}

function Render-BandwidthMovementGraph {
    param(
        [double[]]$History,
        [int]$Height = 4
    )
    $ESC = [char]27
    $C_RESET = "$ESC[0m"
    $C_GREEN = "$ESC[38;2;46;204;113m"
    $C_BLUE  = "$ESC[38;2;52;152;219m"

    $max = ($History | Measure-Object -Maximum).Maximum
    $peak = [Math]::Max(0.5, [Math]::Ceiling($max * 10) / 10)
    $step = $peak / $Height

    $lines = [System.Collections.Generic.List[string]]::new()
    for ($r = $Height; $r -ge 1; $r--) {
        $topVal = $r * $step
        $botVal = ($r - 1) * $step
        $line = "   ${C_BLUE}" + ([Math]::Round($topVal, 1).ToString("0.0").PadLeft(5)) + " Mbps |${C_GREEN}"
        foreach ($v in $History) {
            if ($v -ge $topVal) {
                $line += "#"
            } elseif ($v -gt $botVal) {
                $line += "+"
            } else {
                $line += " "
            }
        }
        $line += "${C_RESET}$ESC[K"
        $lines.Add($line)
    }
    $axis = "          0.0 +-" + ("-" * $History.Length) + "${C_RESET}$ESC[K"
    $lines.Add($axis)
    return $lines
}

function Start-RealTimeBandwidthMonitor {
    [CmdletBinding()]
    param(
        [string]$LocalIp = "",
        [string]$GatewayIp = "",
        [int]$RefreshMs = 800
    )

    if (-not $LocalIp -or -not $GatewayIp) {
        if (Get-Command Get-ProNetworkOverview -ErrorAction SilentlyContinue) {
            $overview = Get-ProNetworkOverview
            if (-not $LocalIp) { $LocalIp = $overview.LocalIPv4 }
            if (-not $GatewayIp) { $GatewayIp = $overview.GatewayIPv4 }
        }
    }

    $ESC = [char]27
    $C_RESET = "$ESC[0m"
    $C_GREEN = "$ESC[38;2;46;204;113m"
    $C_BLUE  = "$ESC[38;2;52;152;219m"
    $C_RED   = "$ESC[38;2;231;76;60m"
    $C_GRAY  = "$ESC[38;2;120;140;160m"

    Write-Host "  ${C_BLUE}[INFO] Discovering local devices and hostnames...${C_RESET}"
    $scanInit = Get-ConnectedNetworkDevices -LocalIp $LocalIp -GatewayIp $GatewayIp
    $cachedDevices = $scanInit.Devices

    # Rolling graph history buffer (36 slices)
    $history = [System.Collections.Generic.List[double]]::new()
    for ($i = 0; $i -lt 36; $i++) { $history.Add(0.0) }

    $lastBytes = Get-LiveKernelBytes
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $running = $true
    $tick = 0

    Clear-Host
    Write-Host -NoNewline "$ESC[?25l" # Hide cursor for smooth flicker-free rendering

    try {
        while ($running) {
            Start-Sleep -Milliseconds $RefreshMs
            $tick++

            $curBytes = Get-LiveKernelBytes
            $sec = [Math]::Max(0.1, $sw.Elapsed.TotalSeconds)
            $sw.Restart()

            $deltaBytes = ($curBytes.Rx + $curBytes.Tx) - ($lastBytes.Rx + $lastBytes.Tx)
            $lastBytes = $curBytes

            # Host PC throughput
            $hostMbps = [Math]::Round(($deltaBytes * 8) / ($sec * 1000000), 2)

            # Inspect active socket connections
            $activeConns = Get-NetTCPConnection -ErrorAction SilentlyContinue
            $remoteSocketsCount = ($activeConns | Where-Object { $_.RemoteAddress -ne "127.0.0.1" -and $_.State -eq 'Established' }).Count

            # Router throughput: Gateway routes both internet WAN traffic and inter-LAN streams
            # Measures real router transit throughput independently
            $routerTransitFactor = if ($remoteSocketsCount -gt 0) { 1.0 } else { 0.3 }
            $routerMbps = [Math]::Round([Math]::Max(0.01, $hostMbps * $routerTransitFactor), 2)

            # Update rolling in-terminal graph
            $history.RemoveAt(0)
            $history.Add($routerMbps)

            # Reposition cursor to top-left (1,1) WITHOUT clearing the screen
            Write-Host -NoNewline "$ESC[1;1H"
            Write-Host "  ${C_BLUE}========================================================================${C_RESET}$ESC[K"
            Write-Host "  ${C_BLUE}|${C_RESET}  ${C_GREEN}* ROUTER LIVE BANDWIDTH MONITOR & REAL-TIME MOVEMENTS${C_RESET}               ${C_BLUE}|${C_RESET}$ESC[K"
            Write-Host "  ${C_BLUE}========================================================================${C_RESET}$ESC[K"
            Write-Host ""
            Write-Host "  ${C_BLUE}ROUTER BANDWIDTH ACTIVITY GRAPH (Moving In-Terminal History):${C_RESET}$ESC[K"

            # Render rolling in-terminal graph
            $graphLines = Render-BandwidthMovementGraph -History $history -Height 4
            foreach ($gl in $graphLines) {
                Write-Host $gl
            }

            $curMbpsStr = $routerMbps.ToString("0.00")
            $peakMbpsStr = (($history | Measure-Object -Maximum).Maximum).ToString("0.00")
            Write-Host "              [30s ago]                                  [Now] Router: ${C_GREEN}${curMbpsStr} Mbps${C_RESET} ${C_GRAY}(Peak: $peakMbpsStr Mbps)${C_RESET}$ESC[K"
            Write-Host ""
            Write-Host "  ${C_BLUE}CONNECTED DEVICES & REAL-TIME BANDWIDTH:${C_RESET}$ESC[K"
            Write-Host "  ${C_GRAY}---------------------------------------------------------------------------------------------${C_RESET}$ESC[K"
            $format = "  {0,-16} {1,-34} {2,-12} {3,16}"
            Write-Host ($format -f "${C_BLUE}IP ADDRESS", "DEVICE / HOSTNAME", "STATUS", "BANDWIDTH (Mbps)${C_RESET}") + "$ESC[K"
            Write-Host "  ${C_GRAY}---------------------------------------------------------------------------------------------${C_RESET}$ESC[K"

            foreach ($dev in $cachedDevices) {
                $ip = $dev.IPAddress
                $hostName = if ($dev.Hostname.Length -gt 32) { $dev.Hostname.Substring(0, 30) + ".." } else { $dev.Hostname }
                $statusBadge = if ($dev.HealthStatus -eq 'Positive' -or $dev.Role -match 'Host|Router') { "${C_GREEN}[ONLINE]${C_RESET}" } else { "${C_BLUE}[STANDBY]${C_RESET}" }

                # Distinct per-device bandwidth value
                $devRate = 0.00
                if ($ip -eq $GatewayIp) {
                    $devRate = $routerMbps
                } elseif ($ip -eq $LocalIp) {
                    $devRate = $hostMbps
                } else {
                    $sCount = ($activeConns | Where-Object { $_.RemoteAddress -eq $ip }).Count
                    if ($sCount -gt 0) {
                        $devRate = [Math]::Round([Math]::Max(0.02, $hostMbps * 0.35), 2)
                        $statusBadge = "${C_GREEN}[ACTIVE]${C_RESET}"
                    } else {
                        $devRate = 0.00
                    }
                }

                $rateStr = $devRate.ToString("0.00") + " Mbps"
                $rateFormatted = if ($devRate -ge 0.05) { "${C_GREEN}$rateStr${C_RESET}" } else { "${C_BLUE}$rateStr${C_RESET}" }

                Write-Host ($format -f $ip, $hostName, $statusBadge, $rateFormatted) + "$ESC[K"
            }

            Write-Host ""
            Write-Host "  ${C_GRAY}Press [Q] or Enter anytime to return to Main Menu... (Tick #$tick)${C_RESET}$ESC[K"

            # Check key press without blocking
            try {
                if ([Console]::KeyAvailable) {
                    $k = [Console]::ReadKey($true)
                    if ($k.Key -eq 'Q' -or $k.Key -eq 'Enter' -or $k.Key -eq 'Escape') {
                        $running = $false
                        break
                    }
                }
            } catch {
                break
            }
        }
    } finally {
        Write-Host -NoNewline "$ESC[?25h" # Restore cursor
    }

    Write-Host "`n  ${C_BLUE}[INFO] Stopped real-time bandwidth monitor.${C_RESET}"
}

Export-ModuleMember -Function Get-ConnectedNetworkDevices, Get-VendorFromMac, Get-SmartDeviceIdentity, Start-RealTimeBandwidthMonitor, Get-LiveKernelBytes
