#!/bin/bash
set -e  # Exit the script immediately if any command fails

# Helper function to update fields in the config JSON using jq
function update_json() {
  local file=$1
  local jq_filter=$2
  local tmp_file
  tmp_file=$(mktemp)

  # Apply the jq update and overwrite the original file
  jq "$jq_filter" "$file" > "$tmp_file" && mv "$tmp_file" "$file"
}

echo "Setting up swirl"

# Remove any existing swirl configuration directory
rm -rf .swirl

# If the system uses APT (i.e., Ubuntu/Debian), update package list and install curl
if command -v apt &>/dev/null; then
  apt update
  apt-get install -y curl
fi

# Collect Django static files and clear any previous ones
python manage.py collectstatic --noinput --clear

# Set Elasticsearch version, default to 8 if not provided
es_version=${SWIRL_ES_VERSION:-8}
if [ "$es_version" -eq 7 ]; then
  echo "Installing ES version 7"
  # If version is 7, uninstall default ES client and install specific compatible version
  pip uninstall elasticsearch --yes
  pip install elasticsearch==7.10.1
fi

echo "msal and oauth config loading"

# Create the API config directory if it doesn't exist
CONFIG_DIR="/app/static/api/config"
mkdir -p "$CONFIG_DIR"

# Define the path for the default config file
DEFAULT_CONFIG="$CONFIG_DIR/default"

# Extract only the "default" part from the JSON configuration
jq '.default' /app/config-swirl-demo.db.json > "$DEFAULT_CONFIG"

# Apply environment variables to specific fields in the config JSON
update_json "$DEFAULT_CONFIG" '.msalConfig.auth.redirectUri = "'"$MSAL_AUTH_REDIRECT_URI"'"'
update_json "$DEFAULT_CONFIG" '.msalConfig.auth.clientId = "'"$MSAL_AUTH_CLIENT_ID"'"'
update_json "$DEFAULT_CONFIG" '.msalConfig.auth.authority = "'"$MSAL_AUTH_AUTHORITY"'"'
update_json "$DEFAULT_CONFIG" '.oauthConfig.issuer = "'"$OAUTH_CONFIG_ISSUER"'"'
update_json "$DEFAULT_CONFIG" '.oauthConfig.redirectUri = "'"$OAUTH_CONFIG_REDIRECT_URI"'"'
update_json "$DEFAULT_CONFIG" '.oauthConfig.clientId = "'"$OAUTH_CONFIG_CLIENT_ID"'"'
update_json "$DEFAULT_CONFIG" '.oauthConfig.tokenEndpoint = "'"$OAUTH_CONFIG_TOKEN_ENDPOINT"'"'
update_json "$DEFAULT_CONFIG" '.webSocketConfig.url = "'"$WEBSOCKET_URL"'"'
update_json "$DEFAULT_CONFIG" '.webSocketConfig.timeout = "'"$WEBSOCKET_TIMEOUT"'"'
update_json "$DEFAULT_CONFIG" '.shouldUseTokenFromOauth = true'
update_json "$DEFAULT_CONFIG" '.swirlBaseURL = "http://localhost/swirl"'  # CHANGE_ME if deploying elsewhere

echo "msal and oauth config loading completed"

# Wait for other services to initialize (e.g., database, search engines)
sleep 30

echo "Starting swirl"

# Start background workers and the Daphne web server
python swirl.py -d start celery-worker celery-healthcheck-worker celery-beats && \
daphne -b 0.0.0.0 -p 8000 swirl_server.asgi:application
