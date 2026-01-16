#!/bin/sh
set -e

echo "Starting Envsubst"
envsubst '${SWIRL_FQDN}' < /etc/nginx/nginx.template > /etc/nginx/nginx.conf

nginx -g 'daemon off;'
