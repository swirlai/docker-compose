# Setup Instructions

This document explains how to configure and deploy SWIRL in your environment using docker-compose.

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

Copy the example environment file and create a new `.env` file:

```sh
cp env.example .env
```

Then **edit `.env`** to match your desired configuration.

**Important Notes:**
* A valid SWIRL license key is required and must be added to the `.env` file.
* If you set **USE_TLS=true** and **USE_NGINX=true** in the `.env` file, ensure that ports **80** and **443** are both open.
* You must add DNS entries for the **fully qualified domain name (FQDN)** you will use for accessing SWIRL.

---

### 4. Prepare the Host

Run the install script:

```sh
sudo ./scripts/install.sh
```

---

### 5. Authenticate to Docker Hub

Create a [Docker Hub Personal Access Token (PAT)](./create-dockerhub-pat.md) for your Docker Hub user.

Then, run this script to log in using the new PAT:

```sh
sudo ./scripts/docker-login.sh
```

---

### 6. Install the SWIRL Docker images


```sh
sudo ./scripts/install-docker-images.sh
```

---

### 7. Start SWIRL and Monitor Logs

#### **On Linux**

Start SWIRL as a system service:

```sh
sudo systemctl start swirl
```

Monitor all SWIRL logs:

```sh
sudo journalctl -f -u swirl
```

Stop SWIRL as a system service:

```sh
sudo systemctl stop swirl
```

Restart SWIRL as a system service:

```sh
sudo systemctl restart swirl
```

---

#### **On MacOS (Darwin)**

Start SWIRL using `launchctl`:

```sh
launchctl kickstart -k gui/$(id -u)/com.swirl.service
```

Monitor all SWIRL logs:

```sh
tail -f $HOME/tmp/log/swirl-service.out $HOME/tmp/log/swirl-service.err
```

Stop SWIRL using:

```sh
./scripts/stop-swirl.sh
```

SWIRL should now be running and accessible at the configured domain.  Look for a log entry similar to this one indicating the service is available:

```
swirl_app | INFO 2025-12-02 14:33:41 server Listening on TCP address 0.0.0.0:8000
```

---

### Configure OIDC with Microsoft as the IDP (Optional)
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

---

### Configure OIDC with Google as the IDP (Optional)
1. Create an App Registration according to [these instructions](https://docs.swirlaiconnect.com/GoogleWorkspace-Guide.html).

2. Configure and activate the [Google Authenticator in SWIRL](https://docs.swirlaiconnect.com/GoogleWorkspace-Guide.html#configure-the-google-authenticator).

3. Edit the following `.env` file entry to include the unique portion of the Google client ID only:

```sh
# Uncomment and set the following to use Google authentication.
GOOGLE_AUTH_CLIENT_ID="xxxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxx"
```

*NOTE: Do not include the `.apps.googleusercontent.com` in this entry.  Instead, add only the unique ID value that appears before that in the app registration.*

4. Restart the SWIRL service.
