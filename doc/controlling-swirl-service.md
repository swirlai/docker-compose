# Overview
Swirl Enterprise runs in a docker-compose environment which we control
as a Systemd service. This means that you can start, stop, and monitor
using that standard service management interface.


## Starting/Stopping Swirl Service
To start or stop the Swirl service, you can use the following commands:

### Linux
```bash
sudo systemctl start swirl
sudo systemctl stop swirl
sudo systemctl restart swirl
```
### Docker
### Monitoring the Service
To monitor the status of the Swirl service, you can use:

### Linux
```bash
sudo systemctl status swirl
sudo journalctl -u swirl
```

### Docker Monitoring
As the containers are standard docker containers, you can also monitor them via
- `docker inspect`
- `docker logs`

## Key Containers
- `swirl_app`: The main Swirl application container.
- `swirl_app_init`: The initialization container for the Swirl application (database migrations, etc.).
- `swirl_app_job`: One time execution container to configure superuser and load initial providers.
- `swirl_redis`: The Redis cache container used by the Swirl application for task queueing and caching.
- `swirl_nginx`: The Nginx reverse proxy container for ingressing traffic to the Swirl application.
- `swirl_certbot`: The Certbot container for managing TLS certificates via Let's Encrypt ACME.
- `swirl_postgres`: The PostgreSQL database container.