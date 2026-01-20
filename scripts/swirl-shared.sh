#!/bin/bash
####
# Shared functions and variables for SWIRL scripts. Include after sourcing .env file.
####
set -e

# Function to determine active Docker Compose profiles based on environment variables
get_active_profiles() {
    local profiles="svc"

    if [ "${USE_LOCAL_POSTGRES:-false}" = "true" ]; then
        profiles="$profiles,db"
    fi

    if [ "${USE_NGINX:-false}" = "true" ]; then
        profiles="$profiles,nginx"

        # Add Certbot profile if using TLS without owned certificate
        if [ "${USE_TLS:-false}" = "true" ] && [ "${USE_CERT:-false}" = "false" ]; then
            profiles="$profiles,certbot"
        fi
    fi

    if [ "${MCP_ENABLED:-false}" = "true" ]; then
        profiles="$profiles,mcp"
    fi

    # Add setup profile if one-time job hasn't been completed.
    # Default: include it (runtime scripts want it). Install scripts can disable.
    if [ "${INCLUDE_SETUP_PROFILE:-true}" = "true" ]; then
        if [ -z "${PARENT_DIR:-}" ]; then
            echo "[ERROR] PARENT_DIR is not set; cannot locate one-time setup flag." >&2
            exit 1
        fi

        local onetime_job_flag="$PARENT_DIR/.swirl-application-setup-job-complete.flag"
        if [ ! -f "$onetime_job_flag" ]; then
            profiles="$profiles,setup"
        fi
    fi

    echo "$profiles"
}
