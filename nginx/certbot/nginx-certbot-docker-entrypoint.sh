#!/bin/sh

set -e

STATUS_DIR="/app/nginx/certbot"
STATUS_FILE="$STATUS_DIR/health"

# Ensure the status directory exists
mkdir -p "$STATUS_DIR"

# Logging helper
info() {
  echo "[INFO] $1"
}

# Liveness update function
update_liveness() {
  local status=${1:-healthy}
  info "Updating liveness to $status"
  echo "$status" > "$STATUS_FILE"
}

# Cleanup function on exit
cleanup() {
  info "Cleaning up liveness file"
  rm -f "$STATUS_FILE"
  exit
}

# Trap SIGTERM signal to allow graceful shutdown
trap cleanup TERM INT EXIT

# Define sleep duration depending on OS (macOS `sleep` uses seconds, just like Linux)
SLEEP_DURATION="43200"  # 12 hours in seconds

while true; do
  certbot renew --no-random-sleep-on-renew --config-dir /app/nginx/certbot/conf
  
  # Update liveness after each renewal attempt
  update_liveness "healthy"
  
  sleep "$SLEEP_DURATION"
done
