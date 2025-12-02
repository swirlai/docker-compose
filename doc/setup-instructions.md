# Setup Instructions

This document explains how to configure and deploy SWIRL by providing:

- A **Setup Instructions** section to guide you through preparing your environment
- A **complete table of all SWIRL configuration settings**, including defaults and notes (all values marked `CHANGE ME` should be reviewed and may require customization)

---

### 1. Allocate a Host Machine
You may deploy SWIRL on:

- **Linux (Ubuntu 24.04 LTS recommended)**
  - See [Minimum System Requirements](../README.md#minimum-system-requirements)
- **macOS (Darwin)**

---

### 2. Clone the Repository

Clone the docker-compose repository for the version you want to deploy and move into the cloned repository.
Example:

```sh
git clone -b v4_3_0_0 https://github.com/swirlai/docker-compose swirl-enterprise-compose
cd swirl-enterprise-compose
```

---

### 3. Create Your Environment File

Copy the example environment file:

```sh
cp env.example .env
```

Then **edit `.env`** to match your desired configuration. [Use the Configuration Table for guidance](#-general-settings)

Important notes:

* If **USE_TLS=true** and **USE_NGINX=true**, ensure ports **80** and **443** are open.
* Add DNS entries for the **fully qualified domain name (FQDN)** you will use for accessing SWIRL.


---

### 4. Prepare the Host

Run the install script:

```sh
sudo scripts/install.sh
````

---


### 5. Authenticate to Docker Hub

Create a [Docker Hub Personal Access Token (PAT)](./create-dockerhub-pat.md) for your Docker Hub user.

Then log in using it with this script:

```sh
sudo ./scripts/docker-login.sh
```

---

### 6. Install Docker images


```sh
sudo ./scripts/install-docker-images.sh
```

---

### 7. Start SWIRL

#### **On Linux**

To start, stop and monitor it as a system service:

```sh
sudo systemctl start swirl
sudo journalctl -f -u swirl
sudo systemctl stop swirl
```

---

#### **On macOS (Darwin)**

Start SWIRL using `launchctl`:

```sh
launchctl kickstart -k gui/$(id -u)/com.swirl.service
```

Monitor the startup logs:

```sh
tail -f $HOME/tmp/log/swirl-service.out $HOME/tmp/log/swirl-service.err
```

Stop SWIRL using:

```sh
./scripts/stop-swirl.sh
```

SWIRL should now be running and accessible at your configured domain.

---

### Configure ODIC with Microsoft as th IDP (Optional)
1. Create an App Registration according to [these instructions](https://docs.swirlaiconnect.com/M365-Guide.html).
2. Configure and activate the [Microsoft Authenticator in SWIRL](https://docs.swirlaiconnect.com/M365-Guide.html#configure-the-microsoft-authenticator).
3. Edit the following `.env` file entries to included the Microsoft client and tenant IDs:

```sh
# Uncomment and set the following to use Microsoft authentication.
MS_AUTH_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
MS_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```
3. Ensure that the `PROTOCOL` and `SWIRL_PORT` values in `.env` are set to match the SWIRL homepage URL. For example, 

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

---

### Configure ODIC with Google as th IDP (Optional)
1. Create an App Registration according to [these instructions](https://docs.swirlaiconnect.com/GoogleWorkspace-Guide.html).
2. Configure and activate the [Google Authenticator in SWIRL](https://docs.swirlaiconnect.com/GoogleWorkspace-Guide.html#configure-the-google-authenticator).
3. Edit the following `.env` file entry to include the unique portion of the Google client ID only:

```sh
# Uncomment and set the following to use Google authentication.
GOOGLE_AUTH_CLIENT_ID="xxxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxx"
```

*NOTE: Do not include the `.apps.googleusercontent.com` in this entry.  Instead, add only the unique ID value that appears before that in the app registration.*

4. Restart the SWIRL service.

---

# All Configuration Settings (Categorized)

Below are all SWIRL configuration variables, grouped by category.
Any value marked **CHANGE ME** can be customized.

---

🟦 Image & Version Settings
| Name             | Default Value                   | Comment                           |
| ---------------- | ------------------------------- | --------------------------------- |
| CERTBOT_VERSION  |                                 | Optional explicit Certbot version |
| NGINX_VERSION    |                                 | Optional explicit Nginx version   |
| POSTGRES_VERSION | 16                              | Postgres version                  |
| REDIS_VERSION    | 8                               | Redis version                     |
| SWIRL_VERSION    | develop                         | SWIRL version/tag                 |
| SWIRL_PATH       | "swirlai/swirl-search-internal" | Docker image path override        |
| TIKA_VERSION     | v4_3_0_0                        | Apache Tika server version        |
| TTM_VERSION      | v4_3_0_0                        | Topic Text Matcher version        |
| MCP_VERSION      | v1_0_6                          | MCP server version                |

🟩 Ingress / TLS / Certificates
| Name          | Default Value                                 | Comment                                         |
| ------------- | --------------------------------------------- | ----------------------------------------------- |
| USE_CERT      | false                                         | Use bring-your-own certificates                 |
| USE_NGINX     | false                                         | Enable Nginx reverse proxy                      |
| USE_TLS       | false                                         | Enable TLS + Certbot                            |
| CERTBOT_EMAIL | [admin@swirl.today](mailto:admin@swirl.today) | CHANGE ME – Email for Certbot ACME registration |

🟧 SQL Database Settings
| Name                 | Default Value                   | Comment                                         |
| -------------------- | ------------------------------- | ----------------------------------------------- |
| USE_LOCAL_POSTGRES   | true                            | Use bundled Postgres, set false for external DB |
| SQL_HOST             | "postgres"                      | DB host                                         |
| SQL_PORT             | "5432"                          | DB port                                         |
| SQL_SSLMODE          | "prefer"                        | SSL mode for DB                                 |
| SQL_DATABASE         | "swirl"                         | Database name                                   |
| SQL_ENGINE           | "django.db.backends.postgresql" | Django database engine                          |
| PGBOUNCER_PRODUCTION | ""                              | Enable/Configure PgBouncer in production        |

🟪 SWIRL Core Application Settings
| Name                         | Default Value                                    | Comment                                       |
| ---------------------------- | ------------------------------------------------ | --------------------------------------------- |
| ADMIN_USER_EMAIL             | "[admin@swirl.today](mailto:admin@swirl.today)"  | Django admin email                            |
| ALLOWED_HOSTS                | "localhost,127.0.0.1,swirl,"                     | Comma-separated allowed hosts                 |
| CSRF_TRUSTED_ORIGINS         | "[http://localhost:8000](http://localhost:8000)" | CSRF whitelist origins                        |
| SWIRL_FQDN                   | "localhost"                                      | Public hostname / DNS name                    |
| SWIRL_LICENSE                | ''                                               | CHANGE ME – Enterprise license key            |
| PROTOCOL                     | "http"                                           | Change to https when TLS enabled              |
| SWIRL_EXPLAIN                | "True"                                           | Enable explain/debug mode                     |
| AXES_CLIENT_IP_CALLABLE      | ""                                               | IP resolver for Django-Axes                   |
| SWIRL_ES_VERSION             | "8"                                              | Elasticsearch compatibility                   |
| IN_PRODUCTION                | "False"                                          | Production flag controlling SSL/host handling |
| AZ_GOV_COMPATIBLE            | false                                            | Azure GovCloud compatibility mode             |
| SWIRL_LOG_DEBUG              | ""                                               | Enable module-specific debug logs             |
| SHOULD_USE_TOKEN_FROM_OAUTH  | "True"                                           | Propagate OAuth token to providers            |
| SWIRL_SVC                    | "swirl"                                          | Service identifier                            |
| SWIRL_TEXT_SUMMARIZATION_URL | "[http://ttm:7029](http://ttm:7029)"             | Summarizer service endpoint                   |
| TIKA_SERVER_ENDPOINT         | "[http://tika:9998](http://tika:9998)"           | Tika server endpoint                          |

🟩 RAG Configuration
| Name                                | Default Value                          | Comment                                |
| ----------------------------------- | -------------------------------------- | -------------------------------------- |
| SWIRL_RAG_CHAT_INTERACTION_APPROACH | "ChatGAIGuided"                        | Chat interaction strategy              |
| SWIRL_RAG_DISTRIBUTION_STRATEGY     | "RoundRobin"                           | Result generator distribution strategy |
| SWIRL_TEXT_SUMMARIZATION_URL        | "[http://ttm:7029](http://ttm:7029)"   | Summarizer API                         |
| TIKA_SERVER_ENDPOINT                | "[http://tika:9998](http://tika:9998)" | Tika processing endpoint               |

🟥 Celery, Redis, and Cache Settings
| Name                          | Default Value                 | Comment                           |
| ----------------------------- | ----------------------------- | --------------------------------- |
| CACHE_REDIS_URL               | "redis://redis-cache:6379/1"  | Cache redis instance              |
| CELERY_BROKER_URL             | "redis://redis-broker:6379/0" | Celery broker                     |
| CELERY_RESULT_BACKEND         | "redis://redis-broker:6379/0" | Celery result backend             |
| PAGE_CACHE_REDIS_URL          | "redis://redis-cache:6379/7"  | Page cache store                  |
| SEARCH_RESULT_STORE_REDIS_URL | "redis://redis-broker:6379/2" | Search results store              |
| SEARCH_RESULTS_STORE_TIMEOUT  | "300"                         | Timeout for cached search results |

🟦 OIDC / Identity / Authentication
| Name                             | Default Value | Comment                    |
| -------------------------------- | ------------- | -------------------------- |
| GOOGLE_AUTH_CLIENT_ID            | ""            | Google OAuth client ID     |
| MS_AUTH_CLIENT_ID                | ""            | Microsoft OAuth client ID  |
| MS_TENANT_ID                     | ""            | Microsoft tenant           |
| OIDC_AUTHENTICATION_CALLBACK_URL | ""            | OIDC callback              |
| OIDC_OP_AUTHORIZATION_ENDPOINT   | ""            | Auth endpoint              |
| OIDC_OP_JWKS_ENDPOINT            | ""            | JWKS URL                   |
| OIDC_OP_TOKEN_ENDPOINT           | ""            | Token endpoint             |
| OIDC_OP_USER_ENDPOINT            | ""            | Userinfo endpoint          |
| OIDC_RP_CLIENT_ID                | ""            | Relying party client ID    |
| OIDC_RP_CLIENT_SECRET            | ""            | RP secret                  |
| OIDC_RP_SIGN_ALGO                | ""            | Algorithm                  |
| OIDC_STORE_ACCESS_TOKEN          | ""            | Store access token         |
| OIDC_STORE_ID_TOKEN              | ""            | Store ID token             |
| OIDC_USERNAME_ALGO               | ""            | Username generation method |

🟧 MCP (Machine Control Protocol)
| Name               | Default Value | Comment                         |
| ------------------ | ------------- | ------------------------------- |
| SWIRL_MCP_USERNAME | ""            | Username used by MCP server     |
| SWIRL_MCP_PASSWORD | ""            | Password used by MCP server     |
| SWIRL_API_USERNAME | ""            | Username for API-based requests |
| SWIRL_API_PASSWORD | ""            | API user password               |

🟥 Secrets
| Name                           | Default Value | Comment                    |
| ------------------------------ | ------------- | -------------------------- |
| ADMIN_PASSWORD                 | ""            | Django admin password      |
| GOOGLE_CREDENTIALS             | ""            | Google JSON credentials    |
| SQL_PASSWORD                   | ""            | PostgreSQL password        |
| SQL_USER                       | ""            | PostgreSQL username        |
| GOOGLE_APPLICATION_CREDENTIALS | ""            | Path to Google credentials |

🟥 Deprecated Variables
| Name                             | Default Value | Comment           |
| -------------------------------- | ------------- | ----------------- |
| GOOGLE_CREDENTIALS               | ""            | Legacy duplicate  |
| LOGIN_REDIRECT_URL               | ""            | Legacy            |
| LOGOUT_REDIRECT_URL              | ""            | Legacy            |
| MICROSOFT_CLIENT_ID              | ""            | Legacy            |
| MICROSOFT_CLIENT_SECRET          | ""            | Legacy            |
| MICROSOFT_REDIRECT_URI           | ""            | Legacy            |
| MCP_ENABLED                      | false         | Old MCP toggle    |
| MCP_PORT                         | "9000"        | Old MCP port      |
| MCP_SWIRL_BASE_URL               | "0.0.0.0"     | Old MCP base URL  |
| MCP_SWIRL_BASE_PATH              | "/api/swirl"  | Old MCP path      |
| MCP_TIMEOUT                      | "30"          | Old MCP timeout   |
| OIDC_AUTHENTICATION_CALLBACK_URL | ""            | (Duplicate entry) |
| OIDC_OP_AUTHORIZATION_ENDPOINT   | ""            | (Duplicate entry) |
| OIDC_OP_JWKS_ENDPOINT            | ""            | (Duplicate entry) |
| OIDC_OP_TOKEN_ENDPOINT           | ""            | (Duplicate entry) |
| OIDC_OP_USER_ENDPOINT            | ""            | (Duplicate entry) |
| OIDC_RP_CLIENT_ID                | ""            | (Duplicate entry) |
| OIDC_RP_CLIENT_SECRET            | ""            | (Duplicate entry) |
| OIDC_RP_SIGN_ALGO                | ""            | (Duplicate entry) |
| OIDC_STORE_ACCESS_TOKEN          | ""            | (Duplicate entry) |
| OIDC_STORE_ID_TOKEN              | ""            | (Duplicate entry) |
| OIDC_USERNAME_ALGO               | ""            | (Duplicate entry) |
