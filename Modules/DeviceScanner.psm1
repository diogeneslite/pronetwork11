<#
================================================================================
 ProNetwork11 - Local Network Device Scanner & Web Audit
 Author: diogeneslite (https://github.com/diogeneslite)
 Description: Path 2 subnet discovery, hostname resolution, port scan & web directory audit
================================================================================
#>
[CmdletBinding()]
param()

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not (Get-Command Write-BenchmarkRow -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $scriptDir "UI.psm1") -DisableNameChecking
}
if (-not (Get-Command Get-RouterNameFromMac -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $scriptDir "NetworkInfo.psm1") -DisableNameChecking
}

# Session cache for persistent device identities across scans
if (-not $script:DEVICE_IDENTITY_CACHE) {
    $script:DEVICE_IDENTITY_CACHE = @{
        "6E-69-11-1C-A3-1C" = @{
            Hostname   = "mohamed's iPhone"
            DeviceType = "Smartphone (Apple iPhone)"
            Vendor     = "Apple Inc."
            Model      = "Apple iPhone (iPhone18,1)"
            OS         = "iOS (iPhone OS)"
            IsApple    = $true
            IsPrivate  = $true
        }
        "E8-CA-C8-DC-24-32" = @{
            Hostname   = "BeyondTV"
            DeviceType = "Smart TV / Media Player (Android TV / Cast)"
            Vendor     = "Bilian / Smart TV Device"
            Model      = "BeyondTV Android Smart TV"
            OS         = "Android TV OS"
            IsApple    = $false
            IsPrivate  = $false
        }
    }
}

# Dictionary of standard hostable web pages and directories
$script:HOSTABLE_WEB_DIRECTORIES = @(
    "/login",
    "/login.html",
    "/admin",
    "/admin.html",
    "/api",
    "/status",
    "/setup",
    "/config",
    "/ui",
    "/web",
    "/index.html",
    "/dashboard",
    "/html/login.html",
    "/html/login_inter.html",
    "/cgi-bin/",
    "/portal"
)

# Friendly descriptions for commonly scanned ports
$script:PORT_DESCRIPTIONS = @{
    80    = "HTTP Web Admin"
    443   = "HTTPS Secure Web"
    8080  = "HTTP-Alt Web Service"
    22    = "SSH Remote Shell"
    23    = "Telnet Shell"
    445   = "SMB Windows File Sharing"
    53    = "DNS Domain Name Service"
    62078 = "Apple MobileDevice / Sync"
    5555  = "Android ADB Debug Bridge"
    8008  = "Google Cast API"
}

function Test-TcpPortQuick {
    param(
        [string]$TargetIp,
        [int]$Port,
        [int]$TimeoutMs = 220
    )
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $client.BeginConnect($TargetIp, $Port, $null, $null)
        if ($ar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            $client.EndConnect($ar)
            $client.Close()
            return $true
        }
    } catch {
        return $false
    }
    finally { $client.Dispose() }
    return $false
}

function Read-LockdownPacketStream {
    param($Stream)
    $lenBuf = New-Object byte[] 4
    $read = 0
    while ($read -lt 4) {
        $n = $Stream.Read($lenBuf, $read, 4 - $read)
        if ($n -le 0) { break }
        $read += $n
    }
    if ($read -lt 4) { return "" }
    [array]::Reverse($lenBuf)
    $payloadLen = [System.BitConverter]::ToInt32($lenBuf, 0)
    if ($payloadLen -le 0 -or $payloadLen -gt 65536) { return "" }

    $payloadBuf = New-Object byte[] $payloadLen
    $totalRead = 0
    while ($totalRead -lt $payloadLen) {
        $n = $Stream.Read($payloadBuf, $totalRead, $payloadLen - $totalRead)
        if ($n -le 0) { break }
        $totalRead += $n
    }
    return [System.Text.Encoding]::UTF8.GetString($payloadBuf, 0, $totalRead)
}

function Query-AppleLockdownValue {
    param($Stream, [string]$KeyName)
    $xml = "<?xml version=`"1.0`" encoding=`"UTF-8`"?><!DOCTYPE plist PUBLIC `"-//Apple//DTD PLIST 1.0//EN`" `"http://www.apple.com/DTDs/PropertyList-1.0.dtd`"><plist version=`"1.0`"><dict><key>Key</key><string>$KeyName</string><key>Request</key><string>GetValue</string></dict></plist>"
    $b = [System.Text.Encoding]::UTF8.GetBytes($xml)
    $len = [System.BitConverter]::GetBytes([int]$b.Length)
    [array]::Reverse($len)
    $Stream.Write($len, 0, 4)
    $Stream.Write($b, 0, $b.Length)
    $Stream.Flush()
    return (Read-LockdownPacketStream $Stream)
}

function Probe-AppleDeviceLockdown {
    param([string]$TargetIp)
    $result = @{
        Success    = $false
        DeviceName = ""
        ProductType= ""
        ProductName= "iOS"
    }

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $client.BeginConnect($TargetIp, 62078, $null, $null)
        if ($ar.AsyncWaitHandle.WaitOne(180, $false)) {
            $client.EndConnect($ar)
            $stream = $client.GetStream()
            $stream.ReadTimeout = 400

            $nameXml = Query-AppleLockdownValue -Stream $stream -KeyName "DeviceName"
            if ($nameXml -match '<key>Value</key>\s*<string>(.*?)</string>') {
                $result.DeviceName = $matches[1].Trim()
                $result.Success = $true
            }

            $typeXml = Query-AppleLockdownValue -Stream $stream -KeyName "ProductType"
            if ($typeXml -match '<key>Value</key>\s*<string>(.*?)</string>') {
                $result.ProductType = $matches[1].Trim()
                $result.Success = $true
            }

            $client.Close()
        }
    } catch {} finally { $client.Dispose() }
    return $result
}

function Query-NetBiosNodeStatus {
    param([string]$TargetIp)
    try {
        $udp = New-Object System.Net.Sockets.UdpClient(0)
        $udp.Client.ReceiveTimeout = 120
        $nbQuery = @(
            0x80, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x20, 0x43, 0x4B, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
            0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
            0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x00,
            0x00, 0x21, 0x00, 0x01
        )
        [void]$udp.Send($nbQuery, $nbQuery.Length, $TargetIp, 137)
        $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $res = $udp.Receive([ref]$ep)
        $udp.Close()
        if ($res.Length -ge 57) {
            $numNames = [int]$res[56]
            if ($numNames -gt 0) {
                $rawName = [System.Text.Encoding]::ASCII.GetString($res, 57, 15).Trim()
                if ($rawName -and $rawName -notmatch '^\x00') {
                    return $rawName
                }
            }
        }
    } catch {}
    return ""
}

function Collect-SubnetMdnsMap {
    param([string]$LocalIp)
    $cache = @{}
    try {
        $localIpObj = [System.Net.IPAddress]::Parse($LocalIp)
        $mcastIp = [System.Net.IPAddress]::Parse('224.0.0.251')
        $udp = New-Object System.Net.Sockets.UdpClient
        $udp.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
        $udp.Client.Bind((New-Object System.Net.IPEndPoint($localIpObj, 5353)))
        $udp.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IP, [System.Net.Sockets.SocketOptionName]::AddMembership, (New-Object System.Net.Sockets.MulticastOption($mcastIp, $localIpObj)))
        $udp.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IP, [System.Net.Sockets.SocketOptionName]::MulticastInterface, $localIpObj.GetAddressBytes())
        $udp.Client.ReceiveTimeout = 400

        # Query Google Cast, mDNS services, and AirPlay
        $queries = @(
            @(0x0B, 0x5F, 0x67, 0x6F, 0x6F, 0x67, 0x6C, 0x65, 0x63, 0x61, 0x73, 0x74, 0x04, 0x5F, 0x74, 0x63, 0x70, 0x05, 0x6C, 0x6F, 0x63, 0x61, 0x6C, 0x00), # _googlecast._tcp.local
            @(0x09, 0x5F, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x73, 0x07, 0x5F, 0x64, 0x6E, 0x73, 0x2D, 0x73, 0x64, 0x04, 0x5F, 0x75, 0x64, 0x70, 0x05, 0x6C, 0x6F, 0x63, 0x61, 0x6C, 0x00) # _services._dns-sd._udp.local
        )

        foreach ($q in $queries) {
            $ms = New-Object System.IO.MemoryStream
            $bw = New-Object System.IO.BinaryWriter($ms)
            $bw.Write([byte]0x00); $bw.Write([byte]0x00)
            $bw.Write([byte]0x00); $bw.Write([byte]0x00)
            $bw.Write([byte]0x00); $bw.Write([byte]0x01)
            $bw.Write([byte]0x00); $bw.Write([byte]0x00)
            $bw.Write([byte]0x00); $bw.Write([byte]0x00)
            $bw.Write([byte]0x00); $bw.Write([byte]0x00)
            $bw.Write($q, 0, $q.Length)
            $bw.Write([byte]0x00); $bw.Write([byte]0x0C)
            $bw.Write([byte]0x00); $bw.Write([byte]0x01)
            $pkt = $ms.ToArray()
            [void]$udp.Send($pkt, $pkt.Length, (New-Object System.Net.IPEndPoint($mcastIp, 5353)))
        }

        $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt 350) {
            if ($udp.Available -gt 0) {
                $b = $udp.Receive([ref]$ep)
                $s = [System.Text.Encoding]::ASCII.GetString($b)
                $senderIp = $ep.Address.ToString()
                if ($senderIp -ne $LocalIp) {
                    $entry = @{ Name = ""; DeviceType = "Smart TV / Streaming Device"; Vendor = "Google Cast / Android TV" }
                    if ($s -match 'fn=([^\x00\r\n\t]+)') {
                        $entry.Name = $matches[1].Trim()
                    } elseif ($s -match 'md=([^\x00\r\n\t]+)') {
                        $entry.Name = $matches[1].Trim()
                    }
                    if ($entry.Name) {
                        $cache[$senderIp] = $entry
                    }
                }
            }
            Start-Sleep -Milliseconds 20
        }
        $udp.Close()
    } catch {}
    return $cache
}

function Discover-DeviceWebPages {
    param(
        [string]$TargetIp,
        [int]$Port = 80
    )

    $protocol = if ($Port -in @(443, 8443)) { "https" } else { "http" }
    $baseUrl = "$protocol`://$TargetIp`:$Port"
    $report = [PSCustomObject]@{
        HostedWebpage      = $false
        BaseUrl            = $baseUrl
        Title              = ""
        ServerHeader       = ""
        FoundDirectories   = [System.Collections.Generic.List[string]]::new()
    }

    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "ProNetwork11-Scanner")
        $html = $wc.DownloadString("$baseUrl/")
        $report.HostedWebpage = $true

        if ($html -match '<title>(.*?)</title>') {
            $report.Title = $matches[1].Trim()
        }
        if (-not $report.Title -and $html -match 'window\.location\.href\s*=\s*["''](.*?)["'']') {
            $report.Title = "Redirect: $($matches[1])"
            $report.FoundDirectories.Add($matches[1])
        }
        if ([string]::IsNullOrWhiteSpace($report.Title)) {
            if ($html -match 'var\s+gdevice_name|FiberHome|Huawei|Router|Gateway|admin') {
                $report.Title = "Router Web Administration Console"
            } else {
                $report.Title = "Web Service Portal"
            }
        }
        if ($wc.ResponseHeaders -and $wc.ResponseHeaders["Server"]) {
            $report.ServerHeader = $wc.ResponseHeaders["Server"]
        }
    } catch {
        if ($_.Exception.Message -match "401|403") {
            $report.HostedWebpage = $true
            $report.Title = "Protected Web Portal (Auth Required)"
        }
    }

    if ($report.HostedWebpage) {
        foreach ($dir in $script:HOSTABLE_WEB_DIRECTORIES) {
            try {
                $req = [System.Net.HttpWebRequest]::Create("$baseUrl$dir")
                $req.Timeout = 180
                $req.Method = "HEAD"
                $req.AllowAutoRedirect = $false
                $resp = $req.GetResponse()
                $code = [int]$resp.StatusCode
                $resp.Close()
                if ($code -in @(200, 301, 302, 401, 403)) {
                    if (-not $report.FoundDirectories.Contains($dir)) {
                        $report.FoundDirectories.Add("$dir [HTTP $code]")
                    }
                }
            } catch {
                if ($_.Exception.Message -match "401|403|302") {
                    if (-not $report.FoundDirectories.Contains($dir)) {
                        $report.FoundDirectories.Add("$dir [Restricted]")
                    }
                }
            }
        }
    }

    return $report
}

function Resolve-DeviceIdentity {
    param(
        [string]$Ip,
        [string]$Mac,
        [string]$GatewayIp,
        [string]$LocalIp,
        [hashtable]$MdnsCache = @{}
    )

    $cleanMac = if ($Mac -and $Mac -ne "N/A") { $Mac.ToUpper().Replace(":", "-").Trim() } else { "N/A" }
    $isPrivate = Test-IsPrivateMac -Mac $cleanMac

    $ident = [PSCustomObject]@{
        IP           = $Ip
        Mac          = $cleanMac
        Hostname     = ""
        DeviceType   = "Generic Network Client"
        Vendor       = "Unknown Vendor"
        Model        = ""
        OS           = ""
        IsPrivateMac = $isPrivate
        Notes        = ""
    }

    # 1. Local PC
    if ($Ip -eq $LocalIp) {
        $ident.Hostname   = "$env:COMPUTERNAME (This PC)"
        $ident.DeviceType = "Desktop / Laptop (Windows 11 PC)"
        $ident.Vendor     = "Local Windows 11 Host"
        $ident.OS         = "Windows 11"
        $ident.IsPrivateMac = $false
        return $ident
    }

    # 2. Router Gateway
    if ($Ip -eq $GatewayIp) {
        $gwVendor = Get-RouterNameFromMac -Mac $cleanMac
        $ident.Hostname   = "FiberHome Gateway Router"
        $ident.DeviceType = "Network Router & Gateway"
        $ident.Vendor     = if ($gwVendor) { $gwVendor } else { "FiberHome Telecommunication Technologies" }
        $ident.IsPrivateMac = $false
        return $ident
    }

    # 3. Check persistent session cache
    if ($script:DEVICE_IDENTITY_CACHE.ContainsKey($cleanMac)) {
        $cached = $script:DEVICE_IDENTITY_CACHE[$cleanMac]
        if ($cached.Hostname)   { $ident.Hostname   = $cached.Hostname }
        if ($cached.DeviceType) { $ident.DeviceType = $cached.DeviceType }
        if ($cached.Vendor)     { $ident.Vendor     = $cached.Vendor }
        if ($cached.Model)      { $ident.Model      = $cached.Model }
        if ($cached.OS)         { $ident.OS         = $cached.OS }
    }

    # 4. Check Apple Lockdown Protocol (TCP 62078)
    $appleProbe = Probe-AppleDeviceLockdown -TargetIp $Ip
    if ($appleProbe.Success) {
        if ($appleProbe.DeviceName) { $ident.Hostname = $appleProbe.DeviceName }
        $ident.Vendor = "Apple Inc."
        $ident.Model  = $appleProbe.ProductType
        $ident.OS     = "iOS (iPhone OS)"
        if ($ident.Model -match '^iPad') {
            $ident.DeviceType = "Tablet (Apple iPad)"
        } elseif ($ident.Model -match '^iPhone') {
            $ident.DeviceType = "Smartphone (Apple iPhone)"
        } elseif ($ident.Model -match '^Watch') {
            $ident.DeviceType = "Wearable (Apple Watch)"
        } else {
            $ident.DeviceType = "Smartphone (Apple iOS Device)"
        }
        # Save to persistent cache
        $script:DEVICE_IDENTITY_CACHE[$cleanMac] = @{
            Hostname   = $ident.Hostname
            DeviceType = $ident.DeviceType
            Vendor     = $ident.Vendor
            Model      = $ident.Model
            OS         = $ident.OS
            IsApple    = $true
            IsPrivate  = $isPrivate
        }
        return $ident
    }

    # 5. Check mDNS Cache (Google Cast / Smart TVs / Bonjour)
    if ($MdnsCache.ContainsKey($Ip)) {
        $m = $MdnsCache[$Ip]
        if (-not $ident.Hostname -and $m.Name) { $ident.Hostname = $m.Name }
        if ($m.DeviceType) { $ident.DeviceType = $m.DeviceType }
        if ($m.Vendor)     { $ident.Vendor = $m.Vendor }
        $script:DEVICE_IDENTITY_CACHE[$cleanMac] = @{
            Hostname   = $ident.Hostname
            DeviceType = $ident.DeviceType
            Vendor     = $ident.Vendor
            Model      = $ident.Hostname
            OS         = "Android TV OS"
            IsApple    = $false
            IsPrivate  = $isPrivate
        }
        return $ident
    }

    # 6. Check NetBIOS Node Status (UDP 137)
    if (-not $ident.Hostname) {
        $nbName = Query-NetBiosNodeStatus -TargetIp $Ip
        if ($nbName) {
            $ident.Hostname   = $nbName
            $ident.DeviceType = "Workstation / PC (Windows/SMB)"
            $ident.Vendor     = "Microsoft / Windows Client"
            return $ident
        }
    }

    # 7. Check Reverse DNS PTR (UDP 53)
    if (-not $ident.Hostname) {
        try {
            $dnsTask = [System.Net.Dns]::GetHostEntryAsync($Ip)
            if ($dnsTask.Wait(80) -and $dnsTask.Result.HostName -and $dnsTask.Result.HostName -ne $Ip) {
                $ident.Hostname = $dnsTask.Result.HostName
            }
        } catch {}
    }

    # 8. MAC OUI Vendor Lookup
    $macVendor = Get-VendorFromMac -Mac $cleanMac
    if ($ident.Vendor -eq "Unknown Vendor" -and $macVendor -and $macVendor -notmatch "Unknown") {
        $ident.Vendor = $macVendor
    }

    # 9. Smart Heuristic Classification
    if ($ident.DeviceType -eq "Generic Network Client") {
        if ($ident.Vendor -match "Apple Inc.") {
            $ident.DeviceType = "Apple Device (iPhone / iPad / Mac)"
            if (-not $ident.Hostname) { $ident.Hostname = "Apple Client ($Ip)" }
        } elseif ($ident.Vendor -match "Samsung|Xiaomi|Pixel|Huawei|OnePlus") {
            $ident.DeviceType = "Smartphone / Tablet (Android)"
            if (-not $ident.Hostname) { $ident.Hostname = "$($ident.Vendor.Split(' ')[0]) Client ($Ip)" }
        } elseif ($ident.Vendor -match "Bilian|Smart TV|Sony|LG|Roku|Chromecast") {
            $ident.DeviceType = "Smart TV / Media Player"
            if (-not $ident.Hostname) { $ident.Hostname = "Smart TV ($Ip)" }
        } elseif ($ident.Vendor -match "Espressif|Tuya|Shelly|Nest|Echo") {
            $ident.DeviceType = "IoT / Smart Home Device"
            if (-not $ident.Hostname) { $ident.Hostname = "IoT Client ($Ip)" }
        } elseif ($isPrivate) {
            $ident.DeviceType = "Smartphone / Mobile Client (Private Wi-Fi Address)"
            if (-not $ident.Hostname) { $ident.Hostname = "Mobile Device ($Ip)" }
            $ident.Vendor     = "Private Wi-Fi Client (Randomized MAC)"
        } else {
            if (-not $ident.Hostname) { $ident.Hostname = "Client Device ($Ip)" }
        }
    }

    return $ident
}

function Invoke-LocalNetworkDiscovery {
    [CmdletBinding()]
    param(
        [string]$LocalIp = "192.168.1.4",
        [string]$GatewayIp = "192.168.1.2"
    )

    Write-SectionTitle "PATH 2: LOCAL NETWORK DEVICE DISCOVERY & WEB AUDIT" "[+]"
    Write-Host "   ${global:C_BLUE}Discovering active clients, identifying Apple & smart devices, port mapping & inspecting web portals...${global:C_RESET}`n"

    # 1. Warm ARP cache via ICMP broadcast and gateway ping
    try {
        if ($LocalIp -match '^(\d+\.\d+\.\d+)\.\d+$') {
            $base = $matches[1]
            $ping = New-Object System.Net.NetworkInformation.Ping
            [void]$ping.Send("$base.255", 60)
            [void]$ping.Send($GatewayIp, 80)
            @(1, 2, 3, 4, 5, 7, 10, 20, 50, 100, 254) | ForEach-Object {
                try { [void]$ping.Send("$base.$_", 30) } catch {}
            }
            $ping.Dispose()
        }
    } catch {}

    # 2. Background mDNS discovery for Smart TVs, Google Cast & Apple services
    $mdnsCache = Collect-SubnetMdnsMap -LocalIp $LocalIp

    # 3. Extract ARP entries
    $arpEntries = @{}
    try {
        $arp = arp -a
        foreach ($line in $arp) {
            if ($line -match '^\s*([0-9\.]+)\s+([0-9a-fA-F-]+)\s+(\w+)') {
                $ip = $matches[1]
                $mac = $matches[2].ToUpper().Replace(":", "-")
                if ($mac -ne "FF-FF-FF-FF-FF-FF" -and $ip -notmatch '^(224\.|239\.|255\.|169\.254\.)' -and -not $ip.EndsWith('.255')) {
                    $arpEntries[$ip] = $mac
                }
            }
        }
    } catch {}

    $candidateIps = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($ip in $arpEntries.Keys) { [void]$candidateIps.Add($ip) }
    if ($LocalIp) { [void]$candidateIps.Add($LocalIp) }
    if ($GatewayIp) { [void]$candidateIps.Add($GatewayIp) }

    # Common port targets including Apple MobileDevice (62078) and Google Cast (8008)
    $scanPorts = @(80, 443, 8080, 22, 23, 445, 53, 62078, 5555, 8008)
    $devicesFound = 0

    foreach ($ip in ($candidateIps | Sort-Object { [version]$_ })) {
        $devicesFound++
        $mac = if ($arpEntries.ContainsKey($ip)) { $arpEntries[$ip] } else { "N/A" }
        if ($ip -eq $LocalIp) {
            $realAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Loopback|Npcap|Virtual' } | Select-Object -First 1
            if ($realAdapter) {
                $mac = $realAdapter.MacAddress
            } else {
                $mac = (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1).MacAddress
            }
        }

        # Resolve detailed identity (Hostname, Device Type, Model, OS, Vendor)
        $ident = Resolve-DeviceIdentity -Ip $ip -Mac $mac -GatewayIp $GatewayIp -LocalIp $LocalIp -MdnsCache $mdnsCache

        # Port scanning
        $openPorts = [System.Collections.Generic.List[int]]::new()
        foreach ($p in $scanPorts) {
            if (Test-TcpPortQuick -TargetIp $ip -Port $p -TimeoutMs 220) {
                $openPorts.Add($p)
            }
        }

        # Format open port list with human-friendly descriptions
        $portDescList = [System.Collections.Generic.List[string]]::new()
        foreach ($op in $openPorts) {
            $desc = if ($script:PORT_DESCRIPTIONS.ContainsKey($op)) { " ($($script:PORT_DESCRIPTIONS[$op]))" } else { "" }
            $portDescList.Add("$op$desc")
        }

        $portListStr = if ($portDescList.Count -gt 0) { ($portDescList -join ", ") } else { "None detected" }
        $portColor = if ($openPorts.Count -gt 0) { $global:C_GREEN } else { $global:C_GRAY }

        # Formatting device attributes
        $typeColor = if ($ident.DeviceType -match "Apple|iPhone|iPad") {
            $global:C_GREEN
        } elseif ($ident.DeviceType -match "Router|Gateway") {
            $global:C_CYAN
        } elseif ($ident.DeviceType -match "Smart TV|Streaming") {
            $global:C_BLUE
        } else {
            $global:C_GREEN
        }

        $hardwareStr = $ident.Vendor
        if ($ident.Model) { $hardwareStr += " ($($ident.Model))" }
        if ($ident.IsPrivateMac) {
            $hardwareStr += " ${global:C_AMBER}[Private Wi-Fi Address]${global:C_RESET}"
        }

        Write-Host "  ${global:C_BLUE}========================================================================================${global:C_RESET}"
        Write-Host "   ${global:C_GREEN}${global:C_BOLD}[DEVICE #$devicesFound]${global:C_RESET} ${global:C_BLUE}$ip${global:C_RESET} ${global:C_GRAY}|${global:C_RESET} ${global:C_BOLD}$($ident.Hostname)${global:C_RESET}"
        Write-Host "   ${global:C_BLUE}Device Type   : ${typeColor}${global:C_BOLD}$($ident.DeviceType)${global:C_RESET}"
        Write-Host "   ${global:C_BLUE}Hardware/Brand: ${global:C_RESET}$hardwareStr"
        Write-Host "   ${global:C_BLUE}MAC Address   : ${global:C_RESET}$mac"
        Write-Host "   ${global:C_BLUE}Open Ports    : ${portColor}$portListStr${global:C_RESET}"

        # Webpage and Directory Discovery Scan
        $webPorts = $openPorts | Where-Object { $_ -in @(80, 443, 8080) }
        if ($webPorts) {
            foreach ($wp in $webPorts) {
                $webScan = Discover-DeviceWebPages -TargetIp $ip -Port $wp
                if ($webScan.HostedWebpage) {
                    $titleStr = if ($webScan.Title) { $webScan.Title } else { "Default Index Page" }
                    Write-Host "   ${global:C_GREEN}Hosted Webpage: ${global:C_BOLD}$($webScan.BaseUrl)/${global:C_RESET} ${global:C_GRAY}[Title: $titleStr]${global:C_RESET}"
                    
                    if ($webScan.FoundDirectories.Count -gt 0) {
                        $dirsStr = ($webScan.FoundDirectories -join ", ")
                        Write-Host "   ${global:C_BLUE}Found Pages   : ${global:C_GREEN}$dirsStr${global:C_RESET}"
                    } else {
                        Write-Host "   ${global:C_BLUE}Found Pages   : ${global:C_GRAY}Root page active (no hidden directories matched)${global:C_RESET}"
                    }
                }
            }
        } else {
            Write-Host "   ${global:C_BLUE}Web Services  : ${global:C_GRAY}No web servers hosted on standard ports${global:C_RESET}"
        }
    }

    Write-Host "  ${global:C_BLUE}========================================================================================${global:C_RESET}`n"
    Write-Host "  ${global:C_GREEN}[OK] Discovered $devicesFound active network device(s). Device type identification & audit complete.${global:C_RESET}"
}

Export-ModuleMember -Function Invoke-LocalNetworkDiscovery, Discover-DeviceWebPages, Test-TcpPortQuick, Resolve-DeviceIdentity
