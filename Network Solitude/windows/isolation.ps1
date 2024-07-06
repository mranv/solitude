# Define the allowed IP and ports
$allowedIP = "192.168.1.100"  # Replace with the desired IP address
$allowedPort1 = 1515
$allowedPort2 = 8080  # Replace with the desired port

# Function to apply firewall rules
function Apply-FirewallRules {
    param (
        [string]$IP,
        [int]$Port1,
        [int]$Port2
    )

    # Clear existing firewall rules
    Write-Host "Clearing existing firewall rules..."
    netsh advfirewall reset

    # Block all inbound and outbound traffic
    Write-Host "Blocking all inbound and outbound traffic..."
    netsh advfirewall set allprofiles firewallpolicy blockinbound,blockoutbound

    # Allow inbound traffic from the specified IP and ports
    Write-Host "Allowing inbound traffic from IP $IP on ports $Port1 and $Port2..."
    netsh advfirewall firewall add rule name="AllowInboundTCP1515" protocol=TCP dir=in localport=1515 remoteip=$IP action=allow
    netsh advfirewall firewall add rule name="AllowInboundUDP1515" protocol=UDP dir=in localport=1515 remoteip=$IP action=allow
    netsh advfirewall firewall add rule name="AllowInboundTCPPort" protocol=TCP dir=in localport=$Port1 remoteip=$IP action=allow
    netsh advfirewall firewall add rule name="AllowInboundUDPPort" protocol=UDP dir=in localport=$Port1 remoteip=$IP action=allow
    netsh advfirewall firewall add rule name="AllowInboundTCPPort2" protocol=TCP dir=in localport=$Port2 remoteip=$IP action=allow
    netsh advfirewall firewall add rule name="AllowInboundUDPPort2" protocol=UDP dir=in localport=$Port2 remoteip=$IP action=allow

    # Allow outbound traffic to the specified IP and ports
    Write-Host "Allowing outbound traffic to IP $IP on ports $Port1 and $Port2..."
    netsh advfirewall firewall add rule name="AllowOutboundTCP1515" protocol=TCP dir=out remoteport=1515 remoteip=$IP action=allow
    netsh advfirewall firewall add rule name="AllowOutboundUDP1515" protocol=UDP dir=out remoteport=1515 remoteip=$IP action=allow
    netsh advfirewall firewall add rule name="AllowOutboundTCPPort" protocol=TCP dir=out remoteport=$Port1 remoteip=$IP action=allow
    netsh advfirewall firewall add rule name="AllowOutboundUDPPort" protocol=UDP dir=out remoteport=$Port1 remoteip=$IP action=allow
    netsh advfirewall firewall add rule name="AllowOutboundTCPPort2" protocol=TCP dir=out remoteport=$Port2 remoteip=$IP action=allow
    netsh advfirewall firewall add rule name="AllowOutboundUDPPort2" protocol=UDP dir=out remoteport=$Port2 remoteip=$IP action=allow

    # Allow loopback access for local process communication
    Write-Host "Allowing loopback access..."
    netsh advfirewall firewall add rule name="AllowLoopbackTCP" protocol=TCP dir=in localip=127.0.0.1 action=allow
    netsh advfirewall firewall add rule name="AllowLoopbackUDP" protocol=UDP dir=in localip=127.0.0.1 action=allow
    netsh advfirewall firewall add rule name="AllowLoopbackOutTCP" protocol=TCP dir=out remoteip=127.0.0.1 action=allow
    netsh advfirewall firewall add rule name="AllowLoopbackOutUDP" protocol=UDP dir=out remoteip=127.0.0.1 action=allow
}

# Apply the firewall rules with the specified IP and ports
Apply-FirewallRules -IP $allowedIP -Port1 $allowedPort1 -Port2 $allowedPort2

Write-Host "Firewall rules applied successfully."
