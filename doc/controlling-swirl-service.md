# Overview
SWIRL Enterprise runs in a docker-compose environment which we control
as a Systemd service, and launchctl on Mac OS. This means that you can start, stop, and monitor
using that standard service management interface.


## Starting/Stopping SWIRL Service
To start or stop the SWIRL service, you can use the following commands:

### Linux
```bash
sudo systemctl start swirl
sudo systemctl stop swirl
sudo systemctl restart swirl
```
### MacOS

**Start (manually):**
```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.swirl.service.plist
launchctl kickstart -k gui/$(id -u)/com.swirl.service
```

**Stop:**
```bash
./scripts/swirl-stop.sh
```

### Docker
### Monitoring the Service
To monitor the status of the SWIRL service, you can use:

### Linux
```bash
sudo systemctl status swirl
sudo journalctl -u swirl
```

### MacOS
To check if the service is running:
```bash
launchctl list | grep com.swirl.service
```

To monitor logs (if configured with `StandardOutPath` and `StandardErrorPath`):
```bash
tail -f $HOME/tmp/log/swirl-service.out $HOME/tmp/log/swirl-service.err
```

### Docker Monitoring
As the containers are standard Docker containers, you can also monitor them via
- `docker inspect`
- `docker logs`

## Key Containers
- `swirl_app`: The main SWIRL application container.
- `swirl_app_init`: The initialization container for the SWIRL application (database migrations, etc.).
- `swirl_app_job`: One time execution container to configure superuser and load initial providers.
- `swirl_redis`: The Redis cache container used by the SWIRL application for task queueing and caching.
- `swirl_nginx`: The Nginx reverse proxy container for ingressing traffic to the SWIRL application.
- `swirl_certbot`: The Certbot container for managing TLS certificates via Let's Encrypt ACME.
- `swirl_postgres`: The PostgreSQL database container.