@@echo off
@@findstr /v "^@@.*" "%~f0" > "%~f0.ps1" & powershell -ExecutionPolicy ByPass -File "%~f0.ps1" & del "%~f0.ps1" & exit
# Powershell Here #

# ============================================================
#  OpenSSH Server installeren en configureren - Windows 11
#  Uitvoeren als Administrator in PowerShell
# ============================================================

# --- Stap 0: Controleer of het script als Administrator draait ---
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "FOUT: Start dit script als Administrator." -ForegroundColor Red
    exit 1
}
Write-Host "OK: script draait als Administrator." -ForegroundColor Green

# --- Stap 1: Controleer de huidige status van OpenSSH ---
Write-Host "`n[1] Huidige status van OpenSSH:" -ForegroundColor Cyan
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*' |
    Select-Object Name, State | Format-Table -AutoSize

# --- Stap 2: Vraag om installatie ---
$antwoord = Read-Host "OpenSSH Server installeren? (j/n)"
if ($antwoord -eq 'j') {
    Write-Host "Bezig met installeren van OpenSSH.Server..." -ForegroundColor Yellow
    # -ErrorAction SilentlyContinue voorkomt fout als het al geinstalleerd is
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue
    Write-Host "Installatiestap afgerond."
} else {
    Write-Host "Installatie overgeslagen." -ForegroundColor Yellow
}

# --- Stap 3: Start de sshd-service ---
$antwoord = Read-Host "sshd-service starten? (j/n)"
if ($antwoord -eq 'j') {
    Start-Service sshd
    Write-Host "sshd gestart."
} else {
    Write-Host "Service starten overgeslagen." -ForegroundColor Yellow
}

# --- Stap 4: Zet de service op automatisch opstarten ---
$antwoord = Read-Host "sshd automatisch laten opstarten bij boot? (j/n)"
if ($antwoord -eq 'j') {
    Set-Service -Name sshd -StartupType Automatic
    Write-Host "Opstarttype ingesteld op Automatic."
} else {
    Write-Host "Instellen opstarttype overgeslagen." -ForegroundColor Yellow
}

# --- Stap 5: Controleer firewallregel en maak die aan indien nodig ---
$antwoord = Read-Host "Firewallregel voor poort 22 controleren/aanmaken? (j/n)"
if ($antwoord -eq 'j') {
    $regel = Get-NetFirewallRule -Name *OpenSSH-Server* -ErrorAction SilentlyContinue
    if ($regel) {
        Write-Host "Firewallregel bestaat al:" -ForegroundColor Green
        $regel | Select-Object Name, Enabled, Direction, Action | Format-Table -AutoSize
    } else {
        Write-Host "Geen regel gevonden, nieuwe regel aanmaken..." -ForegroundColor Yellow
        New-NetFirewallRule -Name sshd `
            -DisplayName 'OpenSSH Server (sshd)' `
            -Enabled True -Direction Inbound `
            -Protocol TCP -Action Allow -LocalPort 22
        Write-Host "Firewallregel aangemaakt."
    }
} else {
    Write-Host "Firewallstap overgeslagen." -ForegroundColor Yellow
}

# --- Stap 6: Controleer of alles werkt ---
$antwoord = Read-Host "Laatste controle uitvoeren (service + poort 22)? (j/n)"
if ($antwoord -eq 'j') {
    Write-Host "`nStatus van sshd:" -ForegroundColor Cyan
    Get-Service sshd | Format-Table Name, Status, StartType -AutoSize

    Write-Host "Testverbinding naar poort 22 op localhost:" -ForegroundColor Cyan
    $test = Test-NetConnection -ComputerName localhost -Port 22 -WarningAction SilentlyContinue
    if ($test.TcpTestSucceeded) {
        Write-Host "OK: poort 22 is bereikbaar." -ForegroundColor Green
    } else {
        Write-Host "WAARSCHUWING: poort 22 niet bereikbaar. Controleer service en firewall." -ForegroundColor Red
    }
} else {
    Write-Host "Laatste controle overgeslagen." -ForegroundColor Yellow
}

# --- Stap 7: Toon het IP-adres om vanaf een andere pc te verbinden ---
Write-Host "`n[7] Verbinden via:" -ForegroundColor Cyan
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object InterfaceAlias, IPAddress | Format-Table -AutoSize
Write-Host "Vanaf een andere machine: ssh gebruikersnaam@<IP-adres>"

Write-Host "`nKlaar!" -ForegroundColor Green
