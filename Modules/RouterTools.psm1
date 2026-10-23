<#
================================================================================
 ProNetwork11 - Router Diagnostics, Traceroute & Management Tools
 Author: diogeneslite (https://github.com/diogeneslite)
 Description: Fast TCP port auditing, hop-by-hop traceroute & remote terminal launcher
================================================================================
#>
[CmdletBinding()]
param()

function Test-PortOpen {
    param(
        [string]$TargetIp,
        [int]$Port,
        [int]$TimeoutMs = 800
    )
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $client.BeginConnect($TargetIp, $Port, $null, $null)
        $success = $ar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($success -and $client.Connected) {
            $client.EndConnect($ar)
            $client.Close()
            return $true
        }
    } catch {}
    finally {
        $client.Dispose()
    }
    return $false
}

function Get-RouterOverview {
    [CmdletBinding()]
    param(
        [string]$GatewayIp = "192.168.1.2"
    )

    $report = [PSCustomObject]@{
        GatewayIp       = $GatewayIp
        Pingable        = $false
        AvgLatencyMs    = 0
        EstimatedOS     = "Unknown (Embedded Linux / RouterOS)"
        HttpWebAdmin    = $false
        HttpsWebAdmin   = $false
        SshPortOpen     = $false
        TelnetPortOpen  = $false
        WebAdminUrl     = ""
    }

    $ping = New-Object System.Net.NetworkInformation.Ping
    try {
        $reply = $ping.Send($GatewayIp, 1000)
        if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            $report.Pingable     = $true
            $report.AvgLatencyMs = $reply.RoundtripTime
            
            if ($reply.Options.Ttl -le 64) {
                $report.EstimatedOS = "Linux / BusyBox / OpenWrt / Custom Router Firmware (TTL <= 64)"
            } elseif ($reply.Options.Ttl -le 128) {
                $report.EstimatedOS = "Windows / Proprietary Gateway (TTL <= 128)"
            } else {
                $report.EstimatedOS = "Cisco / Network Appliance (TTL 255)"
            }
        }
    } catch {}
    $ping.Dispose()

    $report.HttpWebAdmin   = Test-PortOpen -TargetIp $GatewayIp -Port 80
    $report.HttpsWebAdmin  = Test-PortOpen -TargetIp $GatewayIp -Port 443
    $report.SshPortOpen    = Test-PortOpen -TargetIp $GatewayIp -Port 22
    $report.TelnetPortOpen = Test-PortOpen -TargetIp $GatewayIp -Port 23

    if ($report.HttpsWebAdmin) {
        $report.WebAdminUrl = "https://$GatewayIp"
    } elseif ($report.HttpWebAdmin) {
        $report.WebAdminUrl = "http://$GatewayIp"
    }

    return $report
}

function Invoke-RouterTraceroute {
    [CmdletBinding()]
    param(
        [string]$Destination = "1.1.1.1",
        [int]$MaxHops = 10
    )

    $hops = [System.Collections.Generic.List[PSCustomObject]]::new()
    $ping = New-Object System.Net.NetworkInformation.Ping
    $buffer = [byte[]]::new(32)
    (New-Object System.Random).NextBytes($buffer)

    Write-Host "   ${global:C_BLUE}Tracing route to $Destination (Max $MaxHops hops)...${global:C_RESET}"

    for ($ttl = 1; $ttl -le $MaxHops; $ttl++) {
        $options = New-Object System.Net.NetworkInformation.PingOptions($ttl, $true)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        
        try {
            $reply = $ping.Send($Destination, 1500, $buffer, $options)
            $sw.Stop()
            $ms = [Math]::Round($sw.Elapsed.TotalMilliseconds, 1)

            $hopIp = "*"
            $hopName = "Request timed out"
            $status = "Negative"

            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::TtlExpired -or $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $hopIp = $reply.Address.ToString()
                $status = if ($ms -le 40) { "Positive" } else { "Neutral" }
                
                if ($ttl -eq 1) {
                    $hopName = "$hopIp (Local Router Gateway)"
                } else {
                    $hopName = $hopIp
                }
            }

            $hops.Add([PSCustomObject]@{
                Hop       = $ttl
                IPAddress = $hopIp
                Latency   = if ($hopIp -ne "*") { "$ms ms" } else { "*" }
                Detail    = $hopName
                Status    = $status
            })

            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                break
            }
        } catch {
            $hops.Add([PSCustomObject]@{
                Hop       = $ttl
                IPAddress = "*"
                Latency   = "*"
                Detail    = "Hop timeout / Protected"
                Status    = "Negative"
            })
        }
    }
    $ping.Dispose()

    return $hops
}

function Connect-DeviceTerminal {
    [CmdletBinding()]
    param(
        [string]$TargetIp,
        [ValidateSet('SSH', 'Telnet')]
        [string]$Protocol = 'SSH',
        [string]$Username = "admin",
        [int]$Port = 0
    )

    if ($Protocol -eq 'SSH') {
        $portNum = if ($Port -gt 0) { $Port } else { 22 }
        Write-Host "  ${global:C_BLUE}[INFO] Launching Windows 11 OpenSSH client for $Username@$TargetIp (Port $portNum)...${global:C_RESET}"
        Start-Process "wt.exe" -ArgumentList "ssh $Username@$TargetIp -p $portNum" -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0) {
            Start-Process "cmd.exe" -ArgumentList "/k ssh $Username@$TargetIp -p $portNum"
        }
    } elseif ($Protocol -eq 'Telnet') {
        $portNum = if ($Port -gt 0) { $Port } else { 23 }
        Write-Host "  ${global:C_BLUE}[INFO] Opening Telnet session to $TargetIp on port $portNum...${global:C_RESET}"
        $telnetPath = Get-Command telnet.exe -ErrorAction SilentlyContinue
        if ($telnetPath) {
            Start-Process "cmd.exe" -ArgumentList "/k telnet $TargetIp $portNum"
        } else {
            Write-Host "  ${global:C_BLUE}[INFO] Windows 11 optional Telnet Client is not enabled. Launching raw TCP console...${global:C_RESET}"
            Start-Process "powershell.exe" -ArgumentList "-NoExit -Command Write-Host 'Connecting to $TargetIp $portNum...'; `$client = New-Object System.Net.Sockets.TcpClient('$TargetIp', $portNum); `$stream = `$client.GetStream(); Write-Host 'Connected!'"
        }
    }
}

Export-ModuleMember -Function Test-PortOpen, Get-RouterOverview, Invoke-RouterTraceroute, Connect-DeviceTerminal
