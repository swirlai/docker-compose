#!/usr/bin/env bash

# if ubuntu or debian uninstall golang-docker-credential-helpers if installed
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
        if dpkg -l | grep -q golang-docker-credential-helpers; then
            echo "Uninstalling golang-docker-credential-helpers..."
            dpkg -r --ignore-depends=golang-docker-credential-helpers golang-docker-credential-helpers
        else
            echo "golang-docker-credential-helpers is not installed."
        fi
    fi
fi


# read docker username and password from user interactively
read -p "Enter Docker username: " DOCKER_USERNAME
read -sp "Enter Docker personal access token: " DOCKER_PAT

echo $DOCKER_PAT| docker login -u $DOCKER_USERNAME --password-stdin