# Function to check if the script is run as administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "This script needs to be run as an administrator. Please run PowerShell as an administrator and try again."
    exit
}

# Set the execution policy for the current user
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force

# Function to remove firewall rules
function Remove-FirewallRules {
    Write-Host "Removing custom firewall rules..."

    # Remove specific inbound and outbound rules
    netsh advfirewall firewall delete rule name="AllowInboundTCP1515"
    netsh advfirewall firewall delete rule name="AllowInboundUDP1515"
    netsh advfirewall firewall delete rule name="AllowInboundTCPPort"
    netsh advfirewall firewall delete rule name="AllowInboundUDPPort"
    netsh advfirewall firewall delete rule name="AllowInboundTCPPort2"
    netsh advfirewall firewall delete rule name="AllowInboundUDPPort2"
    netsh advfirewall firewall delete rule name="AllowOutboundTCP1515"
    netsh advfirewall firewall delete rule name="AllowOutboundUDP1515"
    netsh advfirewall firewall delete rule name="AllowOutboundTCPPort"
    netsh advfirewall firewall delete rule name="AllowOutboundUDPPort"
    netsh advfirewall firewall delete rule name="AllowOutboundTCPPort2"
    netsh advfirewall firewall delete rule name="AllowOutboundUDPPort2"
    netsh advfirewall firewall delete rule name="AllowLoopbackTCP"
    netsh advfirewall firewall delete rule name="AllowLoopbackUDP"
    netsh advfirewall firewall delete rule name="AllowLoopbackOutTCP"
    netsh advfirewall firewall delete rule name="AllowLoopbackOutUDP"

    # Reset the firewall policy to allow all traffic
    Write-Host "Setting firewall policy to allow all inbound and outbound traffic..."
    netsh advfirewall set allprofiles firewallpolicy allowinbound,allowoutbound

    Write-Host "Firewall rules removed successfully and policy reset."
}

# Remove the firewall rules
Remove-FirewallRules
