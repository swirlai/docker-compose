#!/bin/bash
set -e
PROG="$(basename "$0")"

echo $PROG "Starting data load process"

echo $PROG "Starting data model object load..."
PYTHONPATH=. python ./migration/load.py
echo $PROG "Completed data model object load."
