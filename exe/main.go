package main

import (
	_ "embed"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
)

//go:embed gui.ps1
var script string

func main() {
	dir, err := os.MkdirTemp("", "printmany")
	if err != nil {
		os.Exit(1)
	}
	defer os.RemoveAll(dir)
	ps1 := filepath.Join(dir, "gui.ps1")
	// UTF-8 BOM so PowerShell 5 reads non-ASCII correctly.
	if err := os.WriteFile(ps1, append([]byte{0xEF, 0xBB, 0xBF}, script...), 0600); err != nil {
		os.Exit(1)
	}
	args := []string{"-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", ps1}
	args = append(args, os.Args[1:]...)
	cmd := exec.Command("powershell.exe", args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
	_ = cmd.Run()
}
