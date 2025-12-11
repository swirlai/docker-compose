#!/bin/bash
set -e
PROG="$(basename "$0")"

echo $PROG "Starting data translation process"

echo $PROG "Starting data model object translation..."
PYTHONPATH=. python ./migration/translate.py
echo $PROG "Completed data model object translation."
