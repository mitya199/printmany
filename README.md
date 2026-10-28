# printmany

Print many files at once on Windows (no 20-file limit).

## PrintMany.exe

Double-click it to open the window:

- **File list** – add files or whole folders, or drag and drop them in. Remove, clear and reorder (Up/Down) entries; Ctrl+A selects all, Delete removes.
- **Printer, copies, sides** – pick the printer, number of copies (1-99) and one-sided / two-sided (long or short edge). Two-sided is applied by temporarily changing the printer's own default via Windows' print settings and restored afterwards; if the printer rejects it, printing continues with its default and the result line says so.
- **Progress** – progress bar plus a per-file status (Queued, Printing, Sent, Failed, Stopped). **Stop** halts the queue.
- **Remembers** the last printer, copies and sides in `%APPDATA%\PrintMany\settings.json`.

You can also drag files or a folder onto the .exe to start with them already listed.

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
