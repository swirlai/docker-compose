#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Disable X11 for GUI apps to avoid DBUS-related issues
export DBUS_SESSION_BUS_ADDRESS=/dev/null

# Logging function
function log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${STAGE}] $1"
}

# Error logging function
function error() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${STAGE} ERROR] $1"
}

# Ensure log directory exists and redirect output to log file
mkdir -p /var/log/swirl
exec > >(tee -a /var/log/swirl/swirl.log) 2>&1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log "Script directory: $SCRIPT_DIR"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
log "Parent directory: $PARENT_DIR"

FLAG_FILE="$PARENT_DIR/swirl_job.flag"
ENV_FILE="$PARENT_DIR/.env"
EXAMPLE_ENV_FILE="$PARENT_DIR/.env.example"

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

# Stop previously running Swirl containers
log "Stopping any Swirl containers from previous run"
docker compose --profile all stop

# Conditionally add local Postgres
if [ "$USE_LOCAL_POSTGRES" == "true" ]; then
    log "Local Postgres is enabled. Starting service."
    COMPOSE_PROFILES=db docker compose up --pull never -d
    log "Started local Postgres service."
    sleep 15
fi

# Base profile for Swirl services
COMPOSE_PROFILES=svc

# Conditionally add Nginx and Certbot
if [ "$USE_NGINX" == "true" ]; then
    log "Enabling Nginx profile."
    COMPOSE_PROFILES="$COMPOSE_PROFILES,nginx"

    if [ "$USE_TLS" == "true" ]; then
        if [ "$USE_CERT" == "false" ]; then
            log "TLS enabled with Certbot. Starting Nginx and Certbot."
            log "Issuing certificate using Certbot."

            log "Waiting DNS propagation before Certbot request..."
            MAX_WAIT=300
            WAITED=0
            while ! nslookup  "$SWIRL_FQDN" >/dev/null; do
                if [ "$WAITED" -ge "$MAX_WAIT" ]; then
                    error "DNS name $SWIRL_FQDN did not resolve after $MAX_WAIT seconds."
                    exit 1
                fi
                sleep 1
                WAITED=$((WAITED + 1))
            done

            log "DNS name $SWIRL_FQDN resolved after $WAITED seconds."

            TEMPLATE_FILE="$PARENT_DIR/nginx/nginx-template.tls"
            SNIPPET="ssl_certificate /etc/letsencrypt/live/\${SWIRL_FQDN}/ssl_certificate.crt;"

            if ! grep -Fq "$SNIPPET" "$TEMPLATE_FILE"; then
                awk '
                {
                    if (prev ~ /listen 443 ssl;/ && $0 ~ /server_name .*;/) {
                        print
                        print ""
                        print "      ssl_certificate /etc/letsencrypt/live/${SWIRL_FQDN}/fullchain.pem;"
                        print "      ssl_certificate_key /etc/letsencrypt/live/${SWIRL_FQDN}/privkey.pem;"
                        print "      include /etc/letsencrypt/options-ssl-nginx.conf;"
                        print "      ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;"
                    } else {
                        print
                    }
                    prev = $0
                }
                ' "$TEMPLATE_FILE" > tmp && mv tmp "$TEMPLATE_FILE"
            fi
            
            OPTIONS_FILE="$PARENT_DIR/certbot/conf/options-ssl-nginx.conf"
            DHPARAMS_FILE="$PARENT_DIR/certbot/conf/ssl-dhparams.pem"
            TARGET_DIR="$PARENT_DIR/nginx/certificates/ssl"

            mkdir -p $TARGET_DIR
            cp "$OPTIONS_FILE" "$TARGET_DIR/"
            cp "$DHPARAMS_FILE" "$TARGET_DIR/"
            log "Copied TLS configs to $DIR"

            certbot certonly --standalone --email $CERTBOT_EMAIL --agree-tos --no-eff-email -d "${SWIRL_FQDN}" --config-dir /certbot/conf
            cp -a /certbot/conf/. $PARENT_DIR/certbot/conf

            cp $PARENT_DIR/nginx/nginx-template.tls $PARENT_DIR/nginx/nginx.template
            COMPOSE_PROFILES="$COMPOSE_PROFILES,certbot"

        elif [ "$USE_CERT" == "true" ]; then
            log "TLS enabled with owned certificate. Starting Nginx without Certbot."

            CERT_PATH="$PARENT_DIR/nginx/certificates/ssl/${SWIRL_FQDN}"
            if [ -f "$CERT_PATH/ssl_certificate.crt" ] && [ -f "$CERT_PATH/ssl_certificate_key.key" ]; then
              log "Found owned certificate and key in '${CERT_PATH}'"
                TEMPLATE_FILE="$PARENT_DIR/nginx/nginx-template.tls"
                SNIPPET="ssl_certificate /etc/nginx/ssl/\${SWIRL_FQDN}/ssl_certificate.crt;"

                if ! grep -Fq "$SNIPPET" "$TEMPLATE_FILE"; then
                    log "Updating Nginx template with owned certificate paths."
                    awk '
                    {
                        if (prev ~ /listen 443 ssl;/ && $0 ~ /server_name .*;/) {
                            print
                            print ""
                            print "      ssl_certificate /etc/nginx/ssl/${SWIRL_FQDN}/ssl_certificate.crt;"
                            print "      ssl_certificate_key /etc/nginx/ssl/${SWIRL_FQDN}/ssl_certificate_key.key;"
                        } else {
                            print
                        }
                        prev = $0
                    }
                    ' "$TEMPLATE_FILE" > tmp && mv tmp "$TEMPLATE_FILE"
                else
                    log "Nginx template already contains the owned certificate paths."
                fi
            else
                error "Certificate or key not found in '${CERT_PATH}'."
            fi

            cp $PARENT_DIR/nginx/nginx-template.tls $PARENT_DIR/nginx/nginx.template
        fi
    else
        log "TLS is disabled. Starting Nginx without TLS."
        cp $PARENT_DIR/nginx/nginx-template.notls $PARENT_DIR/nginx/nginx.template
    fi
else
    log "USE_NGINX is false. Nginx will not be started."
    cp $PARENT_DIR/nginx/nginx-template.notls $PARENT_DIR/nginx/nginx.template
fi

# First-time setup detection
if [ -f "$FLAG_FILE" ]; then
    log "Not first time execution."
else
    log "First time execution."
    log "Enabling Swirl service to start on boot..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        log "Running on macOS."
        
        launchctl load $SCRIPT_DIR/com.service.swirl.plist
        launchctl enable system/com.example.myapp
        
        COMPOSE_PROFILES="$COMPOSE_PROFILES,setup"
        touch "$FLAG_FILE"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log "Running on Linux."
        
        systemctl enable swirl

        COMPOSE_PROFILES="$COMPOSE_PROFILES,setup"
        touch "$FLAG_FILE"
    else
        error "Unsupported OS: $OSTYPE"
        exit 1
    fi
fi

# Final startup
log "Docker Compose Up with profiles: $COMPOSE_PROFILES"
COMPOSE_PROFILES=$COMPOSE_PROFILES docker compose up --pull never