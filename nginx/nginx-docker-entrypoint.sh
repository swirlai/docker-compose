#!/bin/sh

echo "Starting Envsubst"

# Check if TLS is enabled and apply the appropriate nginx config template
if [ "$USE_TLS" = "true" ]; then
    echo "Using TLS configuration template"
    envsubst '${DOMAIN_NAME}' < /etc/nginx/nginx-template.tls > /etc/nginx/nginx.conf
else
    echo "Using non-TLS configuration template"
    envsubst '${DOMAIN_NAME}' < /etc/nginx/nginx-template.notls > /etc/nginx/nginx.conf
fi

# Check if inotifywait is available (used to watch for certificate changes)
if ! command -v inotifywait &> /dev/null; then
  echo "inotifywait not found, attempting to install..."

  # macOS: suggest installing via brew, otherwise use apt on Ubuntu
  if echo "$OSTYPE" | grep -q "^darwin"; then
    if command -v brew &> /dev/null; then
      brew install inotify-tools
    else
      echo "Homebrew not found. Please install inotify-tools manually on macOS."
      exit 1
    fi
  elif command -v apt-get &> /dev/null; then
    apt-get update && apt-get install -y inotify-tools
  else
    echo "Unsupported system. Please install inotify-tools manually."
    exit 1
  fi
fi

echo "Starting Nginx"

# Start a background process that watches for certificate file changes and reloads Nginx
if echo "$OSTYPE" | grep -q "^darwin"; then
  echo "macOS detected: using fswatch instead of inotifywait"
  fswatch -o /etc/letsencrypt/live | while read; do
    echo "Detected certificate change, reloading Nginx..."
    nginx -s reload
  done & nginx -g 'daemon off;'
else
  while inotifywait -e modify,create,delete /etc/letsencrypt/live/*; do
    echo "Detected certificate change, reloading Nginx..."
    nginx -s reload
  done & nginx -g 'daemon off;'
fi
