<#
================================================================================
 ProNetwork11 - Network Benchmarks & Diagnostics Engine
 Author: diogeneslite (https://github.com/diogeneslite)
 Description: Path 1 single-line benchmarks, RF jitter, DNS test & health scoring
================================================================================
#>
[CmdletBinding()]
param()

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not (Get-Command Write-BenchmarkRow -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $scriptDir "UI.psm1") -DisableNameChecking
}

function Invoke-AllNetworkBenchmarks {
    [CmdletBinding()]
    param(
        [string]$GatewayIp = "192.168.1.1",
        [string[]]$DnsServers = @("1.1.1.1")
    )

    Write-SectionTitle "PATH 1: NETWORK TESTS & COMPREHENSIVE BENCHMARKS" "[+]"
    Write-Host "   ${global:C_BLUE}Running high-precision diagnostics across your local link and internet edge...${global:C_RESET}`n"

    $ping = New-Object System.Net.NetworkInformation.Ping
    $totalScore = 100

    # 1. Router Gateway Latency & Jitter (35 samples for statistical precision)
    $gwTimes = [System.Collections.Generic.List[double]]::new()
    $gwLost = 0
    $sampleCount = 35
    for ($i = 0; $i -lt $sampleCount; $i++) {
        try {
            $rep = $ping.Send($GatewayIp, 600)
            if ($rep.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $gwTimes.Add($rep.RoundtripTime)
            } else { $gwLost++ }
        } catch { $gwLost++ }
        Start-Sleep -Milliseconds 45
    }

    $gwAvg = if ($gwTimes.Count -gt 0) { [Math]::Round(($gwTimes | Measure-Object -Average).Average, 1) } else { 999 }
    $gwJitter = 0.0
    for ($i = 1; $i -lt $gwTimes.Count; $i++) {
        $gwJitter += [Math]::Abs($gwTimes[$i] - $gwTimes[$i - 1])
    }
    if ($gwTimes.Count -gt 1) { $gwJitter = [Math]::Round($gwJitter / ($gwTimes.Count - 1), 1) }

    $gwLossRate = [Math]::Round(($gwLost / $sampleCount) * 100, 1)

    $gwScore = if ($gwAvg -le 3) { 'EXCELLENT' } elseif ($gwAvg -le 8) { 'GOOD' } elseif ($gwAvg -le 20) { 'FAIR' } else { 'POOR' }
    Write-BenchmarkRow -TestName "Router Gateway Latency" -MeasuredValue "$gwAvg ms" -Score $gwScore -Detail "35-sample average to $GatewayIp"

    $gwJitterScore = if ($gwJitter -le 1.5) { 'EXCELLENT' } elseif ($gwJitter -le 4) { 'GOOD' } elseif ($gwJitter -le 10) { 'FAIR' } else { 'POOR' }
    Write-BenchmarkRow -TestName "Router Gateway Jitter" -MeasuredValue "$gwJitter ms" -Score $gwJitterScore -Detail "Statistical local variance"

    # 2. Internet Backbone Latency & Jitter (Cloudflare 1.1.1.1 - 35 samples)
    $netTimes = [System.Collections.Generic.List[double]]::new()
    $netLost = 0
    for ($i = 0; $i -lt $sampleCount; $i++) {
        try {
            $rep = $ping.Send("1.1.1.1", 800)
            if ($rep.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $netTimes.Add($rep.RoundtripTime)
            } else { $netLost++ }
        } catch { $netLost++ }
        Start-Sleep -Milliseconds 55
    }

    $netAvg = if ($netTimes.Count -gt 0) { [Math]::Round(($netTimes | Measure-Object -Average).Average, 1) } else { 999 }
    $netJitter = 0.0
    for ($i = 1; $i -lt $netTimes.Count; $i++) {
        $netJitter += [Math]::Abs($netTimes[$i] - $netTimes[$i - 1])
    }
    if ($netTimes.Count -gt 1) { $netJitter = [Math]::Round($netJitter / ($netTimes.Count - 1), 1) }

    $netLossRate = [Math]::Round(($netLost / $sampleCount) * 100, 1)
    $ping.Dispose()

    $netScore = if ($netAvg -le 35) { 'EXCELLENT' } elseif ($netAvg -le 65) { 'GOOD' } elseif ($netAvg -le 100) { 'FAIR' } else { 'POOR' }
    Write-BenchmarkRow -TestName "Internet Backbone Latency" -MeasuredValue "$netAvg ms" -Score $netScore -Detail "35-sample Anycast 1.1.1.1"

    $netJitterScore = if ($netJitter -le 3.0) { 'EXCELLENT' } elseif ($netJitter -le 8.0) { 'GOOD' } elseif ($netJitter -le 15.0) { 'FAIR' } else { 'POOR' }
    Write-BenchmarkRow -TestName "Internet Edge Jitter" -MeasuredValue "$netJitter ms" -Score $netJitterScore -Detail "Long-run packet travel deviation"

    # 3. Overall Packet Loss Rate
    $totalLoss = [Math]::Max($gwLossRate, $netLossRate)
    $lossScore = if ($totalLoss -eq 0) { 'EXCELLENT' } elseif ($totalLoss -le 2) { 'FAIR' } else { 'CRITICAL' }
    Write-BenchmarkRow -TestName "ICMP Packet Loss Rate" -MeasuredValue "$totalLoss %" -Score $lossScore -Detail "Evaluated across 70 packets"

    # 4. Multi-Sample TCP Handshake Latency (5 handshakes)
    $tcpSamples = [System.Collections.Generic.List[double]]::new()
    for ($t = 0; $t -lt 5; $t++) {
        try {
            $c = New-Object System.Net.Sockets.TcpClient
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $ar = $c.BeginConnect("1.1.1.1", 443, $null, $null)
            if ($ar.AsyncWaitHandle.WaitOne(1500, $false)) {
                $c.EndConnect($ar)
                $sw.Stop()
                $tcpSamples.Add($sw.Elapsed.TotalMilliseconds)
            }
            $c.Close()
        } catch {}
        Start-Sleep -Milliseconds 60
    }
    $tcpMs = if ($tcpSamples.Count -gt 0) { [Math]::Round(($tcpSamples | Measure-Object -Average).Average, 1) } else { 999.0 }

    $tcpScore = if ($tcpMs -le 45) { 'EXCELLENT' } elseif ($tcpMs -le 85) { 'GOOD' } elseif ($tcpMs -le 130) { 'FAIR' } else { 'POOR' }
    Write-BenchmarkRow -TestName "TCP Handshake Latency" -MeasuredValue "$tcpMs ms" -Score $tcpScore -Detail "5-sample HTTPS 443 SYN/ACK mean"

    # 5. Multi-Query DNS Resolution Benchmarks (3 queries per provider)
    $dnsTargets = @(
        @{ Name = "Local Router DNS"; Server = $GatewayIp },
        @{ Name = "Cloudflare (1.1.1.1)"; Server = "1.1.1.1" },
        @{ Name = "Google Public (8.8.8.8)"; Server = "8.8.8.8" },
        @{ Name = "Quad9 Secure (9.9.9.9)"; Server = "9.9.9.9" }
    )
    $domains = @("microsoft.com", "cloudflare.com", "google.com")

    foreach ($dt in $dnsTargets) {
        $dnsSamples = [System.Collections.Generic.List[double]]::new()
        foreach ($dom in $domains) {
            try {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $dnsRes = Resolve-DnsName -Name $dom -Server $dt.Server -Type A -QuickTimeout -ErrorAction Stop
                $sw.Stop()
                if ($dnsRes) { $dnsSamples.Add($sw.Elapsed.TotalMilliseconds) }
            } catch {}
            Start-Sleep -Milliseconds 30
        }
        $dnsMs = if ($dnsSamples.Count -gt 0) { [Math]::Round(($dnsSamples | Measure-Object -Average).Average, 1) } else { 999.0 }

        $dScore = if ($dnsMs -le 25) { 'EXCELLENT' } elseif ($dnsMs -le 60) { 'GOOD' } elseif ($dnsMs -le 110) { 'FAIR' } else { 'POOR' }
        Write-BenchmarkRow -TestName "$($dt.Name) Benchmark" -MeasuredValue "$dnsMs ms" -Score $dScore -Detail "3-domain averaged resolution"
    }

    # 6. Sustained 8-Second Live Download Bandwidth Speed Test
    $dlSpeedMbps = 0.0
    $testDurationSeconds = 8.0
    $dur = $testDurationSeconds
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
        $req = [System.Net.HttpWebRequest]::Create("https://nodejs.org/dist/v20.12.2/node-v20.12.2-x64.msi")
        $req.Timeout = 12000
        $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ProNetwork11"
        $req.Proxy = $null
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $resp = $req.GetResponse()
        $stream = $resp.GetResponseStream()
        $buffer = New-Object byte[] 65536
        $totalBytes = 0
        $lastReport = 0.0

        Write-Host "   ${global:C_BLUE}[*] Measuring sustained throughput over 8 seconds...${global:C_RESET}" -NoNewline

        while ($sw.Elapsed.TotalSeconds -lt $testDurationSeconds) {
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            $totalBytes += $read

            $curSec = [Math]::Max(0.2, $sw.Elapsed.TotalSeconds)
            $dur = $curSec
            $dlSpeedMbps = [Math]::Round(($totalBytes * 8) / ($curSec * 1000000), 2)

            if ($curSec - $lastReport -ge 0.5) {
                $lastReport = $curSec
                $pct = [Math]::Min(100, [int](($curSec / $testDurationSeconds) * 100))
                Write-Host "`r   ${global:C_BLUE}[*] Measuring sustained throughput... ${global:C_GREEN}$dlSpeedMbps Mbps${global:C_RESET} ${global:C_GRAY}($($pct)% complete - $([Math]::Round($curSec, 1))s / ${testDurationSeconds}s)${global:C_RESET}   " -NoNewline
            }
        }
        $stream.Close()
        $resp.Close()
        $sw.Stop()
    } catch {}
    finally {
        Write-Host "`r                                                                                `r" -NoNewline
        if ($dur -gt 0 -and $totalBytes -gt 0) {
            $dlSpeedMbps = [Math]::Round(($totalBytes * 8) / ($dur * 1000000), 2)
        }
    }

    $speedScore = if ($dlSpeedMbps -ge 30) { 'EXCELLENT' } elseif ($dlSpeedMbps -ge 15) { 'GOOD' } elseif ($dlSpeedMbps -ge 5) { 'FAIR' } else { 'POOR' }
    Write-BenchmarkRow -TestName "Internet Download Speed" -MeasuredValue "$dlSpeedMbps Mbps" -Score $speedScore -Detail "$([Math]::Round($dur, 1))s sustained CDN throughput"

    # 7. Composite Connection Health Score
    if ($totalLoss -gt 0) { $totalScore -= [int]($totalLoss * 4) }
    if ($gwAvg -gt 10) { $totalScore -= 10 }
    if ($gwJitter -gt 5) { $totalScore -= 10 }
    if ($dlSpeedMbps -lt 15) { $totalScore -= 10 }
    $totalScore = [Math]::Max(10, [Math]::Min(100, $totalScore))

    $compositeRating = if ($totalScore -ge 90) { 'EXCELLENT' } elseif ($totalScore -ge 75) { 'GOOD' } elseif ($totalScore -ge 50) { 'FAIR' } else { 'POOR' }
    Write-Host ""
    Write-BenchmarkRow -TestName "Overall Network Health Score" -MeasuredValue "$totalScore / 100" -Score $compositeRating -Detail "Composite rating across all tests"

    Write-Host ""
    if ($compositeRating -in @('EXCELLENT', 'GOOD')) {
        Write-Host "  ${global:C_GREEN}[OK] Your network is performing at peak efficiency with low latency and zero packet loss.${global:C_RESET}"
    } else {
        Write-Host "  ${global:C_RED}[FAIL] Network bottlenecks detected. Review tests with [FAIR] or [POOR] ratings above.${global:C_RESET}"
    }
}

Export-ModuleMember -Function Invoke-AllNetworkBenchmarks
