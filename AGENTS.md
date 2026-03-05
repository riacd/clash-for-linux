# Repository Guidelines

## Project Structure & Module Organization
Core scripts live in the repository root (`start.sh`, `restart.sh`, `shutdown.sh`); keep new automation alongside them. Runtime binaries sit under `bin/` (one per architecture), and `conf/` stores the active `config.yaml`, cached profiles, and GeoIP data. Temporary assets land in `temp/`, persistent logs in `logs/`, and the Yacd dashboard bundle in `dashboard/public/`. Helper utilities belong in `scripts/`, while third-party tools (for example `subconverter`) stay in `tools/`.

## Build, Test, and Development Commands
`sudo bash start.sh` provisions dependencies, syncs from `CLASH_URL`, and launches the Clash daemon. `sudo bash restart.sh` reloads the daemon without re-downloading the subscription; run it after editing `conf/config.yaml`. `sudo bash shutdown.sh` stops the service and reminds users to disable system proxies. `bash test-claude.sh` performs a quick connectivity smoke test. Profile conversion lives in `bash scripts/clash_profile_conversion.sh`; invoke it when the fetched YAML needs normalization.

## Coding Style & Naming Conventions
Scripts target Bash 4+ and start with `#!/bin/bash`. Use two-space indentation inside functions, prefer `[[ … ]]` tests, and wrap variables as `${var}`. Reuse the shared `action` and `if_success` helpers for status reporting and exit early on failures. Name new executables `clash-<purpose>.sh` and keep configuration artifacts lowercase with hyphen-separated words. Run `bash -n` (optionally `shellcheck`) before sending patches.

## Testing Guidelines
There is no automated CI, so rely on scripted probes. After networking changes, run `bash test-claude.sh` and review the tail of `logs/clash.log` for rule hits. When touching startup logic, execute `sudo bash start.sh` and confirm listeners with `netstat -tln | grep -E '9090|789'`. For configuration tweaks, validate the rendered YAML in `temp/config.yaml` using `python -c 'import yaml; yaml.safe_load(open(\"conf/config.yaml\"))'`.

## Commit & Pull Request Guidelines
Recent history favors terse messages (`update`); improve clarity with imperative subjects such as `fix: harden subscription retry loop`. Group related edits per commit and describe user-visible impacts when relevant. Pull requests should include the motivation, commands exercised, and screenshots or log excerpts for dashboard or proxy changes. Link associated issues and note any configuration prerequisites for reviewers.

## Configuration & Security Tips
Never commit `.env` or subscription URLs; reference variables such as `CLASH_URL` and `CLASH_SECRET` instead. Rotate generated secrets stored in `/etc/profile.d/clash.sh` when sharing environments, and scrub `logs/clash.log` before uploading diagnostics. Provide reproduction steps with sanitized sample URLs whenever you need to share proxy details.
