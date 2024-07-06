
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
