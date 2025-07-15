#!/usr/bin/env bash
set -e

export ENV_FILE="/app/.env"
WORKING_DIR=/tmp/backup$(basename "$BACKUP_FILE"| sed 's/\.tar\.gz$//')
export WORKING_DIR

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
cleanup() {
    rm -rf $WORKING_DIR
    if [ -d $WORKING_DIR ]; then
        error "Failed to clean up working directory $WORKING_DIR"
    else
        info "Cleaned up working directory $WORKING_DIR"
    fi
}

restore_db() {
    # start postgres
    if [ "$USE_LOCAL_POSTGRES" == "true" ]; then
        info "Starting local Postgres."
        pushd /app
        COMPOSE_PROFILES=db docker compose up --pull never -d
        popd
        info "Started local Postgres."
        sleep 15
    fi

  # Locate the latest SQL dump file
  DUMPFILE=$(ls -rt $WORKING_DIR/sql/swirl*sql|tail -n 1)
  if [ -z "$DUMPFILE" ]; then
    find $WORKING_DIR/sql
    error "No SQL dump file found in $WORKING_DIR/sql"
  fi

  # Check if the database has user tables
  TABLE_COUNT=$(docker run --rm \
    --network=app_swirl \
    -e PGPASSWORD=$SQL_PASSWORD \
    postgres:15 \
    psql -h postgres -U postgres -d swirl -t -c "SELECT count(*) FROM pg_tables WHERE schemaname='public';" | xargs)

  if [ "$TABLE_COUNT" -gt 0 ]; then
    CLEAN_FLAG="--clean"
    info "Database is not empty, using --clean for pg_restore"
  else
    CLEAN_FLAG=""
    info "Database is empty, not using --clean for pg_restore"
  fi

  info "Restoring database from $DUMPFILE"

  docker run --rm \
    --network=app_swirl \
    -e PGPASSWORD=$SQL_PASSWORD \
    -e WORKING_DIR=$WORKING_DIR \
    -e DUMPFILE=$DUMPFILE \
    -v $WORKING_DIR:/$WORKING_DIR \
    postgres:15 \
    pg_restore $CLEAN_FLAG -h postgres -U postgres -d swirl -c $DUMPFILE
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
 }

function unpack_archive() {
  : ${ENCRYPTION_PASSWORD:="$ADMIN_PASSWORD"}


  mkdir -p $WORKING_DIR
  info "Decrypting backup file $BACKUP_FILE in $WORKING_DIR"
  gpg --batch --yes \
    --passphrase "$ENCRYPTION_PASSWORD" \
    --output $WORKING_DIR/backup.tar.gz --decrypt $BACKUP_FILE
  pushd $WORKING_DIR
  tar xvfz $WORKING_DIR/backup.tar.gz
}
# ----------------------
# Main
# ----------------------

# variables from env
if [ ! -f $ENV_FILE ]; then
    error "Environment file /app/.env not found. Exiting."
fi
source /app/.env

export BACKUP_FILE=$1
if [ ! -f "$BACKUP_FILE" ]; then
    info "Usage: $0 <backup_file>"
    error "Backup file $BACKUP_FILE not found. Exiting."
fi


# print environment variables
info "Environment variables:"
info "  BACKUP_DIR: $BACKUP_DIR"
info "  DATESTAMP: $DATESTAMP"
info "  ENV_FILE: $ENV_FILE"
info "  WORKING_DIR: $WORKING_DIR"
info "  SQL_FILE: $SQL_FILE"
info "  TAR_FILE: $TAR_FILE"


trap 'cleanup' ERR
# stop Swirl to get a consistent backup
# and to prevent auto restart of containers
systemctl stop swirl
check_environment
unpack_archive
restore_db

info "Restoring application files from $WORKING_DIR/app"
rsync -rvlHtogpc $WORKING_DIR/app /

cleanup
