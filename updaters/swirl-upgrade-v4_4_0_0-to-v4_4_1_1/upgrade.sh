#!/usr/bin/env bash
# upgrade.sh - Upgrade Swirl docker-compose support files from 4.4.0.0 -> 4.4.1.1
#
# Preserves (never overwritten):
#   - /app/.env   (but we may update selected image version keys in-place)
#   - /app/nginx/nginx.template
#
# Copies managed files from an unpacked 4.4.1.1 release tarball directory into /app,
# pulls images (via scripts/install-docker-images.sh), then runs docker compose up
# + migrations in a safe order.
#
# Typical usage:
#   sudo ./upgrade.sh --app-dir /app --release-dir /tmp/docker-compose-4_4_1_1/docker-compose-4_4_1_1
#
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  sudo ./upgrade.sh --app-dir /app --release-dir /path/to/docker-compose-4_4_1_1/docker-compose-4_4_1_1 \
    [--manifest ./manifest.copy.txt] \
    [--dry-run] \
    [--force] \
    [--no-set-versions] [--swirl-version v4_4_1_1] [--tika-version v4_4_1_0] [--ttm-version v4_4_1_0] \
    [--no-pull]

Notes:
  - Must be run on the docker host that runs Swirl.
  - Preserves /app/.env and /app/nginx/nginx.template (never overwritten by release copy).
  - By default, updates SWIRL_VERSION/TIKA_VERSION/TTM_VERSION in /app/.env to the provided versions.
  - By default, pulls images by running /app/scripts/install-docker-images.sh (which sources .env).
  - Creates snapshot under /app/rollback/ and writes /app/rollback/LAST.
USAGE
}

APP_DIR=""
RELEASE_DIR=""
MANIFEST=""
DRY_RUN=0
FORCE=0

SET_VERSIONS=1
DO_PULL=1
NEW_SWIRL_VERSION="v4_4_1_1"
NEW_TIKA_VERSION="v4_4_1_0"
NEW_TTM_VERSION="v4_4_1_0"
NEW_SWIRL_PATH="swirlai/release-swirl-search-enterprise"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-dir)      APP_DIR="${2:-}"; shift 2;;
    --release-dir)  RELEASE_DIR="${2:-}"; shift 2;;
    --manifest)     MANIFEST="${2:-}"; shift 2;;
    --dry-run)      DRY_RUN=1; shift;;
    --force)        FORCE=1; shift;;

    --no-set-versions) SET_VERSIONS=0; shift;;
    --swirl-version)   NEW_SWIRL_VERSION="${2:-}"; shift 2;;
    --tika-version)    NEW_TIKA_VERSION="${2:-}"; shift 2;;
    --ttm-version)     NEW_TTM_VERSION="${2:-}"; shift 2;;
    --no-pull)         DO_PULL=0; shift;;

    -h|--help)      usage; exit 0;;
    *) echo "ERROR: Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$APP_DIR" || -z "$RELEASE_DIR" ]]; then
  echo "ERROR: --app-dir and --release-dir are required" >&2
  usage
  exit 2
fi

if [[ "$FORCE" -ne 1 && "$APP_DIR" != "/app" ]]; then
  echo "ERROR: Refusing to run with --app-dir '$APP_DIR' (expected /app). Use --force to override." >&2
  exit 2
fi

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found in PATH" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: 'docker compose' not available" >&2; exit 1; }

[[ -d "$APP_DIR" ]] || { echo "ERROR: app dir not found: $APP_DIR" >&2; exit 1; }
[[ -d "$RELEASE_DIR" ]] || { echo "ERROR: release dir not found: $RELEASE_DIR" >&2; exit 1; }

# Required current install files
[[ -f "$APP_DIR/docker-compose.yml" ]] || { echo "ERROR: missing $APP_DIR/docker-compose.yml" >&2; exit 1; }
[[ -f "$APP_DIR/.env" ]] || { echo "ERROR: missing $APP_DIR/.env" >&2; exit 1; }
[[ -f "$APP_DIR/nginx/nginx.template" ]] || { echo "ERROR: missing $APP_DIR/nginx/nginx.template" >&2; exit 1; }

# Required release files (guard rails)
[[ -f "$RELEASE_DIR/docker-compose.yml" ]] || { echo "ERROR: release missing docker-compose.yml in $RELEASE_DIR" >&2; exit 1; }
[[ -f "$RELEASE_DIR/nginx/reloader.sh" ]] || { echo "ERROR: release missing nginx/reloader.sh in $RELEASE_DIR" >&2; exit 1; }
[[ -f "$RELEASE_DIR/scripts/swirl-load.sh" ]] || { echo "ERROR: release missing scripts/swirl-load.sh in $RELEASE_DIR" >&2; exit 1; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$MANIFEST" ]]; then
  MANIFEST="$SCRIPT_DIR/manifest.copy.txt"
fi
[[ -f "$MANIFEST" ]] || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 1; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    eval "$@"
  fi
}

# Set or append KEY=VALUE in a .env file (VALUE may include quotes if desired)
set_env_kv() {
  local file="$1" key="$2" val="$3"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] (would set $key=$val in $file)"
    return 0
  fi

  if grep -qE "^${key}=" "$file"; then
    KEY="$key" VAL="$val" perl -0777 -i -pe '
      my $k = $ENV{KEY};
      my $v = $ENV{VAL};
      s/^\Q$k\E=.*/$k=$v/m;
    ' "$file"
  else
    printf '%s\n' "${key}=${val}" >> "$file"
  fi
}


# Snapshot dir
TS="$(date +%Y%m%d-%H%M%S)"
SNAP_DIR="$APP_DIR/rollback/4.4.0.0-to-4.4.1.1-$TS"
LAST_FILE="$APP_DIR/rollback/LAST"

echo "==> App dir        : $APP_DIR"
echo "==> Release dir    : $RELEASE_DIR"
echo "==> Manifest       : $MANIFEST"
echo "==> Snapshot       : $SNAP_DIR"
echo "==> Dry-run        : $DRY_RUN"
echo "==> Set versions   : $SET_VERSIONS (SWIRL=$NEW_SWIRL_VERSION TIKA=$NEW_TIKA_VERSION TTM=$NEW_TTM_VERSION)"
echo "==> Pull images    : $DO_PULL"
echo

# Create snapshot
run "mkdir -p '$SNAP_DIR'"

# Preserve site-local files
run "cp -a '$APP_DIR/.env' '$SNAP_DIR/.env'"
run "mkdir -p '$SNAP_DIR/nginx'"
run "cp -a '$APP_DIR/nginx/nginx.template' '$SNAP_DIR/nginx/nginx.template'"

# Backup current managed files if they exist
backup_if_exists() {
  local rel="$1"
  local src="$APP_DIR/$rel"
  local dst="$SNAP_DIR/$rel"
  if [[ -e "$src" ]]; then
    run "mkdir -p '$(dirname "$dst")'"
    run "cp -a '$src' '$dst'"
  fi
}

backup_if_exists "docker-compose.yml"
backup_if_exists "Makefile"
backup_if_exists "certbot/docker-entrypoint.sh"
backup_if_exists "nginx/docker-entrypoint.sh"
backup_if_exists "nginx/reloader.sh"
backup_if_exists "scripts"

# Headless-safe docker config for pulls (avoids secretservice / dbus / X11 helpers)
ensure_headless_docker_config() {
  local tmp_cfg="$1"
  mkdir -p "$tmp_cfg"

  # Minimal config: do NOT set credsStore.
  # If you need auth, do docker login with --password-stdin (see below).
  cat > "$tmp_cfg/config.json" <<'JSON'
{
  "auths": {}
}
JSON
}

pull_images_headless_safe() {
  local app_dir="$1"
  local tmp_cfg
  tmp_cfg="$(mktemp -d /tmp/docker-config.XXXXXX)"

  ensure_headless_docker_config "$tmp_cfg"

  # Run pull using the temporary DOCKER_CONFIG
  # Note: if install-docker-images.sh runs `docker compose pull`, this will apply.
  dpkg -r --ignore-depends=golang-docker-credential-helpers golang-docker-credential-helpers

  (export DOCKER_CONFIG="$tmp_cfg"; cd "$app_dir"; bash ./scripts/install-docker-images.sh)

  rm -rf "$tmp_cfg"
}


# Capture runtime state
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] (would capture docker compose ps + docker images --digests)"
else
  (cd "$APP_DIR" && docker compose ps > "$SNAP_DIR/compose-ps.txt" 2>/dev/null) || true
  docker images --digests > "$SNAP_DIR/docker-images.txt" || true
fi

run "mkdir -p '$(dirname "$LAST_FILE")'"
run "printf '%s\n' '$SNAP_DIR' > '$LAST_FILE'"

echo "==> Snapshot complete."

# Create new required dirs (compose diff)
run "mkdir -p '$APP_DIR/certbot/conf' '$APP_DIR/certbot/www' '$APP_DIR/certbot/run' '$APP_DIR/certbot/work' '$APP_DIR/certbot/logs'"

# Copy managed files from release
echo "==> Copying managed files from release into app dir..."
while IFS= read -r rel || [[ -n "$rel" ]]; do
  # skip blanks and comments
  [[ -z "$rel" ]] && continue
  [[ "$rel" =~ ^[[:space:]]*# ]] && continue

  src="$RELEASE_DIR/$rel"
  dst="$APP_DIR/$rel"

  # Hard safety: never overwrite these via manifest
  if [[ "$rel" == ".env" || "$rel" == "nginx/nginx.template" ]]; then
    echo "WARN: manifest contains preserved file '$rel'; skipping"
    continue
  fi

  if [[ ! -e "$src" ]]; then
    echo "WARN: missing in release (skipping): $rel"
    continue
  fi

  run "mkdir -p '$(dirname "$dst")'"
  run "cp -a '$src' '$dst'"
done < "$MANIFEST"

# Belt-and-suspenders restore of preserved files
echo "==> Restoring preserved files (.env, nginx/nginx.template)..."
run "cp -a '$SNAP_DIR/.env' '$APP_DIR/.env'"
run "cp -a '$SNAP_DIR/nginx/nginx.template' '$APP_DIR/nginx/nginx.template'"

# Update image versions in .env (in-place)
if [[ "$SET_VERSIONS" -eq 1 ]]; then
  echo "==> Updating image versions in $APP_DIR/.env ..."
  set_env_kv "$APP_DIR/.env" "SWIRL_PATH" "$NEW_SWIRL_PATH"
  set_env_kv "$APP_DIR/.env" "SWIRL_VERSION" "$NEW_SWIRL_VERSION"
  set_env_kv "$APP_DIR/.env" "TIKA_VERSION"  "$NEW_TIKA_VERSION"
  set_env_kv "$APP_DIR/.env" "TTM_VERSION"   "$NEW_TTM_VERSION"
fi

# Validate compose config
echo "==> Validating docker compose config..."
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] (would run: cd '$APP_DIR' && docker compose -f docker-compose.yml config)"
else
  (cd "$APP_DIR" && docker compose -f docker-compose.yml config >/tmp/swirl.compose.rendered.yml)
fi

# Optional env key check (warn only): compare env.example vs .env
if [[ -f "$APP_DIR/env.example" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] (would check env keys: env.example vs .env)"
  else
    EX_KEYS="$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$APP_DIR/env.example" | sed 's/=.*//' | sort -u || true)"
    LIVE_KEYS="$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$APP_DIR/.env" | sed 's/=.*//' | sort -u || true)"
    MISSING="$(comm -23 <(printf '%s\n' "$EX_KEYS") <(printf '%s\n' "$LIVE_KEYS") || true)"
    if [[ -n "$MISSING" ]]; then
      echo "WARN: .env is missing keys present in env.example:"
      echo "$MISSING" | sed 's/^/  - /'
      echo "WARN: upgrade will continue, but you may need to add these to .env if required."
    fi
  fi
fi

# Pull images using the project's helper (sources .env and pulls for active profiles)
if [[ "$DO_PULL" -eq 1 ]]; then
  echo "==> Pulling images (headless-safe)..."
  if [[ ! -f "$APP_DIR/scripts/install-docker-images.sh" ]]; then
    echo "WARN: $APP_DIR/scripts/install-docker-images.sh not found; falling back to docker compose pull"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] (would run: cd '$APP_DIR' && docker compose pull)"
    else
      (cd "$APP_DIR" && docker compose pull)
    fi
  else
    pull_images_headless_safe "$APP_DIR"
  fi
fi

# Apply upgrade (safe ordering due to compose changes)
echo "==> Applying upgrade (docker compose up)..."

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] (would run: cd '$APP_DIR' && docker compose --profile nginx --profile certbot up -d nginx certbot nginx_reloader)"
  echo "[dry-run] (would run: cd '$APP_DIR' && docker compose --profile db --profile redis --profile svc up -d)"
  echo "[dry-run] (would run: cd '$APP_DIR' && docker compose run --rm swirl-init)"
  echo "[dry-run] (would run: cd '$APP_DIR' && docker compose up -d swirl)"
else
  cd "$APP_DIR"

  # Bring up edge first
  docker compose --profile nginx --profile certbot up -d nginx certbot nginx_reloader

  # Bring up core services
  docker compose --profile db --profile redis --profile svc up -d

  # Run migrations explicitly (idempotent)
  docker compose run --rm swirl-init

  # Ensure swirl is up (depends_on should handle ordering)
  docker compose up -d swirl

  echo "==> Upgrade applied."
  echo
  docker compose ps
  echo
  echo "Next checks:"
  echo "  docker logs swirl_app_init --tail=200"
  echo "  docker logs swirl_app      --tail=200"
  echo "  docker logs swirl_nginx    --tail=200"
fi
