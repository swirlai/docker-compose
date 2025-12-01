# Overview
Swirl runs in a Docker compose environment controlled by a service.

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
   - [Setting Up Docker Support on Host OS](../doc/docker-package-setup-ubuntu.md)
   - [Docker Credentials](#docker-credentials)
3. [Service Setup Instructions](../doc/setup-instructions.md)
4. [TLS Scenarios](#tls-scenarios)
    - [No TLS](#no-tls)
    - [Bring Your Own Certificate (BYOC)](#bring-your-own-certificate-byoc)
    - [TLS Configuration with Let's Encrypt & Certbot (optional)](#tls-configuration-with-lets-encrypt--certbot-optional)
5. [Database](#database)
   - [PostgreSQL](#postgresql)
6. [Configuring Swirl Enterprise](#configuring-swirl-enterprise)
    - [Licensing](#licensing)
7. [Connecting Swirl to the Enterprise](#connecting-swirl-to-the-enterprise)
    - [Connecting to Microsoft IDP](#connecting-to-microsoft-idp)

## Prerequisites
- Docker Compose installed on the host system. (see [Setting Up Docker Support on Host OS](../doc/docker-package-setup-ubuntu.md))
- Docker login credentials for the Swirl Enterprise Docker registry.
- Properly configured `.env` file with the required environment variables.

### Docker Credentials
If you do not already have credentials for the Swirl Enterprise Docker registry,
you can obtain them by contacting Swirl support(via [email](mailto:hello@swirlaiconnect.com) or [ticket](https://swirlaiconnect.com/support-ticket).

- [Generate a personal access token (PAT)](https://docs.docker.com/security/access-tokens/)
- Login to the Swirl Enterprise Docker registry either manually or via the [scripts/docker_login.sh](../scripts/docker_login.sh) script

This will cache authentication credentials in the Docker configuration file, allowing the service to pull images from the Swirl
Enterprise Docker registry without requiring manual login each time.


## TLS Scenarios
### No TLS
In this scenario, the service runs without TLS and can be run with our without Nginx.
If Nginx is not used, the service can be accessed directly via the Swirl port (default 8000).

This is primarily intended for development and testing purposes.

```bash
USE_CERT=false
USE_NGINX=true
USE_TLS=false
```
When the service starts, certbot is not used, and the service runs without TLS.

### Bring Your Own Certificate (BYOC)
In this scenario, you provide your own TLS certificate and key files.
```bash
SWIRL_FQDN=<fully qualified domain name for host>
USE_CERT=true
USE_NGINX=true
USE_TLS=true
```

For this work, the following must be true:
- `SWIRL_FQDN` is set to a valid domain name that points to the host running Swirl and is resolved by DNS globally
- Certificate and key files from a Certificate Authority (CA) are available in the following directory:
```bash
<INSTALLATION_DIR>/nginx/certificates/ssl/${SWIRL_FQDN}/
```

The Nginx server is configured to use these files for HTTPS connections. The certificate and
key files should be named `fullchain.pem` and `privkey.pem`, respectively.

Routine rotation/update of the certificate and key files is required to maintain a valid TLS connection.

### TLS Configuration with Let's Encrypt & Certbot (optional)
In this scenario, the service uses certbot to automatically obtain a TLS certificate from Let's Encrypt using ACME protocol with HTTP verification.
```bash
SWIRL_FQDN=<fully qualified domain name for host>
USE_CERT=false
USE_NGINX=true
USE_TLS=true
```

For this to work the following must be true:
- `SWIRL_FQDN` is set to a valid domain name that points to the host running Swirl and is resolved by DNS globally
- Port 80 and 443 must be open and accessible from the internet

When the system starts, certbot:
1. Generates a token
2. Makes the token available via a well-known HTTP path
3. Generates a TLS certificate request for the specified domain name
4. Sends the request to Let's Encrypt

Let's Encrypt then:
1. Checks the token against the well-known HTTP path using the SWIRL_FQDN domain name to prove ownership
2. If the token is valid, it issues a TLS certificate

Certbot stores the certificate in the `certbot/conf` directory, which is mounted into the Nginx container. The Nginx
server is configured to use this certificate for HTTPS connections.

This process repeats every 60 days to ensure the certificate remains valid.


FYI, on first execution [scripts/swirl-service.sh](../scripts/swirl-service.sh) executes the following steps to populate
the `certbot/conf` directory with the necessary configuration files for Certbot:
```bash
mkdir -p certbot/conf
curl -o certbot/conf/options-ssl-nginx.conf https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
curl -o certbot/conf/ssl-dhparams.pem https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem
```

## Database

The local docker-compose.yml file for Swirl Enterprise is configured to use a local instance of PostgreSQL.
If preferred, you can modify the compose file to connect to an external database service.
For production environments, Swirl recommends using a dedicated PostgreSQL database such as RDS or Azure Flexible Server.


### PostgreSQL

Configure the database environment variables (referenced by a `# CHANGE_ME` comment)
in the `.env` file before starting the application:

```env
ADMIN_PASSWORD="" # CHANGE_ME  - Swirl application admin password
SQL_HOST="postgres" # CHANGE_ME  - Swirl DB host name or domain name
SQL_PORT="5432" # CHANGE_ME  - Swirl DB port
SQL_USER="" # CHANGE_ME - Swirl DB User name
SQL_PASSWORD="" # CHANGE_ME  - Swirl DB User password
SQL_SSLMODE="prefer" # CHANGE_ME  - Swirl DB SSL mode
```

> For more information see: [Admin Guide - Configuring Django](https://docs.swirl.today/Admin-Guide.html#configuring-django).

## Configuring Swirl Enterprise
### Licensing
Add the license provided by Swirl, to the installation's `.env` file. It will be in the
following format:

```env
SWIRL_LICENSE='{"owner": "<owner-name>", "expiration": "<expiration-date>", "key": "<public-key>"}'
```

**Note: the single quotes wrapping the JSON string are required or the license fails to parse correctly.**


Copy & paste this into the file exactly as it is. Swirl Enterprise will not operate without the correct license configuration.


# Connecting Swirl to the Enterprise

## Connecting to Microsoft IDP

If you will be using Microsoft as your IDP, you need to complete the following configuration steps:

1. [Create a App Registration in your Microsoft Tenant. Note the Client Id, the tenant ID, and the Client Secrete](https://docs.swirlaiconnect.com/M365-Guide.html)
2. [Start Swirl and update the Microsoft Authentication Provider, filling in the Client and and Secrete](https://docs.swirlaiconnect.com/M365-Guide.html)
3. Configure the following environment variables in the `.env` file:

| Environment Variable | Description |
|----------------------|-------------|
| MS_AUTH_CLIENT_ID | Client ID for Microsoft Entra ID application registration. |
| MS_TENANT_ID | Tenant ID for Microsoft Entra ID application registration. |

Example configuration for Microsoft Application Registration:

```env
MS_AUTH_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
MS_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```