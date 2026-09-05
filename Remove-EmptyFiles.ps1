<#
.SYNOPSIS
Finds zero byte files and optionally removes them.

.DESCRIPTION
Recursively scans a local path, mapped drive, or UNC path for files whose size is
exactly zero bytes. By default the script only reports what it finds. Use -Delete
to remove the files. -WhatIf and -Confirm are supported for safer review.

This is useful for administrators, home lab users, photographers, media managers,
and anyone cleaning up failed downloads, interrupted copies, or empty export files.

.PARAMETER Path
Root directory to scan.

.PARAMETER Delete
Removes zero byte files after they are found. Without this switch, no files are changed.

.EXAMPLE
.\Remove-EmptyFiles.ps1 -Path 'D:\Data'

.EXAMPLE
.\Remove-EmptyFiles.ps1 -Path '\\server\share' -Delete -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [switch]$Delete
)

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Directory not found: $Path"
}

Write-Host "Searching for zero byte files under: $Path" -ForegroundColor Cyan
$emptyFiles = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -eq 0 })

if ($emptyFiles.Count -eq 0) {
    Write-Host 'No zero byte files found.' -ForegroundColor Green
    return
}

$emptyFiles | Select-Object FullName, LastWriteTime | Format-Table -AutoSize
Write-Host "Found $($emptyFiles.Count) zero byte file(s)." -ForegroundColor Yellow

if (-not $Delete) {
    Write-Host 'No files were removed. Re-run with -Delete to remove them.' -ForegroundColor Cyan
    return
}

$removed = 0
foreach ($file in $emptyFiles) {
    if ($PSCmdlet.ShouldProcess($file.FullName, 'Remove zero byte file')) {
        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
        $removed++
    }
}

Write-Host "Removed $removed file(s)." -ForegroundColor Green
