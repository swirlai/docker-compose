#!/bin/bash
set -e  # Exit the script immediately if any command fails
PROG="$(basename "$0")"

echo $PROG "Show all docker containers"
sudo docker docker ps -a

echo $PROG "Show docker networks"
sudo docker network ls
