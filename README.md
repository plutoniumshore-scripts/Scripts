# Scripts

A collection of standalone PowerShell scripts created, adapted, or refined over time and shared because they are useful, interesting, or practical enough to keep around.

The repository focuses on small utilities that are easy to understand and run independently. Current scripts cover Windows maintenance, file management, network troubleshooting, SMB performance testing, and a small amount of intentionally unserious code.

**If you find anything here useful, please consider donating:**

https://paypal.me/plutoniumshore

## Intended Use

These scripts are intended primarily for Windows users, administrators, help desk technicians, home lab users, and technically inclined users who want focused tools without installing a larger management framework.

Most scripts are designed to be run directly from PowerShell and expose parameters rather than requiring source code edits for local paths or environment values. Scripts that modify files support safer review options where practical, such as `-WhatIf`, explicit action switches, or confirmation prompts.

## Who This Is For

The collection may be useful to:

* Windows and infrastructure administrators performing routine troubleshooting or cleanup.
* Help desk and field support staff who need lightweight diagnostic tools.
* Home lab and NAS users testing DNS, network shares, or file transfer performance.
* Photographers and media users consolidating or cleaning large file collections.
* Anyone learning PowerShell from short scripts with a narrow, visible purpose.

## Script Catalog

| Script | Purpose | Who may find it useful |
| --- | --- | --- |
| [`Test-DnsServerPerformance.ps1`](./Test-DnsServerPerformance.ps1) | Queries multiple DNS resolvers repeatedly and compares average, fastest, and slowest response times. | Network administrators, home lab users, help desk technicians, and anyone comparing local, ISP, or public DNS performance. |
| [`Remove-EmptyFiles.ps1`](./Remove-EmptyFiles.ps1) | Recursively finds zero byte files and optionally removes them. Reporting is the default; deletion must be explicitly requested. | Administrators, media managers, backup operators, and users cleaning failed downloads, interrupted copies, or empty export files. |
| [`Touch-Files.ps1`](./Touch-Files.ps1) | Recursively updates file `LastWriteTime` values without changing file contents. | Backup and synchronization testers, migration administrators, developers, and users working with timestamp driven workflows. |
| [`Network-Tools-GUI.ps1`](./Network-Tools-GUI.ps1) | Provides a small Windows GUI for Ping, NSLookup, and Tracert. | Help desk staff, junior administrators, field technicians, and users who prefer a graphical interface for basic network diagnostics. |
| [`Test-SmbReadWriteSpeed.ps1`](./Test-SmbReadWriteSpeed.ps1) | Creates temporary test data and measures approximate write/read throughput to an SMB share. | Windows administrators, NAS owners, home lab users, and anyone troubleshooting practical SMB transfer performance. |
| [`Copy-FilesFlattened.ps1`](./Copy-FilesFlattened.ps1) | Copies files from nested directories into one flat destination while automatically resolving duplicate filenames. | Photographers, media collectors, migration users, and anyone consolidating files from complex folder trees. |
| [`Dont-Hit-Stuff.ps1`](./Dont-Hit-Stuff.ps1) | A tiny humorous PowerShell adaptation of the `if (goingToHitStuff) { dont(); }` programming meme. | Anyone who appreciates extremely small and intentionally impractical code. |

## Requirements

* Windows PowerShell 5.1 or later is appropriate for the current scripts.
* `Network-Tools-GUI.ps1` requires Windows Forms and is intended for an interactive Windows desktop session.
* `Test-DnsServerPerformance.ps1` requires the Windows `Resolve-DnsName` cmdlet.
* `Network-Tools-GUI.ps1` uses the standard Windows `ping.exe`, `nslookup.exe`, and `tracert.exe` utilities.
* `Test-SmbReadWriteSpeed.ps1` requires access to an SMB share and enough free space for the requested test file on both the local system and remote share.

No script in this repository requires a hardcoded username, password, private server name, API key, or local filesystem path. Environment specific values are supplied as parameters when needed.

## Script Details

### Test-DnsServerPerformance.ps1

**Purpose**

Compares DNS resolver performance by sending the same query to each supplied DNS server multiple times. It reports successful tests, average response time, fastest and slowest responses, returned addresses, and failures. The fastest successful resolver is highlighted at the end.

The default DNS servers are Cloudflare (`1.1.1.1`) and Google (`8.8.8.8`), and the default query is `example.com`. These are examples, not required values. Supply your own resolver addresses and query name with parameters.

**Who might benefit**

Network administrators comparing internal and external resolvers, home lab users evaluating DNS choices, and support staff investigating slow name resolution.

**Run**

```powershell
.\Test-DnsServerPerformance.ps1
```

```powershell
.\Test-DnsServerPerformance.ps1 -DnsServer '192.0.2.53','1.1.1.1' -QueryName 'example.com' -RepeatCount 5
```

`192.0.2.53` is an example address from documentation space. Replace it with the DNS server you actually want to test.

### Remove-EmptyFiles.ps1

**Purpose**

Recursively searches a local directory, mapped drive, or UNC path for zero byte files. Running the script without `-Delete` only reports the files it finds. Deletion requires the explicit `-Delete` switch and supports PowerShell `-WhatIf` and `-Confirm` behavior.

**Who might benefit**

Administrators, photographers, media users, backup operators, and anyone cleaning up empty files left by failed copies, downloads, exports, or processing jobs.

**Run**

```powershell
.\Remove-EmptyFiles.ps1 -Path 'D:\Data'
```

Preview deletion behavior:

```powershell
.\Remove-EmptyFiles.ps1 -Path '\\server\share' -Delete -WhatIf
```

### Touch-Files.ps1

**Purpose**

Recursively changes each file's `LastWriteTime` without changing file contents. By default the current time is used, or a specific timestamp can be supplied.

**Who might benefit**

Administrators testing backup or synchronization products, migration teams, developers testing file watchers, and users working with applications that react to modification timestamps.

**Run**

```powershell
.\Touch-Files.ps1 -Path 'D:\TestData'
```

Preview a specific timestamp change:

```powershell
.\Touch-Files.ps1 -Path 'D:\TestData' -Timestamp '2026-01-01 12:00:00' -WhatIf
```

### Network-Tools-GUI.ps1

**Purpose**

Opens a small Windows GUI that accepts a hostname or IP address and runs Ping, NSLookup, or Tracert. The script launches the Windows utilities directly rather than passing user input through a command shell.

**Who might benefit**

Help desk personnel, junior administrators, field technicians, or users who want basic Windows network diagnostics without manually entering commands in a terminal.

**Run**

```powershell
.\Network-Tools-GUI.ps1
```

Enter a hostname or IP address in the window and choose the desired test.

### Test-SmbReadWriteSpeed.ps1

**Purpose**

Creates a temporary file containing random data, copies it to an SMB share while timing the operation, then copies it back to measure approximate read throughput. Temporary local and remote test files and the temporary PowerShell drive are removed when the test finishes or fails.

The result is an application level file copy benchmark. Caching, SMB features, storage performance, antivirus scanning, network congestion, and other system behavior can affect the numbers, so it should not be treated as a synthetic maximum for the underlying network link.

**Who might benefit**

Windows administrators, NAS owners, home lab users, and anyone investigating whether a network share is performing as expected or comparing before and after changes to storage or networking.

**Run**

```powershell
.\Test-SmbReadWriteSpeed.ps1 -NetworkPath '\\server\share' -FileSizeMB 512
```

If alternate credentials are required:

```powershell
$cred = Get-Credential
.\Test-SmbReadWriteSpeed.ps1 -NetworkPath '\\server\share' -Credential $cred
```

### Copy-FilesFlattened.ps1

**Purpose**

Recursively copies files from a source tree into a single destination folder without preserving the source subdirectories. If a destination filename already exists, the script creates a unique name such as `photo_1.jpg`, `photo_2.jpg`, and so on rather than overwriting it.

The destination cannot be the source directory or a child of the source directory, which prevents the script from recursively copying its own output.

**Who might benefit**

Photographers consolidating exports, media collectors, migration users, archive recovery work, and anyone who needs files gathered from many nested folders into a flat directory.

**Run**

```powershell
.\Copy-FilesFlattened.ps1 -SourcePath 'D:\Photos' -DestinationPath 'E:\Combined'
```

Preview the copy plan:

```powershell
.\Copy-FilesFlattened.ps1 -SourcePath 'D:\Photos' -DestinationPath 'E:\Combined' -WhatIf
```

### Dont-Hit-Stuff.ps1

**Purpose**

Demonstrates a very small PowerShell function and conditional flow using a randomly generated value. The script is intentionally humorous rather than a practical administrative utility.

**Who might benefit**

Anyone looking for a tiny PowerShell example or familiar with the long circulating programming joke it adapts.

**Run**

```powershell
.\Dont-Hit-Stuff.ps1
```

**Background**

This is a PowerShell adaptation of the long circulating `if (goingToHitStuff) { dont(); }` programming meme rather than a claim of authorship of the underlying joke.

## Safety and Security Notes

Review a script before running it in an environment that contains important data. The utilities are intentionally small, but several of them perform real filesystem or network operations.

* `Remove-EmptyFiles.ps1` does not delete files unless `-Delete` is supplied. Use `-WhatIf` with `-Delete` to preview removals.
* `Touch-Files.ps1` changes file metadata recursively. Use `-WhatIf` to review the affected files before applying a timestamp change.
* `Copy-FilesFlattened.ps1` copies files and can consume substantial destination storage. It does not overwrite existing filenames; collisions receive numbered names. `-WhatIf` is supported.
* `Test-SmbReadWriteSpeed.ps1` temporarily writes data to both the local system and the requested SMB share. Ensure sufficient free space and appropriate permissions before running a large test.
* `Test-DnsServerPerformance.ps1` sends the requested DNS name to each configured resolver. Queries sent to public DNS servers leave the local network.
* `Network-Tools-GUI.ps1` runs standard Windows network diagnostic utilities against the hostname or IP address entered by the user.

These scripts do not contain credentials or private environment values. If you adapt one to include local credentials, private hostnames, internal addresses, or other sensitive information, protect that information appropriately and avoid committing it to public source control.

## Attribution and AI Assistance

Some scripts or portions of scripts in this repository may be adaptations of, inspired by, or derived from publicly available examples, documentation, community discussions, or other prior work. AI tools may also have been used to help create, review, troubleshoot, document, format, or refine code.

Where a specific third party source is known and materially contributes to a script, an effort will be made to identify it in the relevant file or documentation. This repository is intended to share useful work in good faith, not to claim authorship of material known to originate elsewhere.

Third party tools, operating system components, services, and APIs referenced by scripts remain subject to their own licenses and terms.

## License

This repository is provided under the MIT License. See [`LICENSE`](./LICENSE) for the applicable terms and warranty disclaimer.
