#!/usr/bin/env bash
# rollback.sh - Roll back support files using snapshot created by upgrade.sh
# Restores: docker-compose.yml, scripts/, entrypoints + preserved .env and nginx/nginx.template
# Then runs docker compose up -d.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  sudo ./rollback.sh --app-dir /app (--snapshot /app/rollback/<snapdir> | --last) [--dry-run] [--force]

Examples:
  sudo ./rollback.sh --app-dir /app --last
  sudo ./rollback.sh --app-dir /app --snapshot /app/rollback/4.4.0-to-4.4.1-20260224-101500

Notes:
  - Does not attempt DB restore (safe for additive-column migrations).
USAGE
}

APP_DIR=""
SNAP_DIR=""
USE_LAST=0
DRY_RUN=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-dir)   APP_DIR="${2:-}"; shift 2;;
    --snapshot)  SNAP_DIR="${2:-}"; shift 2;;
    --last)      USE_LAST=1; shift;;
    --dry-run)   DRY_RUN=1; shift;;
    --force)     FORCE=1; shift;;
    -h|--help)   usage; exit 0;;
    *) echo "ERROR: Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$APP_DIR" ]]; then
  echo "ERROR: --app-dir is required" >&2
  usage
  exit 2
fi

if [[ "$FORCE" -ne 1 && "$APP_DIR" != "/app" ]]; then
  echo "ERROR: Refusing to run with --app-dir '$APP_DIR' (expected /app). Use --force to override." >&2
  exit 2
fi

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found in PATH" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: 'docker compose' not available" >&2; exit 1; }

LAST_FILE="$APP_DIR/rollback/LAST"

if [[ "$USE_LAST" -eq 1 ]]; then
  [[ -f "$LAST_FILE" ]] || { echo "ERROR: LAST snapshot file not found: $LAST_FILE" >&2; exit 1; }
  SNAP_DIR="$(cat "$LAST_FILE")"
fi

if [[ -z "$SNAP_DIR" ]]; then
  echo "ERROR: Must specify --snapshot or --last" >&2
  usage
  exit 2
fi

[[ -d "$SNAP_DIR" ]] || { echo "ERROR: snapshot dir not found: $SNAP_DIR" >&2; exit 1; }
[[ -d "$APP_DIR" ]] || { echo "ERROR: app dir not found: $APP_DIR" >&2; exit 1; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    eval "$@"
  fi
}

echo "==> App dir   : $APP_DIR"
echo "==> Snapshot  : $SNAP_DIR"
echo "==> Dry-run   : $DRY_RUN"
echo

# Restore top-level files if present
restore_if_exists() {
  local rel="$1"
  local src="$SNAP_DIR/$rel"
  local dst="$APP_DIR/$rel"
  if [[ -e "$src" ]]; then
    run "mkdir -p '$(dirname "$dst")'"
    # Remove destination if restoring a directory (avoid mixing old/new)
    if [[ -d "$src" ]]; then
      run "rm -rf '$dst'"
    fi
    run "cp -a '$src' '$dst'"
  else
    echo "WARN: snapshot missing $rel (skipping)"
  fi
}

restore_if_exists ".env"
restore_if_exists "nginx/nginx.template"
restore_if_exists "docker-compose.yml"
restore_if_exists "Makefile"
restore_if_exists "certbot/docker-entrypoint.sh"
restore_if_exists "nginx/docker-entrypoint.sh"
restore_if_exists "nginx/reloader.sh"
restore_if_exists "scripts"

echo "==> Restored files from snapshot."

# Validate compose config if possible
if [[ -f "$APP_DIR/docker-compose.yml" ]]; then
  echo "==> Validating docker compose config..."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] (would run: docker compose -f $APP_DIR/docker-compose.yml config)"
  else
    (cd "$APP_DIR" && docker compose -f docker-compose.yml config >/tmp/swirl.compose.rendered.rollback.yml)
  fi
fi

# Restart stack
echo "==> Restarting docker compose stack..."
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] (would run: docker compose up -d)"
else
  cd "$APP_DIR"
  docker compose up -d
  echo "==> Rollback applied."
  echo
  docker compose ps
fi
