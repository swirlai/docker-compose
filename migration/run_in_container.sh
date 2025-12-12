#!/usr/bin/env bash

set -euo pipefail

PROG="$(basename "$0")"

IMAGE_TAG="${1:-}"
PHASE="${2:-}"
NETWORK="${3:-docker-compose-internal_default}"

# Shift off the first three parameters so $@ contains only PHASE args
shift 3 || true

if [[ -z "$IMAGE_TAG" || -z "$PHASE" ]]; then
  echo "Usage: $PROG IMAGE_TAG {extract|translate|load} [NETWORK_NAME] [PHASE_ARGS...]"
  exit 1
fi

case "$PHASE" in
  extract|translate|load) ;;
  *)
    echo "$PROG Invalid phase: $PHASE (expected: extract, translate, load)"
    exit 1
    ;;
esac

echo "$PROG Running migration phase '$PHASE' in container"
echo "$PROG Image:   $IMAGE_TAG"
echo "$PROG Network: $NETWORK"
echo "$PROG Args to phase: $*"

sudo docker run --rm \
  --network "$NETWORK" \
  -v ./migration:/app/migration \
  -v ./.env:/app/migration/.env.host \
  "$IMAGE_TAG" \
  bash -lc 'set -euo pipefail
    set -a
    source /app/migration/.env.host
    set +a
    cd /app
    ./migration/'"$PHASE"'.sh "$@"' bash "$@"
