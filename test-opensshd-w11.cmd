@@echo off
@@findstr /v "^@@.*" "%~f0" > "%~f0.ps1" & powershell -ExecutionPolicy ByPass -File "%~f0.ps1" & del "%~f0.ps1" & exit
# Powershell Here #
  
# ============================================================
#  OpenSSH diagnose - Windows 11
#  Waarom krijg ik "Connection refused" op poort 22?
#  Uitvoeren als Administrator op de Windows-pc zelf
# ============================================================

# --- Stap 0: Controleer of het script als Administrator draait ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "`n[0] Administrator-rechten: $isAdmin" -ForegroundColor Cyan

# --- Stap 1: Is OpenSSH Server geinstalleerd? ---
Write-Host "`n[1] Installatiestatus OpenSSH" -ForegroundColor Cyan
$cap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
$cap | Select-Object Name, State | Format-Table -AutoSize
$serverInstalled = ($cap | Where-Object State -eq 'Installed') -ne $null

# --- Stap 2: Draait de sshd-service? ---
Write-Host "`n[2] Status sshd-service" -ForegroundColor Cyan
$svc = Get-Service sshd -ErrorAction SilentlyContinue
if ($svc) {
    $svc | Format-Table Name, Status, StartType -AutoSize
} else {
    Write-Host "sshd-service bestaat niet (server niet geinstalleerd of naam anders)." -ForegroundColor Red
}
$svcRunning = $svc -and $svc.Status -eq 'Running'

# --- Stap 3: Luistert er iets op poort 22? (kern van 'refused') ---
Write-Host "`n[3] Luisteraars op poort 22" -ForegroundColor Cyan
$listeners = netstat -an | Select-String '\s0\.0\.0\.0:22\s.*LISTENING|\s\[::\]:22\s.*LISTENING|\s0\.0\.0\.0:22\s.*Listening'
$portListening = $listeners -ne $null
if ($portListening) { $listeners } else {
    Write-Host "NIETS luistert op poort 22 -> dit verklaart 'connection refused'." -ForegroundColor Red
}

# --- Stap 4: Op welke poort moet sshd luisteren volgens de config? ---
Write-Host "`n[4] Configured poort in sshd_config" -ForegroundColor Cyan
if (Test-Path C:\ProgramData\ssh\sshd_config) {
    $port = Select-String -Path C:\ProgramData\ssh\sshd_config -Pattern '^\s*#?\s*Port\s+(\d+)' -ErrorAction SilentlyContinue
    if ($port) { $port } else { Write-Host "Geen expliciete Port-regel -> standaard 22." }
} else {
    Write-Host "sshd_config niet gevonden (C:\ProgramData\ssh\sshd_config)." -ForegroundColor Red
}

# --- Stap 5: Lokaal verbindingsverzoek op poort 22 ---
Write-Host "`n[5] Testconnectie naar poort 22 op dit lokale IP" -ForegroundColor Cyan
$myIp = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object -First 1).IPAddress
Write-Host "Lokaal IPv4-adres: $myIp"
$tcp = Test-NetConnection -ComputerName $myIp -Port 22 -WarningAction SilentlyContinue
$localOk = $tcp.TcpTestSucceeded
Write-Host "Lokale connectie op poort 22 naar $myIp : $localOk" $(if ($localOk) {"(OK)"} else {"(GEFAALD)"})

# --- Stap 6: Firewallregel ---
Write-Host "`n[6] Firewallregel OpenSSH" -ForegroundColor Cyan
$fw = Get-NetFirewallRule -Name *OpenSSH-Server* -ErrorAction SilentlyContinue
if ($fw) { $fw | Select-Object Name, Enabled, Direction, Action | Format-Table -AutoSize } else {
    Write-Host "Geen firewallregel genaamd *OpenSSH-Server* gevonden." -ForegroundColor Yellow
}

# ============================================================
#  SAMENVATTING + advies
# ============================================================
Write-Host "`n========== SAMENVATTING ==========" -ForegroundColor Cyan
Write-Host "1. OpenSSH Server geinstalleerd : $serverInstalled"
Write-Host "2. sshd service draait           : $svcRunning"
Write-Host "3. Poort 22 LISTENING            : $portListening"
Write-Host "5. Lokale connectie poort 22     : $localOk"

Write-Host "`nAdvies:" -ForegroundColor Yellow
if (-not $serverInstalled) { Write-Host " -> Installeer: Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0" }
elseif (-not $svcRunning)  { Write-Host " -> Start service: Start-Service sshd ; Set-Service sshd -StartupType Automatic" }
elseif (-not $portListening) { Write-Host " -> Service draait maar luistert niet op 22; controleer sshd_config en Restart-Service sshd" }
elseif (-not $localOk)     { Write-Host " -> Lokale connectie faalt; mogelijk firewall- of bindprobleem" }
else                       { Write-Host " -> Alles lokaal OK: 'refused' komt dan niet van deze pc. Controleer dan VPN, router/firewall, VLAN of of je het juiste IP gebruikt." }
