![Swirl](https://docs.swirl.today/images/transparent_header_3.png)

# Swirl Enterprise Edition
**Notice:** this repository is commercially licensed. A valid license key is required for use.
Please contact [ hello@swirlaiconnect.com](mailto: hello@swirlaiconnect.com) for more information.

# Installation
## Minimum System Requirements
* **OS:** Linux platform (Ubuntu, RHEL) | MacOS X 1
* **Processor:** +8 VCPU
* **Memory:** +16 GB RAM
* **Storage:** 500 GB available space
* **Docker**: 28 or later

> **Note:** Swirl does support use of a proxy server between Swirl and target systems. Refer to section TBD for more information.

## Downloading Swirl Enterprise
### Installing Locally
For proof-of-value (POV) engagements, Swirl recommends cloning this repository locally. Doing so enables Swirl to provide the fastest possible support during the integration period. To clone Swirl Enterprise Compose, run:
```
git clone -b develop https://github.com/swirlai/docker-compose-internal swirl-enterprise-compose
cd swirl-enterprise-compose
```

See Configurations instructions below, after you have configured Swirl, you can run it with the following docker command:
```
docker compose --profile all --env-file .env up -d
```

## Configuring Swirl Enterprise
### Licensing
Add the license provided by Swirl, to the installation's `.env` file. It will be in the following format:
```
SWIRL_LICENSE='{"owner": "<owner-name>", "expiration": "<expiration-date>", "key": "<public-key>"}'
```
Copy & paste this into the file exactly as it is. Swirl Enterprise will not operate without the correct license configuration.

### Database
The local docker-compose.yml file for Swirl Enterprise is configured to use a local instance of PostgreSQL. If preferred, you can modify the compose file to connect to an external database service. For production environments, Swirl recommends using a dedicated PostgreSQL database.

#### PostgreSQL
Configure the database environment variables (referenced by a `# CHANGE_ME` comment) in the `.env` file before starting the application:

```
ADMIN_PASSWORD="" # CHANGE_ME  - Swirl application admin password
SQL_HOST="postgres" # CHANGE_ME  - Swirl DB host name or domain name
SQL_PORT="5432" # CHANGE_ME  - Swirl DB port
SQL_USER="" # CHANGE_ME - Swirl DB User name
SQL_PASSWORD="" # CHANGE_ME  - Swirl DB User password
```

> For more information see: [Admin Guide - Configuring Django](https://docs.swirl.today/Admin-Guide.html#configuring-django).

# Connecting Swirl to the Enterprise
## Connecting to Microsoft IDP
If you will be using Microsoft as your IDP, configure the following environment variables in the `.env` file:
```
OAUTH_CONFIG_ISSUER=''              ## Base URL of the OIDC provider (e.g., Microsoft Entra ID). Used to fetch discovery metadata.
OAUTH_CONFIG_REDIRECT_URI=''        ## URL where the provider will redirect after authentication (must match app registration).
OAUTH_CONFIG_CLIENT_ID=''           ## The client (application) ID registered with the identity provider.
OAUTH_CONFIG_TOKEN_ENDPOINT=''      ## OAuth 2.0 token endpoint URL for exchanging authorization code for tokens.
OAUTH_CONFIG_USER_INFO_ENDPOINT=''  ## Endpoint to fetch authenticated user's profile information (e.g., name, email).
```

# Additional Documentation

[Overview](https://docs.swirlaiconnect.com/) | [Quick Start](https://docs.swirlaiconnect.com/Quick-Start) | [User Guide](https://docs.swirlaiconnect.com/User-Guide) | [Admin Guide](https://docs.swirlaiconnect.com/Admin-Guide) | [M365 Guide](https://docs.swirlaiconnect.com/M365-Guide) | [Developer Guide](https://docs.swirlaiconnect.com/Developer-Guide) | [Developer Reference](https://docs.swirlaiconnect.com/Developer-Reference) | [AI Guide](https://docs.swirlaiconnect.com/AI-Guide)

# Support

For general support, please use the private Slack or Microsoft Teams channel connecting Swirl and your company.
To report an issue please [create a ticket](https://swirlaiconnect.com/support-ticket).