#!/bin/sh

echo "Starting Envsubst"
envsubst '${SWIRL_FQDN}' < /etc/nginx/nginx.template > /etc/nginx/nginx.conf

if [ "$USE_TLS" = "true" ] && [ "$USE_CERT" = "false" ]; then
  echo "TLS is enabled and USE_CERT is false. Monitoring certificate directory for changes."
  
  PREVIOUS_STATE=$(find /etc/letsencrypt/live -type f -exec stat --format '%n %Y' {} \;)

  while true; do
    sleep 5
    CURRENT_STATE=$(find /etc/letsencrypt/live -type f -exec stat --format '%n %Y' {} \;)

    if [ "$PREVIOUS_STATE" != "$CURRENT_STATE" ]; then
      echo "Change detected, reloading Nginx..."
      nginx -s reload
      PREVIOUS_STATE=$CURRENT_STATE
    fi
  done &
elif [ "$USE_TLS" = "true" ] && [ "$USE_CERT" = "true" ]; then
  echo "TLS is enabled and USE_CERT is true. Using provided certificates."
else
  echo "TLS is not enabled. Skipping certificate monitoring."
fi

nginx -g 'daemon off;'