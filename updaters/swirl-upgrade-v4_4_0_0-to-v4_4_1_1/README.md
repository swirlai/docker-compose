
# Swirl Upgrade Guide

## 4.4.0.0 → 4.4.1.1 (Docker Compose)

This package provides a supported upgrade path for Swirl Docker Compose deployments from **v4_4_0_0** to **v4_4_1_1**.

The upgrade is safe, snapshot-based, and preserves your existing configuration.

---

# What This Upgrade Does

The upgrader will:

* Create a backup under `/app/rollback/`
* Preserve your:

  * `.env`
  * `nginx/nginx.template`
  * certificates and runtime data
* Replace support files (compose file, scripts, entrypoints)
* Update container image versions
* Pull new images
* Restart services
* Run required database migrations

Database changes in 4.4.1.1 are additive and backward-compatible.

---

# Prerequisites

* Existing Swirl installation in `/app`
* Docker and Docker Compose installed
* 4.4.1.1 release package unpacked on the host
* Root or sudo access

---

# Unpack the upgrader
```bash
tar -xzf upgrade_v4_4_0_0_to_v4_4_1_1.tar.gz
cd swirl-upgrade-v4_4_0_0-to-v4_4_1_1
```

# Run the Upgrade

1. Stop SWIRL

```bash
sudo systemctl start swirl
```

2. Unpack the 4.4.1.1 release tarball:

```bash
tar -xzf docker-compose-4_4_1_1.tar.gz
```

3. Run the upgrader:

```bash
sudo ./upgrade.sh \
  --app-dir /app \
  --release-dir /path/to/docker-compose-4_4_1_1
```

Example:

```bash
sudo ./upgrade.sh \
  --app-dir /app \
  --release-dir /home/azureuser/docker-compose-4_4_1_1
```

---

# Verify the Upgrade

```bash
cd /app
docker compose ps
```

If needed:

```bash
docker logs swirl_app --tail=200
docker logs swirl_app_init --tail=200
```

---

# Rollback (If Needed)

To revert to the previous version:

```bash
sudo ./rollback.sh --app-dir /app --last
```

This restores the previous configuration and restarts the stack.

---

# Notes

* Customer configuration files are preserved.
* No Docker login is required (images are public).
* The process is repeatable and safe to re-run if necessary.

If you experience any issues, please contact Swirl Support.
