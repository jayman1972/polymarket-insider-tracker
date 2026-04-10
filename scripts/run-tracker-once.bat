@echo off
setlocal EnableDelayedExpansion
REM Double-click or Task Scheduler: run the PowerShell launcher once; preserve exit code.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-tracker.ps1"
exit /b !ERRORLEVEL!
