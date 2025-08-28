![Swirl](https://docs.swirl.today/images/transparent_header_3.png)

# Swirl Enterprise Edition

**Notice:** this repository is commercially licensed. A valid license key is required for use.
Please contact [hello@swirlaiconnect.com](mailto:hello@swirlaiconnect.com) for more information.

# Table of Contents
1. [Installation](#installation)
    - [Minimum System Requirements](#minimum-system-requirements)
    - [Installation Steps](#installation-steps)
    - [Configuring Swirl Enterprise](#configuring-swirl-enterprise)
    - [Controlling and Monitoring Swirl Service](#controlling-and-monitoring-swirl-service)
2. [Additional Documentation](#additional-documentation)
3. [Support](#support)

# Installation

## Minimum System Requirements

* **OS:** Linux platform (Ubuntu, RHEL)
* **Processor:** +8 VCPU
* **Memory:** +16 GB RAM
* **Storage:** 500 GB available space
* **Docker**: v28 or later

> **Note:** Swirl does support use of a proxy server between Swirl and target systems. Refer to section TBD for more information.

## Installation Steps
- [Downloading Swirl Enterprise](doc/downloading-swirl-enterprise-docker-environment.md)
- [Setting up Docker Support on Host OS](doc/docker-package-setup-ubuntu.md)
- [Setting up the Swirl Service](doc/service-setup.md)
- [Controlling Swirl Service](doc/controlling-swirl-service.md)


## Configuring Swirl Enterprise
- [TLS Scenarios](doc/service-setup.md#tls-scenarios)
    - [No TLS](doc/service-setup.md#no-tls)
    - [Bring Your Own Certificate (BYOC)](doc/service-setup.md#bring-your-own-certificate-byoc)
    - [TLS Configuration with Let's Encrypt & Certbot (optional)](doc/service-setup.md#tls-configuration-with-lets-encrypt--certbot-optional)
- [License](doc/service-setup.md#licensing)
- [Database](doc/service-setup.md#database) 
    - [PostgreSQL](doc/service-setup.md#postgresql)
- [Connecting Swirl to the Enterprise](doc/service-setup.md#connecting-swirl-to-the-enterprise)
    - [Connecting to Microsoft IDP](doc/service-setup.md#connecting-to-microsoft-idp)

## Controlling and Monitoring Swirl Service
- [Controlling Swirl Service](doc/controlling-swirl-service.md)
    - Start, stop, and restart the Swirl service.
    - View logs and status of the service.
    - Manage service configuration.

# Downloads
- [Swirl Enterprise Edition Docker Environment 4.3.0 tar file](https://github.com/swirlai/docker-compose/archive/refs/tags/v4_3_0_0.tar.gz)

# Additional Documentation

[Overview](https://docs.swirlaiconnect.com/) | [Quick Start](https://docs.swirlaiconnect.com/Quick-Start) | [User Guide](https://docs.swirlaiconnect.com/User-Guide) | [Admin Guide](https://docs.swirlaiconnect.com/Admin-Guide) | [M365 Guide](https://docs.swirlaiconnect.com/M365-Guide) | [Developer Guide](https://docs.swirlaiconnect.com/Developer-Guide) | [Developer Reference](https://docs.swirlaiconnect.com/Developer-Reference) | [AI Search Guide](https://docs.swirlaiconnect.com/AI-Search.html) | [AI Search Assistant Guide](https://docs.swirlaiconnect.com/AI-Search-Assistant.html)

# Support

For general support, please use the private Slack or Microsoft Teams channel connecting Swirl and your company.
To report an issue please [create a ticket](https://swirlaiconnect.com/support-ticket).
