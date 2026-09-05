<#
.SYNOPSIS
Measures approximate file read and write throughput to an SMB share.

.DESCRIPTION
Creates a temporary file containing random data, maps the supplied SMB path as a
temporary PowerShell drive, times a copy to the share, then times a copy back to the
local system. Temporary files and the temporary PSDrive are removed in a finally block.

This is useful for Windows administrators, NAS owners, home lab users, and anyone
troubleshooting or comparing practical SMB file transfer performance.

.PARAMETER NetworkPath
UNC path to the SMB share or folder to test.

.PARAMETER FileSizeMB
Size of the generated test file in megabytes. Defaults to 256 MB.

.PARAMETER Credential
Optional credential for the SMB path. If omitted, the current Windows credentials are used.

.EXAMPLE
.\Test-SmbReadWriteSpeed.ps1 -NetworkPath '\\server\share' -FileSizeMB 512

.EXAMPLE
$cred = Get-Credential
.\Test-SmbReadWriteSpeed.ps1 -NetworkPath '\\server\share' -Credential $cred
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\\\\[^\\]+\\[^\\]+')]
    [string]$NetworkPath,

    [ValidateRange(1, 102400)]
    [int]$FileSizeMB = 256,

    [pscredential]$Credential
)

$driveName = 'SMBTest' + ([guid]::NewGuid().ToString('N').Substring(0, 6))
$localSource = Join-Path ([System.IO.Path]::GetTempPath()) ("smb-write-test-{0}.bin" -f [guid]::NewGuid().ToString('N'))
$localReadback = Join-Path ([System.IO.Path]::GetTempPath()) ("smb-read-test-{0}.bin" -f [guid]::NewGuid().ToString('N'))
$remoteFile = $null

try {
    $driveParams = @{
        Name       = $driveName
        PSProvider = 'FileSystem'
        Root       = $NetworkPath
        ErrorAction = 'Stop'
    }
    if ($Credential) {
        $driveParams.Credential = $Credential
    }
    New-PSDrive @driveParams | Out-Null

    $remoteFile = Join-Path ("$driveName`:") ("smb-speed-test-{0}.bin" -f [guid]::NewGuid().ToString('N'))

    Write-Host "Creating $FileSizeMB MB local test file..." -ForegroundColor Cyan
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $buffer = New-Object byte[] 1048576
    $remaining = [int64]$FileSizeMB * 1MB
    $stream = [System.IO.File]::Open($localSource, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        while ($remaining -gt 0) {
            $rng.GetBytes($buffer)
            $toWrite = [int][Math]::Min($buffer.Length, $remaining)
            $stream.Write($buffer, 0, $toWrite)
            $remaining -= $toWrite
        }
    }
    finally {
        $stream.Dispose()
        $rng.Dispose()
    }

    Write-Host 'Testing write speed...' -ForegroundColor Cyan
    $write = Measure-Command { Copy-Item -LiteralPath $localSource -Destination $remoteFile -Force -ErrorAction Stop }
    $writeMBps = [math]::Round($FileSizeMB / $write.TotalSeconds, 2)

    Write-Host 'Testing read speed...' -ForegroundColor Cyan
    $read = Measure-Command { Copy-Item -LiteralPath $remoteFile -Destination $localReadback -Force -ErrorAction Stop }
    $readMBps = [math]::Round($FileSizeMB / $read.TotalSeconds, 2)

    [pscustomobject]@{
        NetworkPath    = $NetworkPath
        TestSizeMB     = $FileSizeMB
        WriteSeconds   = [math]::Round($write.TotalSeconds, 2)
        WriteMBps      = $writeMBps
        ReadSeconds    = [math]::Round($read.TotalSeconds, 2)
        ReadMBps       = $readMBps
    } | Format-List
}
finally {
    foreach ($file in @($localSource, $localReadback, $remoteFile)) {
        if ($file -and (Test-Path -LiteralPath $file)) {
            Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
        }
    }
    if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
    }
}
