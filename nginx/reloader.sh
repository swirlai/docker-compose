#!/bin/sh
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
