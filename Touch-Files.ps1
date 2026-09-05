<#
.SYNOPSIS
Updates file LastWriteTime values without changing file contents.

.DESCRIPTION
Recursively updates the LastWriteTime timestamp for files beneath a specified path.
The timestamp defaults to the current time but can be supplied explicitly. -WhatIf
and -Confirm are supported.

This is useful for backup and synchronization testing, migration validation,
application testing, and workflows that react to file modification timestamps.

.PARAMETER Path
Root directory containing files to update.

.PARAMETER Timestamp
Timestamp to apply. Defaults to the current date and time.

.EXAMPLE
.\Touch-Files.ps1 -Path 'D:\TestData'

.EXAMPLE
.\Touch-Files.ps1 -Path 'D:\TestData' -Timestamp '2026-01-01 12:00:00' -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [datetime]$Timestamp = (Get-Date)
)

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Directory not found: $Path"
}

$files = @(Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction Stop)
if ($files.Count -eq 0) {
    Write-Host 'No files found.'
    return
}

$updated = 0
for ($i = 0; $i -lt $files.Count; $i++) {
    $file = $files[$i]
    $percent = [math]::Round((($i + 1) / $files.Count) * 100, 0)
    Write-Progress -Activity 'Updating file timestamps' -Status "$($i + 1) of $($files.Count)" -PercentComplete $percent -CurrentOperation $file.FullName

    if ($PSCmdlet.ShouldProcess($file.FullName, "Set LastWriteTime to $Timestamp")) {
        $file.LastWriteTime = $Timestamp
        $updated++
    }
}

Write-Progress -Activity 'Updating file timestamps' -Completed
Write-Host "Updated $updated of $($files.Count) file(s)." -ForegroundColor Green
