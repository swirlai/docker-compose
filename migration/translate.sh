#!/usr/bin/env bash
## Example usage
#./migration/translate.sh \
#  -i /app/migration/extract_authenticators_search_providers__name_Azure.json \
#  -o /app/migration/load_azure_auth_sp.json

set -euo pipefail

PROG="$(basename "$0")"

log() {
    echo "[$PROG] $1"
}

log "Starting translation process"

# Forward all args to translate.py
PYTHONPATH=. python ./migration/translate.py "$@"

log "Completed translation process"
