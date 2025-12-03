#!/usr/bin/env bash
set -e

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR_NAME="$(basename "$PARENT_DIR")"
export PARENT_DIR PARENT_DIR_NAME

BACKUP_DIR="${PARENT_DIR}/backups"
DATESTAMP=$(date +%Y-%b-%d-%H%M)
export BACKUP_DIR DATESTAMP

# variables from env
ENV_FILE="${PARENT_DIR}/.env"
export ENV_FILE

if [ ! -f $ENV_FILE ]; then
    error "Environment file $ENV_FILE not found. Exiting."
fi
source $ENV_FILE



export WORKING_DIR=/tmp/backup.$DATESTAMP
# files for process
export SQL_DUMP_ENV_FILE=sql/$SQL_DATABASE-$DATESTAMP.sql
export TAR_FILE=swirl-backup-$DATESTAMP.tar.gz

# ----------------------
# Functions
# ----------------------

function info() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) INFO] $1"
}

function error() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S) ERROR] $1"
    exit 1
}

# Clean up on errors
function cleanup() {
    rm -rf $WORKING_DIR
    if [ -d $WORKING_DIR ]; then
        error "Failed to clean up working directory $WORKING_DIR"
    else
        info "Cleaned up working directory $WORKING_DIR"
    fi
}

function backup_db() {
    # start postgres
    if [ "$USE_LOCAL_POSTGRES" == "true" ]; then
        info "Starting local Postgres."
        pushd $PARENT_DIR
        COMPOSE_PROFILES=db docker compose up --pull never -d
        popd
        info "Started local Postgres."
        sleep 15
    fi

    info "Starting backup of $SQL_DATABASE to $SQL_DUMP_ENV_FILE"
    pushd $WORKING_DIR
    docker run --rm \
      --network=swirl_network \
      -e PGPASSWORD=$SQL_PASSWORD \
      postgres:15 \
      pg_dump -h postgres -U postgres -d swirl -F c > $SQL_DUMP_ENV_FILE
}

function backup_files() {
  info "Copying $PARENT_DIR directory to $WORKING_DIR"
  FILE_BACKUP_DIR=$WORKING_DIR/$(dirname "$PARENT_DIR")
  mkdir -p $FILE_BACKUP_DIR
  rsync -rvlHtogpc --exclude='backups/*' $PARENT_DIR $FILE_BACKUP_DIR
}

function package_archive() {
  info "Compressing $WORKING_DIR into $TAR_FILE"
  tar cfz $TAR_FILE *
  info "Encrypting backup file $TAR_FILE"
   : ${ENCRYPTION_PASSWORD:="$ADMIN_PASSWORD"}
  echo $ENCRYPTION_PASSWORD | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 $TAR_FILE
  mv $TAR_FILE.gpg $BACKUP_DIR
  rm $TAR_FILE
  info "Backup of $SQL_DATABASE and fileset completed successfully"
  info "   Archive file: $BACKUP_DIR/$TAR_FILE.gpg"

}

function check_environment() {
  # does swirl_postgres container exist?
  if ! docker ps -a --format '{{.Names}}' | grep -q swirl_postgres; then
    error "swirl_postgres container does not exist. Please start the swirl services first."
  fi

  # does swirl_app container exist?
  if ! docker ps -a --format '{{.Names}}' | grep -q swirl_app; then
    error "swirl_app container does not exist. Please start the swirl services first."
  fi

  # Create directories
  mkdir -p $BACKUP_DIR
  mkdir -p $WORKING_DIR/sql
}

# ----------------------
# Main
# ----------------------

# print environment variables
info "Environment variables:"
info "  BACKUP_DIR: $BACKUP_DIR"
info "  DATESTAMP: $DATESTAMP"
info "  ENV_FILE: $ENV_FILE"
info "  WORKING_DIR: $WORKING_DIR"
info "  SQL_DUMP_ENV_FILE: $SQL_DUMP_ENV_FILE"
info "  TAR_FILE: $TAR_FILE"


trap 'cleanup' ERR

# stop SWIRL to get a consistent backup
# and to prevent auto restart of containers
systemctl stop swirl

check_environment
backup_db
backup_files
package_archive
cleanup

# Restart SWIRL service
systemctl start swirl