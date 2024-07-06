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
