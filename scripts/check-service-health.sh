#!/bin/sh

# List of ignored services (space-separated string for POSIX compatibility)
IGNORED_SERVICES="swirl_app_job swirl_app_init"

# Initialize a variable to track the overall status
OVERALL_STATUS=0
FAILING_SERVICE=""

# Get a list of all containers
CONTAINERS=$(docker compose ps -q)

# Start the timer (5 minutes)
END_TIME=$(($(date +%s) + 300))

# Function to check health of a service
check_health() {
  CONTAINER="$1"
  CONTAINER_NAME="$2"

  # Check if container is in the ignored list
  for IGNORED_SERVICE in $IGNORED_SERVICES; do
    if [ "$CONTAINER_NAME" = "$IGNORED_SERVICE" ]; then
      echo "Service $CONTAINER_NAME is an ignored service. Skipping health checks..."
      exit 0
    fi
  done

  # Start checking health periodically
  while [ "$(date +%s)" -lt "$END_TIME" ]; do
    HEALTH=$(docker inspect --format '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo "")
    EXIT_CODE=$(docker inspect --format '{{.State.ExitCode}}' "$CONTAINER" 2>/dev/null || echo 0)

    if [ "$EXIT_CODE" -ne 0 ] && [ "$HEALTH" = "unhealthy" ]; then
      echo "Service $CONTAINER_NAME terminated with health issues (unhealthy)."
      OVERALL_STATUS=1
      FAILING_SERVICE="$CONTAINER_NAME"
      break
    elif [ "$HEALTH" = "healthy" ] && [ "$EXIT_CODE" -eq 0 ]; then
      echo "Service $CONTAINER_NAME became healthy."
      break
    elif [ "$(date +%s)" -ge "$END_TIME" ]; then
      echo "Service $CONTAINER_NAME did not become healthy after 5 minutes."
      OVERALL_STATUS=1
      FAILING_SERVICE="$CONTAINER_NAME"
      break
    fi

    sleep 10
  done
}

# Loop through each container and check health concurrently
for CONTAINER in $CONTAINERS; do
  CONTAINER_NAME=$(docker inspect --format '{{.Name}}' "$CONTAINER" | sed 's/\///g')

  # Run health check in background
  check_health "$CONTAINER" "$CONTAINER_NAME" &
done

# Wait for all background jobs to finish
wait

# Final status message
if [ "$OVERALL_STATUS" -eq 1 ]; then
  echo "Error: The following service caused the workflow to fail: $FAILING_SERVICE"
fi

# Exit with overall status
exit "$OVERALL_STATUS"
