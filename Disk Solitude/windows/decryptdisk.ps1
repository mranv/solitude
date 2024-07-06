
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
