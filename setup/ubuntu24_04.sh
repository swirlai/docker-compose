#!/usr/bin/env sh


# Setup Official Docker Repository for later installs
apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update

  # Install required packages
  apt-get install -y \
   apt-transport-https \
   software-properties-common \
   docker-ce \
   docker-ce-cli \
   containerd.io \
   docker-buildx-plugin\
   docker-compose-plugin \
   certbot \
   docker-compose


   # Ensure all patches and security fixes updated
   sudo apt-get install -y