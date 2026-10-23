<#
================================================================================
 ProNetwork11 - UI & Terminal Styling Module
 Author: diogeneslite (https://github.com/diogeneslite)
 Description: ANSI Tri-Color styling, headers, dividers, and row formatters
================================================================================
#>
# Strict Tri-Color: GREEN (Positive/Healthy), RED (Negative/Warning), BLUE (Neutral/Info)
[CmdletBinding()]
param()

$global:ESC = [char]27
$global:C_RESET   = "$ESC[0m"
$global:C_BOLD    = "$ESC[1m"
$global:C_DIM     = "$ESC[2m"

# Core Tri-Color Palette
$global:C_GREEN   = "$ESC[38;2;46;204;113m"   # Positive / Healthy / Excellent
$global:C_RED     = "$ESC[38;2;231;76;60m"    # Negative / Vulnerable / Poor
$global:C_BLUE    = "$ESC[38;2;52;152;219m"   # Neutral / Labels / Information
$global:C_AMBER   = "$ESC[38;2;241;196;15m"   # Warning / Caution / Fair
$global:C_GRAY    = "$ESC[38;2;120;140;160m"  # Neutral Dividers / Borders

function Write-CompactHeader {
    Write-Host ""
    Write-Host "  ${global:C_BLUE}${global:C_BOLD}========================================================================================${global:C_RESET}"
    Write-Host "  ${global:C_BLUE}${global:C_BOLD}|${global:C_RESET}  ${global:C_GREEN}${global:C_BOLD}* ProNetwork11${global:C_RESET} ${global:C_BLUE}- Windows 11 Network Operations, Benchmarks & Diagnostics Hub${global:C_RESET}       ${global:C_BLUE}${global:C_BOLD}|${global:C_RESET}"
    Write-Host "  ${global:C_BLUE}${global:C_BOLD}========================================================================================${global:C_RESET}"
}

function Write-CompactDivider {
    Write-Host "  ${global:C_GRAY}----------------------------------------------------------------------------------------${global:C_RESET}"
}

function Write-SectionTitle {
    param([string]$Title, [string]$Icon = "*")
    Write-Host ""
    Write-Host "  ${global:C_BLUE}${global:C_BOLD}$Icon $Title${global:C_RESET}"
    Write-CompactDivider
}

# Single-line test metric with a colored score text in front (ranging from bad to excellent)
function Write-BenchmarkRow {
    param(
        [string]$TestName,
        [string]$MeasuredValue,
        [ValidateSet('EXCELLENT', 'GOOD', 'FAIR', 'POOR', 'CRITICAL', 'SECURE', 'WARNING')]
        [string]$Score = 'GOOD',
        [string]$Detail = ""
    )
    $scoreBadge = switch ($Score) {
        'EXCELLENT' { "${global:C_GREEN}[EXCELLENT]${global:C_RESET}" }
        'GOOD'      { "${global:C_GREEN}[GOOD]     ${global:C_RESET}" }
        'SECURE'    { "${global:C_GREEN}[SECURE]   ${global:C_RESET}" }
        'FAIR'      { "${global:C_AMBER}[FAIR]     ${global:C_RESET}" }
        'WARNING'   { "${global:C_AMBER}[WARNING]  ${global:C_RESET}" }
        'POOR'      { "${global:C_RED}[POOR]     ${global:C_RESET}" }
        'CRITICAL'  { "${global:C_RED}[CRITICAL] ${global:C_RESET}" }
        Default     { "${global:C_BLUE}[INFO]     ${global:C_RESET}" }
    }

    $formattedName = $TestName.PadRight(30)
    $formattedVal  = $MeasuredValue.PadRight(18)
    $detailStr = if ($Detail) { " ${global:C_GRAY}($Detail)${global:C_RESET}" } else { "" }
    Write-Host "   ${global:C_BLUE}-${global:C_RESET} $scoreBadge ${global:C_BLUE}$formattedName${global:C_RESET} : ${global:C_BOLD}$formattedVal${global:C_RESET}$detailStr"
}

function Get-FriendlyUserName {
    $rawUser = $env:USERNAME
    $hostname = $env:COMPUTERNAME
    
    # Capitalize username for human-friendly greeting (e.g. moham -> Mohamed)
    $name = if ($rawUser.ToLower() -eq "moham") {
        "Mohamed"
    } else {
        (Get-Culture).TextInfo.ToTitleCase($rawUser.ToLower())
    }
    return "$name ($hostname\$rawUser)"
}

Export-ModuleMember -Function Write-CompactHeader, Write-CompactDivider, Write-SectionTitle, Write-BenchmarkRow, Get-FriendlyUserName
