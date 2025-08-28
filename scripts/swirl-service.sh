#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Disable X11 for GUI apps to avoid DBUS-related issues
export DBUS_SESSION_BUS_ADDRESS=/dev/null

# Find full path to Docker binary
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export DOCKER_BIN="$(command -v docker)"

# Logging function
function log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${STAGE}] $1"
}

# Error logging function
function error() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${STAGE} ERROR] $1"
}

# Ensure log directory exists and redirect output to log file
if [[ "$OSTYPE" == "darwin"* ]]; then
    LOG_DIR="$HOME/Library/Logs/swirl"
    log "Creating base log directory for MacOS: $LOG_DIR"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    LOG_DIR="/var/log/swirl"
    log "Creating base log directory for Linux: $LOG_DIR"
fi
mkdir -p "$LOG_DIR"
log "Log directory successfully created."
exec > >(tee -a "$LOG_DIR/swirl.log") 2>&1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log "Script directory: $SCRIPT_DIR"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
log "Parent directory: $PARENT_DIR"

SERVICE_SETUP_FLAG="$PARENT_DIR/.swirl-service-setup-complete.flag"
ENV_FILE="$PARENT_DIR/.env"
EXAMPLE_ENV_FILE="$PARENT_DIR/env.example"

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

# Check Properly Configured Environment Variables
if [ -z "$SWIRL_FQDN" ]; then
    error "SWIRL_FQDN is not set in .env file. Please set it to your domain name."
    exit 1
fi
if [ -z "$SWIRL_VERSION" ] || [ -z "$TIKA_VERSION" ] || [ -z "$TTM_VERSION" ]; then
    error "SWIRL_VERSION, TIKA_VERSION, and TTM_VERSION must all be set in .env file."
    exit 1
fi

# First-time setup detection
if [ -f "$SERVICE_SETUP_FLAG" ]; then
    log "Not first time execution."
else
    if [ "$USE_TLS" == "true" ]; then
        if [ "$USE_CERT" == "false" ]; then
            OPTIONS_FILE="$PARENT_DIR/certbot/conf/options-ssl-nginx.conf"
            DHPARAMS_FILE="$PARENT_DIR/certbot/conf/ssl-dhparams.pem"

            # Fetch certbot configuration files if necessary
            if [ -f "$OPTIONS_FILE" ] && [ -f "$DHPARAMS_FILE" ]; then
                log "Setup: Certbot configuration files already exist."
            else
                log "Setup:Fetching Certbot configuration files..."
                if [ ! $(which curl) ]; then
                    error "Setup: curl is not installed. Please install curl to fetch Certbot configuration files or Install them manually (see 'TLS Configuration with Let's Encrypt & Certbot (optional)' section of Readme)"
                fi
                mkdir -p "$PARENT_DIR/certbot/conf"
                curl -o "$PARENT_DIR/certbot/conf/options-ssl-nginx.conf" https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
                curl -o  "$PARENT_DIR/certbot/conf/ssl-dhparams.pem" https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem
            fi
        fi
    fi

    # check for local images
    if "${DOCKER_BIN}" inspect "swirlai/release-swirl-search-enterprise:${SWIRL_VERSION}" > /dev/null 2>&1; then
        log "Setup: Found local Swirl image swirlai/release-swirl-search-enterprise:${SWIRL_VERSION}"
    else
        log "Setup: Local Swirl image swirlai/release-swirl-search-enterprise:${SWIRL_VERSION} not found. Pulling images from Docker Hub."
        "${DOCKER_BIN}" compose -f $PARENT_DIR/docker-compose.yml --profile all pull --quiet
    fi

    log "Setup: Setup starting..."
    log "Setup: Enabling Swirl service to start on boot..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        log "Setup: Running on macOS (user-level LaunchAgent)."

        SERVICE_FILE="$SCRIPT_DIR/com.swirl.service.plist"
        REPLACEMENT="$SCRIPT_DIR/swirl-service.sh"

        log "Setup: Patching service .plist file to use $REPLACEMENT..."
        sed -i '' "s|{{SWIRL_SCRIPT_PATH}}|$REPLACEMENT|g" "$SERVICE_FILE"
        sed -i '' "s|{{HOME_LOG_PATH}}|$HOME|g" "$SERVICE_FILE"
        log "Setup: Service .plist file successfully patched"

        log "Setup: Copying service .plist file to ~/Library/LaunchAgents/"
        cp "$SERVICE_FILE" ~/Library/LaunchAgents/com.swirl.service.plist
        log "Service .plist file successfully copied to ~/Library/LaunchAgents/com.swirl.service.plist"

        # Verifies if the current shell is a valid GUI session
        if launchctl print "gui/$(id -u)" &>/dev/null; then
            log "Setup: Session supports user-level LaunchAgent. Bootstrapping..."

            launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.swirl.service.plist 2>/dev/null || true
            launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.swirl.service.plist
            launchctl enable gui/$(id -u)/com.swirl.service

            log "Setup: LaunchAgent bootstrapped successfully."
            log "To start Swirl manually, run the following command in a terminal: 'launchctl kickstart -k gui/\$(id -u)/com.swirl.service'"
        else
            log "WARNING: Current shell is not a GUI session."
            log "You must manually run the following command in a terminal: 'launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/com.swirl.service.plist'"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log "Setup: Running on Linux."

        if [ ! -f "/etc/systemd/system/swirl.service" ]; then
            log "Setup: Copying swirl.service to /etc/systemd/system/"
            TEMPLATE_FILE="$SCRIPT_DIR/swirl.service.template"
            TARGET_FILE="/etc/systemd/system/swirl.service"

            if [ -f "$TEMPLATE_FILE" ]; then
                sed -e "s|{{WORKING_DIRECTORY}}|$PARENT_DIR|g" \
                    "$TEMPLATE_FILE" > "$TARGET_FILE"
                log "Setup: swirl.service generated and copied to /etc/systemd/system/"
            else
                error "Setup: swirl.service.template not found in $SCRIPT_DIR."
            fi
            systemctl daemon-reload
        else
            log "Setup: swirl.service already exists in /etc/systemd/system/"
        fi
        systemctl enable swirl

        log "Start Service via: systemctl start swirl"
        log "Monitor Service via: journalctl -u swirl"

    else
        error "Setup: Unsupported OS: $OSTYPE"
    fi
    # prevent setup on subsequent runs
    touch "$SERVICE_SETUP_FLAG"
    log "Setup: Setup complete"
    exit 0
fi

# Base profile for Swirl services
COMPOSE_PROFILES=svc

# Stop previously running Swirl containers
log "Stopping any Swirl containers from previous run"
"${DOCKER_BIN}" compose -f $PARENT_DIR/docker-compose.yml --profile all stop

# Conditionally add local Postgres
if [ "$USE_LOCAL_POSTGRES" == "true" ]; then
    log "Local Postgres is enabled. Starting service."
    (COMPOSE_PROFILES=db "${DOCKER_BIN}" compose -f $PARENT_DIR/docker-compose.yml up --pull never -d)
    log "Started local Postgres service."
    sleep 15
fi

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
            UPDATE_MARKER="# swirl-service updated: USE_TLS=true, USE_CERT=false"

            if ! grep -Fq "$UPDATE_MARKER" "$TEMPLATE_FILE"; then
                log "Update Marker not found, adding TLS configuration to Nginx ${TEMPLATE_FILE}"
                awk -v update_marker="$UPDATE_MARKER" '
                {
                    if (prev ~ /listen 443 ssl;/ && $0 ~ /server_name .*;/) {
                        print
                        print ""
                        print "      " update_marker
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
            log "Copied TLS configs to $TARGET_DIR"

            # when renewal not required
            # we use existing certifiactes
            certbot certonly --standalone --email $CERTBOT_EMAIL \
              --agree-tos --no-eff-email -d "${SWIRL_FQDN}" \
              --config-dir /certbot/conf \
              --non-interactive --quiet

            cp -a /certbot/conf/. $PARENT_DIR/certbot/conf

            cp $PARENT_DIR/nginx/nginx-template.tls $PARENT_DIR/nginx/nginx.template
            COMPOSE_PROFILES="$COMPOSE_PROFILES,certbot"

        elif [ "$USE_CERT" == "true" ]; then
            log "TLS enabled with owned certificate. Starting Nginx without Certbot."

            CERT_PATH="$PARENT_DIR/nginx/certificates/ssl/${SWIRL_FQDN}"
            if [ -f "$CERT_PATH/ssl_certificate.crt" ] && [ -f "$CERT_PATH/ssl_certificate_key.key" ]; then
              log "Found owned certificate and key in '${CERT_PATH}'"
                TEMPLATE_FILE="$PARENT_DIR/nginx/nginx-template.tls"

                UPDATE_MARKER="# swirl-service updated: USE_TLS=true, USE_CERT=true"

                # Check if the market is already present in the template
                if ! grep -Fq "$UPDATE_MARKER" "$TEMPLATE_FILE"; then
                    log "Update Marker not found, updating Nginx template with owned certificate paths."
                    awk -v update_marker="$UPDATE_MARKER" '
                    {
                        if (prev ~ /listen 443 ssl;/ && $0 ~ /server_name .*;/) {
                            print
                            print ""
                            print "      " update_marker
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

ONETIME_JOB_FLAG="$PARENT_DIR/.swirl-application-setup-job-complete.flag"
if [ -f "$ONETIME_JOB_FLAG" ]; then
    log "Application setup job already completed. Skipping initial setup."
    COMPOSE_PROFILES="$COMPOSE_PROFILES,reload"
else
    log "Setting up run one-time application setup job..."
    # Run the initial setup job
    COMPOSE_PROFILES="$COMPOSE_PROFILES,setup"
    touch "$ONETIME_JOB_FLAG"
fi

# Final startup
log "Docker Compose Up with profiles: $COMPOSE_PROFILES"
COMPOSE_PROFILES=$COMPOSE_PROFILES "${DOCKER_BIN}" compose -f $PARENT_DIR/docker-compose.yml up --pull never
