#!/bin/bash
set -e  # Exit the script immediately if any command fails
PROG="$(basename "$0")"
echo $PROG "Starting data extraction process"

echo $PROG "Starting data model object extraction..."
PYTHONPATH=. python ./migration/extract.py
echo $PROG "Completed data model object extraction."
