#!/bin/sh
set -e

STATUS_DIR="/etc/certbot"
STATUS_FILE="$STATUS_DIR/health"
RUN_DIR="/var/run/certbot"
RELOAD_FILE="$RUN_DIR/nginx-reload"

CONFIG_DIR="/certbot/conf"
WORK_DIR="/certbot/work"
LOGS_DIR="/certbot/logs"
WEBROOT_DIR="/var/www/certbot"

mkdir -p "$STATUS_DIR" "$RUN_DIR" "$CONFIG_DIR" "$WORK_DIR" "$LOGS_DIR" "$WEBROOT_DIR"
touch "$RELOAD_FILE" 2>/dev/null || true

info()  { echo "[INFO] $1"; }
error() { echo "[ERROR] $1"; }

update_liveness() {
  status=${1:-healthy}
  info "Updating liveness to $status"
  echo "$status" > "$STATUS_FILE"
}

# Start state immediately
update_liveness "starting"

if [ "$USE_CERT" = "true" ]; then
  info "Using owned certificate. Not starting Certbot service."
  update_liveness "healthy"
  tail -f /dev/null
fi

if [ -z "$SWIRL_FQDN" ] || [ -z "$CERTBOT_EMAIL" ]; then
  error "SWIRL_FQDN and CERTBOT_EMAIL must be set."
  update_liveness "unhealthy"
  exit 1
fi


# ---- helpers ----

have_cert() {
  [ -n "$SWIRL_FQDN" ] && \
  [ -f "$CONFIG_DIR/live/$SWIRL_FQDN/fullchain.pem" ] && \
  [ -f "$CONFIG_DIR/live/$SWIRL_FQDN/privkey.pem" ]
}

wait_for_nginx_acme() {
  testfile="$WEBROOT_DIR/.well-known/acme-challenge/_healthcheck"
  mkdir -p "$(dirname "$testfile")"
  echo "ok" > "$testfile"

  info "Waiting for nginx to serve ACME challenge path for $SWIRL_FQDN..."
  i=0
  while [ $i -lt 60 ]; do
    # Prefer internal service name (nginx) first
    if python3 - "$@" <<'PY' 2>/dev/null; then
import sys, urllib.request
for url in [
  "http://nginx/.well-known/acme-challenge/_healthcheck",
]:
  try:
    with urllib.request.urlopen(url, timeout=2) as r:
      if r.read().decode("utf-8", "ignore").strip() == "ok":
        sys.exit(0)
  except Exception:
    pass
sys.exit(1)
PY
      info "nginx ACME path reachable via http://nginx/ ..."
      return 0
    fi

    # Also try via fqdn to catch DNS/public routing issues (optional but useful)
    if python3 - "$@" <<PY 2>/dev/null; then
import sys, urllib.request
url = "http://${SWIRL_FQDN}/.well-known/acme-challenge/_healthcheck"
try:
  with urllib.request.urlopen(url, timeout=2) as r:
    if r.read().decode("utf-8", "ignore").strip() == "ok":
      sys.exit(0)
except Exception:
  pass
sys.exit(1)
PY
      info "nginx ACME path reachable via http://$SWIRL_FQDN/ ..."
      return 0
    fi

    i=$((i+1))
    sleep 2
  done

  error "Timed out waiting for nginx ACME path readiness."
  return 1
}

issue_cert_webroot() {
  info "Issuing certificate for $SWIRL_FQDN via webroot..."
  certbot certonly \
    --webroot -w "$WEBROOT_DIR" \
    --email "$CERTBOT_EMAIL" \
    --agree-tos --no-eff-email \
    -d "$SWIRL_FQDN" \
    --config-dir "$CONFIG_DIR" \
    --work-dir "$WORK_DIR" \
    --logs-dir "$LOGS_DIR" \
    --cert-name "$SWIRL_FQDN" \
    --keep-until-expiring \
    --non-interactive
}

# ---- initial issuance ----

update_liveness "healthy"

if ! have_cert; then
  wait_for_nginx_acme
  issue_cert_webroot
  info "Initial certificate issued."
  # Trigger nginx reload (your watcher can pick this up)
  date > "$RELOAD_FILE"
else
  info "Certificate already present for $SWIRL_FQDN; skipping initial issuance."
fi

# ---- renew loop ----

while true; do
  info "Running: certbot renew"

  set +e
  certbot renew \
    --no-random-sleep-on-renew \
    --config-dir "$CONFIG_DIR" \
    --work-dir "$WORK_DIR" \
    --logs-dir "$LOGS_DIR" \
    --quiet \
    --deploy-hook "date > $RELOAD_FILE"
  rc=$?
  set -e

  if [ "$rc" -eq 0 ]; then
    update_liveness "healthy"
    info "certbot renew completed successfully."
  else
    error "certbot renew failed (exit code $rc). See $LOGS_DIR/letsencrypt.log"
    update_liveness "unhealthy"
  fi

  sleep 12h
done
