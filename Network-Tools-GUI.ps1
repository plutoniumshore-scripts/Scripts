<#
.SYNOPSIS
Provides a small Windows GUI for Ping, NSLookup, and Tracert.

.DESCRIPTION
Displays a simple graphical interface where a hostname or IP address can be entered
and tested with the built in Windows ping.exe, nslookup.exe, or tracert.exe tools.
Commands are launched directly rather than through cmd.exe.

This is useful for help desk staff, junior administrators, field technicians,
and anyone who wants common Windows network diagnostics without using a command prompt.

.EXAMPLE
.\Network-Tools-GUI.ps1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Invoke-NetworkTool {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Ping', 'NSLookup', 'Tracert')]
        [string]$Tool,

        [Parameter(Mandatory)]
        [string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($Target) -or $Target -notmatch '^(?!-)[A-Za-z0-9._:%-]+$') {
        throw 'Enter a valid hostname or IP address.'
    }

    $command = switch ($Tool) {
        'Ping'     { @{ File = 'ping.exe';     Arguments = "-n 4 $Target" } }
        'NSLookup' { @{ File = 'nslookup.exe'; Arguments = $Target } }
        'Tracert'  { @{ File = 'tracert.exe';  Arguments = $Target } }
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $command.File
    $startInfo.Arguments = $command.Arguments
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($stderr) {
        return ($stdout + "`r`n" + $stderr).Trim()
    }
    return $stdout.Trim()
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Network Tools'
$form.Size = New-Object System.Drawing.Size(700, 450)
$form.StartPosition = 'CenterScreen'

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 15)
$label.Size = New-Object System.Drawing.Size(300, 20)
$label.Text = 'Enter IP address or hostname:'
$form.Controls.Add($label)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(10, 38)
$textBox.Size = New-Object System.Drawing.Size(660, 22)
$form.Controls.Add($textBox)

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Location = New-Object System.Drawing.Point(10, 100)
$outputBox.Size = New-Object System.Drawing.Size(660, 300)
$outputBox.Multiline = $true
$outputBox.ScrollBars = 'Both'
$outputBox.ReadOnly = $true
$outputBox.Font = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.Add($outputBox)

function Run-SelectedTool {
    param([string]$Tool)
    $outputBox.Clear()
    try {
        $outputBox.Text = Invoke-NetworkTool -Tool $Tool -Target $textBox.Text.Trim()
    }
    catch {
        $outputBox.Text = $_.Exception.Message
    }
}

$pingButton = New-Object System.Windows.Forms.Button
$pingButton.Location = New-Object System.Drawing.Point(10, 70)
$pingButton.Size = New-Object System.Drawing.Size(80, 25)
$pingButton.Text = 'Ping'
$pingButton.Add_Click({ Run-SelectedTool 'Ping' })
$form.Controls.Add($pingButton)

$nslookupButton = New-Object System.Windows.Forms.Button
$nslookupButton.Location = New-Object System.Drawing.Point(95, 70)
$nslookupButton.Size = New-Object System.Drawing.Size(90, 25)
$nslookupButton.Text = 'NSLookup'
$nslookupButton.Add_Click({ Run-SelectedTool 'NSLookup' })
$form.Controls.Add($nslookupButton)

$tracertButton = New-Object System.Windows.Forms.Button
$tracertButton.Location = New-Object System.Drawing.Point(190, 70)
$tracertButton.Size = New-Object System.Drawing.Size(80, 25)
$tracertButton.Text = 'Tracert'
$tracertButton.Add_Click({ Run-SelectedTool 'Tracert' })
$form.Controls.Add($tracertButton)

[void]$form.ShowDialog()
