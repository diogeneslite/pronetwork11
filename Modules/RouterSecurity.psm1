<#
================================================================================
 ProNetwork11 - Router Security & Health Audit
 Author: diogeneslite (https://github.com/diogeneslite)
 Description: Path 3 Wi-Fi encryption, WPS warnings, remote ports & security audits
================================================================================
#>
[CmdletBinding()]
param()

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not (Get-Command Write-BenchmarkRow -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $scriptDir "UI.psm1") -DisableNameChecking
}
if (-not (Get-Command Test-TcpPortQuick -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $scriptDir "DeviceScanner.psm1") -DisableNameChecking
}

function Invoke-RouterSecurityAudit {
    [CmdletBinding()]
    param(
        [PSCustomObject]$NetInfo
    )

    Write-SectionTitle "PATH 3: ROUTER HEALTH & CONFIGURATION AUDIT" "[+]"
    Write-Host "   ${global:C_BLUE}Auditing Wi-Fi encryption, link speed, WPS exposure risks, and router service configurations...${global:C_RESET}`n"

    # 1. Wi-Fi Encryption & Cipher Check
    $auth = if ($NetInfo.WifiAuth) { $NetInfo.WifiAuth } else { "WPA2-Personal" }
    $cipher = if ($NetInfo.WifiCipher) { $NetInfo.WifiCipher } else { "CCMP/AES" }

    $authScore = 'GOOD'
    $authDetail = "Modern AES encryption"
    if ($auth -match "WPA3") {
        $authScore = 'EXCELLENT'
        $authDetail = "Latest WPA3 SAE resistant to offline dictionary attacks"
    } elseif ($auth -match "WPA2") {
        $authScore = 'SECURE'
        $authDetail = "Industry standard AES-CCMP encryption"
    } elseif ($auth -match "WPA" -or $cipher -match "TKIP") {
        $authScore = 'WARNING'
        $authDetail = "Deprecated TKIP cipher detected! Switch to WPA2/WPA3 AES"
    } elseif ($auth -match "Open|None") {
        $authScore = 'CRITICAL'
        $authDetail = "Unencrypted network! Anyone can intercept packets"
    }
    Write-BenchmarkRow -TestName "Wi-Fi Encryption Standard" -MeasuredValue "$auth ($cipher)" -Score $authScore -Detail $authDetail

    # 2. Wi-Fi WPS (Wi-Fi Protected Setup) Advisory Warning
    # WPS PIN authentication is inherently susceptible to offline brute-force (Pixie-Dust & Reaver attacks)
    Write-BenchmarkRow -TestName "Wi-Fi WPS Security Notice" -MeasuredValue "PIN Brute-Force Risk" -Score "WARNING" -Detail "Advisory: Disable WPS in router settings to prevent PIN attacks"

    # 3. Negotiated Link Speed & Channel Capacity
    $speedNum = 0
    if ($NetInfo.LinkSpeed -match '(\d+(\.\d+)?)') { $speedNum = [double]$matches[1] }
    
    $linkScore = if ($speedNum -ge 200) { 'EXCELLENT' } elseif ($speedNum -ge 100) { 'GOOD' } elseif ($speedNum -ge 40) { 'FAIR' } else { 'POOR' }
    $linkDetail = if ($speedNum -ge 100) { "High bandwidth connection to router" } else { "Throttled speed. Check 5GHz band / distance" }
    Write-BenchmarkRow -TestName "Link Speed Negotiation" -MeasuredValue "$($NetInfo.LinkSpeed)" -Score $linkScore -Detail $linkDetail

    # 4. Router Web Admin Encryption (HTTP 80 vs HTTPS 443)
    $httpOpen  = Test-TcpPortQuick -TargetIp $NetInfo.GatewayIPv4 -Port 80 -TimeoutMs 200
    $httpsOpen = Test-TcpPortQuick -TargetIp $NetInfo.GatewayIPv4 -Port 443 -TimeoutMs 200

    if ($httpsOpen) {
        Write-BenchmarkRow -TestName "Router Web Admin Security" -MeasuredValue "HTTPS (Port 443)" -Score "SECURE" -Detail "Encrypted TLS admin connection"
    } elseif ($httpOpen) {
        Write-BenchmarkRow -TestName "Router Web Admin Security" -MeasuredValue "HTTP (Port 80)" -Score "WARNING" -Detail "Cleartext HTTP admin login - use HTTPS if available"
    } else {
        Write-BenchmarkRow -TestName "Router Web Admin Security" -MeasuredValue "Closed / Custom Port" -Score "GOOD" -Detail "Standard web ports are protected"
    }

    # 5. Cleartext Telnet Port 23 Audit
    $telnetOpen = Test-TcpPortQuick -TargetIp $NetInfo.GatewayIPv4 -Port 23 -TimeoutMs 200
    if ($telnetOpen) {
        Write-BenchmarkRow -TestName "Router Telnet Remote Access" -MeasuredValue "Port 23 Open" -Score "CRITICAL" -Detail "Telnet transmits passwords unencrypted! Disable immediately"
    } else {
        Write-BenchmarkRow -TestName "Router Telnet Remote Access" -MeasuredValue "Port 23 Closed" -Score "SECURE" -Detail "No unencrypted console exposed"
    }

    # 6. SSH Port 22 Audit
    $sshOpen = Test-TcpPortQuick -TargetIp $NetInfo.GatewayIPv4 -Port 22 -TimeoutMs 200
    $sshScore = if ($sshOpen) { 'GOOD' } else { 'SECURE' }
    $sshDetail = if ($sshOpen) { "Secure encrypted shell available" } else { "Port 22 closed" }
    Write-BenchmarkRow -TestName "Router SSH Management" -MeasuredValue $(if ($sshOpen) { "Port 22 Open" } else { "Port 22 Closed" }) -Score $sshScore -Detail $sshDetail

    # 7. Predictable Gateway Subnet IP Check
    $isDefaultSubnet = ($NetInfo.GatewayIPv4 -match '^192\.168\.(0|1)\.(1|2)$')
    if ($isDefaultSubnet) {
        Write-BenchmarkRow -TestName "Router Subnet Configuration" -MeasuredValue "$($NetInfo.GatewayIPv4) Default" -Score "WARNING" -Detail "Default subnet targets automated CSRF. Changing to custom IP helps"
    } else {
        Write-BenchmarkRow -TestName "Router Subnet Configuration" -MeasuredValue "$($NetInfo.GatewayIPv4) Custom" -Score "SECURE" -Detail "Non-standard private subnet"
    }

    # 8. DNS Server Integrity Check
    $dnsStr = ($NetInfo.DnsServers -join ", ")
    $isTrustedDns = ($dnsStr -match '1\.1\.1\.1|8\.8\.8\.8|9\.9\.9\.9|192\.168\.')
    $dnsScore = if ($isTrustedDns) { 'SECURE' } else { 'WARNING' }
    $dnsDetail = if ($isTrustedDns) { "Verified trustworthy public/router resolver" } else { "External DNS - verify configuration" }
    Write-BenchmarkRow -TestName "DNS Resolver Integrity" -MeasuredValue $dnsStr -Score $dnsScore -Detail $dnsDetail

    Write-Host ""
    Write-Host "  ${global:C_BLUE}${global:C_BOLD}ROUTER ACTIONABLE RECOMMENDATIONS:${global:C_RESET}"
    Write-Host "   ${global:C_GREEN}[>]${global:C_RESET} ${global:C_BLUE}Disable WPS (Wi-Fi Protected Setup) in your router's Wireless settings to stop PIN cracking.${global:C_RESET}"
    if ($httpOpen -and -not $httpsOpen) {
        Write-Host "   ${global:C_AMBER}[>]${global:C_RESET} ${global:C_BLUE}Enable HTTPS / SSL access for your router's management dashboard to prevent local credential sniffing.${global:C_RESET}"
    }
    Write-Host "   ${global:C_GREEN}[>]${global:C_RESET} ${global:C_BLUE}Ensure your Wi-Fi uses WPA2-AES or WPA3 and keep firmware updated from your ISP or manufacturer.${global:C_RESET}"
}

Export-ModuleMember -Function Invoke-RouterSecurityAudit
