# Updaters
These packages facilitate the updating of a docker-compose environment, such as the Swirl VM Offer.

# Versions
- [4.2.1](https://github.com/swirlai/docker-compose/blob/main/updaters/update_swirl_v4_2_1_0_6df2c40.tar.gz) supports updating the Swirl VM Offer from 4.0 - 4.2.0 to 4.2.1

# Usage

1. Copy the updater to the VM /tmp directory
2. Unpack the updater to the /app directory
```bash
cd /app
sudo tar xvfz /tmp/update_swirl_v...tgz
````
3. Run the updater
```bash
sudo /app/update_swirl_v.../update.sh
```

This will perform the following actions:
- Stop the Swirl services
- Backup the current Swirl environment to `/app/backup`
    - files beneath `/app`
    - Swirl database in gpg encrypted tar file using `ADMIN_PASSWORD` from `/app/.env`
- Update `/app/.env`
- Prompt operator to authenticate with docker hub using
- Pull the updated Swirl Docker images
- Copy required updated files to `/app`, renaming existing with _backup suffix
- Prompt operator to restart the Swirl services


