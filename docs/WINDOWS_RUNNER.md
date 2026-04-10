# Windows: run the tracker (Docker + app)

This repo includes portable scripts under `scripts/` — paths are resolved from the script location, not your username.

| File | Purpose |
|------|---------|
| `scripts/run-tracker.ps1` | Ensures Docker is up, `docker compose up -d`, waits for DB/Redis, runs `uv run python -m polymarket_insider_tracker`, appends output to `logs/tracker-YYYYMMDD.log`, exits with the tracker’s exit code. |
| `scripts/run-tracker-once.bat` | Wrapper so you can double-click or point Task Scheduler at a `.bat` file. |

## Prerequisites (one-time)

1. **Docker Desktop** installed (WSL2 backend if Docker asks for it). Optionally enable **Start Docker Desktop when you log in** if you schedule the tracker at startup/logon before you open Docker manually.
2. **uv** available — the script prepends `%USERPROFILE%\.local\bin` to `PATH` (typical `uv` install). If `uv.exe` lives elsewhere, add that folder to your user PATH or install `uv` into `%USERPROFILE%\.local\bin`.
3. **Repository** cloned to the machine you use (any path; scripts do not hardcode drive or user).
4. **`.env`** in the repo root (copy from `.env.example`):
   - `DATABASE_URL` / `REDIS_URL` consistent with `docker-compose.yml`
   - Polygon RPC, Polymarket keys, etc.
   - **`ALPHASCOUT_WEBHOOK_SECRET`** must match **`POLYMARKET_ALERT_WEBHOOK_SECRET`** in DataBridge if you use that integration.

## One-time setup (repo root)

```powershell
cd <path-to>\polymarket-insider-tracker
uv sync --all-extras
uv run alembic upgrade head
```

## Smoke test

```powershell
cd <path-to>\polymarket-insider-tracker
.\scripts\run-tracker.ps1
```

Or double-click `scripts\run-tracker-once.bat`.

- On failure, open `logs\tracker-YYYYMMDD.log` (same calendar day).
- The tracker is a **long-running daemon**; the script blocks until the process exits (Ctrl+C stops it when run interactively).

## Task Scheduler (recommended for “always on”)

Use **Create Task** (not “Create Basic Task”) for full control.

1. **General**
   - Name: e.g. `Polymarket Insider Tracker`.
   - Prefer **Run only when user is logged on** unless you explicitly need **Run whether user is logged on or not** (stores credentials; harder to debug `uv`/Docker/PATH issues).

2. **Triggers**
   - **At log on** (your user), **or**
   - **At startup** with a **delay** of 1–2 minutes so Docker Desktop can start before the script runs.

3. **Actions** → **Start a program**
   - **Program:** `powershell.exe`
   - **Arguments:** `-NoProfile -ExecutionPolicy Bypass -File "<REPO>\scripts\run-tracker.ps1"`  
     Replace `<REPO>` with your clone path, e.g. `C:\Users\jmann\projects\polymarket-insider-tracker`.
   - **Start in:** same `<REPO>` directory (repo root).

4. **Conditions**
   - On a laptop, uncheck **Start the task only if the computer is on AC power** if you want it on battery.

5. **Settings**
   - Enable **Run task on demand**.
   - Optionally: **Run task as soon as possible after a scheduled start is missed**.

### Important behavior

- **One logon or startup task** is normal. The tracker runs until it exits. **Do not** schedule `run-tracker.ps1` every 5–15 minutes unless you intentionally want overlapping processes or a restart-every-N-minutes design.
- **If the process crashes**, the scheduled task is done until the **next** trigger (e.g. next logon). Auto-restart on crash is **not** included here (would need NSSM, a Windows service wrapper, or a separate watchdog—ask if you want that).
- **Task Scheduler PATH** is minimal; the script prepends `%USERPROFILE%\.local\bin` for `uv`. If `uv` still is not found, fix PATH for your user or document a full path inside a thin wrapper you control.

### Exit codes

The launcher ends with the same exit code as `uv run python -m polymarket_insider_tracker` (via `cmd /c … >> log 2>&1`). Task Scheduler records success/failure from that code. Avoid swapping this for a PowerShell pipeline to `Tee-Object` on Windows PowerShell 5.1 without verifying exit codes still propagate.

## Optional follow-ups (not in this repo by default)

- **NSSM** or another Windows Service wrapper for restart-on-failure.
- A **watchdog** task that only starts the tracker if the process is missing (extra moving parts).
