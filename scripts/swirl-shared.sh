#!/bin/bash
####
# Shared functions and variables for SWIRL scripts. Include after sourcing .env file.
####
set -e

# Function to determine active Docker Compose profiles based on environment variables
function get_active_profiles() {
    local profiles="svc"

    if [ "$USE_LOCAL_POSTGRES" == "true" ]; then
        profiles="$profiles,db"
    fi

    # Add Nginx profile if enabled
    if [ "$USE_NGINX" == "true" ]; then
        profiles="$profiles,nginx"

        # Add Certbot profile if using TLS without owned certificate
        if [ "$USE_TLS" == "true" ] && [ "$USE_CERT" == "false" ]; then
            profiles="$profiles,certbot"
        fi
    fi

    # Add MCP profile if enabled
    if [ "$MCP_ENABLED" == "true" ]; then
        profiles="$profiles,mcp"
    fi

    # Add setup profile if one-time job hasn't been completed
    local ONETIME_JOB_FLAG="$PARENT_DIR/.swirl-application-setup-job-complete.flag"
    if [ ! -f "$ONETIME_JOB_FLAG" ]; then
        profiles="$profiles,setup"
    fi

    echo "$profiles"
}
