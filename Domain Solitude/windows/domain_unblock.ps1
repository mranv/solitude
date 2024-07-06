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

$DOMAIN_TO_UNBLOCK = "example.com"

function Unblock-Domain {
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $hostsContent = Get-Content -Path $hostsPath
    $updatedContent = $hostsContent | Where-Object { $_ -notmatch $DOMAIN_TO_UNBLOCK }

    if ($hostsContent -ne $updatedContent) {
        Set-Content -Path $hostsPath -Value $updatedContent
        Write-Output "Domain $DOMAIN_TO_UNBLOCK unblocked."
        Update-Label -Config $OSSEC_CONF -Label "unblock"
    } else {
        Write-Output "Domain $DOMAIN_TO_UNBLOCK is not blocked."
    }
}

function Update-Label {
    param (
        [string]$Config,
        [string]$Label
    )
    # Implementation for updating the label in $OSSEC_CONF
}

# Call the unblock function
Unblock-Domain
