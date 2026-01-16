#!/bin/sh
#
# nginx-entrypoint.sh
#
# Function:
# ----------
# Generates the active Nginx configuration from a template and starts Nginx
# in the foreground.
#
# Behavior:
# ---------
# - Performs environment variable substitution on nginx.template
#   (currently SWIRL_FQDN).
# - Writes the rendered configuration to /etc/nginx/nginx.conf.
# - Starts Nginx with daemon mode disabled (container PID 1).
#
# Design Notes:
# -------------
# - No certificate logic lives here.
# - No reload or monitoring logic lives here.
# - TLS activation and reloads are handled externally by the certbot
#   and nginx_reloader containers.
#
# Intended Use:
# -------------
# Entry point for the nginx container.

set -e

echo "Starting Envsubst"
envsubst '${SWIRL_FQDN}' < /etc/nginx/nginx.template > /etc/nginx/nginx.conf

nginx -g 'daemon off;'
