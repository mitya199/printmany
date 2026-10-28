param([string[]]$Paths)
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

if (-not $Paths) {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Select the files to print (Ctrl+A selects all)'
    $dlg.Multiselect = $true
    $dlg.Filter = 'All files (*.*)|*.*'
    if ($dlg.ShowDialog() -ne 'OK') { return }
    $Paths = $dlg.FileNames
}

$files = @()
foreach ($p in $Paths) {
    if (Test-Path -LiteralPath $p -PathType Container) { $files += Get-ChildItem -LiteralPath $p -File | Sort-Object Name }
    elseif (Test-Path -LiteralPath $p -PathType Leaf) { $files += Get-Item -LiteralPath $p }
}
if (-not $files.Count) { return }

Add-Type -AssemblyName System.Drawing
$printers = @([System.Drawing.Printing.PrinterSettings]::InstalledPrinters)
if (-not $printers.Count) {
    [System.Windows.Forms.MessageBox]::Show('No printers are installed.', 'Print Many', 'OK', 'Error') | Out-Null
    return
}
$defaultPrinter = (New-Object System.Drawing.Printing.PrinterSettings).PrinterName

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Print Many'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false; $form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(380, 130)

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = "Print $($files.Count) file(s) on:"
$lbl.Location = New-Object System.Drawing.Point(15, 15); $lbl.AutoSize = $true
$combo = New-Object System.Windows.Forms.ComboBox
$combo.DropDownStyle = 'DropDownList'
$combo.Location = New-Object System.Drawing.Point(15, 40); $combo.Width = 350
$printers | ForEach-Object { [void]$combo.Items.Add($_) }
$combo.SelectedItem = $defaultPrinter
if ($combo.SelectedIndex -lt 0) { $combo.SelectedIndex = 0 }
$ok = New-Object System.Windows.Forms.Button
$ok.Text = 'Print'; $ok.DialogResult = 'OK'
$ok.Location = New-Object System.Drawing.Point(205, 85)
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = 'Cancel'; $cancel.DialogResult = 'Cancel'
$cancel.Location = New-Object System.Drawing.Point(290, 85)
$form.AcceptButton = $ok; $form.CancelButton = $cancel
$form.Controls.AddRange(@($lbl, $combo, $ok, $cancel))
if ($form.ShowDialog() -ne 'OK') { return }
$printer = [string]$combo.SelectedItem

$net = New-Object -ComObject WScript.Network
$switched = $false
$failed = @()
foreach ($f in $files) {
    try {
        $verbs = (New-Object System.Diagnostics.ProcessStartInfo($f.FullName)).Verbs
        if ($verbs -contains 'printto') {
            Start-Process -FilePath $f.FullName -Verb PrintTo -ArgumentList "`"$printer`"" -WindowStyle Hidden
        } else {
            # Handler has no "printto" (e.g. Edge for PDFs): print to the default printer instead.
            if (-not $switched -and $printer -ne $defaultPrinter) {
                $net.SetDefaultPrinter($printer); $switched = $true
            }
            Start-Process -FilePath $f.FullName -Verb Print -WindowStyle Hidden
        }
    } catch { $failed += $f.Name }
    Start-Sleep -Seconds 3
}
if ($switched) {
    Start-Sleep -Seconds 5
    $net.SetDefaultPrinter($defaultPrinter)
}
$msg = "Sent $($files.Count - $failed.Count) of $($files.Count) file(s) to $printer."
if ($failed) { $msg += "`n`nCould not print:`n" + ($failed -join "`n") }
[System.Windows.Forms.MessageBox]::Show($msg, 'Print Many') | Out-Null
