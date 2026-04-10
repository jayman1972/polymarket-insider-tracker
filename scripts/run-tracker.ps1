#Requires -Version 5.1
<#
.SYNOPSIS
  Start Docker services (Postgres/Redis) and run the Polymarket insider tracker.
  Repo root is derived from this script location (portable; no hardcoded user paths).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$LocalBin = Join-Path $env:USERPROFILE '.local\bin'
if (Test-Path $LocalBin) {
  $env:PATH = "$LocalBin;$env:PATH"
}

Set-Location $RepoRoot

$logsDir = Join-Path $RepoRoot 'logs'
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
$logFile = Join-Path $logsDir ("tracker-$(Get-Date -Format 'yyyyMMdd').log")

Add-Content -Path $logFile -Value @(
  ''
  '========================================'
  "$(Get-Date -Format 'o') run-tracker start"
  '========================================'
  ''
)

# Fail fast if Docker daemon is not available (Task Scheduler has minimal PATH)
cmd /c "docker info >nul 2>&1"
if ($LASTEXITCODE -ne 0) {
  $msg = "ERROR: docker info failed (exit $LASTEXITCODE). Is Docker Desktop running?"
  Add-Content -Path $logFile -Value $msg
  Write-Error $msg
  exit $LASTEXITCODE
}

# docker compose writes progress to stderr; run via cmd so $ErrorActionPreference does not abort on stderr
cmd /c "cd /d `"$RepoRoot`" && docker compose up -d >nul 2>&1"
if ($LASTEXITCODE -ne 0) {
  $msg = "ERROR: docker compose up -d failed (exit $LASTEXITCODE)"
  Add-Content -Path $logFile -Value $msg
  Write-Error $msg
  exit $LASTEXITCODE
}

# Brief pause for Postgres/Redis to accept connections after compose returns
Start-Sleep -Seconds 8

# Preserve process exit code for Task Scheduler; avoid Tee-Object pipelines that mask exit on PS 5.1
cmd /c "cd /d `"$RepoRoot`" && uv run python -m polymarket_insider_tracker >> `"$logFile`" 2>&1"
$exitCode = $LASTEXITCODE

Add-Content -Path $logFile -Value @(
  ''
  "$(Get-Date -Format 'o') run-tracker end exit=$exitCode"
  ''
)

exit $exitCode
