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
if [ "$USE_LOCAL_POSTGRES" == "true" ]; then
    log "Enabling local Postgres profile."
    COMPOSE_PROFILES="$COMPOSE_PROFILES,local-postgres"
fi

# Conditionally add Nginx
if [ "$USE_NGINX" == "true" ]; then
    COMPOSE_PROFILES="$COMPOSE_PROFILES,nginx"

    # Handle TLS and Certbot setup
    if [ "$USE_TLS" == "true" ]; then
        if [ "$USE_CERT" == "false" ]; then
            log "TLS enabled with Certbot. Starting Nginx and Certbot."
            log "Issuing certificate using Certbot."
            log "Waiting DNS propagation..."
            sleep 300

            TEMPLATE_FILE="nginx/nginx.template.tls"
            SNIPPET="ssl_certificate /etc/letsencrypt/live/\${SWIRL_FQDN}/fullchain.pem;"

            if ! grep -Fq "$SNIPPET" "$TEMPLATE_FILE"; then
                awk '
                {
                    if (prev ~ /listen 443 ssl;/ && $0 ~ /server_name .*;/) {
                        print
                        print ""
                        print "    ssl_certificate /etc/letsencrypt/live/${SWIRL_FQDN}/fullchain.pem;"
                        print "    ssl_certificate_key /etc/letsencrypt/live/${SWIRL_FQDN}/privkey.pem;"
                        print "    include /etc/letsencrypt/options-ssl-nginx.conf;"
                        print "    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;"
                    } else {
                        print
                    }
                    prev = $0
                }
                ' "$TEMPLATE_FILE" > tmp && mv tmp "$TEMPLATE_FILE"
            fi
            
            CERTBOT_SOURCE_DIR="/app/nginx/certbot/conf"
            OPTIONS_FILE="$CERTBOT_SOURCE_DIR/options-ssl-nginx.conf"
            DHPARAMS_FILE="$CERTBOT_SOURCE_DIR/ssl-dhparams.pem"
            
            TARGET_LOCATIONS="/etc/letsencrypt /etc/nginx/ssl"

            for DIR in $TARGET_LOCATIONS; do
                mkdir -p "$DIR"
                cp "$OPTIONS_FILE" "$DIR/"
                cp "$DHPARAMS_FILE" "$DIR/"
                echo "Copied TLS configs to $DIR"
            done

            certbot certonly --standalone --email $CERTBOT_EMAIL --agree-tos --no-eff-email -d "${SWIRL_FQDN}" --config-dir /app/nginx/certbot/conf

            cp nginx/nginx.template.tls nginx/nginx.template
            COMPOSE_PROFILES="$COMPOSE_PROFILES,certbot"

        elif [ "$USE_CERT" == "true" ]; then
            log "TLS enabled with owned certificate. Starting Nginx without Certbot."

            CERT_PATH="/etc/nginx/ssl/${SWIRL_FQDN}"
            if [ -f "$CERT_PATH/ssl_certificate.crt" ] && [ -f "$CERT_PATH/ssl_certificate_key.key" ]; then
                TEMPLATE_FILE="nginx/nginx.template.tls"
                SNIPPET="ssl_certificate /etc/nginx/ssl/\${SWIRL_FQDN}/ssl_certificate.crt;"

                if ! grep -Fq "$SNIPPET" "$TEMPLATE_FILE"; then
                    awk '
                    {
                        if (prev ~ /listen 443 ssl;/ && $0 ~ /server_name .*;/) {
                            print
                            print ""
                            print "    ssl_certificate /etc/nginx/ssl/${SWIRL_FQDN}/ssl_certificate.crt;"
                            print "    ssl_certificate_key /etc/nginx/ssl/${SWIRL_FQDN}/ssl_certificate_key.key;"
                        } else {
                            print
                        }
                        prev = $0
                    }
                    ' "$TEMPLATE_FILE" > tmp && mv tmp "$TEMPLATE_FILE"
                fi
            else
                echo "Certificate or key not found in '${CERT_PATH}'."
            fi

            cp nginx/nginx.template.tls nginx/nginx.template
        fi
    else
        log "TLS is disabled. Starting Nginx without TLS."
        cp nginx/nginx.template.notls nginx/nginx.template
    fi
else
    log "USE_NGINX is false. Nginx will not be started."
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
