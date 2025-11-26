#!/bin/bash
####
# Main installation script for Swirl application. Sets up environment, installs dependencies, and configures services.
####

set -e

PROG=`basename "$0"`

# Logging function
function log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${PROG}] $1"
}

# Error logging function
function error() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ${PROG} ERROR] $1"
}

# Find full path to Docker binary
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export DOCKER_BIN="$(command -v docker)"

log "This script will require Sudo at several points you will be prompted for admin creds."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then

    ## Che for minimum disk space
    MIN_FREE_GB=60
    avail_kb=$(df --output=avail / | tail -n 1)
    avail_gb=$((avail_kb / 1024 / 1024))

    if [ "$avail_gb" -lt "$MIN_FREE_GB" ]; then
        error "Not enough free disk space on /. At least ${MIN_FREE_GB}GB free is required, but only ${avail_gb}GB is available."
        error "Consider resizing the VM disk or attaching a larger data disk and configuring containerd to use it."
        exit 1
    fi

    # Setup Official Docker Repository for later installs
    sudo apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo  chmod a+r /etc/apt/keyrings/docker.asc
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update

    # Install required packages
    sudo apt-get install -y \
    apt-transport-https \
    software-properties-common \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin\
    docker-compose-plugin \
    certbot \
    docker-compose

    # Ensure all patches and security fixes updated
    sudo apt-get install -y
fi

# Get our location in the file system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log "Script directory: $SCRIPT_DIR"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
log "Parent directory: $PARENT_DIR"

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
log "Loading env file $ENV_FILE and sourcing shared functions..."
source "$ENV_FILE"
source "$PARENT_DIR/scripts/swirl-shared.sh"

# Sanity checks for required env vars
if [ -z "$SWIRL_VERSION" ] || [ -z "$SWIRL_PATH" ]; then
    error "SWIRL_VERSION and SWIRL_PATH must all be set in .env file."
    exit 1
fi

# check for local images and pull if not found
if "${DOCKER_BIN}" inspect "${SWIRL_PATH}:${SWIRL_VERSION}" > /dev/null 2>&1; then
    log "Found local Swirl image ${SWIRL_PATH}:${SWIRL_VERSION}"
else
    log "Local Swirl image ${SWIRL_PATH}:${SWIRL_VERSION} not found. Pulling images from Docker Hub."
    log "Pulling for profiles: $(get_active_profiles)"
    COMPOSE_PROFILES="$(get_active_profiles)" "${DOCKER_BIN}" compose -f $PARENT_DIR/docker-compose.yml  pull --quiet
fi


if [ "$USE_TLS" == "true" ]; then
    if [ "$USE_CERT" == "false" ]; then
        OPTIONS_FILE="$PARENT_DIR/certbot/conf/options-ssl-nginx.conf"
        DHPARAMS_FILE="$PARENT_DIR/certbot/conf/ssl-dhparams.pem"

        # Fetch certbot configuration files if necessary
        if [ -f "$OPTIONS_FILE" ] && [ -f "$DHPARAMS_FILE" ]; then
            log "Certbot configuration files already exist."
        else
            log "Fetching Certbot configuration files..."
            if [ ! $(which curl) ]; then
                error "curl is not installed. Please install curl to fetch Certbot configuration files or Install them manually (see 'TLS Configuration with Let's Encrypt & Certbot (optional)' section of Readme)"
            fi
            sudo  mkdir -p "$PARENT_DIR/certbot/conf"
            sudo curl -o "$PARENT_DIR/certbot/conf/options-ssl-nginx.conf" https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
            sudo curl -o  "$PARENT_DIR/certbot/conf/ssl-dhparams.pem" https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem
        fi
    fi
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    log "Running on macOS (user-level LaunchAgent)."

    SERVICE_FILE="$PARENT_DIR/scripts/com.swirl.service.plist"
    REPLACEMENT="$PARENT_DIR/scripts/swirl-service.sh"

    log "Patching service .plist file to use $REPLACEMENT..."
    sudo sed -i '' "s|{{SWIRL_SCRIPT_PATH}}|$REPLACEMENT|g" "$SERVICE_FILE"
    sudo sed -i '' "s|{{HOME_LOG_PATH}}|$HOME|g" "$SERVICE_FILE"
    log "Service .plist file successfully patched"

    log "Copying service .plist file to ~/Library/LaunchAgents/"
    sudo cp "$SERVICE_FILE" ~/Library/LaunchAgents/com.swirl.service.plist
    log "Service .plist file successfully copied to ~/Library/LaunchAgents/com.swirl.service.plist"

    # Verifies if the current shell is a valid GUI session
    if launchctl print "gui/$(id -u)" &>/dev/null; then
        log "Session supports user-level LaunchAgent. Bootstrapping..."

        sudo launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.swirl.service.plist 2>/dev/null || true
        sudo launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.swirl.service.plist
        sudo launchctl enable gui/$(id -u)/com.swirl.service

        log "LaunchAgent bootstrapped successfully."
        log "To start Swirl manually, run the following command in a terminal: 'launchctl kickstart -k gui/\$(id -u)/com.swirl.service'"
    else
        log "Current shell is not a GUI session."
        log "You must manually run the following command in a terminal: 'launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/com.swirl.service.plist'"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    log "Running on Linux."


    if [ ! -f "/etc/logrotate.d/swirl" ]; then
      sudo cp  $PARENT_DIR/scripts/logrotate.d-swirl /etc/logrotate.d/swirl
    fi

    if [ ! -f "/etc/systemd/system/swirl.service" ]; then
        log "Copying swirl.service to /etc/systemd/system/"
        TEMPLATE_FILE="$PARENT_DIR/scripts/swirl.service.template"
        TARGET_FILE="/etc/systemd/system/swirl.service"

        if [ -f "$TEMPLATE_FILE" ]; then
            sudo bash -c "sed -e \"s|{{WORKING_DIRECTORY}}|$PARENT_DIR|g\" \"$TEMPLATE_FILE\" > \"$TARGET_FILE\""
            log "swirl.service generated and copied to /etc/systemd/system/"
        else
            error "swirl.service.template not found in $PARENT_DIR/scripts/."
        fi
        sudo systemctl daemon-reload
    else
        log "swirl.service already exists in /etc/systemd/system/"
    fi
    sudo systemctl enable swirl

    log "Install docker images and you can start and monitor the service."
    log "Start Service via: systemctl start swirl"
    log "Monitor Service via: journalctl -u swirl"

else
    error "Unsupported OS: $OSTYPE"
fi
# prevent setup on subsequent runs
#touch "$SERVICE_SETUP_FLAG"
log "Setup complete"
exit 0
fi
