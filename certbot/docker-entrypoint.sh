#!/bin/sh

set -e

STATUS_DIR="/etc/certbot"
STATUS_FILE="$STATUS_DIR/health"

# Ensure the status directory exists
mkdir -p "$STATUS_DIR"

# Logging helper
info() {
  echo "[INFO] $1"
}

error() {
    echo "[ERROR] $1"
}

# Liveness update function
update_liveness() {
  local status=${1:-healthy}
  info "Updating liveness to $status"
  echo "$status" > "$STATUS_FILE"
}

if [ "$USE_CERT" = "true" ]; then
  echo "Using owned certificate. Not starting Certbot service."
else
  echo "Certbot is enabled. Starting the service..."

  while true; do
    certbot renew --no-random-sleep-on-renew --config-dir /certbot/conf

    # Update liveness after each renewal attempt
    update_liveness "healthy"

    sleep 12h
  done
fi