@echo off
REM Repo-root launcher: Docker + tracker (see scripts\run-tracker.ps1).
REM Double-click, or point Task Scheduler here; keeps working if repo path changes when this file moves with the repo.
cd /d "%~dp0"
call "%~dp0scripts\run-tracker-once.bat"
exit /b %ERRORLEVEL%
