<#
================================================================================
 ProNetwork11 - Router API & Hostname Resolution Diagnostics
 Author: diogeneslite (https://github.com/diogeneslite)
 Description: Diagnostic script to test router APIs, UPnP discovery and hostname resolution
================================================================================
#>
[CmdletBinding()]
param(
    [string]$GatewayIp,
    [string]$TargetIp
)

# Auto-detect default gateway if not specified
if (-not $GatewayIp) {
    try {
        $GatewayIp = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
    } catch {}
    if (-not $GatewayIp) { $GatewayIp = "192.168.1.1" }
}

if (-not $TargetIp) {
    $TargetIp = $GatewayIp
}

Write-Host "=== 1. Testing Router Gateway ($GatewayIp) ===" -ForegroundColor Cyan

# Test HiLink / Router REST API endpoint
try {
    $wc = New-Object System.Net.WebClient
    $wc.Timeout = 1500
    $res = $wc.DownloadString("http://$GatewayIp/api/monitoring/traffic-statistics")
    Write-Host "Router Traffic Stats API: $res" -ForegroundColor Green
} catch {
    Write-Host "Router API Note: $($_.Exception.Message)" -ForegroundColor DarkGray
}

# Test SSDP / UPnP Discovery
try {
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.Client.ReceiveTimeout = 1500
    $ssdpMsg = "M-SEARCH * HTTP/1.1`r`nHOST: 239.255.255.250:1900`r`nMAN: `"ssdp:discover`"`r`nMX: 1`r`nST: urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1`r`n`r`n"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($ssdpMsg)
    $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse("239.255.255.250"), 1900)
    $udp.Send($bytes, $bytes.Length, $ep)
    $remoteEp = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
    $recv = $udp.Receive([ref]$remoteEp)
    $respStr = [System.Text.Encoding]::ASCII.GetString($recv)
    Write-Host "UPnP Response from $($remoteEp.Address):`n$respStr" -ForegroundColor Green
    $udp.Close()
} catch {
    Write-Host "UPnP SSDP: $($_.Exception.Message)" -ForegroundColor DarkGray
}

Write-Host "`n=== 2. Testing Device Hostname Resolution for Target ($TargetIp) ===" -ForegroundColor Cyan

# Test NetBIOS status
Write-Host "nbtstat -A $TargetIp :"
$nbt = nbtstat -A $TargetIp 2>&1
Write-Host ($nbt -join "`n")

# Test Reverse DNS via Ping
Write-Host "`nping -a $TargetIp :"
$p = ping -a -n 1 -w 500 $TargetIp 2>&1
Write-Host ($p -join "`n")
