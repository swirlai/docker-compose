# Overview
SWIRL runs in a Docker compose environment controlled by a service.

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
6. [Configuring SWIRL Enterprise](#configuring-swirl-enterprise)
    - [Licensing](#licensing)
7. [Connecting SWIRL to the Enterprise](#connecting-swirl-to-the-enterprise)
    - [Connecting to Microsoft IDP](#connecting-to-microsoft-idp)
    - [Connecting to Google IDP](#connecting-to-google-idp)

## Prerequisites
- Docker Compose installed on the host system. (see [Setting Up Docker Support on Host OS](../doc/docker-package-setup-ubuntu.md))
- Docker login credentials for the SWIRL Enterprise Docker registry.
- Properly configured `.env` file with the required environment variables.

### Docker Credentials
If you do not already have credentials for the SWIRL Enterprise Docker registry,
you can obtain them by contacting SWIRL support(via [email](mailto:hello@swirlaiconnect.com) or [ticket](https://swirlaiconnect.com/support-ticket).

- [Generate a personal access token (PAT)](https://docs.docker.com/security/access-tokens/) [See also](../doc/create-dockerhub-pat.md)
- Login to the SWIRL Enterprise Docker registry either manually or via the [scripts/docker_login.sh](../scripts/docker_login.sh) script
- Install SWIRL Images via the [scripts/scripts/install-docker-images.sh](../scripts/install-docker-images.sh) script

This will cache authentication credentials in the Docker configuration file, allowing the service to pull images from the SWIRL
Enterprise Docker registry without requiring manual login each time.


## TLS Scenarios
### No TLS
In this scenario, the service runs without TLS and can be run with our without Nginx.
If Nginx is not used, the service can be accessed directly via the SWIRL port (default 8000).

This is primarily intended for development and testing purposes.

```bash
USE_CERT=false
USE_NGINX=false
USE_TLS=false
```
When the service starts, certbot is not used, and the service runs without TLS.

Sure — here’s your fragment with **clear, low-key call-outs** added for points **(2)** and **(3)**, without over-dramatizing or sounding like a warning label. This fits well with late-release documentation.

### Bring Your Own Certificate (BYOC)
In this scenario, you provide your own TLS certificate and key files.

```bash
SWIRL_FQDN=<fully qualified domain name for host>
USE_CERT=true
USE_NGINX=true
USE_TLS=true
````

For this to work, the following must be true:

* `SWIRL_FQDN` is set to a valid domain name that points to the host running SWIRL and is resolved by DNS globally.
* Certificate and key files from a Certificate Authority (CA) are available in the following directory:

```bash
<INSTALLATION_DIR>/nginx/certificates/ssl/${SWIRL_FQDN}/
```

* The certificate and key files **must** be named:

  * `ssl_certificate.crt`
  * `ssl_certificate_key.key`

The NGINX server is configured to use these files for HTTPS connections.

> **Important**
> If a deployment is initially configured using Certbot-managed TLS (`USE_CERT=false`), switching later to BYOC (`USE_CERT=true`) requires regeneration of the NGINX configuration. Prior Let’s Encrypt configuration may otherwise remain active and take precedence.

> **Note**
> BYOC deployments are considered an advanced configuration and should be performed with assistance from SWIRL to ensure correct setup.

Routine rotation or update of the certificate and key files is required to maintain a valid TLS connection.


### TLS Configuration with Let's Encrypt & Certbot (optional)
In this scenario, the service uses certbot to automatically obtain a TLS certificate from Let's Encrypt using ACME protocol with HTTP verification.
```bash
SWIRL_FQDN=<fully qualified domain name for host>
USE_CERT=false
USE_NGINX=true
USE_TLS=true
```

For this to work the following must be true:
- `SWIRL_FQDN` is set to a valid domain name that points to the host running SWIRL and is resolved by DNS globally
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

The local docker-compose.yml file for SWIRL Enterprise is configured to use a local instance of PostgreSQL.
If preferred, you can modify the compose file to connect to an external database service.
For production environments, SWIRL recommends using a dedicated PostgreSQL database such as RDS or Azure Flexible Server.


### PostgreSQL

Configure the database environment variables (referenced by a `# CHANGE ME` comment)
in the `.env` file before starting the application:

```env
ADMIN_PASSWORD="" # CHANGE ME  - SWIRL application admin password
SQL_HOST="postgres" # CHANGE ME  - SWIRL DB host name or domain name
SQL_PORT="5432" # CHANGE ME  - SWIRL DB port
SQL_USER="" # CHANGE ME - SWIRL DB User name
SQL_PASSWORD="" # CHANGE ME  - SWIRL DB User password
SQL_SSLMODE="prefer" # CHANGE ME  - SWIRL DB SSL mode
```

> For more information see: [Admin Guide - Configuring Django](https://docs.swirl.today/Admin-Guide.html#configuring-django).

## Configuring SWIRL Enterprise
### Licensing
Add the license provided by SWIRL, to the installation's `.env` file. It will be in the
following format:

```env
SWIRL_LICENSE='{"owner": "<owner-name>", "expiration": "<expiration-date>", "key": "<public-key>"}'
```

**Note: the single quotes wrapping the JSON string are required or the license fails to parse correctly.**


Copy & paste this into the file exactly as it is. SWIRL Enterprise will not operate without the correct license configuration.


# Connecting SWIRL to the Enterprise

## Connecting to Microsoft IDP
1. Create an App Registration according to [these instructions](https://docs.swirlaiconnect.com/M365-Guide.html).

2. Configure and activate the [Microsoft Authenticator in SWIRL](https://docs.swirlaiconnect.com/M365-Guide.html#configure-the-microsoft-authenticator).

3. Edit the following `.env` file entries to included the Microsoft client and tenant IDs:

```sh
# Uncomment and set the following to use Microsoft authentication.
MS_AUTH_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
MS_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

4. Ensure that the `PROTOCOL` and `SWIRL_PORT` values in the `.env` file are set to match the SWIRL homepage URL. For example,

When accessing SWIRL on a local machine:
```sh
PROTOCOL="http"
SWIRL_PORT="8000"
```

When accessing SWIRL through `https` and standard ports:
```sh
PROTOCOL="https"
SWIRL_PORT=""
```

5. Restart the SWIRL service.

## Connecting to Google IDP
1. Create an App Registration according to [these instructions](https://docs.swirlaiconnect.com/GoogleWorkspace-Guide.html).

2. Configure and activate the [Google Authenticator in SWIRL](https://docs.swirlaiconnect.com/GoogleWorkspace-Guide.html#configure-the-google-authenticator).

3. Edit the following `.env` file entry to include the unique portion of the Google client ID only:

```sh
# Uncomment and set the following to use Google authentication.
GOOGLE_AUTH_CLIENT_ID="xxxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxx"
```

*NOTE: Do not include the `.apps.googleusercontent.com` in this entry.  Instead, add only the unique ID value that appears before that in the app registration.*

4. Restart the SWIRL service.
