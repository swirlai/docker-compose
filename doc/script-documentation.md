# SWIRL Scripts Reference

This page documents the helper scripts used to install, run, back up, and manage a SWIRL Enterprise deployment.

---

## Installation & Host Setup

- **`install.sh`**
  One-time host setup script. Installs Docker and related packages (on Ubuntu), creates `.env` from `env.example` if missing, configures Certbot files (if TLS+Certbot are enabled), and installs/activates the appropriate system service:
  - macOS: sets up a `LaunchAgent` using `swirl-service.sh`
  - Linux: sets up a `systemd` service (`swirl.service`) and log rotation

- **`docker-login.sh`**
  Interactive Docker Hub login helper. On Ubuntu/Debian, removes `golang-docker-credential-helpers` if present, then prompts for a Docker username and Personal Access Token and logs into Docker Hub using `--password-stdin`.

- **`install-docker-images.sh`**
  Ensures the required SWIRL Docker image(s) are available locally. If the configured `${SWIRL_PATH}:${SWIRL_VERSION}` image is missing, it uses Docker Compose and the active profiles to pull all needed images from Docker Hub.

---

## Service Control & Lifecycle

- **`swirl-service.sh`**
  Main service launcher for SWIRL, intended to be invoked by `LaunchAgent` (macOS) or `systemd` (Linux).
  - Loads `.env` and shared functions
  - Validates key settings (`SWIRL_FQDN`, version tags, etc.)
  - Optionally starts local Postgres, Nginx, and Certbot based on `USE_LOCAL_POSTGRES`, `USE_NGINX`, `USE_TLS`, and `USE_CERT`
  - Manages TLS configuration (Certbot or BYO cert) and nginx templates
  - Computes active Docker Compose profiles and runs `docker compose up` with those profiles

- **`swirl-stop.sh`**
  Stops the SWIRL stack both at the Docker and system-service levels:
  - Runs `docker compose --profile all stop`
  - macOS: stops the `com.swirl.service` LaunchAgent
  - Linux: stops the `swirl.service` systemd unit

- **`swirl-destroy.sh`**
  Hard reset script for SWIRL’s Docker environment.
  - Brings down all services via `docker compose --profile all down`
  - Removes the `swirl_db_data` volume
  - Shows any remaining containers with “swirl” in their name
  - Clears `.swirl-*.flag` files
  Use this when you need to completely rebuild the environment from scratch.

- **`check-service-health.sh`**
  CI/automation-friendly health checker for all Docker Compose services.
  - Iterates over running containers, ignoring `swirl_app_job` and `swirl_app_init`
  - Polls each container’s health status for up to 5 minutes
  - Fails if a service exits unhealthy or never becomes healthy
  - Returns a non-zero exit code and prints the name of the failing service

---

## Shared Logic

- **`swirl-shared.sh`**
  Shared helper file sourced by other scripts.
  - Provides `get_active_profiles`, which computes the Docker Compose profiles to use based on environment settings such as `USE_LOCAL_POSTGRES`, `USE_NGINX`, `USE_TLS`, `USE_CERT`, `MCP_ENABLED`, and whether the one-time setup job has completed.

---

## Application Bootstrapping (Inside Containers)

- **`swirl-load.sh`**
  Container entrypoint for the main SWIRL application.
  - Derives `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` from `SWIRL_FQDN` and `PORT`
  - Clears any existing `.swirl` configuration
  - Runs `python manage.py collectstatic --noinput --clear`
  - Adjusts the Elasticsearch Python client when `SWIRL_ES_VERSION=7`
  - Writes default API configuration via `swirl.py config_default_api_settings`
  - Waits for dependencies (e.g., DB/search) and then starts Celery workers and the Daphne ASGI server on `SWIRL_PORT` (default `8000`)

- **`swirl-load-job.sh`**
  One-time application setup job, typically run as a separate Docker Compose profile (`setup`).
  - Creates the Django superuser using `ADMIN_USER_EMAIL` / `ADMIN_PASSWORD`
  - If MSAL/M365 config is present, activates Microsoft 365 search providers in `preloaded.json`
  - When `MICROSOFT_CLIENT_SECRET` is set, configures and enables MSAL-based authentication in `DefaultAuthenticators.json`
  - If `AZ_GOV_COMPATIBLE=true`, rewrites Microsoft endpoints to `microsoft.us`
  - Loads initial SWIRL data (`load_data`, `reload_ai_prompts`, `load_branding`)
  - Optionally creates a SWIRL API user when `SWIRL_API_USERNAME` and `SWIRL_API_PASSWORD` are set

---

## Backup & Restore

- **`backup.sh`**
  Creates an encrypted backup of both the SWIRL database and filesystem.
  - Stops the `swirl` service to ensure a consistent snapshot
  - Ensures required containers exist; optionally starts local Postgres
  - Uses `pg_dump` via a `postgres:15` container to dump the `swirl` DB
  - Uses `rsync` to copy the SWIRL directory tree (excluding `backups/`) into a working directory
  - Packages everything into a `tar.gz`, encrypts it with GPG (using `ENCRYPTION_PASSWORD` or `ADMIN_PASSWORD`), and writes the `.tar.gz.gpg` into the `backups/` directory

- **`restore.sh`**
  Restores a SWIRL backup created by `backup.sh`.
  - Takes a single argument: the path to the encrypted backup file (`.tar.gz.gpg`)
  - Loads `.env`, stops the `swirl` service, and validates the environment
  - Decrypts the backup into a working directory and extracts it
  - Restores the database via `pg_restore` inside a `postgres:15` container, using `--clean` when the DB already has tables
  - Uses `rsync` to restore application files back into `/`
  - Cleans up the working directory when finished

