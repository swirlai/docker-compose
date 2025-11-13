#!/bin/bash

set -e
echo "This script will require Sudo at several points you will be prompted for admin creds."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then

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

  
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Script directory: $SCRIPT_DIR"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
echo "Parent directory: $PARENT_DIR"

ENV_FILE="$PARENT_DIR/.env"
EXAMPLE_ENV_FILE="$PARENT_DIR/env.example"

# Create .env file from example if not present
if [ ! -f "$ENV_FILE" ]; then
    echo ".env file does not exist. Copying $EXAMPLE_ENV_FILE to $ENV_FILE..."

    if [ -f "$EXAMPLE_ENV_FILE" ]; then
        cp "$EXAMPLE_ENV_FILE" "$ENV_FILE"
        echo ".env file created successfully."
    else
        error ".env.example file not found. Cannot create .env file."
        exit 1
    fi
else
    echo ".env file already exists."
fi

# Load environment variables from .env
source "$ENV_FILE"

if [ "$USE_TLS" == "true" ]; then
if [ "$USE_CERT" == "false" ]; then
    OPTIONS_FILE="$PARENT_DIR/certbot/conf/options-ssl-nginx.conf"
    DHPARAMS_FILE="$PARENT_DIR/certbot/conf/ssl-dhparams.pem"

    # Fetch certbot configuration files if necessary
    if [ -f "$OPTIONS_FILE" ] && [ -f "$DHPARAMS_FILE" ]; then
        echo "Setup: Certbot configuration files already exist."
    else
        echo "Setup:Fetching Certbot configuration files..."
        if [ ! $(which curl) ]; then
            error "Setup: curl is not installed. Please install curl to fetch Certbot configuration files or Install them manually (see 'TLS Configuration with Let's Encrypt & Certbot (optional)' section of Readme)"
        fi
        sudo  mkdir -p "$PARENT_DIR/certbot/conf"
        sudo curl -o "$PARENT_DIR/certbot/conf/options-ssl-nginx.conf" https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
        sudo curl -o  "$PARENT_DIR/certbot/conf/ssl-dhparams.pem" https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem
    fi
fi
fi



if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Setup: Running on macOS (user-level LaunchAgent)."

    SERVICE_FILE="$PARENT_DIR/scripts/com.swirl.service.plist"
    REPLACEMENT="$PARENT_DIR/scripts/swirl-service.sh"

    echo "Setup: Patching service .plist file to use $REPLACEMENT..."
    sudo sed -i '' "s|{{SWIRL_SCRIPT_PATH}}|$REPLACEMENT|g" "$SERVICE_FILE"
    sudo sed -i '' "s|{{HOME_LOG_PATH}}|$HOME|g" "$SERVICE_FILE"
    echo "Setup: Service .plist file successfully patched"

    echo "Setup: Copying service .plist file to ~/Library/LaunchAgents/"
    sudo cp "$SERVICE_FILE" ~/Library/LaunchAgents/com.swirl.service.plist
    echo "Service .plist file successfully copied to ~/Library/LaunchAgents/com.swirl.service.plist"

    # Verifies if the current shell is a valid GUI session
    if launchctl print "gui/$(id -u)" &>/dev/null; then
        echo "Setup: Session supports user-level LaunchAgent. Bootstrapping..."

        sudo launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.swirl.service.plist 2>/dev/null || true
        sudo launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.swirl.service.plist
        sudo launchctl enable gui/$(id -u)/com.swirl.service

        echo "Setup: LaunchAgent bootstrapped successfully."
        echo "To start Swirl manually, run the following command in a terminal: 'launchctl kickstart -k gui/\$(id -u)/com.swirl.service'"
    else
        echo "WARNING: Current shell is not a GUI session."
        echo "You must manually run the following command in a terminal: 'launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/com.swirl.service.plist'"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Setup: Running on Linux."


    if [ ! -f "/etc/logrotate.d/swirl" ]; then
      sudo cp  $PARENT_DIR/scripts/logrotate.d-swirl /etc/logrotate.d/swirl
    fi
    
    if [ ! -f "/etc/systemd/system/swirl.service" ]; then
        echo "Setup: Copying swirl.service to /etc/systemd/system/"
        TEMPLATE_FILE="$PARENT_DIR/scripts/swirl.service.template"
        TARGET_FILE="/etc/systemd/system/swirl.service"

        if [ -f "$TEMPLATE_FILE" ]; then
            sudo bash -c "sed -e \"s|{{WORKING_DIRECTORY}}|$PARENT_DIR|g\" \"$TEMPLATE_FILE\" > \"$TARGET_FILE\""
            echo "Setup: swirl.service generated and copied to /etc/systemd/system/"
        else
            error "Setup: swirl.service.template not found in $PARENT_DIR/scripts/."
        fi
        sudo systemctl daemon-reload
    else
        echo "Setup: swirl.service already exists in /etc/systemd/system/"
    fi
    sudo systemctl enable swirl

    echo "Start Service via: systemctl start swirl"
    echo "Monitor Service via: journalctl -u swirl"

else
    error "Setup: Unsupported OS: $OSTYPE"
fi
# prevent setup on subsequent runs
#touch "$SERVICE_SETUP_FLAG"
echo "Setup: Setup complete"
exit 0
fi
