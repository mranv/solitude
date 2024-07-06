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

function Unblock-USB {
    $usbStorKey = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"
    $startValue = (Get-ItemProperty -Path $usbStorKey).Start

    if ($startValue -ne 3) {
        Set-ItemProperty -Path $usbStorKey -Name "Start" -Value 3
        Write-Output "USB ports have been unblocked."
    } else {
        Write-Output "USB ports are already unblocked."
    }
}

Unblock-USB
