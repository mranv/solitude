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

function Decrypt-AllDisks {
    param (
        [string]$Password
    )

    $disks = Get-PhysicalDisk | Where-Object { $_.MediaType -eq 'HDD' -or $_.MediaType -eq 'SSD' }

    foreach ($disk in $disks) {
        $partitions = Get-Partition -DiskNumber $disk.DeviceID
        foreach ($partition in $partitions) {
            if ($partition.Type -eq 'Basic') {
                Write-Host "Decrypting partition $($partition.PartitionNumber) on disk $($disk.DeviceID)"
                Disable-BitLocker -MountPoint $partition.AccessPaths[0] -Password $Password
            }
        }
    }
}

# Replace 'YourPassword' with your desired password
Decrypt-AllDisks -Password 'YourPassword'
