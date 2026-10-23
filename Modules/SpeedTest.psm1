<#
================================================================================
 ProNetwork11 - Multi-Provider Speed Engine & Latency Suite
 Author: diogeneslite (https://github.com/diogeneslite)
 Description: Sustained CDN download throughput tests, high-precision latency & jitter probes
================================================================================
#>
[CmdletBinding()]
param()

$script:SPEED_PROVIDERS = @(
    [PSCustomObject]@{
        Id          = "1"
        Name        = "Cloudflare Speed Test"
        Region      = "Global Anycast Edge (Recommended)"
        Url         = "https://speed.cloudflare.com/__down?bytes=35000000"
        PayloadMB   = 35
    },
    [PSCustomObject]@{
        Id          = "2"
        Name        = "Fastly Global CDN"
        Region      = "Python Software Foundation Edge"
        Url         = "https://www.python.org/ftp/python/3.12.2/python-3.12.2-amd64.exe"
        PayloadMB   = 25
    },
    [PSCustomObject]@{
        Id          = "3"
        Name        = "Node.js Distribution CDN"
        Region      = "Cloudflare / Fastly Multi-CDN"
        Url         = "https://nodejs.org/dist/v20.12.2/node-v20.12.2-x64.msi"
        PayloadMB   = 30
    },
    [PSCustomObject]@{
        Id          = "4"
        Name        = "AWS / Fastly CDN"
        Region      = "GitHub Software Distribution Edge"
        Url         = "https://github.com/cli/cli/releases/download/v2.45.0/gh_2.45.0_windows_amd64.zip"
        PayloadMB   = 15
    }
)

function Get-SpeedProviders {
    return $script:SPEED_PROVIDERS
}

function Test-DeepLatencyAndJitter {
    [CmdletBinding()]
    param(
        [string]$Target = "1.1.1.1",
        [string]$Label = "Internet Edge (Cloudflare)",
        [int]$SampleCount = 30
    )

    $times = [System.Collections.Generic.List[double]]::new()
    $lost = 0
    $ping = New-Object System.Net.NetworkInformation.Ping

    Write-Host "   ${global:C_BLUE}Collecting $SampleCount live ping samples for high-precision average...${global:C_RESET}"
    
    for ($i = 1; $i -le $SampleCount; $i++) {
        try {
            $reply = $ping.Send($Target, 800)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $rtt = [double]$reply.RoundtripTime
                $times.Add($rtt)
                $sampleColor = if ($rtt -le 35) { $global:C_GREEN } elseif ($rtt -le 75) { $global:C_BLUE } else { $global:C_RED }
                Write-Host -NoNewline "`r   ${global:C_BLUE}Sample [$i/$SampleCount]: ${sampleColor}$rtt ms${global:C_RESET}  "
            } else {
                $lost++
                Write-Host -NoNewline "`r   ${global:C_BLUE}Sample [$i/$SampleCount]: ${global:C_RED}Timeout${global:C_RESET}  "
            }
        } catch {
            $lost++
        }
        Start-Sleep -Milliseconds 35
    }
    $ping.Dispose()
    Write-Host "`r                                                                       `r" -NoNewline

    if ($times.Count -eq 0) {
        return [PSCustomObject]@{
            Target       = $Target
            Label        = $Label
            SampleCount  = $SampleCount
            ValidSamples = 0
            MinMs        = 0
            AvgMs        = 0
            MedianMs     = 0
            MaxMs        = 0
            JitterMs     = 0
            StdDevMs     = 0
            PacketLoss   = 100.0
            Status       = "Failed"
            HealthStatus = "Negative"
        }
    }

    $sorted = $times | Sort-Object
    $min = ($times | Measure-Object -Minimum).Minimum
    $max = ($times | Measure-Object -Maximum).Maximum
    $avg = [Math]::Round(($times | Measure-Object -Average).Average, 1)

    # Median calculation
    $mid = [int]($sorted.Count / 2)
    $median = if ($sorted.Count % 2 -ne 0) {
        $sorted[$mid]
    } else {
        [Math]::Round(($sorted[$mid - 1] + $sorted[$mid]) / 2.0, 1)
    }

    # Jitter (Mean Absolute Deviation between consecutive packets)
    $jitterSum = 0.0
    for ($i = 1; $i -lt $times.Count; $i++) {
        $jitterSum += [Math]::Abs($times[$i] - $times[$i - 1])
    }
    $jitter = if ($times.Count -gt 1) { [Math]::Round($jitterSum / ($times.Count - 1), 2) } else { 0 }

    # Standard Deviation
    $varianceSum = 0.0
    foreach ($val in $times) {
        $varianceSum += [Math]::Pow(($val - $avg), 2)
    }
    $stdDev = [Math]::Round([Math]::Sqrt($varianceSum / $times.Count), 2)
    $lossRate = [Math]::Round(($lost / $SampleCount) * 100, 1)

    # Overall health categorization
    $healthStatus = if ($lossRate -eq 0 -and $avg -le 40 -and $jitter -le 5) {
        "Positive"
    } elseif ($lossRate -gt 0 -or $avg -gt 80 -or $jitter -gt 15) {
        "Negative"
    } else {
        "Neutral"
    }

    return [PSCustomObject]@{
        Target       = $Target
        Label        = $Label
        SampleCount  = $SampleCount
        ValidSamples = $times.Count
        MinMs        = $min
        AvgMs        = $avg
        MedianMs     = $median
        MaxMs        = $max
        JitterMs     = $jitter
        StdDevMs     = $stdDev
        PacketLoss   = $lossRate
        Status       = "Success"
        HealthStatus = $healthStatus
    }
}

function Test-DownloadSpeedFromProvider {
    [CmdletBinding()]
    param(
        [string]$TestUrl = "https://speed.cloudflare.com/__down?bytes=35000000",
        [string]$ProviderName = "Cloudflare Speed Test",
        [int]$MaxSeconds = 14
    )

    $result = [PSCustomObject]@{
        ProviderName = $ProviderName
        SpeedMbps    = 0.0
        TotalMB      = 0.0
        DurationSec  = 0.0
        Grade        = "Unknown"
        Status       = "Neutral"
        HumanVerdict = ""
    }

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
        $req = [System.Net.HttpWebRequest]::Create($TestUrl)
        $req.Timeout = 12000
        $req.UserAgent = "ProNetwork11-Win11-Diagnostic"
        $req.Proxy = $null

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $resp = $req.GetResponse()
        $stream = $resp.GetResponseStream()

        $buffer = New-Object byte[] 65536
        $totalBytesRead = 0
        $lastReport = [System.Diagnostics.Stopwatch]::StartNew()

        Write-Host ""
        while ($sw.Elapsed.TotalSeconds -lt $MaxSeconds) {
            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -le 0) { break }
            $totalBytesRead += $bytesRead

            if ($lastReport.ElapsedMilliseconds -ge 120) {
                $curSec = $sw.Elapsed.TotalSeconds
                $curMbps = if ($curSec -gt 0) { [Math]::Round(($totalBytesRead * 8) / ($curSec * 1000000), 2) } else { 0 }
                $curMB = [Math]::Round($totalBytesRead / 1MB, 2)
                
                $blocks = [Math]::Min(30, [int]($curMbps / 5))
                $meter = ("#" * $blocks).PadRight(30, [char]'-')
                Write-Host -NoNewline "`r   ${global:C_BLUE}Progress: [${global:C_GREEN}$meter${global:C_BLUE}] $curMB MB * Speed: ${global:C_GREEN}${global:C_BOLD}$curMbps Mbps${global:C_RESET}  "
                $lastReport.Restart()
            }
        }

        $stream.Close()
        $resp.Close()
        $sw.Stop()

        Write-Host "`r                                                                                   `r" -NoNewline

        $dur = [Math]::Max(0.1, $sw.Elapsed.TotalSeconds)
        $mbps = [Math]::Round(($totalBytesRead * 8) / ($dur * 1000000), 2)
        $totalMB = [Math]::Round($totalBytesRead / 1MB, 2)

        $result.SpeedMbps   = $mbps
        $result.TotalMB     = $totalMB
        $result.DurationSec = [Math]::Round($dur, 2)

        if ($mbps -ge 80) {
            $result.Grade = "A+ (Ultra-Fast Fiber)"
            $result.Status = "Positive"
            $result.HumanVerdict = "Outstanding download throughput. Flawless 4K/8K video streaming, near-instant gigabyte transfers, and seamless heavy workload handling."
        } elseif ($mbps -ge 40) {
            $result.Grade = "A (High-Speed Broadband)"
            $result.Status = "Positive"
            $result.HumanVerdict = "Fast and reliable speed. Great for uninterrupted 4K HDR playback, rapid gaming downloads, and multiple concurrent users."
        } elseif ($mbps -ge 15) {
            $result.Grade = "B (Standard Broadband)"
            $result.Status = "Neutral"
            $result.HumanVerdict = "Decent connectivity. Capable of handling HD streaming, smooth video conference calls, and daily web tasks."
        } elseif ($mbps -ge 5) {
            $result.Grade = "C (Fair Connection)"
            $result.Status = "Neutral"
            $result.HumanVerdict = "Basic bandwidth. Sufficient for simple browsing, but concurrent high-resolution streams or file updates may buffer."
        } else {
            $result.Grade = "D (Slow / Bottlenecked)"
            $result.Status = "Negative"
            $result.HumanVerdict = "Noticeable bottleneck detected. You may encounter streaming buffering, meeting disconnects, or sluggish downloads."
        }

    } catch {
        $result.Status = "Negative"
        $result.HumanVerdict = "Could not download test payload from $ProviderName ($($_.Exception.Message))."
    }

    return $result
}

Export-ModuleMember -Function Get-SpeedProviders, Test-DeepLatencyAndJitter, Test-DownloadSpeedFromProvider
