# Overview
Swirl runs in a Docker compose environment controlled by a service. 

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
   - [Setting Up Docker Support on Host OS](../doc/docker-package-setup-ubuntu.md)
   - [Docker Credentials](#docker-credentials)
3. [Service Setup](#service-setup)
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


## Service Setup
On first execution [scripts/swirl-service.sh](../scripts/swirl-service.sh) does the following:
- Optionally downloads Certbot configuration files for TLS setup (when: USE_TLS=true, USE_CERT=false).
- Pulls required Docker images from the Swirl Enterprise Docker registry.
- Configures the service (Systemd for Ubuntu, launchd for MacOS).

See [Controlling Swirl Service](../doc/controlling-swirl-service.md) for more details on how to control the service.


*Note*: The service script creates a `.swirl-service-setup-complete.flag` file to indicate that the setup has been completed. 
If you need to re-run the setup, you can delete this flag file.

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

If you will be using Microsoft as your IDP, configure the following environment variables in the `.env` file:

| Environment Variable | Description |
|----------------------|-------------|
| MSAL_AUTH_AUTHORITY | Authority URL for Microsoft Entra ID authentication. |
| MSAL_AUTH_REDIRECT_URI | Redirect URI for Microsoft Entra ID authentication callback. |
| MS_AUTH_CLIENT_ID | Client ID for Microsoft Entra ID application registration. |
| MICROSOFT_CLIENT_SECRET | Client secret for Microsoft Entra ID application registration. |
| OAUTH_CONFIG_ISSUER | Base URL of the OIDC provider (e.g., Microsoft Entra ID). Used to fetch discovery metadata. |
| OAUTH_CONFIG_REDIRECT_URI | URL where the provider will redirect after authentication (must match app registration). |
| OAUTH_CONFIG_CLIENT_ID | The client (application) ID registered with the identity provider. |
| OAUTH_CONFIG_TOKEN_ENDPOINT | OAuth 2.0 token endpoint URL for exchanging authorization code for tokens. |
| OAUTH_CONFIG_USER_INFO_ENDPOINT | Endpoint to fetch authenticated user's profile information (e.g., name, email). |

Example configuration for Microsoft Application Registration:

```env
MSAL_AUTH_AUTHORITY="https://login.microsoftonline.com/<Tenant ID>/oauth2/v2.0/authorize"
MSAL_AUTH_REDIRECT_URI="https://<SWIRL_FQDN>/galaxy/microsoft-callback"

MS_AUTH_CLIENT_ID="<Application (client) ID>"
MICROSOFT_CLIENT_SECRET="your-client-secret"

OAUTH_CONFIG_ISSUER="https://login.microsoftonline.com/<Tenant ID>/v2.0"
OAUTH_CONFIG_REDIRECT_URI="https://<SWIRL_FQDN>/galaxy/oidc-callback"
OAUTH_CONFIG_CLIENT_ID="<Application (client) ID>"
OAUTH_CONFIG_TOKEN_ENDPOINT="https://login.microsoftonline.com/<Tenant ID>/oauth2/v2.0/token"
```