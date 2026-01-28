#!/bin/bash
#
# swirl-service.sh
#
# Purpose:
#   Host-side preflight and startup wrapper for the SWIRL Docker Compose stack.
#   Runs before any containers start. Prepares templates, selects Nginx mode,
#   starts optional dependencies, then executes `docker compose up`.
#
# Responsibilities:
#   - Ensure .env exists (copy from env.example on first run)
#   - Load configuration and shared helpers
#   - Stop any previously running stack containers
#   - Optionally start local Postgres first (db profile)
#   - Render/select the correct nginx.template based on TLS / cert mode:
#       * Notls template
#       * Bootstrap HTTP template (until cert exists)
#       * TLS template (certbot-managed or owned cert)
#   - Enable one-time setup job profile on first run
#   - Start the stack with the computed Compose profiles
#
# Notes:
#   - Certificate issuance and renewal are handled inside containers.
#   - This script only prepares host-mounted templates and directories.
#

set -e

# Stage label used in log output (safe default)
STAGE="${STAGE:-swirl-service}"

# Disable X11 for GUI apps to avoid DBUS-related issues
export DBUS_SESSION_BUS_ADDRESS=/dev/null

# Find full path to Docker binary
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export DOCKER_BIN="$(command -v docker)"

# Logging function
log() {
  echo "[$(date +%Y-%m-%dT%H:%M:%S) ${STAGE}] $1"
}

# Error logging function
error() {
  echo "[$(date +%Y-%m-%dT%H:%M:%S) ${STAGE} ERROR] $1"
}

# Ensure log directory exists and redirect output to log file
if [[ "$OSTYPE" == "darwin"* ]]; then
  LOG_DIR="$HOME/Library/Logs/swirl"
  log "Creating base log directory for MacOS: $LOG_DIR"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  LOG_DIR="/var/log/swirl"
  log "Creating base log directory for Linux: $LOG_DIR"
else
  # Best-effort fallback
  LOG_DIR="${LOG_DIR:-/var/log/swirl}"
  log "Unknown OSTYPE '$OSTYPE'; using log directory: $LOG_DIR"
fi

mkdir -p "$LOG_DIR"
log "Log directory successfully created."
exec > >(tee -a "$LOG_DIR/swirl.log") 2>&1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log "Script directory: $SCRIPT_DIR"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
log "Parent directory: $PARENT_DIR"

ENV_FILE="$PARENT_DIR/.env"
EXAMPLE_ENV_FILE="$PARENT_DIR/env.example"

# Create .env file from example if not present
if [ ! -f "$ENV_FILE" ]; then
  log ".env file does not exist. Copying $EXAMPLE_ENV_FILE to $ENV_FILE..."

  if [ -f "$EXAMPLE_ENV_FILE" ]; then
    cp "$EXAMPLE_ENV_FILE" "$ENV_FILE"
    log ".env file created successfully."
  else
    error "env.example file not found. Cannot create .env file."
    exit 1
  fi
else
  log ".env file already exists."
fi

# Load environment variables from .env
# shellcheck disable=SC1090
source "$ENV_FILE"
# shellcheck disable=SC1090
source "$PARENT_DIR/scripts/swirl-shared.sh"

# Default boolean flags (avoid surprises if unset)
USE_LOCAL_POSTGRES="${USE_LOCAL_POSTGRES:-false}"
USE_NGINX="${USE_NGINX:-false}"
USE_TLS="${USE_TLS:-false}"
USE_CERT="${USE_CERT:-false}"

# Check Properly Configured Environment Variables
if [ -z "${SWIRL_FQDN:-}" ]; then
  error "SWIRL_FQDN is not set in .env file. Please set it to your domain name."
  exit 1
fi

if [ -z "${SWIRL_VERSION:-}" ] || [ -z "${TIKA_VERSION:-}" ] || [ -z "${TTM_VERSION:-}" ]; then
  error "SWIRL_VERSION, TIKA_VERSION, and TTM_VERSION must all be set in .env file."
  exit 1
fi

COMPOSE_FILE="$PARENT_DIR/docker-compose.yml"

# Stop previously running SWIRL containers
log "Stopping any SWIRL containers from previous run"
"${DOCKER_BIN}" compose -f "$COMPOSE_FILE" --profile all stop

# Conditionally add local Postgres
if [ "$USE_LOCAL_POSTGRES" = "true" ]; then
  log "Local Postgres is enabled. Starting service."
  (COMPOSE_PROFILES=db "${DOCKER_BIN}" compose -f "$COMPOSE_FILE" up --pull never -d)
  log "Started local Postgres service."
  sleep 15
fi

# Conditionally add Nginx and Certbot
if [ "$USE_NGINX" = "true" ]; then
  if [ "$USE_TLS" = "true" ]; then
    if [ "$USE_CERT" = "false" ]; then
      log "TLS enabled with Certbot. Selecting Nginx template (cert issuance/renewal handled by certbot container)."

      TEMPLATE_FILE="$PARENT_DIR/nginx/nginx-template.tls"
      UPDATE_MARKER="# swirl-service updated: USE_TLS=true, USE_CERT=false"

      if ! grep -Fq "$UPDATE_MARKER" "$TEMPLATE_FILE"; then
        log "Update Marker not found; ensuring TLS + ACME configuration exists in ${TEMPLATE_FILE}"
        log "NOTE: nginx templates assume 'listen ...' and 'server_name ...' lines are adjacent for injection."

        tmp="$(mktemp)"
        awk -v update_marker="$UPDATE_MARKER" '
        {
          if ($0 ~ /\/\.well-known\/acme-challenge\//) acme_seen = 1

          # Inject TLS directives after server_name line following a 443 listen line
          if (prev ~ /listen[[:space:]]+443[[:space:]]+ssl;/ && $0 ~ /server_name[[:space:]].*;/) {
            print
            print ""
            print "      " update_marker
            print "      ssl_certificate /etc/letsencrypt/live/${SWIRL_FQDN}/fullchain.pem;"
            print "      ssl_certificate_key /etc/letsencrypt/live/${SWIRL_FQDN}/privkey.pem;"
            print "      include /etc/letsencrypt/options-ssl-nginx.conf;"
            print "      ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;"
            prev = $0
            next
          }

          # Ensure ACME challenge location exists in port-80 server block
          if (!acme_injected && !acme_seen &&
              prev ~ /listen[[:space:]]+80;/ &&
              $0 ~ /server_name[[:space:]].*;/) {

            print
            print ""
            print "      # swirl-service updated: add ACME webroot location"
            print "      location ^~ /.well-known/acme-challenge/ {"
            print "          root /var/www/certbot;"
            print "          default_type \"text/plain\";"
            print "          try_files $uri =404;"
            print "      }"
            acme_injected = 1
            prev = $0
            next
          }

          print
          prev = $0
        }
        ' "$TEMPLATE_FILE" > "$tmp" && mv "$tmp" "$TEMPLATE_FILE"
      fi

      CERT_LIVE_DIR="$PARENT_DIR/certbot/conf/live/$SWIRL_FQDN"
      if [ -f "$CERT_LIVE_DIR/fullchain.pem" ] && [ -f "$CERT_LIVE_DIR/privkey.pem" ]; then
        log "Cert files found; using TLS Nginx template."
        cp "$PARENT_DIR/nginx/nginx-template.tls" "$PARENT_DIR/nginx/nginx.template"
      else
        log "Cert files not found yet; using bootstrap HTTP Nginx template."
        cp "$PARENT_DIR/nginx/nginx-template.bootstrap" "$PARENT_DIR/nginx/nginx.template"
      fi

    else
      # USE_CERT == true
      log "TLS enabled with owned certificate. Selecting Nginx template (no certbot)."

      CERT_PATH="$PARENT_DIR/nginx/certificates/ssl/${SWIRL_FQDN}"
      if [ -f "$CERT_PATH/ssl_certificate.crt" ] && [ -f "$CERT_PATH/ssl_certificate_key.key" ]; then
        log "Found owned certificate and key in '${CERT_PATH}'"

        TEMPLATE_FILE="$PARENT_DIR/nginx/nginx-template.tls"
        UPDATE_MARKER="# swirl-service updated: USE_TLS=true, USE_CERT=true"

        if ! grep -Fq "$UPDATE_MARKER" "$TEMPLATE_FILE"; then
          log "Update Marker not found; updating Nginx template with owned certificate paths."
          tmp="$(mktemp)"
          awk -v update_marker="$UPDATE_MARKER" '
          {
            if (prev ~ /listen[[:space:]]+443[[:space:]]+ssl;/ && $0 ~ /server_name[[:space:]].*;/) {
              print
              print ""
              print "      " update_marker
              print "      ssl_certificate /etc/nginx/ssl/${SWIRL_FQDN}/ssl_certificate.crt;"
              print "      ssl_certificate_key /etc/nginx/ssl/${SWIRL_FQDN}/ssl_certificate_key.key;"
              prev = $0
              next
            }
            print
            prev = $0
          }
          ' "$TEMPLATE_FILE" > "$tmp" && mv "$tmp" "$TEMPLATE_FILE"
        else
          log "Nginx template already contains the owned certificate paths."
        fi

        cp "$PARENT_DIR/nginx/nginx-template.tls" "$PARENT_DIR/nginx/nginx.template"
      else
        error "Certificate or key not found in '${CERT_PATH}'."
        # Proceeding would start nginx with missing TLS assets; fail fast.
        exit 1
      fi
    fi

  else
    log "TLS is disabled. Using non-TLS Nginx template."
    cp "$PARENT_DIR/nginx/nginx-template.notls" "$PARENT_DIR/nginx/nginx.template"
  fi
else
  log "USE_NGINX is false. Nginx will not be started; using non-TLS template for consistency."
  cp "$PARENT_DIR/nginx/nginx-template.notls" "$PARENT_DIR/nginx/nginx.template"
fi

COMPOSE_PROFILES="$(get_active_profiles)"

# Final startup
log "Docker Compose Up with profiles: $COMPOSE_PROFILES"
COMPOSE_PROFILES="$COMPOSE_PROFILES" "${DOCKER_BIN}" compose -f "$COMPOSE_FILE" up --pull never
