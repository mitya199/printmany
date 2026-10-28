# printmany

Print many files at once on Windows (no 20-file limit).

## PrintMany.exe

Double-click it, select your files (Ctrl+A selects all), choose a printer and click **Print**.
You can also drag files or a folder onto the .exe.

Files print one at a time through each file type's default Windows "Print" action.
Handlers without a direct print-to-printer action (e.g. Edge for PDFs) are printed by
temporarily switching the Windows default printer, which is restored afterwards.

Windows SmartScreen may warn because the exe is unsigned: choose "More info" > "Run anyway".

## Other versions

- `print-many.ps1` – command-line PowerShell script (`-Path`, `-Filter`, `-Recurse`, `-Printer`, `-WhatIf`)
- `print-many.bat` – drag-and-drop launcher for the script

## Rebuilding the exe

```
cd exe
GOOS=windows GOARCH=amd64 go build -ldflags "-s -w -H windowsgui" -o ../PrintMany.exe .
```
