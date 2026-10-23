<#
================================================================================
 ProNetwork11 - Router API & Hostname Resolution Diagnostics
 Author: diogeneslite (https://github.com/diogeneslite)
================================================================================
#>
# Diagnostic script to test router APIs and Device Hostname resolution
$gatewayIp = "192.168.1.2"
$sampleDeviceIp = "192.168.1.3"
$device7Ip = "192.168.1.7"

Write-Host "=== 1. Testing Router ($gatewayIp) ==="
# Test Huawei HiLink API
try {
    $wc = New-Object System.Net.WebClient
    $wc.Timeout = 1500
    $res = $wc.DownloadString("http://$gatewayIp/api/monitoring/traffic-statistics")
    Write-Host "Huawei Traffic Stats: $res"
} catch {
    Write-Host "Huawei API Error: $($_.Exception.Message)"
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
    Write-Host "UPnP Response from $($remoteEp.Address):`n$respStr"
    $udp.Close()
} catch {
    Write-Host "UPnP SSDP Error: $($_.Exception.Message)"
}

Write-Host "`n=== 2. Testing Device Hostname Resolution for $sampleDeviceIp and $device7Ip ==="
# Test nbtstat
Write-Host "nbtstat -A $sampleDeviceIp :"
$nbt1 = nbtstat -A $sampleDeviceIp
Write-Host ($nbt1 -join "`n")

Write-Host "`nnbtstat -A $device7Ip :"
$nbt2 = nbtstat -A $device7Ip
Write-Host ($nbt2 -join "`n")

# Test ping -a
Write-Host "`nping -a $sampleDeviceIp :"
$p1 = ping -a -n 1 -w 500 $sampleDeviceIp
Write-Host ($p1 -join "`n")

Write-Host "`nping -a $device7Ip :"
$p2 = ping -a -n 1 -w 500 $device7Ip
Write-Host ($p2 -join "`n")
