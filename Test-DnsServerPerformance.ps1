<#
.SYNOPSIS
Compares DNS query performance across one or more DNS servers.

.DESCRIPTION
Queries the same DNS name against each supplied resolver several times and reports
successful query count, average response time, fastest response, slowest response,
and returned IP addresses. The fastest successful resolver is highlighted at the end.

This is useful for network administrators, home lab users, help desk technicians,
and anyone comparing local, ISP, or public DNS performance.

.PARAMETER DnsServer
One or more DNS server IP addresses. Defaults to Cloudflare and Google public DNS.

.PARAMETER QueryName
DNS name used for testing. Defaults to example.com.

.PARAMETER RepeatCount
Number of queries sent to each resolver. Defaults to 3.

.EXAMPLE
.\Test-DnsServerPerformance.ps1

.EXAMPLE
.\Test-DnsServerPerformance.ps1 -DnsServer '192.0.2.53','1.1.1.1' -QueryName 'example.com' -RepeatCount 5
#>

[CmdletBinding()]
param(
    [string[]]$DnsServer = @('1.1.1.1', '8.8.8.8'),

    [ValidateNotNullOrEmpty()]
    [string]$QueryName = 'example.com',

    [ValidateRange(1, 20)]
    [int]$RepeatCount = 3
)

$results = foreach ($server in $DnsServer) {
    $samples = @()
    $addresses = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $lastError = $null

    for ($i = 1; $i -le $RepeatCount; $i++) {
        try {
            $lookup = $null
            $elapsed = Measure-Command {
                $lookup = Resolve-DnsName -Name $QueryName -Server $server -DnsOnly -ErrorAction Stop
            }

            $samples += $elapsed.TotalMilliseconds
            foreach ($address in ($lookup | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique)) {
                [void]$addresses.Add([string]$address)
            }
        }
        catch {
            $lastError = $_.Exception.Message
        }
    }

    if ($samples.Count -gt 0) {
        [pscustomobject]@{
            DNSServer       = $server
            SuccessfulTests = $samples.Count
            AverageMs       = [math]::Round(($samples | Measure-Object -Average).Average, 2)
            FastestMs       = [math]::Round(($samples | Measure-Object -Minimum).Minimum, 2)
            SlowestMs       = [math]::Round(($samples | Measure-Object -Maximum).Maximum, 2)
            IPAddress       = ($addresses | Sort-Object) -join ', '
            Status          = if ($samples.Count -eq $RepeatCount) { 'Success' } else { 'Partial' }
            Error           = $lastError
        }
    }
    else {
        [pscustomobject]@{
            DNSServer       = $server
            SuccessfulTests = 0
            AverageMs       = $null
            FastestMs       = $null
            SlowestMs       = $null
            IPAddress       = $null
            Status          = 'Failed'
            Error           = $lastError
        }
    }
}

$results | Sort-Object @{ Expression = { if ($null -eq $_.AverageMs) { [double]::PositiveInfinity } else { $_.AverageMs } } } |
    Format-Table DNSServer, SuccessfulTests, AverageMs, FastestMs, SlowestMs, Status, IPAddress -AutoSize

$fastest = $results | Where-Object { $null -ne $_.AverageMs } | Sort-Object AverageMs | Select-Object -First 1
if ($fastest) {
    Write-Host "Fastest average response: $($fastest.DNSServer) at $($fastest.AverageMs) ms" -ForegroundColor Green
}

$failed = $results | Where-Object { $_.Status -ne 'Success' -and $_.Error }
if ($failed) {
    Write-Host "`nErrors:" -ForegroundColor Yellow
    $failed | ForEach-Object { Write-Host "$($_.DNSServer): $($_.Error)" }
}
