@echo off
rem Drag a folder (or many files) onto this file, or run: print-many.bat "C:\Docs"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0print-many.ps1" -Path %*
pause
