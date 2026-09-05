<#
.SYNOPSIS
Provides a small Windows GUI for Ping, NSLookup, and Tracert.

.DESCRIPTION
Displays a graphical interface for running common Windows network diagnostics
against a hostname or IP address.

The diagnostic utilities are launched as separate processes so the Windows
Forms interface remains responsive while a test is running. Output is displayed
while the command runs and the active diagnostic can be cancelled.

The script launches ping.exe, nslookup.exe, and tracert.exe directly and does
not pass user input through cmd.exe.

This can be useful for help desk staff, administrators, field technicians,
home lab users, and anyone who wants basic Windows network diagnostics without
working directly from a command prompt.

.EXAMPLE
.\Network-Tools-GUI.ps1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

$script:CurrentProcess = $null
$script:CurrentTool = $null
$script:StdoutPath = $null
$script:StderrPath = $null
$script:LastOutput = ''
$script:WasCancelled = $false

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

function Test-NetworkTarget {
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($Target)) {
        return $false
    }

    $Target = $Target.Trim()

    # Allows normal hostnames, IPv4, IPv6, and IPv6 scope identifiers.
    # Characters that could be useful to a command shell are intentionally
    # excluded even though this script does not invoke a command shell.
    if ($Target -notmatch '^[A-Za-z0-9._:%-]+$') {
        return $false
    }

    if ($Target.Length -gt 253) {
        return $false
    }

    return $true
}

function Get-NetworkToolDefinition {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Ping', 'NSLookup', 'Tracert')]
        [string]$Tool,

        [Parameter(Mandatory)]
        [string]$Target
    )

    switch ($Tool) {
        'Ping' {
            return @{
                FilePath  = (Join-Path $env:SystemRoot 'System32\ping.exe')
                Arguments = @('-n', '4', $Target)
            }
        }

        'NSLookup' {
            return @{
                FilePath  = (Join-Path $env:SystemRoot 'System32\nslookup.exe')
                Arguments = @($Target)
            }
        }

        'Tracert' {
            return @{
                FilePath  = (Join-Path $env:SystemRoot 'System32\tracert.exe')
                Arguments = @($Target)
            }
        }
    }
}

function Set-DiagnosticButtonsEnabled {
    param(
        [bool]$Enabled
    )

    $pingButton.Enabled = $Enabled
    $nslookupButton.Enabled = $Enabled
    $tracertButton.Enabled = $Enabled

    $cancelButton.Enabled = -not $Enabled
}

function Remove-DiagnosticTempFiles {
    foreach ($path in @($script:StdoutPath, $script:StderrPath)) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }

    $script:StdoutPath = $null
    $script:StderrPath = $null
}

function Get-RedirectedText {
    param(
        [string]$Path
    )

    if (-not $Path) {
        return ''
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        return ''
    }

    try {
        return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop)
    }
    catch {
        # The process may briefly have the file locked.
        return ''
    }
}

function Update-DiagnosticOutput {

    $stdout = Get-RedirectedText -Path $script:StdoutPath
    $stderr = Get-RedirectedText -Path $script:StderrPath

    $combined = $stdout

    if (-not [string]::IsNullOrWhiteSpace($stderr)) {

        if (-not [string]::IsNullOrWhiteSpace($combined)) {
            $combined += "`r`n"
        }

        $combined += $stderr
    }

    if ($combined -ne $script:LastOutput) {
        $script:LastOutput = $combined

        $outputBox.Text = $combined
        $outputBox.SelectionStart = $outputBox.TextLength
        $outputBox.ScrollToCaret()
    }
}

function Complete-Diagnostic {

    if (-not $script:CurrentProcess) {
        return
    }

    Update-DiagnosticOutput

    $exitCode = $null

    try {
        $exitCode = $script:CurrentProcess.ExitCode
    }
    catch {
        # Exit code may not be available during forced termination.
    }

    if ($script:WasCancelled) {
        $statusLabel.Text = "$($script:CurrentTool) cancelled."
        $statusLabel.ForeColor = [System.Drawing.Color]::DarkOrange
    }
    elseif ($exitCode -eq 0) {
        $statusLabel.Text = "$($script:CurrentTool) completed."
        $statusLabel.ForeColor = [System.Drawing.Color]::DarkGreen
    }
    else {
        $statusLabel.Text = "$($script:CurrentTool) completed with exit code $exitCode."
        $statusLabel.ForeColor = [System.Drawing.Color]::DarkRed
    }

    $diagnosticTimer.Stop()

    try {
        $script:CurrentProcess.Dispose()
    }
    catch {
    }

    $script:CurrentProcess = $null
    $script:CurrentTool = $null

    Set-DiagnosticButtonsEnabled -Enabled $true

    Remove-DiagnosticTempFiles
}

function Start-Diagnostic {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Ping', 'NSLookup', 'Tracert')]
        [string]$Tool
    )

    if ($script:CurrentProcess) {
        [System.Windows.Forms.MessageBox]::Show(
            'A diagnostic is already running.',
            'Network Tools',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null

        return
    }

    $target = $targetTextBox.Text.Trim()

    if (-not (Test-NetworkTarget -Target $target)) {
        [System.Windows.Forms.MessageBox]::Show(
            'Enter a valid hostname or IP address.',
            'Invalid Target',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null

        $targetTextBox.Focus()
        return
    }

    $definition = Get-NetworkToolDefinition -Tool $Tool -Target $target

    if (-not (Test-Path -LiteralPath $definition.FilePath -PathType Leaf)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Required Windows utility not found:`r`n$($definition.FilePath)",
            'Network Tools',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null

        return
    }

    Remove-DiagnosticTempFiles

    $tempDirectory = [System.IO.Path]::GetTempPath()
    $runId = [Guid]::NewGuid().ToString('N')

    $script:StdoutPath = Join-Path $tempDirectory "NetworkTools-$runId-out.txt"
    $script:StderrPath = Join-Path $tempDirectory "NetworkTools-$runId-error.txt"

    $script:CurrentTool = $Tool
    $script:WasCancelled = $false
    $script:LastOutput = ''

    $outputBox.Clear()

    $statusLabel.Text = "Running $Tool against $target..."
    $statusLabel.ForeColor = [System.Drawing.Color]::DarkBlue

    Set-DiagnosticButtonsEnabled -Enabled $false

    try {
        $script:CurrentProcess = Start-Process `
            -FilePath $definition.FilePath `
            -ArgumentList $definition.Arguments `
            -RedirectStandardOutput $script:StdoutPath `
            -RedirectStandardError $script:StderrPath `
            -NoNewWindow `
            -PassThru `
            -ErrorAction Stop

        $diagnosticTimer.Start()
    }
    catch {
        $statusLabel.Text = "$Tool failed to start."
        $statusLabel.ForeColor = [System.Drawing.Color]::DarkRed

        $outputBox.Text = $_.Exception.Message

        $script:CurrentProcess = $null
        $script:CurrentTool = $null

        Set-DiagnosticButtonsEnabled -Enabled $true

        Remove-DiagnosticTempFiles
    }
}

function Stop-Diagnostic {

    if (-not $script:CurrentProcess) {
        return
    }

    $script:WasCancelled = $true

    $statusLabel.Text = "Cancelling $($script:CurrentTool)..."
    $statusLabel.ForeColor = [System.Drawing.Color]::DarkOrange

    try {
        if (-not $script:CurrentProcess.HasExited) {
            Stop-Process -Id $script:CurrentProcess.Id -Force -ErrorAction Stop
        }
    }
    catch {
        $outputBox.AppendText(
            "`r`nUnable to terminate process: $($_.Exception.Message)"
        )
    }
}

# ---------------------------------------------------------------------------
# Form
# ---------------------------------------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Network Tools'
$form.Size = New-Object System.Drawing.Size(800, 560)
$form.MinimumSize = New-Object System.Drawing.Size(650, 450)
$form.StartPosition = 'CenterScreen'

# ---------------------------------------------------------------------------
# Target
# ---------------------------------------------------------------------------

$targetLabel = New-Object System.Windows.Forms.Label
$targetLabel.Location = New-Object System.Drawing.Point(12, 15)
$targetLabel.Size = New-Object System.Drawing.Size(250, 20)
$targetLabel.Text = 'Hostname or IP address:'
$form.Controls.Add($targetLabel)

$targetTextBox = New-Object System.Windows.Forms.TextBox
$targetTextBox.Location = New-Object System.Drawing.Point(12, 38)
$targetTextBox.Size = New-Object System.Drawing.Size(758, 23)
$targetTextBox.Anchor = 'Top,Left,Right'
$form.Controls.Add($targetTextBox)

# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

$pingButton = New-Object System.Windows.Forms.Button
$pingButton.Location = New-Object System.Drawing.Point(12, 72)
$pingButton.Size = New-Object System.Drawing.Size(85, 30)
$pingButton.Text = 'Ping'
$pingButton.Add_Click({
    Start-Diagnostic -Tool 'Ping'
})
$form.Controls.Add($pingButton)

$nslookupButton = New-Object System.Windows.Forms.Button
$nslookupButton.Location = New-Object System.Drawing.Point(103, 72)
$nslookupButton.Size = New-Object System.Drawing.Size(90, 30)
$nslookupButton.Text = 'NSLookup'
$nslookupButton.Add_Click({
    Start-Diagnostic -Tool 'NSLookup'
})
$form.Controls.Add($nslookupButton)

$tracertButton = New-Object System.Windows.Forms.Button
$tracertButton.Location = New-Object System.Drawing.Point(199, 72)
$tracertButton.Size = New-Object System.Drawing.Size(85, 30)
$tracertButton.Text = 'Tracert'
$tracertButton.Add_Click({
    Start-Diagnostic -Tool 'Tracert'
})
$form.Controls.Add($tracertButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(300, 72)
$cancelButton.Size = New-Object System.Drawing.Size(85, 30)
$cancelButton.Text = 'Cancel'
$cancelButton.Enabled = $false
$cancelButton.Add_Click({
    Stop-Diagnostic
})
$form.Controls.Add($cancelButton)

$clearButton = New-Object System.Windows.Forms.Button
$clearButton.Location = New-Object System.Drawing.Point(391, 72)
$clearButton.Size = New-Object System.Drawing.Size(100, 30)
$clearButton.Text = 'Clear Output'
$clearButton.Add_Click({
    $outputBox.Clear()
    $script:LastOutput = ''

    if (-not $script:CurrentProcess) {
        $statusLabel.Text = 'Ready.'
        $statusLabel.ForeColor = [System.Drawing.Color]::Black
    }
})
$form.Controls.Add($clearButton)

# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(12, 112)
$statusLabel.Size = New-Object System.Drawing.Size(758, 22)
$statusLabel.Anchor = 'Top,Left,Right'
$statusLabel.Text = 'Ready.'
$form.Controls.Add($statusLabel)

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Location = New-Object System.Drawing.Point(12, 140)
$outputBox.Size = New-Object System.Drawing.Size(758, 365)
$outputBox.Anchor = 'Top,Bottom,Left,Right'
$outputBox.Multiline = $true
$outputBox.ScrollBars = 'Both'
$outputBox.ReadOnly = $true
$outputBox.WordWrap = $false
$outputBox.Font = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.Add($outputBox)

# ---------------------------------------------------------------------------
# Timer
# ---------------------------------------------------------------------------

$diagnosticTimer = New-Object System.Windows.Forms.Timer
$diagnosticTimer.Interval = 250

$diagnosticTimer.Add_Tick({

    if (-not $script:CurrentProcess) {
        $diagnosticTimer.Stop()
        return
    }

    Update-DiagnosticOutput

    try {
        if ($script:CurrentProcess.HasExited) {
            Complete-Diagnostic
        }
    }
    catch {
        Complete-Diagnostic
    }
})

# ---------------------------------------------------------------------------
# Keyboard behavior
# ---------------------------------------------------------------------------

$form.AcceptButton = $pingButton

# ---------------------------------------------------------------------------
# Cleanup when window closes
# ---------------------------------------------------------------------------

$form.Add_FormClosing({

    $diagnosticTimer.Stop()

    if ($script:CurrentProcess) {
        try {
            if (-not $script:CurrentProcess.HasExited) {
                Stop-Process -Id $script:CurrentProcess.Id -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
        }

        try {
            $script:CurrentProcess.Dispose()
        }
        catch {
        }

        $script:CurrentProcess = $null
    }

    Remove-DiagnosticTempFiles
})

# ---------------------------------------------------------------------------
# Start GUI
# ---------------------------------------------------------------------------

$targetTextBox.Focus()

[void]$form.ShowDialog()
