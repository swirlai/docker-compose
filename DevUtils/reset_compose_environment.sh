#!/usr/bin/env bash


# Stop Swirl
systemctl stop swirl

# Remove Swirl's Docker containers
docker system prune --force

# Remove Volumes
docker volume prune --force
docker volume rm app_db_data

# Verify that the volumes and containers are removed
docker volume ls
docker ps -a
