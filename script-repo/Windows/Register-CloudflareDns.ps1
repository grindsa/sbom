Start-Transcript -Path "C:\MyStuff\dns_log.txt" -Append

# Proxy - uncomment and provide details if using a proxy
# $env:https_proxy = "http://<proxyuser>:<proxypassword>@<proxyip>:<proxyport>"

# Cloudflare zone is the zone which holds the record
$zone = "domain.com"

# DNS records (A) which will be updated
$dnsrecord1 = "fqdn.$zone"


# Cloudflare authentication details
$cloudflare_token = "<token>" # API token with permissions to edit DNS records for the zone

# Common headers for Cloudflare API
$headers = @{
    Authorization = "Bearer $cloudflare_token"
    "Content-Type" = "application/json"
}

# Get the current external IP address
$ip = (Invoke-RestMethod -Method Get -Uri "https://checkip.amazonaws.com").Trim()
Write-Host "Current IP is $ip"

function Update-CloudflareARecordIfNeeded {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Zone,

        [Parameter(Mandatory = $true)]
        [string]$RecordName,

        [Parameter(Mandatory = $true)]
        [string]$CurrentIp,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    # Resolve current DNS A record value via Cloudflare DNS (1.1.1.1)
    $resolvedIp = $null
    try {
        $dnsResult = Resolve-DnsName -Name $RecordName -Type A -Server "1.1.1.1" -ErrorAction Stop
        $resolvedIp = ($dnsResult | Where-Object { $_.Type -eq "A" } | Select-Object -First 1 -ExpandProperty IPAddress)
    } catch {
        Write-Host "Could not resolve $RecordName via 1.1.1.1 (will attempt update)."
    }

    if ($resolvedIp -eq $CurrentIp) {
        Write-Host "$RecordName is currently set to $CurrentIp; no changes needed"
        return
    }

    # Get zone ID
    $zoneResp = Invoke-RestMethod -Method Get -Uri "https://api.cloudflare.com/client/v4/zones?name=$Zone&status=active" -Headers $Headers
    $zoneId = $zoneResp.result[0].id

    if (-not $zoneId) {
        throw "Could not find active zone ID for '$Zone'."
    }

    Write-Host "Zoneid for $Zone is $zoneId"

    # Get DNS record ID
    $recordResp = Invoke-RestMethod -Method Get -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?type=A&name=$RecordName" -Headers $Headers
    $dnsRecordId = $recordResp.result[0].id

    if (-not $dnsRecordId) {
        throw "Could not find A record ID for '$RecordName'."
    }

    Write-Host "DNSrecordid for $RecordName is $dnsRecordId"

    # Update the A record
    $body = @{
        type    = "A"
        name    = $RecordName
        content = $CurrentIp
        ttl     = 1
        proxied = $false
    } | ConvertTo-Json -Depth 3

    $updateResp = Invoke-RestMethod -Method Put -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$dnsRecordId" -Headers $Headers -Body $body

    # Pretty-print response (similar to piping to jq)
    $updateResp | ConvertTo-Json -Depth 10
}

Update-CloudflareARecordIfNeeded -Zone $zone -RecordName $dnsrecord1 -CurrentIp $ip -Headers $headers
Stop-Transcript
