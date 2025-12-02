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

Clone the docker-compose repository for the version you want to deploy.
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

Then **edit `.env`** to match your desired configuration.

Important notes:

* If **USE_TLS=true** and **USE_NGINX=true**, ensure ports **80** and **443** are open.
* Add DNS entries for the **fully qualified domain name (FQDN)** you will use for accessing SWIRL.

[See Configuration Table for more information](#-general-settings)

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

### 6. Install docker images


```sh
sudo ./scripts/install-docker-images.sh
```

---

### 6. Start SWIRL

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

### 8. Configure ODIC with Microsoft as th IDP (Optional)
1. Create an App Registration according to [instructions](https://docs.swirlaiconnect.com/M365-Guide.html)
2. Update the default SWIRL Microsoft Authenticator [instructions](https://docs.swirlaiconnect.com/M365-Guide.html#configure-the-microsoft-authenticator)
3. Edit the `.env` file entries to included the client ID and tenant :

```sh
# Uncomment and set the following if you want to use Microsoft authentication
MS_AUTH_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
MS_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```
3. In addition, make sure that ```PROTOCOL``` and ```SWIRL_PORT``` are set to match your front page URL,some examples:
If you're accessing SWIRL on your local machine:
```sh
PROTOCOL="http"
SWIRL_PORT="8000"
```

If you're accessing SWIRL through https and standard ports:
```sh
## If your running SWIRL on your local machine:
PROTOCOL="https"
SWIRL_PORT=""
```
TODO : talk about MS authenticator, we do it someplace else in here as well.

# 2. All Configuration Settings (Categorized)

Below are all SWIRL configuration variables, grouped by category.
Any value marked **CHANGE_ME** can be customized.

---

## 🟦 General Settings

Int the env.example file you will see the phrase CHANGE_ME next to several settings. These are settings you should consider changing to customize your deployment.

| Name | Default Value | Comment |
|------|---------------|---------|
| CERTBOT_EMAIL | admin@swirl.today | CHANGE_ME – Email used for Certbot certificate registration |
| CERTBOT_VERSION |  | Certbot version override (optional) |
| NGINX_VERSION |  | Nginx version override (optional) |
| POSTGRES_VERSION | 15 | Version of Postgres used |
| REDIS_VERSION | 7 | Version of Redis used |
| SWIRL_VERSION | v4_3_0_0 | SWIRL release version |
| TIKA_VERSION | v4_3_0_0 | Apache Tika server version |
| TTM_VERSION | v4_3_0_0 | Topic Text Matcher version |
| USE_CERT | false | CHANGE_ME – Enable Bring your own Cert TLS |
| USE_LOCAL_POSTGRES | true | CHANGE_ME – Use local Postgres container,or an external Postgres instance |
| USE_NGINX | false | CHANGE_ME – Enable Nginx reverse proxy, almost always set to true if USE_TLS is true|
| USE_TLS | false | CHANGE_ME – Enable TLS for SWIRL |

---

## 🟩 SWIRL Application Settings

| Name | Default Value | Comment |
|------|---------------|---------|
| ADMIN_USER_EMAIL | "admin@swirl.today" | CHANGE_ME – Django admin email |
| ALLOWED_HOSTS | "localhost,127.0.0.1,swirl," | CHANGE_ME – Comma-separated host list, add your FDQN if you've created a DNS entry for it   |
| AXES_CLIENT_IP_CALLABLE | "" | Optional: Django-Axes IP resolver |
| AZ_GOV_COMPATIBLE | false | CHANGE_ME – Azure GovCloud compatibility, only set if you're deploying unde Azrue Gov restrictions |
| CACHE_REDIS_URL | redis://redis:6379/1 | Cache backend |
| CELERY_BROKER_URL | redis://redis:6379/0 | Celery broker |
| CELERY_RESULT_BACKEND | redis://redis:6379/0 | Celery result backend |
| CSRF_TRUSTED_ORIGINS | "http://localhost:8000" | CHANGE_ME – Allowed origins for CSRF, add your FDQN if you've created a DNS entry for it  |
| GOOGLE_APPLICATION_CREDENTIALS | /app/secrets/google-credentials.json | Path to Google JSON key |
| IN_PRODUCTION | "False" | Production mode toggle |
| LOGIN_REDIRECT_URL | "" | Post-login redirect |
| LOGOUT_REDIRECT_URL | "" | Post-logout redirect |
| PAGE_CACHE_REDIS_URL | redis://redis:6379/7 | Redis cache for pages |
| PGBOUNCER_PRODUCTION | "" | Optional PGBouncer settings |
| PROTOCOL | http | CHANGE_ME – Must match SWIRL UI protocol, change to https if using TLS |
| SEARCH_RESULT_STORE_REDIS_URL | redis://redis:6379/2 | Redis store for search results |
| SEARCH_RESULTS_STORE_TIMEOUT | 300 | Seconds before search results expire |
| SHOULD_USE_TOKEN_FROM_OAUTH | True | Use OAuth token forwarded by client |
| SQL_DATABASE | SWIRL | Database name,, default is set to be compatible with USE_LOCAL_POSTGRES set to true |
| SQL_ENGINE | django.db.backends.postgresql | PostgreSQL engine, default is set to be compatible with USE_LOCAL_POSTGRES set to true |
| SQL_HOST | postgres | CHANGE_ME – Database hostname, default is set to be compatible with USE_LOCAL_POSTGRES set to true |
| SQL_PORT | 5432 | CHANGE_ME – Database port,, default is set to be compatible with USE_LOCAL_POSTGRES set to true |
| SQL_SSLMODE | prefer | CHANGE_ME – SSL mode (prefer/require/disable), default is set to be compatible with USE_LOCAL_POSTGRES set to true |
| SWIRL_ES_VERSION | 8 | Elasticsearch compatibility |
| SWIRL_EXPLAIN | True | Enable explain output |
| SWIRL_FQDN | localhost | CHANGE_ME – Public hostname, set to your FDQN if you've created a DNS entry for it|
| SWIRL_LOG_DEBUG | "" | Enable debug logging |
| SWIRL_LICENSE | '' | CHANGE_ME – Enterprise license key, acquire this from SWIRL, make sure to add it between the single quotes |
| SWIRL_PORT | "8000" | CHANGE_ME - remove if not using localhost directly with no gateway |
| SWIRL_RAG_CHAT_INTERACTION_APPROACH | ChatGAIGuided | RAG conversation approach |
| SWIRL_RAG_DISTRIBUTION_STRATEGY | RoundRobin | RAG distribution strategy |
| SWIRL_SVC | SWIRL | Main service identifier |
| SWIRL_TEXT_SUMMARIZATION_URL | "http://ttm:7029" | Summarization service |
| TIKA_SERVER_ENDPOINT | "http://tika:9998" | Tika server endpoint |

---

## 🟨 Authentication & Identity (OIDC / OAuth)

| Name | Default Value | Comment |
|------|---------------|---------|
| MICROSOFT_CLIENT_ID | "" | Microsoft OAuth client ID, set if you plan to use OIDC with Microsoft as the IDP |
| MICROSOFT_CLIENT_SECRET | "" | Microsoft OAuth client secret, set if you plan to use OIDC with Microsoft as the IDP |
| MICROSOFT_REDIRECT_URI | "" | Microsoft OAuth redirect |
| OIDC_AUTHENTICATION_CALLBACK_URL | "" | OIDC callback URL |
| OIDC_OP_AUTHORIZATION_ENDPOINT | "" | Authorization endpoint |
| OIDC_OP_JWKS_ENDPOINT | "" | JWKS endpoint |
| OIDC_OP_TOKEN_ENDPOINT | "" | Token endpoint |
| OIDC_OP_USER_ENDPOINT | "" | Userinfo endpoint |
| OIDC_RP_CLIENT_ID | "" | RP client ID |
| OIDC_RP_CLIENT_SECRET | "" | RP client secret |
| OIDC_RP_SIGN_ALGO | "" | Signing algorithm |
| OIDC_STORE_ACCESS_TOKEN | "" | Store access token |
| OIDC_STORE_ID_TOKEN | "" | Store ID token |
| OIDC_USERNAME_ALGO | "" | Username generation method |

---

## 🟥 Secrets

| Name | Default Value | Comment |
|------|---------------|---------|
| ADMIN_PASSWORD | "" | CHANGE_ME – Django admin password |
| GOOGLE_CREDENTIALS | "" | CHANGE_ME – Google service account JSON |
| SQL_PASSWORD | "" | CHANGE_ME – PostgreSQL user password |
| SQL_USER | "" | CHANGE_ME – PostgreSQL username |
