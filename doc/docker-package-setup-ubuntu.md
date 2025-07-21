# Overview
At present, our recommended Linux distribution for this solution is the
most recent long-term support release of Ubuntu ([24.04 LTS](https://releases.ubuntu.com/noble/)). 


# Ubuntu 24.04 LTS

This [ubuntu24_04.sh](../setup/ubuntu24_04.sh) script automates the setup 
of the official Docker repository and installs Docker-related tools on an 
Ubuntu 24.04 system. Below is a step-by-step explanation of the script:

## Install Prerequisites
```sh
apt-get install -y ca-certificates curl
```
- Installs essential tools:
    - `ca-certificates`: Ensures secure HTTPS communication.
    - `curl`: Used to download files from the internet.

## Add Docker Repository
```sh
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
```
- Creates the directory `/etc/apt/keyrings` with appropriate permissions.
- Downloads the Docker GPG key to `/etc/apt/keyrings/docker.asc`.
- Sets the GPG key file to be readable by all users.

```sh
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null
```
- Adds the Docker repository to the system's package sources:
    - Dynamically determines the system architecture (`dpkg --print-architecture`).
    - Uses the Ubuntu version codename (`VERSION_CODENAME`) from `/etc/os-release`.

## Update Package Index
```sh
apt-get update
```
- Updates the local package index to include the newly added Docker repository.

## Install Docker and Related Tools
```sh
apt-get install -y \
  apt-transport-https \
  software-properties-common \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  certbot \
  docker-compose
```
- Installs the following:
    - `apt-transport-https`: Enables HTTPS for APT.
    - `software-properties-common`: Adds repository management tools.
    - `docker-ce`: Docker Community Edition.
    - `docker-ce-cli`: Command-line interface for Docker.
    - `containerd.io`: Container runtime.
    - `docker-buildx-plugin`: Docker Buildx plugin for advanced builds.
    - `docker-compose-plugin`: Plugin for Docker Compose.
    - `certbot`: Tool for obtaining SSL certificates.
    - `docker-compose`: Standalone Docker Compose tool.

## Apply System Updates
```sh
sudo apt-get install -y
```
- Ensures all system patches and security updates are applied.

# MacOS
For MacOS, the recommended approach is to use [Docker Desktop](https://www.docker.com/products/docker-desktop/). This application provides a
user-friendly interface for managing Docker containers and includes Docker Compose support out of the box.

**Note**: MacOS is defined for development and testing purposes and is not recommended for production use.

