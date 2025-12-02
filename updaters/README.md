# Updaters
These packages facilitate the updating of a docker-compose environment, such as the SWIRL VM Offer.

- [Versions](#versions)
- [Usage](#usage)
- [Docker Credentials For Updater](#docker-credentials-for-updater)
- [Restoring from Backup](#restoring-from-backup)

## Versions
- [4.2.1](https://github.com/swirlai/docker-compose/raw/main/updaters/update_swirl_4_2_1_0_be59405.tar.gz) supports updating the SWIRL VM Offer from 4.0 - 4.2.0 to 4.2.1

## Usage

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
- Stop the SWIRL services
- Backup the current SWIRL environment to `/app/backup`
    - files beneath `/app`
    - SWIRL database in gpg encrypted tar file using `ADMIN_PASSWORD` from `/app/.env`
- Update `/app/.env`
- Prompt operator to authenticate with Docker hub using
- Pull the updated SWIRL Docker images
- Copy required updated files to `/app`, renaming existing with _backup suffix
- Prompt operator to restart the SWIRL services via `sudo systemctl start swirl`


Please note: the updater results in storage of Docker  credentials in `/root/.docker/config.json` which can be removed after the update is complete.

## Docker Credentials For Updater
The updater's `docker_login.sh` script prompts the operator to authenticate with Docker Hub using a username and
personal access token (PAT). SWIRL support will provide the customer with an account invite and you will want to follow
the [Docker Hub instructions to create a PAT](https://docs.docker.com/security/for-developers/access-tokens/#create-an-access-token).

The basic process is as follows:
1. Login to Docker Hub using the provided account invite
2. Go to [Account Settings](https://hub.docker.com/settings/security)
3. Go to the "Access Tokens" section
4. Create a new Personal Access Token (PAT) with `Read-Only` scope (not the `Public Repo Read-Only` scope)
5. Store that access token securely.
6. Use the username and PAT to authenticate with the updater script when prompted.


## Restoring from Backup
To restore from the backup created during the update process, you can follow these steps:
1. Determine the backup to use from `/app/backup`
2. Restore the files from the backup:
```bash
sudo /app/restore.sh /app/backup/<backup-file>
```

The script will
1. Stop the SWIRL service
2. Verify that the correct offline containers exist
3. Use the `ADMIN_PASSWORD` from `/app/.env` to decrypt the database backup
4. Start postgres and restore the database
5. Restore the files from the backup
6. Cleaup the unencrypted backup files

After the restore is complete, you can restart the SWIRL services via
```bash
sudo systemctl start swirl
```