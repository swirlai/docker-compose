#!/bin/bash
set -e  # Exit the script immediately if any command fails

echo "Setting up swirl"

# auto populating Variables
export PROTOCOL=${PROTOCOL:-http}
if [ -z "$PORT" ]; then
  export CSRF_TRUSTED_ORIGINS=${CSRF_TRUSTED_ORIGINS:-$PROTOCOL://$SWIRL_FQDN}
else
  export CSRF_TRUSTED_ORIGINS=${CSRF_TRUSTED_ORIGINS:-$PROTOCOL://$SWIRL_FQDN:$PORT}
fi

# if $SWIRL_FQDN is not in ALLOWED_HOSTS, add it
if [[ -z "$ALLOWED_HOSTS" ]]; then
  export ALLOWED_HOSTS=localhost,$SWIRL_FQDN
elif [[ ! "$ALLOWED_HOSTS" =~ (^|,)$SWIRL_FQDN(,|$) ]]; then
  export ALLOWED_HOSTS=$ALLOWED_HOSTS,$SWIRL_FQDN
fi

echo "SWIRL_FQDN is set to: $SWIRL_FQDN"
echo "ALLOWED_HOSTS is set to: $ALLOWED_HOSTS"
echo "CSRF_TRUSTED_ORIGINS is set to: $CSRF_TRUSTED_ORIGINS"



# Remove any existing swirl configuration directory
rm -rf .swirl

# Collect Django static files and clear any previous ones
python manage.py collectstatic --noinput --clear

# Set Elasticsearch version, default to 8 if not provided
es_version=${SWIRL_ES_VERSION:-8}
if [ "$es_version" -eq 7 ]; then
  echo "Installing ES version 7"
  # If version is 7, uninstall default ES client and install specific compatible version
  pip uninstall elasticsearch --yes
  pip install elasticsearch==7.17.12
fi

echo "msal and oauth config loading"

# Create the API config directory if it doesn't exist
CONFIG_DIR="/app/static/api/config"
mkdir -p "$CONFIG_DIR"

python swirl.py config_default_api_settings

echo "msal and oauth config loading completed"

# Wait for other services to initialize (e.g., database, search engines)
sleep 30

# Start background workers and the Daphne web server
echo "Starting swirl"
python swirl.py start celery-worker celery-healthcheck-worker celery-beats && daphne -b 0.0.0.0 -p ${SWIRL_PORT:-8000} swirl_server.asgi:application;
