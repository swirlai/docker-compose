#!/bin/sh
#
# Wait for every container in the compose project to be healthy, then exit 0; exit 1 otherwise.
#
# Rules, per container (DS-5747):
#   - one-shot services (ONE_SHOT_SERVICES, default swirl_app_init swirl_app_job):
#                          exited 0 -> OK; exited non-zero -> FAIL; still running -> keep waiting
#   - has a healthcheck (read from the container config, so it counts before the first probe):
#                          healthy -> OK; unhealthy -> FAIL; otherwise keep waiting
#   - no healthcheck:      running -> OK; exited non-zero -> FAIL; created/starting -> keep waiting
#   - IGNORED_SERVICES:    optional space-separated container names to skip (none by default)
#   - anything still undecided at the deadline -> FAIL
#
# Each container is checked in a background job whose exit code is the result, collected with
# `wait` per PID. (The previous version set a status variable inside the background jobs, which
# never reaches the parent shell, so the script could not fail.)

# One-shot jobs (swirl_app_init, swirl_app_job) are judged by their exit code like everything else.
IGNORED_SERVICES="${IGNORED_SERVICES:-}"
ONE_SHOT_SERVICES="${ONE_SHOT_SERVICES:-swirl_app_init swirl_app_job}"
TIMEOUT_SECONDS=${HEALTH_TIMEOUT_SECONDS:-300}
POLL_SECONDS=10

END_TIME=$(( $(date +%s) + TIMEOUT_SECONDS ))

check_health() {
  CONTAINER="$1"
  CONTAINER_NAME="$2"

  for IGNORED_SERVICE in $IGNORED_SERVICES; do
    if [ "$CONTAINER_NAME" = "$IGNORED_SERVICE" ]; then
      echo "Service $CONTAINER_NAME is an ignored service. Skipping health checks."
      exit 0
    fi
  done

  HAS_HEALTHCHECK=$(docker inspect --format '{{if .Config.Healthcheck}}{{if ne (index .Config.Healthcheck.Test 0) "NONE"}}yes{{else}}no{{end}}{{else}}no{{end}}' "$CONTAINER" 2>/dev/null || echo "no")
  ONE_SHOT=no
  for ONE_SHOT_SERVICE in $ONE_SHOT_SERVICES; do
    [ "$CONTAINER_NAME" = "$ONE_SHOT_SERVICE" ] && ONE_SHOT=yes
  done

  while :; do
    STATUS=$(docker inspect --format '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "missing")
    EXIT_CODE=$(docker inspect --format '{{.State.ExitCode}}' "$CONTAINER" 2>/dev/null || echo 0)
    HEALTH=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$CONTAINER" 2>/dev/null || echo "")

    if [ "$STATUS" = "exited" ] || [ "$STATUS" = "dead" ] || [ "$STATUS" = "missing" ]; then
      if [ "$STATUS" = "exited" ] && [ "$EXIT_CODE" -eq 0 ]; then
        echo "Service $CONTAINER_NAME exited 0 (one-shot). OK."
        exit 0
      fi
      echo "Service $CONTAINER_NAME is $STATUS with exit code $EXIT_CODE. FAIL."
      exit 1
    fi

    if [ "$ONE_SHOT" = "yes" ]; then
      : # still running: a one-shot is only OK once it has exited 0
    elif [ "$HAS_HEALTHCHECK" = "yes" ]; then
      case "$HEALTH" in
        healthy)   echo "Service $CONTAINER_NAME became healthy."; exit 0 ;;
        unhealthy) echo "Service $CONTAINER_NAME is unhealthy. FAIL."; exit 1 ;;
      esac
    elif [ "$STATUS" = "running" ]; then
      echo "Service $CONTAINER_NAME is running (no healthcheck defined). OK."
      exit 0
    fi

    if [ "$(date +%s)" -ge "$END_TIME" ]; then
      echo "Service $CONTAINER_NAME did not become healthy within ${TIMEOUT_SECONDS}s (status=$STATUS health=${HEALTH:-none}). FAIL."
      exit 1
    fi
    sleep "$POLL_SECONDS"
  done
}

CONTAINERS=$(docker compose --profile all ps -aq)
if [ -z "$CONTAINERS" ]; then
  echo "Error: no containers found in the compose project."
  exit 1
fi

PIDS=""
NAMES=""
for CONTAINER in $CONTAINERS; do
  CONTAINER_NAME=$(docker inspect --format '{{.Name}}' "$CONTAINER" | sed 's#^/##')
  check_health "$CONTAINER" "$CONTAINER_NAME" &
  PIDS="$PIDS $!"
  NAMES="$NAMES $CONTAINER_NAME"
done

OVERALL_STATUS=0
FAILING_SERVICES=""
# shellcheck disable=SC2086  # intentional word split: one positional per container name
set -- $NAMES
for PID in $PIDS; do
  NAME=$1
  shift
  if ! wait "$PID"; then
    OVERALL_STATUS=1
    FAILING_SERVICES="$FAILING_SERVICES $NAME"
  fi
done

COUNT=$(echo "$NAMES" | wc -w | tr -d " ")
if [ "$OVERALL_STATUS" -eq 1 ]; then
  echo "Error: the following service(s) failed the health check:$FAILING_SERVICES"
else
  echo "All $COUNT services are healthy:$NAMES"
fi
exit "$OVERALL_STATUS"
