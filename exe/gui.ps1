param([string[]]$Paths)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$settingsDir  = Join-Path $env:APPDATA 'PrintMany'
$settingsFile = Join-Path $settingsDir 'settings.json'

function Load-Settings {
    try { return Get-Content -LiteralPath $settingsFile -Raw -ErrorAction Stop | ConvertFrom-Json } catch { return $null }
}
function Save-Settings {
    try {
        if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir | Out-Null }
        @{ printer = [string]$cmbPrinter.SelectedItem; copies = [int]$numCopies.Value; sides = $cmbSides.SelectedIndex } |
            ConvertTo-Json | Set-Content -LiteralPath $settingsFile -Encoding UTF8
    } catch { }
}

try {
    $printers = @([System.Drawing.Printing.PrinterSettings]::InstalledPrinters)
    if (-not $printers.Count) {
        [System.Windows.Forms.MessageBox]::Show('No printers are installed.', 'Print Many', 'OK', 'Error') | Out-Null
        return
    }
    $defaultPrinter = (New-Object System.Drawing.Printing.PrinterSettings).PrinterName
    $saved = Load-Settings
    $script:cancel = $false
    $script:busy = $false

    # ---------- layout ----------
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Print Many'
    $form.StartPosition = 'CenterScreen'
    $form.ClientSize = New-Object System.Drawing.Size(760, 540)
    $form.MinimumSize = New-Object System.Drawing.Size(640, 460)
    $form.AllowDrop = $true
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    function New-Btn($text, $x, $y, $w) {
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $text; $b.Location = New-Object System.Drawing.Point($x, $y)
        $b.Size = New-Object System.Drawing.Size($w, 28)
        return $b
    }

    $btnAddFiles  = New-Btn 'Add files...'  12 10 100
    $btnAddFolder = New-Btn 'Add folder...' 118 10 100
    $btnRemove    = New-Btn 'Remove'        224 10 80
    $btnClear     = New-Btn 'Clear'         310 10 70
    $btnUp        = New-Btn 'Up'            386 10 55
    $btnDown      = New-Btn 'Down'          447 10 55

    $lv = New-Object System.Windows.Forms.ListView
    $lv.View = 'Details'; $lv.FullRowSelect = $true; $lv.MultiSelect = $true
    $lv.HideSelection = $false; $lv.ShowItemToolTips = $true; $lv.GridLines = $true; $lv.AllowDrop = $true
    $lv.Location = New-Object System.Drawing.Point(12, 46)
    $lv.Size = New-Object System.Drawing.Size(736, 330)
    $lv.Anchor = 'Top,Bottom,Left,Right'
    [void]$lv.Columns.Add('File', 260)
    [void]$lv.Columns.Add('Folder', 330)
    [void]$lv.Columns.Add('Status', 130)

    $grp = New-Object System.Windows.Forms.GroupBox
    $grp.Text = 'Print settings'
    $grp.Location = New-Object System.Drawing.Point(12, 384)
    $grp.Size = New-Object System.Drawing.Size(736, 62)
    $grp.Anchor = 'Bottom,Left,Right'

    $lblP = New-Object System.Windows.Forms.Label
    $lblP.Text = 'Printer:'; $lblP.AutoSize = $true; $lblP.Location = New-Object System.Drawing.Point(12, 28)
    $cmbPrinter = New-Object System.Windows.Forms.ComboBox
    $cmbPrinter.DropDownStyle = 'DropDownList'
    $cmbPrinter.Location = New-Object System.Drawing.Point(62, 24); $cmbPrinter.Width = 290
    $printers | ForEach-Object { [void]$cmbPrinter.Items.Add($_) }

    $lblC = New-Object System.Windows.Forms.Label
    $lblC.Text = 'Copies:'; $lblC.AutoSize = $true; $lblC.Location = New-Object System.Drawing.Point(366, 28)
    $numCopies = New-Object System.Windows.Forms.NumericUpDown
    $numCopies.Minimum = 1; $numCopies.Maximum = 99; $numCopies.Value = 1
    $numCopies.Location = New-Object System.Drawing.Point(414, 24); $numCopies.Width = 50

    $lblS = New-Object System.Windows.Forms.Label
    $lblS.Text = 'Sides:'; $lblS.AutoSize = $true; $lblS.Location = New-Object System.Drawing.Point(480, 28)
    $cmbSides = New-Object System.Windows.Forms.ComboBox
    $cmbSides.DropDownStyle = 'DropDownList'
    $cmbSides.Location = New-Object System.Drawing.Point(520, 24); $cmbSides.Width = 200
    @('Printer default', 'One-sided', 'Two-sided (long edge)', 'Two-sided (short edge)') | ForEach-Object { [void]$cmbSides.Items.Add($_) }
    $grp.Controls.AddRange(@($lblP, $cmbPrinter, $lblC, $numCopies, $lblS, $cmbSides))

    $bar = New-Object System.Windows.Forms.ProgressBar
    $bar.Location = New-Object System.Drawing.Point(12, 458); $bar.Size = New-Object System.Drawing.Size(736, 18)
    $bar.Anchor = 'Bottom,Left,Right'

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = 'Add files, then click Print.'
    $lblStatus.Location = New-Object System.Drawing.Point(12, 500); $lblStatus.Size = New-Object System.Drawing.Size(480, 22)
    $lblStatus.Anchor = 'Bottom,Left'

    $btnPrint = New-Btn 'Print' 560 494 90
    $btnPrint.Anchor = 'Bottom,Right'
    $btnStop = New-Btn 'Stop' 658 494 90
    $btnStop.Anchor = 'Bottom,Right'; $btnStop.Enabled = $false
    $form.AcceptButton = $null

    $form.Controls.AddRange(@($btnAddFiles, $btnAddFolder, $btnRemove, $btnClear, $btnUp, $btnDown,
                              $lv, $grp, $bar, $lblStatus, $btnPrint, $btnStop))

    # ---------- settings ----------
    $cmbSides.SelectedIndex = 0
    if ($saved) {
        if ($saved.printer -and $printers -contains $saved.printer) { $cmbPrinter.SelectedItem = $saved.printer }
        if ($saved.copies -ge 1 -and $saved.copies -le 99) { $numCopies.Value = [int]$saved.copies }
        if ($saved.sides -ge 0 -and $saved.sides -lt $cmbSides.Items.Count) { $cmbSides.SelectedIndex = [int]$saved.sides }
    }
    if ($cmbPrinter.SelectedIndex -lt 0) { $cmbPrinter.SelectedItem = $defaultPrinter }
    if ($cmbPrinter.SelectedIndex -lt 0) { $cmbPrinter.SelectedIndex = 0 }

    # ---------- helpers ----------
    function Update-Summary {
        if ($script:busy) { return }
        $n = $lv.Items.Count
        $lblStatus.Text = if ($n) { "$n file(s) in the list." } else { 'Add files, then click Print.' }
    }

    function Add-Paths([string[]]$items) {
        $known = @{}
        foreach ($it in $lv.Items) { $known[$it.Tag.ToLowerInvariant()] = $true }
        foreach ($p in $items) {
            if (-not $p) { continue }
            $found = @()
            if (Test-Path -LiteralPath $p -PathType Container) { $found = Get-ChildItem -LiteralPath $p -File | Sort-Object Name }
            elseif (Test-Path -LiteralPath $p -PathType Leaf) { $found = @(Get-Item -LiteralPath $p) }
            foreach ($f in $found) {
                if ($known.ContainsKey($f.FullName.ToLowerInvariant())) { continue }
                $known[$f.FullName.ToLowerInvariant()] = $true
                $li = New-Object System.Windows.Forms.ListViewItem($f.Name)
                [void]$li.SubItems.Add($f.DirectoryName)
                [void]$li.SubItems.Add('Queued')
                $li.Tag = $f.FullName
                [void]$lv.Items.Add($li)
            }
        }
        Update-Summary
    }

    function Remove-Selected {
        if ($script:busy) { return }
        foreach ($it in @($lv.SelectedItems)) { $lv.Items.Remove($it) }
        Update-Summary
    }

    function Move-Selected([int]$dir) {
        if ($script:busy -or -not $lv.SelectedItems.Count) { return }
        $idx = @($lv.SelectedIndices | Sort-Object)
        if ($dir -gt 0) { [array]::Reverse($idx) }
        if (($dir -lt 0 -and $idx[0] -eq 0) -or ($dir -gt 0 -and $idx[0] -eq $lv.Items.Count - 1)) { return }
        foreach ($i in $idx) {
            $it = $lv.Items[$i]
            $lv.Items.RemoveAt($i)
            [void]$lv.Items.Insert($i + $dir, $it)
            $it.Selected = $true
        }
    }

    function Wait-Pump([double]$seconds) {
        $end = (Get-Date).AddSeconds($seconds)
        while ((Get-Date) -lt $end -and -not $script:cancel) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 50
        }
    }

    function Set-Busy([bool]$b) {
        $script:busy = $b
        foreach ($c in @($btnAddFiles, $btnAddFolder, $btnRemove, $btnClear, $btnUp, $btnDown, $btnPrint, $grp)) { $c.Enabled = -not $b }
        $btnStop.Enabled = $b
    }

    # ---------- events ----------
    $btnAddFiles.Add_Click({
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = 'Select files to print (Ctrl+A selects all)'
        $dlg.Multiselect = $true; $dlg.Filter = 'All files (*.*)|*.*'
        if ($dlg.ShowDialog() -eq 'OK') { Add-Paths $dlg.FileNames }
    })
    $btnAddFolder.Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Add every file in this folder'
        if ($dlg.ShowDialog() -eq 'OK') { Add-Paths @($dlg.SelectedPath) }
    })
    $btnRemove.Add_Click({ Remove-Selected })
    $btnClear.Add_Click({ if (-not $script:busy) { $lv.Items.Clear(); $bar.Value = 0; Update-Summary } })
    $btnUp.Add_Click({ Move-Selected -1 })
    $btnDown.Add_Click({ Move-Selected 1 })
    $lv.Add_KeyDown({
        if ($_.KeyCode -eq 'Delete') { Remove-Selected }
        elseif ($_.Control -and $_.KeyCode -eq 'A') { foreach ($it in $lv.Items) { $it.Selected = $true } }
    })
    $enter = { if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = 'Copy' } }
    $drop  = { if (-not $script:busy) { Add-Paths ([string[]]$_.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)) } }
    $form.Add_DragEnter($enter); $form.Add_DragDrop($drop)
    $lv.Add_DragEnter($enter);   $lv.Add_DragDrop($drop)

    $btnStop.Add_Click({ $script:cancel = $true; $lblStatus.Text = 'Stopping...' })

    $form.Add_FormClosing({
        if ($script:busy) {
            $a = [System.Windows.Forms.MessageBox]::Show('Printing is in progress. Stop and close?', 'Print Many', 'YesNo', 'Question')
            if ($a -ne 'Yes') { $_.Cancel = $true; return }
            $script:cancel = $true
        }
        Save-Settings
    })

    $btnPrint.Add_Click({
        if (-not $lv.Items.Count) {
            [System.Windows.Forms.MessageBox]::Show('Add some files first.', 'Print Many') | Out-Null
            return
        }
        $printer = [string]$cmbPrinter.SelectedItem
        $copies  = [int]$numCopies.Value
        $sides   = $cmbSides.SelectedIndex
        $total   = $lv.Items.Count * $copies
        $ans = [System.Windows.Forms.MessageBox]::Show("Print $($lv.Items.Count) file(s) x $copies cop$(if ($copies -eq 1) {'y'} else {'ies'}) on:`n$printer ?", 'Print Many', 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }

        Save-Settings
        $script:cancel = $false
        Set-Busy $true
        $bar.Minimum = 0; $bar.Maximum = $total; $bar.Value = 0
        foreach ($it in $lv.Items) { $it.SubItems[2].Text = 'Queued' }

        $net = New-Object -ComObject WScript.Network
        $switchedDefault = $false
        $origDuplex = $null
        $note = ''

        try {
            # Two-sided / one-sided: temporarily change the printer's own default, restored afterwards.
            if ($sides -gt 0) {
                try {
                    $origDuplex = (Get-PrintConfiguration -PrinterName $printer -ErrorAction Stop).DuplexingMode
                    $mode = @('', 'OneSided', 'TwoSidedLongEdge', 'TwoSidedShortEdge')[$sides]
                    Set-PrintConfiguration -PrinterName $printer -DuplexingMode $mode -ErrorAction Stop
                } catch {
                    $origDuplex = $null
                    $note = ' (the printer did not accept the sides setting)'
                }
            }

            $done = 0; $failed = 0
            foreach ($it in $lv.Items) {
                if ($script:cancel) { break }
                $path = [string]$it.Tag
                $it.EnsureVisible()
                $ok = $true
                for ($c = 1; $c -le $copies -and -not $script:cancel; $c++) {
                    $it.SubItems[2].Text = if ($copies -gt 1) { "Printing $c/$copies" } else { 'Printing...' }
                    $lblStatus.Text = "Printing $($done + 1) of $($lv.Items.Count): $($it.Text)"
                    try {
                        $verbs = (New-Object System.Diagnostics.ProcessStartInfo($path)).Verbs
                        if ($verbs -contains 'printto') {
                            Start-Process -FilePath $path -Verb PrintTo -ArgumentList "`"$printer`"" -WindowStyle Hidden
                        } else {
                            # Handler has no "printto" (e.g. Edge for PDFs): use the default printer instead.
                            if (-not $switchedDefault -and $printer -ne $defaultPrinter) {
                                $net.SetDefaultPrinter($printer); $switchedDefault = $true
                            }
                            Start-Process -FilePath $path -Verb Print -WindowStyle Hidden
                        }
                    } catch {
                        $ok = $false
                        $it.SubItems[2].Text = 'Failed'
                        $it.ToolTipText = $_.Exception.Message
                        break
                    }
                    $bar.Value = [Math]::Min($bar.Maximum, $bar.Value + 1)
                    Wait-Pump 3
                }
                if ($ok -and -not $script:cancel) { $it.SubItems[2].Text = 'Sent'; $done++ }
                elseif (-not $ok) { $failed++ }
                elseif ($script:cancel) { $it.SubItems[2].Text = 'Stopped' }
            }

            # Let the last jobs reach the spooler before restoring printer settings.
            if ($switchedDefault -or $origDuplex) { $lblStatus.Text = 'Finishing...'; Wait-Pump 5 }
        } finally {
            if ($switchedDefault) { try { $net.SetDefaultPrinter($defaultPrinter) } catch { } }
            if ($origDuplex) { try { Set-PrintConfiguration -PrinterName $printer -DuplexingMode $origDuplex } catch { } }
            Set-Busy $false
        }

        $lblStatus.Text = if ($script:cancel) { "Stopped. $done sent, $failed failed." } else { "Done. $done sent, $failed failed$note." }
        $bar.Value = $bar.Maximum
    })

    # ---------- go ----------
    if ($Paths) { Add-Paths $Paths }
    [void]$form.ShowDialog()
} catch {
    [System.Windows.Forms.MessageBox]::Show("Unexpected error:`n$($_.Exception.Message)", 'Print Many', 'OK', 'Error') | Out-Null
}
