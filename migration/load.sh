#!/usr/bin/env bash
set -euo pipefail

PROG="$(basename "$0")"

log() {
    echo "[$PROG] $1"
}

log "Starting load process"

PYTHONPATH=. python ./migration/load.py "$@"

log "Completed load process"
