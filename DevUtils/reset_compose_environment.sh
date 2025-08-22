#!/usr/bin/env bash


# Stop Swirl
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  systemctl stop swirl
fi

docker-compose --profile all down
# Remove Swirl's Docker containers
docker system prune --force

# Remove Volumes
docker volume prune --force
docker volume rm app_db_data

# Verify that the volumes and containers are removed
docker volume ls
docker ps -a
