#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Logging function
function log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${STAGE}] $1"
}

# Error logging function
function error() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${STAGE} ERROR] $1"
}

# Disable X11 for GUI apps to avoid DBUS-related issues
export DBUS_SESSION_BUS_ADDRESS=/dev/null

# Ensure log directory exists and redirect output to log file
mkdir -p /var/log/swirl
exec > >(tee -a /var/log/swirl/swirl.log) 2>&1

FLAG_FILE="./swirl_job.flag"
ENV_FILE="./.env"
EXAMPLE_ENV_FILE="/app/.env.example"

# Create .env file from example if not present
if [ ! -f "$ENV_FILE" ]; then
    log ".env file does not exist. Copying $EXAMPLE_ENV_FILE to $ENV_FILE..."

    if [ -f "$EXAMPLE_ENV_FILE" ]; then
        cp "$EXAMPLE_ENV_FILE" "$ENV_FILE"
        log ".env file created successfully."
    else
        error ".env.example file not found. Cannot create .env file."
        exit 1
    fi
else
    log ".env file already exists."
fi

# Load environment variables from .env
source "$ENV_FILE"

# Stop previously running swirl containers
log "Stopping any swirl containers from previous run"
docker compose --profile all stop || true

COMPOSE_PROFILES="svc"  # Base profile for Swirl services

# Conditionally add local Postgres
if [ "$USE_LOCAL_POSTGRES" = "true" ]; then
    log "Enabling local Postgres profile."
    COMPOSE_PROFILES="$COMPOSE_PROFILES,local-postgres"
fi

# Conditionally add Nginx
if [ "$USE_NGINX" = "true" ]; then
    log "Enabling Nginx profile."
    COMPOSE_PROFILES="$COMPOSE_PROFILES,nginx"
fi

# Handle TLS and Certbot setup
if [ "$USE_TLS" = "true" ] && [ ! -f "nginx/certbot/conf/live/$FQDN/privkey.pem" ]; then
    log "Issuing certificate using Certbot."
    log "Waiting DNS propagation..."
    sleep 300

    # Paths
    CERTBOT_SOURCE_DIR="/app/nginx/certbot/conf"
    OPTIONS_FILE="$CERTBOT_SOURCE_DIR/options-ssl-nginx.conf"
    DHPARAMS_FILE="$CERTBOT_SOURCE_DIR/ssl-dhparams.pem"

    # Directories to copy the configs into
    TARGET_LOCATIONS="/etc/letsencrypt /app/nginx/certbot/conf /etc/nginx/ssl"

    # Ensure source directory exists
    for dir in $TARGET_LOCATIONS; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "Created directory: $dir"
        else
            echo "Directory already exists: $dir"
        fi
     done

    # Download the TLS config files if not already present
    if [ ! -f "$OPTIONS_FILE" ] || [ ! -f "$DHPARAMS_FILE" ]; then
        echo "Downloading Certbot TLS config files..."

        if command -v wget >/dev/null 2>&1; then
            wget -P "$CERTBOT_SOURCE_DIR" https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
            wget -P "$CERTBOT_SOURCE_DIR" https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem
        elif command -v curl >/dev/null 2>&1; then
            curl -o "$OPTIONS_FILE" https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
            curl -o "$DHPARAMS_FILE" https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem
        else
            echo "Error: Neither wget nor curl is installed. Cannot fetch Certbot TLS configs."
            exit 1
        fi
    fi

    # Copy the files into each target directory
    for DIR in $TARGET_LOCATIONS; do
        mkdir -p "$DIR"
        cp "$OPTIONS_FILE" "$DIR/"
        cp "$DHPARAMS_FILE" "$DIR/"
        echo "Copied TLS configs to $DIR"
    done

    # Copy the downloaded files into each target directory
    for DIR in $TARGET_LOCATIONS; do
        mkdir -p "$DIR"
        cp "$OPTIONS_FILE" "$DIR/"
        cp "$DHPARAMS_FILE" "$DIR/"
        echo "Copied TLS configs to $DIR"
    done

    certbot certonly --standalone --email "$CERTBOT_EMAIL" --agree-tos --no-eff-email -d "$FQDN" --config-dir /app/nginx/certbot/conf
    cp nginx/nginx.template.tls nginx/nginx.template
    COMPOSE_PROFILES="$COMPOSE_PROFILES,certbot"
    log "Will start Nginx with Certbot"
elif [ "$USE_TLS" = "true" ]; then
    log "Will start Nginx with Certbot (cert already present)"
    cp nginx/nginx.template.tls nginx/nginx.template
    COMPOSE_PROFILES="$COMPOSE_PROFILES,certbot"
else
    log "Will NOT use TLS or Certbot"
    cp nginx/nginx.template.notls nginx/nginx.template
fi

# First-time setup detection
if [ ! -f "$FLAG_FILE" ]; then
    log "First time execution."
    if command -v systemctl >/dev/null 2>&1; then
        log "Enabling Swirl service to start on boot..."
        systemctl enable swirl
    else
        log "Skipping systemctl - not available on this platform."
    fi
    COMPOSE_PROFILES="$COMPOSE_PROFILES,setup"
    touch "$FLAG_FILE"
else
    log "Not first time execution."
fi

# Final startup
log "Docker Compose Up with profiles: $COMPOSE_PROFILES"
COMPOSE_PROFILES="$COMPOSE_PROFILES" docker compose up --pull never -d
