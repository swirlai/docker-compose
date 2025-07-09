#!/bin/sh

set -eu

# Default fallback versions
DEFAULT_POSTGRES_VERSION="15"
DEFAULT_REDIS_VERSION="7"
DEFAULT_CERTBOT_VERSION="v2.11.0"
DEFAULT_NGINX_VERSION="1.27.1"
DEFAULT_SWIRL_VERSION="v4_2_1_0"
DEFAULT_TTM_VERSION="v4_2_1_0"
DEFAULT_TIKA_VERSION="v4_2_1_0"

# Use environment variables if defined, or fallback defaults
POSTGRES_VERSION="${POSTGRES_VERSION:-$DEFAULT_POSTGRES_VERSION}"
REDIS_VERSION="${REDIS_VERSION:-$DEFAULT_REDIS_VERSION}"
CERTBOT_VERSION="${CERTBOT_VERSION:-$DEFAULT_CERTBOT_VERSION}"
NGINX_VERSION="${NGINX_VERSION:-$DEFAULT_NGINX_VERSION}"
SWIRL_VERSION="${SWIRL_VERSION:-$DEFAULT_SWIRL_VERSION}"
TTM_VERSION="${TTM_VERSION:-$DEFAULT_TTM_VERSION}"
TIKA_VERSION="${TIKA_VERSION:-$DEFAULT_TIKA_VERSION}"

# Function to pull a Docker image with fallback and export the used version
pull_image() {
  IMAGE="$1"
  USER_VERSION="$2"
  FALLBACK_VERSION="$3"
  VAR_NAME="$4"
  PULLED_VERSION=""

  echo "Checking availability of $IMAGE:$USER_VERSION..."
  if docker manifest inspect "$IMAGE:$USER_VERSION" >/dev/null 2>&1; then
    echo "Pulling $IMAGE:$USER_VERSION"
    docker pull "$IMAGE:$USER_VERSION"
    PULLED_VERSION="$USER_VERSION"
  else
    echo "Version $USER_VERSION not found. Falling back to $IMAGE:$FALLBACK_VERSION"
    docker pull "$IMAGE:$FALLBACK_VERSION"
    PULLED_VERSION="$FALLBACK_VERSION"
  fi

  # Export to GITHUB_ENV if available
  if [ -n "${GITHUB_ENV:-}" ]; then
    echo "${VAR_NAME}_USED=$PULLED_VERSION" >> "$GITHUB_ENV"
  fi

  # Also export as an env var for use later in this script
  # Using eval since sh doesn't support indirect variables
  eval "${VAR_NAME}_USED=\$PULLED_VERSION"
  export "${VAR_NAME}_USED"
}

# Pull images with fallback
pull_image "postgres" "$POSTGRES_VERSION" "$DEFAULT_POSTGRES_VERSION" "POSTGRES_VERSION"
pull_image "redis" "$REDIS_VERSION" "$DEFAULT_REDIS_VERSION" "REDIS_VERSION"
pull_image "certbot/certbot" "$CERTBOT_VERSION" "$DEFAULT_CERTBOT_VERSION" "CERTBOT_VERSION"
pull_image "nginx" "$NGINX_VERSION" "$DEFAULT_NGINX_VERSION" "NGINX_VERSION"
pull_image "swirlai/release-swirl-search-enterprise" "$SWIRL_VERSION" "$DEFAULT_SWIRL_VERSION" "SWIRL_VERSION"
pull_image "swirlai/release-topic-text-matcher-enterprise" "$TTM_VERSION" "$DEFAULT_TTM_VERSION" "TTM_VERSION"
pull_image "swirlai/release-tika-enterprise" "$TIKA_VERSION" "$DEFAULT_TIKA_VERSION" "TIKA_VERSION"

# Save resolved images to archive
echo "Saving Docker images to docker-images.tar.gz..."
docker save \
  "postgres:$POSTGRES_VERSION_USED" \
  "redis:$REDIS_VERSION_USED" \
  "certbot/certbot:$CERTBOT_VERSION_USED" \
  "nginx:$NGINX_VERSION_USED" \
  "swirlai/release-swirl-search-enterprise:$SWIRL_VERSION_USED" \
  "swirlai/release-topic-text-matcher-enterprise:$TTM_VERSION_USED" \
  "swirlai/release-tika-enterprise:$TIKA_VERSION_USED" | \
  gzip -9 > docker-images.tar.gz
