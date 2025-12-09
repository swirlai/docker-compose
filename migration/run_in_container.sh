#!/usr/bin/env bash

set -euo pipefail

PROG="$(basename "$0")"

IMAGE_TAG="${1:-}"
PHASE="${2:-}"
NETWORK="${3:-docker-compose-internal_default}"

if [[ -z "$IMAGE_TAG" || -z "$PHASE" ]]; then
  echo "Usage: $PROG IMAGE_TAG {extract|translate|load} [NETWORK_NAME]"
  exit 1
fi

case "$PHASE" in
  extract|translate|load) ;;
  *)
    echo $PROG "Invalid phase: $PHASE (expected: extract, translate, load)"
    exit 1
    ;;
esac

echo $PROG "Running migration phase '$PHASE' in container using image '$IMAGE_TAG' on network '$NETWORK'"

sudo docker run --rm \
--network "$NETWORK" \
-v /app/migration:/app/migration \
-v /app/.env:/app/migration/.env.host \
"$IMAGE_TAG" \
bash -lc 'set -a; source /app/migration/.env.host; set +a; cd /app && ./migration/'"${PHASE}"'.sh'
