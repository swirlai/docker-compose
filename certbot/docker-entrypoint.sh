#!/bin/sh
#
# certbot-entrypoint.sh
#
# Function:
# ----------
# Runs Certbot inside a container for:
#   1) Initial certificate issuance (HTTP-01 via nginx webroot), and
#   2) Periodic renewals.
#
# Trigger / Integration:
# ----------------------
# - Uses webroot: /var/www/certbot (shared with nginx) for HTTP-01 challenges.
# - Signals nginx reloads by touching: /var/run/certbot/nginx-reload
#   (consumed by the nginx_reloader container via inotify).
#
# Startup Behavior:
# -----------------
# - If USE_CERT=true: certbot is disabled (owned certificates are used) and this
#   container stays alive for healthcheck stability.
# - Validates required env: SWIRL_FQDN and CERTBOT_EMAIL.
# - If no existing renewal config is found, waits for nginx to serve the ACME
#   challenge path and performs initial issuance.
#
# Renewal Behavior:
# -----------------
# - Runs `certbot renew` in a loop (default interval: 12h).
# - On successful deploy, touches the reload signal file via deploy-hook.
# - Updates a simple liveness file at /etc/certbot/health for docker healthcheck.
#
# Environment Knobs:
# ------------------
# - CERTBOT_STAGING=true
#     Use Let's Encrypt staging CA (untrusted certs; safe for repeated tests).
# - CERTBOT_RENEW_TEST=true
#     Runs renew in test mode (`--dry-run -v`) and forces a reload signal each loop.
# - CERTBOT_RENEW_INTERVAL_SECONDS=<N>
#     Overrides sleep interval between renewal attempts (default: 43200 = 12h).
#
# Volumes / Paths:
# ---------------
# - /certbot/conf  : Certbot config + certificates (persisted)
# - /certbot/work  : Certbot work dir
# - /certbot/logs  : Certbot logs dir
# - /var/www/certbot: ACME webroot (shared with nginx)
# - /var/run/certbot: Reload signal (shared with nginx_reloader)
#
# Troubleshooting:
# ----------------
# - Initial issuance stuck:
#     Check nginx serves the ACME path:
#       http://nginx/.well-known/acme-challenge/_healthcheck
# - Renew not reloading nginx:
#     Confirm deploy-hook touched /var/run/certbot/nginx-reload and review
#     nginx_reloader logs.
# - Rate limits:
#     Use CERTBOT_STAGING=true for testing/iteration.
#

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

staging_args() {
  if [ "${CERTBOT_STAGING:-false}" = "true" ]; then
    echo "--staging"
  fi
}

cert_name() {
  echo "${SWIRL_FQDN}"
}

have_cert() {
  CN="$(cert_name)"
  [ -n "$SWIRL_FQDN" ] && [ -f "$CONFIG_DIR/renewal/${CN}.conf" ]
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

  STAGING_ARGS="$(staging_args)"
  [ -n "$STAGING_ARGS" ] && info "Using Let's Encrypt STAGING environment."

  certbot certonly \
    $STAGING_ARGS \
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

SLEEP_SECS="${CERTBOT_RENEW_INTERVAL_SECONDS:-43200}"  # default: 12h

STAGING_ARGS="$(staging_args)"
if [ -n "$STAGING_ARGS" ]; then
  info "Using Let's Encrypt STAGING environment for renew."
fi

while true; do
  if [ "${CERTBOT_RENEW_TEST:-false}" = "true" ]; then
    info "TEST MODE: running certbot renew --dry-run every ${SLEEP_SECS}s"
    RENEW_EXTRA_ARGS="--dry-run -v"
  else
    info "Running: certbot renew"
    RENEW_EXTRA_ARGS="--quiet"
  fi

  set +e
  certbot renew \
    $STAGING_ARGS \
    --no-random-sleep-on-renew \
    --config-dir "$CONFIG_DIR" \
    --work-dir "$WORK_DIR" \
    --logs-dir "$LOGS_DIR" \
    $RENEW_EXTRA_ARGS \
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

  # In test mode, force the reload signal so you can exercise the reloader path
  # even when certbot decides no renewal is due.
  if [ "${CERTBOT_RENEW_TEST:-false}" = "true" ]; then
    date > "$RELOAD_FILE"
  fi

  sleep "$SLEEP_SECS"
done
