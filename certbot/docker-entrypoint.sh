#!/bin/sh
set -e

STATUS_DIR="/etc/certbot"
STATUS_FILE="$STATUS_DIR/health"
RUN_DIR="/var/run/certbot"
RELOAD_FILE="$RUN_DIR/nginx-reload"

mkdir -p "$STATUS_DIR"

info()  { echo "[INFO] $1"; }
error() { echo "[ERROR] $1"; }

update_liveness() {
  status=${1:-healthy}
  info "Updating liveness to $status"
  echo "$status" > "$STATUS_FILE"
}

# Start state immediately (so healthcheck has a file to read)
update_liveness "starting"

# Ensure deploy-hook path exists (shared with nginx_reloader)
mkdir -p "$RUN_DIR"
# Ensure file exists; doesn't have to trigger the watcher yet
touch "$RELOAD_FILE" 2>/dev/null || true

if [ "$USE_CERT" = "true" ]; then
  info "Using owned certificate. Not starting Certbot service."
  update_liveness "healthy"
  # keep container alive so healthcheck stays green
  tail -f /dev/null
else
  info "Certbot is enabled. Starting the service..."
  update_liveness "healthy"

  while true; do
    info "Running: certbot renew"

    # Temporarily disable "exit on error" so a renew failure doesn't crash-loop the container
    set +e
    certbot renew \
      --no-random-sleep-on-renew \
      --config-dir /certbot/conf \
      --quiet \
      --deploy-hook "date > $RELOAD_FILE"
    rc=$?
    set -e

    if [ "$rc" -eq 0 ]; then
      update_liveness "healthy"
      info "certbot renew completed successfully."
    else
      error "certbot renew failed (exit code $rc). See /var/log/letsencrypt/letsencrypt.log"
      update_liveness "unhealthy"
    fi

    sleep 12h
  done
fi
