#!/bin/sh
#
# nginx-reloader.sh
#
# Function:
# ----------
# Watches for a reload signal from the certbot container and safely reloads
# Nginx when certificates or TLS configuration change.
#
# Trigger:
# --------
# Certbot touches /var/run/certbot/nginx-reload after:
#   - Initial certificate issuance
#   - Successful certificate renewal
#
# Actions:
# --------
# 1. Waits for filesystem events on /var/run/certbot/nginx-reload (inotify).
# 2. Checks whether TLS certificates exist inside the Nginx container.
# 3. If certificates are present:
#      - Switches nginx.template to the TLS template.
# 4. Validates the Nginx configuration (nginx -t).
# 5. Reloads Nginx in-place (no container restart).
#
# Guarantees:
# -----------
# - Nginx will not be reloaded with invalid configuration.
# - TLS configuration is only activated once certificates exist.
# - Safe for clean deployments and repeated reload events.
#
# Dependencies:
# -------------
# - Docker socket access (/var/run/docker.sock)
# - inotify-tools
# - docker-cli
# - Shared volumes:
#     * /nginx/nginx-template.tls
#     * /nginx/nginx.template
#     * /var/run/certbot/nginx-reload
#
# Environment:
# ------------
# - SWIRL_FQDN: Fully-qualified domain name for certificate validation.
#
# Notes:
# ------
# - This container does not manage certificates; it reacts to certbot signals.
# - All certificate issuance and renewal is handled by the certbot container.
#
# Intended Use:
# -------------
# Runs as the entrypoint for the nginx_reloader container.
#
#
# Troubleshooting:
# ----------------
# Reload not happening?
#   - Verify certbot touched the reload file:
#       ls -l /var/run/certbot/nginx-reload
#   - Check reloader logs for inotify events:
#       docker logs swirl_nginx_reloader
#
# Nginx fails to reload?
#   - Inspect config validation output:
#       docker exec swirl_nginx nginx -t
#   - Confirm nginx.template was switched correctly:
#       ls -l /nginx/nginx.template
#
# TLS not activating?
#   - Verify certificate files exist in the nginx container:
#       docker exec swirl_nginx ls -l /etc/letsencrypt/live/$SWIRL_FQDN
#   - Ensure certbot is writing to the expected config volume:
#       ls -l ./certbot/conf/live/
#
# Unexpected reload loops?
#   - Check for processes repeatedly touching nginx-reload.
#   - Confirm certbot renew interval is set correctly (default: 12h).
#
# Safe manual reload:
#   - Touch the reload signal to force a safe reload:
#       date > ./certbot/run/nginx-reload
#
# Last resort:
#   - Restart reloader container:
#       docker restart swirl_nginx_reloader
#

set -eu

echo "[reloader] installing deps..."
apk add --no-cache docker-cli inotify-tools

echo "[reloader] watching for /var/run/certbot/nginx-reload"
mkdir -p /var/run/certbot
touch /var/run/certbot/nginx-reload

# Paths inside this container (host-mounted nginx dir)
TLS_TEMPLATE="/nginx/nginx-template.tls"
ACTIVE_TEMPLATE="/nginx/nginx.template"

# Cert path inside nginx container (matches your nginx template + nginx mounts)
CERT_DIR="/etc/letsencrypt/live/${SWIRL_FQDN}"

while inotifywait -e close_write,create,move /var/run/certbot/nginx-reload; do
  echo "[reloader] reload signal detected"

  # If cert exists, switch the active template to TLS before reloading nginx
  if docker exec swirl_nginx sh -lc "[ -f '${CERT_DIR}/fullchain.pem' ] && [ -f '${CERT_DIR}/privkey.pem' ]"; then
    echo "[reloader] cert present; switching nginx.template -> TLS"
    cp -f "$TLS_TEMPLATE" "$ACTIVE_TEMPLATE"
  else
    echo "[reloader] cert not present; leaving nginx.template unchanged"
  fi

  echo "[reloader] validating nginx config..."
  docker exec swirl_nginx nginx -t
  docker exec swirl_nginx nginx -s reload
  echo "[reloader] nginx reloaded"
done
