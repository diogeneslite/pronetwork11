<#
================================================================================
 ProNetwork11 - Network Performance & Stability Audit Suite
 Author: diogeneslite (https://github.com/diogeneslite)
 Description: Long-run gateway stability, packet loss metrics & multi-resolver DNS benchmarks
================================================================================
#>
[CmdletBinding()]
param()

function Test-GatewayStability {
    [CmdletBinding()]
    param(
        [string]$GatewayIp = "192.168.1.2",
        [int]$Count = 25
    )

    $times = [System.Collections.Generic.List[double]]::new()
    $lost = 0
    $ping = New-Object System.Net.NetworkInformation.Ping

    for ($i = 0; $i -lt $Count; $i++) {
        try {
            $reply = $ping.Send($GatewayIp, 800)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $times.Add($reply.RoundtripTime)
            } else {
                $lost++
            }
        } catch {
            $lost++
        }
        Start-Sleep -Milliseconds 35
    }
    $ping.Dispose()

    if ($times.Count -eq 0) {
        return [PSCustomObject]@{
            GatewayIp  = $GatewayIp
            MinMs      = 0
            AvgMs      = 0
            MedianMs   = 0
            MaxMs      = 0
            JitterMs   = 0
            LossRate   = 100.0
            Health     = "Critical: Router is unreachable on ICMP packets."
            Status     = "Negative"
        }
    }

    $sorted = $times | Sort-Object
    $min = ($times | Measure-Object -Minimum).Minimum
    $max = ($times | Measure-Object -Maximum).Maximum
    $avg = [Math]::Round(($times | Measure-Object -Average).Average, 1)
    $mid = [int]($sorted.Count / 2)
    $median = if ($sorted.Count % 2 -ne 0) { $sorted[$mid] } else { [Math]::Round(($sorted[$mid-1] + $sorted[$mid]) / 2.0, 1) }

    $jitterSum = 0.0
    for ($i = 1; $i -lt $times.Count; $i++) {
        $jitterSum += [Math]::Abs($times[$i] - $times[$i - 1])
    }
    $jitter = if ($times.Count -gt 1) { [Math]::Round($jitterSum / ($times.Count - 1), 2) } else { 0 }
    $lossRate = [Math]::Round(($lost / $Count) * 100, 1)

    $health = ""
    $status = "Neutral"

    if ($lossRate -eq 0 -and $avg -le 5 -and $jitter -le 3) {
        $health = "Flawless local connection. Zero packet drops and minimal latency between your PC and the router."
        $status = "Positive"
    } elseif ($lossRate -eq 0 -and $avg -le 20) {
        $health = "Good local connection. Suitable for gaming and video conferencing."
        $status = "Positive"
    } elseif ($lossRate -gt 0) {
        $health = "Packet loss ($lossRate%) detected on your local link! Likely Wi-Fi interference or cabling issues."
        $status = "Negative"
    } else {
        $health = "High jitter ($jitter ms) detected between PC and router. Check Wi-Fi distance or radio channel congestion."
        $status = "Negative"
    }

    return [PSCustomObject]@{
        GatewayIp  = $GatewayIp
        MinMs      = $min
        AvgMs      = $avg
        MedianMs   = $median
        MaxMs      = $max
        JitterMs   = $jitter
        LossRate   = $lossRate
        Health     = $health
        Status     = $status
    }
}

function Test-DnsBenchmark {
    [CmdletBinding()]
    param(
        [string[]]$LocalDnsServers = @("192.168.1.2")
    )

    $testHostnames = @("google.com", "cloudflare.com", "microsoft.com", "github.com")
    $providers = @(
        @{ Name = "Local/Configured DNS"; Server = ($LocalDnsServers | Select-Object -First 1) },
        @{ Name = "Cloudflare (1.1.1.1)"; Server = "1.1.1.1" },
        @{ Name = "Google Public (8.8.8.8)"; Server = "8.8.8.8" },
        @{ Name = "Quad9 Secure (9.9.9.9)"; Server = "9.9.9.9" }
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($p in $providers) {
        if (-not $p.Server) { continue }
        $totalMs = 0
        $successCount = 0

        foreach ($hostName in $testHostnames) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $dnsRes = Resolve-DnsName -Name $hostName -Server $p.Server -Type A -QuickTimeout -ErrorAction Stop
                $sw.Stop()
                if ($dnsRes) {
                    $totalMs += $sw.Elapsed.TotalMilliseconds
                    $successCount++
                }
            } catch {
                $sw.Stop()
            }
        }

        $avgMs = if ($successCount -gt 0) { [Math]::Round($totalMs / $successCount, 1) } else { 999.0 }
        
        $rating = ""
        $status = "Neutral"

        if ($avgMs -le 25) {
            $rating = "Ultra-Fast"
            $status = "Positive"
        } elseif ($avgMs -le 60) {
            $rating = "Good"
            $status = "Neutral"
        } elseif ($avgMs -lt 999) {
            $rating = "Sluggish"
            $status = "Negative"
        } else {
            $rating = "Unreachable"
            $status = "Negative"
        }

        $results.Add([PSCustomObject]@{
            Provider = $p.Name
            Server   = $p.Server
            AvgMs    = $avgMs
            Rating   = $rating
            Status   = $status
        })
    }

    return $results
}

function Invoke-FullStabilityAudit {
    [CmdletBinding()]
    param(
        [string]$GatewayIp = "192.168.1.2",
        [string[]]$DnsServers = @("1.1.1.1"),
        [string]$ConnectionType = "Wi-Fi",
        [string]$LinkSpeed = "350 Mbps"
    )

    $audit = [PSCustomObject]@{
        Score            = 100
        StatusBadge      = "EXCELLENT"
        StatusColor      = "Positive"
        GatewayReport    = $null
        DnsReport        = $null
        Recommendations  = [System.Collections.Generic.List[string]]::new()
    }

    $gw = Test-GatewayStability -GatewayIp $GatewayIp -Count 25
    $audit.GatewayReport = $gw

    if ($gw.LossRate -gt 0) {
        $audit.Score -= [Math]::Min(35, [int]($gw.LossRate * 3))
        $audit.Recommendations.Add("Fix packet loss: Move closer to your Wi-Fi AP or switch to a wired Cat6 Ethernet cable.")
    }
    if ($gw.JitterMs -gt 8) {
        $audit.Score -= 15
        $audit.Recommendations.Add("High local jitter: Avoid congested 2.4GHz Wi-Fi channels and prioritize 5GHz or 6GHz bands.")
    }
    if ($gw.AvgMs -gt 25) {
        $audit.Score -= 10
        $audit.Recommendations.Add("Elevated router ping ($($gw.AvgMs) ms): Router CPU may be busy or handling heavy background device traffic.")
    }

    $dns = Test-DnsBenchmark -LocalDnsServers $DnsServers
    $audit.DnsReport = $dns
    
    $bestDns = $dns | Where-Object { $_.Rating -ne 'Unreachable' } | Sort-Object AvgMs | Select-Object -First 1
    if ($bestDns -and $bestDns.Provider -notmatch "Local/Configured") {
        $configuredDns = $dns | Where-Object { $_.Provider -match "Local/Configured" } | Select-Object -First 1
        if ($configuredDns -and ($configuredDns.AvgMs - $bestDns.AvgMs) -gt 25) {
            $audit.Score -= 5
            $audit.Recommendations.Add("Switch DNS: $($bestDns.Provider) responded in $($bestDns.AvgMs) ms, which is faster than current DNS ($($configuredDns.AvgMs) ms).")
        }
    }

    if ($ConnectionType -eq "Wi-Fi" -and $LinkSpeed -match "Mbps") {
        $speedNum = 0
        if ($LinkSpeed -match '(\d+(\.\d+)?)') { $speedNum = [double]$matches[1] }
        if ($speedNum -lt 100) {
            $audit.Score -= 10
            $audit.Recommendations.Add("Low Wi-Fi link speed ($LinkSpeed): Adapter negotiated a throttled rate. Check antenna line-of-sight.")
        }
    }

    $audit.Score = [Math]::Max(10, [Math]::Min(100, $audit.Score))
    if ($audit.Score -ge 90) {
        $audit.StatusBadge = "EXCELLENT"
        $audit.StatusColor = "Positive"
    } elseif ($audit.Score -ge 75) {
        $audit.StatusBadge = "GOOD"
        $audit.StatusColor = "Positive"
    } elseif ($audit.Score -ge 55) {
        $audit.StatusBadge = "FAIR"
        $audit.StatusColor = "Neutral"
    } else {
        $audit.StatusBadge = "DEGRADED"
        $audit.StatusColor = "Negative"
    }

    if ($audit.Recommendations.Count -eq 0) {
        $audit.Recommendations.Add("No issues found! Your local network and DNS configuration are running at peak performance.")
    }

    return $audit
}

Export-ModuleMember -Function Test-GatewayStability, Test-DnsBenchmark, Invoke-FullStabilityAudit
