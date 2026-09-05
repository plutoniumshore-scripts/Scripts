<#
.SYNOPSIS
Copies files from a directory tree into a single flat destination folder.

.DESCRIPTION
Recursively collects files from a source directory and copies them into one destination
folder without preserving the original subdirectory structure. Filename collisions are
resolved by appending _1, _2, and so on instead of overwriting existing files.

This is useful for photographers, media collectors, migration work, archive recovery,
and anyone consolidating files from many nested folders into one location.

.PARAMETER SourcePath
Root directory containing files to copy.

.PARAMETER DestinationPath
Flat destination directory. It is created if necessary.

.EXAMPLE
.\Copy-FilesFlattened.ps1 -SourcePath 'D:\Photos' -DestinationPath 'E:\Combined'

.EXAMPLE
.\Copy-FilesFlattened.ps1 -SourcePath 'D:\Photos' -DestinationPath 'E:\Combined' -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationPath
)

if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
    throw "Source directory not found: $SourcePath"
}

$sourceFull = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path).TrimEnd('\')
$destinationFull = [System.IO.Path]::GetFullPath($DestinationPath).TrimEnd('\')
if ($destinationFull.Equals($sourceFull, [System.StringComparison]::OrdinalIgnoreCase) -or
    $destinationFull.StartsWith($sourceFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'DestinationPath must not be the source directory or a subdirectory of it.'
}

if (-not (Test-Path -LiteralPath $destinationFull)) {
    if ($PSCmdlet.ShouldProcess($destinationFull, 'Create destination directory')) {
        New-Item -ItemType Directory -Path $destinationFull -Force | Out-Null
    }
}

$reservedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if (Test-Path -LiteralPath $destinationFull) {
    Get-ChildItem -LiteralPath $destinationFull -File -Force -ErrorAction SilentlyContinue |
        ForEach-Object { [void]$reservedNames.Add($_.Name) }
}

$files = @(Get-ChildItem -LiteralPath $sourceFull -Recurse -File -Force -ErrorAction Stop)
if ($files.Count -eq 0) {
    Write-Host 'No files found.'
    return
}

$copied = 0
for ($i = 0; $i -lt $files.Count; $i++) {
    $file = $files[$i]
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $extension = [System.IO.Path]::GetExtension($file.Name)
    $candidate = $file.Name
    $index = 1

    while ($reservedNames.Contains($candidate)) {
        $candidate = '{0}_{1}{2}' -f $baseName, $index, $extension
        $index++
    }
    [void]$reservedNames.Add($candidate)

    $destinationFile = Join-Path $destinationFull $candidate
    $percent = [math]::Round((($i + 1) / $files.Count) * 100, 0)
    Write-Progress -Activity 'Copying files into flat destination' -Status "$($i + 1) of $($files.Count)" -PercentComplete $percent -CurrentOperation $file.FullName

    if ($PSCmdlet.ShouldProcess($file.FullName, "Copy to $destinationFile")) {
        Copy-Item -LiteralPath $file.FullName -Destination $destinationFile -ErrorAction Stop
        $copied++
    }
}

Write-Progress -Activity 'Copying files into flat destination' -Completed
Write-Host "Copied $copied of $($files.Count) file(s) to $destinationFull." -ForegroundColor Green
