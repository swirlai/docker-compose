#!/bin/bash
set -e
PROG="$(basename "$0")"

echo $PROG "Starting data load process"

echo $PROG "Starting data model object load..."
python /migration/translate.py
echo $PROG "Completed data model object load."
