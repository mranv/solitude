
function Block-USB {
    $usbStorKey = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"
    $startValue = (Get-ItemProperty -Path $usbStorKey).Start

    if ($startValue -ne 4) {
        Set-ItemProperty -Path $usbStorKey -Name "Start" -Value 4
        Write-Output "USB ports have been blocked."
    } else {
        Write-Output "USB ports are already blocked."
    }
}

Block-USB
