<img src="https://docs.swirlaiconnect.com/images/swirl-galaxy-logo.svg" alt="SWIRL" width="220">

# SWIRL Enterprise Edition

**Notice:** this repository is commercially licensed. A valid license key is required for use.
Please contact [hello@swirlaiconnect.com](mailto:hello@swirlaiconnect.com) for more information.

There are two ways to run SWIRL Enterprise from this repository:

1. **[Quick Start (evaluation)](#quick-start-evaluation)** — a local install on a Mac or Linux workstation, running in minutes.
2. **[Production deployment](doc/setup-instructions.md)** — a Linux VM with systemd, TLS ingress, and DNS.

See [Monitoring and Logs](#monitoring-and-logs) for watching either kind of deployment.

Product documentation lives at [docs.swirlaiconnect.com](https://docs.swirlaiconnect.com/) — see the [Installation Guide](https://docs.swirlaiconnect.com/Installation) and [Quick Start](https://docs.swirlaiconnect.com/Quick-Start-Enterprise).

# Quick Start (evaluation)

```sh
git clone https://github.com/swirlai/docker-compose swirl-enterprise-compose
cd swirl-enterprise-compose
cp env.example .env
```

Edit `.env` and set the REQUIRED values: `SWIRL_LICENSE` (the signed license JSON from SWIRL), `ADMIN_PASSWORD`, `SQL_USER`, and `SQL_PASSWORD`. To enable the MCP server, also set `MCP_ENABLED=true` and `SWIRL_MCP_TOKEN`.

```sh
docker compose pull
docker compose up -d
docker compose logs -f swirl-init   # watch the one-time database setup complete
```

Then open [http://localhost:8000/galaxy/](http://localhost:8000/galaxy/) and log in as `admin` with the `ADMIN_PASSWORD` you set.

# Monitoring and Logs

**Quick Start (docker compose)** — from this directory:

```sh
docker compose logs -f              # all services, follow
docker compose logs -f swirl        # the SWIRL app only
docker compose logs swirl-init     # one-time database setup
docker compose logs swirl-job      # one-time seed/config job
```

**Application log files** — bind-mounted to `logs/` in this checkout, so you can tail them directly on the host:

```sh
tail -f logs/django.log                  # web/API server
tail -f logs/celery-search-worker.log    # federated search execution
```

Also present: `celery-pagefetch-worker.log`, `celery-interactive-worker.log`, `celery-maintenance-worker.log`, `celery-healthcheck-worker.log`, and `celery-beats.log`.

**Production (systemd service)**:

```sh
sudo journalctl -f -u swirl
```

**In the browser**: administrators can watch live logs in the Business Console [Log Viewer](https://docs.swirlaiconnect.com/Admin-Guide#log-viewer).

# Installation

## Minimum System Requirements

### Linux

- **OS:** Linux platform (Ubuntu, RHEL)
- **Processor:** +8 VCPU
- **Memory:** +16 GB RAM
- **Storage:** 500 GB available space
- **Docker**: v28 or later

### MacOS

- **OS:** MacOS 14.5 Sonoma or later
- **Processor:** Apple Silicon (M1 or later)
- **Memory (RAM):** 8 GB minimum (16 GB recommended)
- **Storage:** 100 GB of available disk space for installation
- **Docker**: v27.3.1 or later

# Production Setup Documentation
- [Production Deployment (Linux VM + systemd)](doc/setup-instructions.md)
- [Downloading SWIRL Enterprise](doc/downloading-swirl-enterprise-docker-environment.md)
- [Description of Docker Support Installation Script](doc/docker-package-setup-ubuntu.md)
- [Details of Setting up the SWIRL Service](doc/service-setup.md)
  - [TLS Scenarios](doc/service-setup.md#tls-scenarios)
    - [No TLS](doc/service-setup.md#no-tls)
    - [Bring Your Own Certificate (BYOC)](doc/service-setup.md#bring-your-own-certificate-byoc)
    - [TLS Configuration with Let's Encrypt & Certbot (optional)](doc/service-setup.md#tls-configuration-with-lets-encrypt--certbot-optional)
  - [License](doc/service-setup.md#licensing)
  - [Database](doc/service-setup.md#database)
    - [PostgreSQL](doc/service-setup.md#postgresql)
  - [Connecting SWIRL to the Enterprise](doc/service-setup.md#connecting-swirl-to-the-enterprise)
    - [Connecting to Microsoft IDP](doc/service-setup.md#connecting-to-microsoft-idp)
    - [Connecting to Google IDP](doc/service-setup.md#connecting-to-google-idp)
- [Controlling SWIRL Service](doc/controlling-swirl-service.md)
- [Configuring the SWIRL MCP Server (optional)](doc/mcp-setup.md)

# SWIRL Documentation

[Overview](https://docs.swirlaiconnect.com/) | [Quick Start](https://docs.swirlaiconnect.com/Quick-Start) | [User Guide](https://docs.swirlaiconnect.com/User-Guide) | [Admin Guide](https://docs.swirlaiconnect.com/Admin-Guide) | [M365 Guide](https://docs.swirlaiconnect.com/M365-Guide) | [Developer Guide](https://docs.swirlaiconnect.com/Developer-Guide) | [Developer Reference](https://docs.swirlaiconnect.com/Developer-Reference) | [AI Search Guide](https://docs.swirlaiconnect.com/AI-Search.html) | [AI Search Assistant Guide](https://docs.swirlaiconnect.com/AI-Search-Assistant.html)

# Support

For general support, please use the private Slack or Microsoft Teams channel connecting SWIRL and your company.
To report an issue please [create a ticket](https://swirlaiconnect.com/support-ticket).
