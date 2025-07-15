#!/bin/bash
set -e  # Exit the script immediately if any command fails

echo "Setting up swirl"

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
python swirl.py start celery-worker celery-healthcheck-worker celery-beats && daphne -b 0.0.0.0 -p 8000 swirl_server.asgi:application;
