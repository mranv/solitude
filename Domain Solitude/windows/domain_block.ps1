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

$DOMAIN_BLOCK_RULE = "127.0.0.1"
$DOMAIN_TO_BLOCK = "example.com"

function Block-Domain {
    $entry = "$DOMAIN_BLOCK_RULE $DOMAIN_TO_BLOCK"
    if (-not (Get-Content -Path "$env:SystemRoot\System32\drivers\etc\hosts" | Select-String -Pattern $DOMAIN_TO_BLOCK)) {
        Add-Content -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Value $entry
        Write-Output "Domain $DOMAIN_TO_BLOCK blocked."
        Update-Label -Config $OSSEC_CONF -Label "block"
    } else {
        Write-Output "Domain $DOMAIN_TO_BLOCK is already blocked."
    }
}

function Update-Label {
    param (
        [string]$Config,
        [string]$Label
    )
    # Implementation for updating the label in $OSSEC_CONF
}

# Call the block function
Block-Domain
