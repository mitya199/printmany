<#
.SYNOPSIS
  Print many files at once on Windows (no 20-file limit).

.EXAMPLE
  .\print-many.ps1 -Path C:\Docs\ToPrint
  .\print-many.ps1 -Path C:\Docs -Filter *.pdf -Recurse
  .\print-many.ps1 -Path a.pdf,b.docx -Printer "HP LaserJet"
  .\print-many.ps1 -Path C:\Docs -WhatIf        # list only, print nothing
#>
param(
    [Parameter(Mandatory, Position = 0)][string[]]$Path,
    [string]$Filter = '*',
    [switch]$Recurse,
    [string]$Printer,
    [int]$DelaySeconds = 3,
    [switch]$WhatIf
)

$files = foreach ($p in $Path) {
    if (Test-Path -LiteralPath $p -PathType Container) {
        Get-ChildItem -LiteralPath $p -Filter $Filter -File -Recurse:$Recurse
    } elseif (Test-Path -LiteralPath $p -PathType Leaf) {
        Get-Item -LiteralPath $p
    } else {
        Write-Warning "Not found: $p"
    }
}
$files = @($files | Sort-Object FullName -Unique)

if (-not $files.Count) { Write-Host 'No files found.'; return }

Write-Host "$($files.Count) file(s) to print:"
$files | ForEach-Object { Write-Host "  $($_.FullName)" }
if ($WhatIf) { return }

if ((Read-Host "Print all $($files.Count) files? (y/N)") -notmatch '^[yY]') { return }

$i = 0
foreach ($f in $files) {
    $i++
    Write-Host "[$i/$($files.Count)] $($f.Name)"
    try {
        if ($Printer) {
            Start-Process -FilePath $f.FullName -Verb PrintTo -ArgumentList "`"$Printer`"" -WindowStyle Hidden
        } else {
            Start-Process -FilePath $f.FullName -Verb Print -WindowStyle Hidden
        }
    } catch {
        Write-Warning "Failed: $($f.Name) - $($_.Exception.Message)"
    }
    # Give the print handler time to spool before launching the next one.
    Start-Sleep -Seconds $DelaySeconds
}
Write-Host 'Done. Jobs are in the printer queue.'
