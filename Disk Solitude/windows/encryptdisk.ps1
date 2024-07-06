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

function ConvertTo-SecureStringFromPlainText {
    param (
        [string]$PlainText
    )
    $secureString = New-Object System.Security.SecureString
    $PlainText.ToCharArray() | ForEach-Object { $secureString.AppendChar($_) }
    return $secureString
}

function Encrypt-AllDisks {
    param (
        [string]$Password
    )

    $securePassword = ConvertTo-SecureStringFromPlainText -PlainText $Password
    $disks = Get-PhysicalDisk | Where-Object { $_.MediaType -eq 'HDD' -or $_.MediaType -eq 'SSD' }
    
    foreach ($disk in $disks) {
        $partitions = Get-Partition -DiskNumber $disk.DeviceID
        foreach ($partition in $partitions) {
            if ($partition.Type -eq 'Basic') {
                Write-Host "Encrypting partition $($partition.PartitionNumber) on disk $($disk.DeviceID)"
                Enable-BitLocker -MountPoint $partition.AccessPaths[0] -Password $securePassword -PasswordProtector
            }
        }
    }
}

# Replace 'YourPassword' with your desired password
Encrypt-AllDisks -Password 'YourPassword'
