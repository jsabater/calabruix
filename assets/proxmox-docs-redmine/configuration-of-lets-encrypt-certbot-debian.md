# Configuration of Let's Encrypt's Certbot on Debian

*Created on 2021-12-22. Last updated on 2024-11-22.*

Based on Debian 12 Bullseye x86_64 running in a Linux Container (LXC) on Proxmox 7. This tutorial installs Let's Encrypt's Certbot and issues a wildcard certificate for the organisation, which is deployed via *Ansible*.

For our convenience, it is installed under the `ansible` user in the Ansible Controller LXC, but in a separate virtual environment.

## Introduction

> "Certbot is a free, open source software tool for automatically using Let's Encrypt certificates on manually-administered websites to enable HTTPS. Certbot offers domain owners and website administrators a convenient way to move to HTTPS with easy-to-follow, interactive instructions based on your webserver and operating system." - [EFF](https://www.eff.org/)

Although [Certbot's installation instructions](https://certbot.eff.org/instructions) recommend installing [Certbot](https://certbot.eff.org/) using [Snap](https://snapcraft.io/docs/installing-snap-on-debian), we will be creating a Python virtual environment and install it using `pip`. Reasons:

1. Snap requires FUSE.
2. It is not possible to do a backup reliably when a FUSE mount is activated inside the container.
3. Very easy to update using `pip install --upgrade` when new versions are released.

From the [PVE Admin Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#pct_container_storage):

> Because of existing issues in the Linux kernel's freezer subsystem the usage of FUSE mounts inside a container is strongly advised against, as containers need to be frozen for suspend or snapshot mode backups.

From the [Linux Container page](https://pve.proxmox.com/wiki/Linux_Container#_bind_mount_points) of the PVE Wiki:

> Bind mounts are considered to not be managed by the storage subsystem, so you cannot make snapshots or deal with quotas from inside the container. With unprivileged containers you might run into permission problems caused by the user mapping and cannot use ACLs.

## Installation

We will be following the [official Certbot instructions](https://certbot.eff.org/instructions). Install the dependency packages from the main repository:

```bash
apt-get install libaugeas0 python3 python3-venv
```

Become the `ansible` user, then create the virtual environment:

```bash
python3 -m venv ~/venv/certbot
```

Activate the virtual environment:

```bash
source ~/venv/certbot/bin/activate
```

Upgrade *Pip* to the latest version:

```bash
python -m pip install --upgrade pip
```

Install *Certbot* and the *Cloudflare* challenge plug-in:

```bash
python3 -m pip install certbot certbot-dns-cloudflare
```

You can check the installed version with this command:

```bash
# certbot --version
certbot 3.0.1
```

Other DNS Authenticator plug-ins for Certbot, such as those for Hetzner and IONOS, can be searched for at [PyPI](https://pypi.org/) and installed via the following command, if needed.

```bash
source ~/venv/certbot/bin/activate
python3 -m pip install certbot-dns-hetzner certbot-dns-ionos 
```

## Configuration

We will go through a number of steps to set up our Certbot installation.

### Systemd

We will create the *Systemd* service and timer files. As `root` user,
first create the file `/etc/systemd/system/certbot.service` with the
following content:

```systemd
[Unit]
Description="Certbot certificates renewer"
Documentation=https://certbot.eff.org/docs
Wants=certbot.timer
After=network.target

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=2
IOSchedulingPriority=7
User=ansible
Group=ansible
Environment="PATH=/home/ansible/venv/certbot/bin:/usr/local/bin:/usr/bin:/bin"
WorkingDirectory=/home/ansible/
ExecStart=/home/ansible/venv/certbot/bin/certbot renew --quiet
PrivateTmp=true

# Static service (cannot be enabled), so no 'Install' section.
# See: https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units
```

Then create the file `/etc/systemd/system/certbot.timer` with the following content:

```systemd
# Enable and start this timer file

[Unit]
Description="Certbot certificates renewer"

[Timer]
Unit=certbot.service
OnCalendar=*-*-* 04:30:00

[Install]
WantedBy=timers.target
```

Enable the newly created files:

```bash
systemctl enable certbot.timer
```

### Directory structure

*Certbot* expects to be run by the `root` user by default, but can be run as an unprivileged user by specifying a number of parametres. First of all, we will create the necessary structure inside the `ansible` user home folder:

```bash
mkdir --parents ~/letsencrypt/etc
mkdir --parents ~/letsencrypt/log
mkdir --parents ~/letsencrypt/var
```

The following options can be used to instruct *Certbot* to make use of these new locations instead of the default ones:

* `--config-dir`: configuration directory, which defaults to `/etc/letsencrypt`.
* `--work-dir`: working directory, which defaults to `/var/lib/letsencrypt`.
* `--logs-dir`: logging directory, which defaults to `/var/log/letsencrypt`.

So the command would include the options as follows:

```
certbot --config-dir ~/letsencrypt/etc --work-dir ~/letsencrypt/var --logs-dir ~/letsencrypt/log [..]
```

However, there is also the possibility of using a configuration file and store there all the options. As per [the official documentation](https://eff-certbot.readthedocs.io/en/stable/using.html#configuration-file), the following locations are automatically searched for such configuration file:

* `/etc/letsencrypt/cli.ini`
* `$XDG_CONFIG_HOME/letsencrypt/cli.ini` (or `~/.config/letsencrypt/cli.ini` if `$XDG_CONFIG_HOME` is not set).

Since the `$XDG_CONFIG_HOME` variable is not set in the containers, we will create the `~/.config/letsencrypt` subdirectory:

```bash
mkdir --parents ~/.config/letsencrypt
```

And then we will create the file `~/.config/letsencrypt/cli.ini` with the following content:

```conf
agree-tos = true
email = sysadmin@andromedant.com
eff-email = false
config-dir = /home/ansible/letsencrypt/etc
work-dir = /home/ansible/letsencrypt/var
logs-dir = /home/ansible/letsencrypt/log
deploy-hook = /home/ansible/.config/letsencrypt/ansible.deploy

# secp256r1 (P-256), i.e. prime256v1 in openssl, default value
key-type = ecdsa

# Disable the internal Certbot rotation as we will be using logrotate
max-log-backups = 0
```

The deploy hook is a command to be run in a shell once for each successfully issued certificate. For now we will create a dummy `~/.config/letsencrypt/ansible.deploy` file with the following content:

```bash
#!/bin/bash

echo "Executing Certbot's deploy hook ansible.deploy..."
```

And we will give it executable permissions:

```bash
chmod +x ~/.config/letsencrypt/ansible.deploy
```

## Cloudflare DNS challenge

In order to be able to issue certificates using the `dns-cloudflare` plug-in we need an API token. Cloudflare's newer API tokens can be restricted to specific domains and operations. Therefore, they are the recommended authentication option. The token needed by *Certbot* requires `Zone: DNS: Edit` permissions only for the zone we need certificates for, in this case `andromedant.com`.

Configure the plug-in by creating the file `~/.config/letsencrypt/cloudflare-<zone>.com.ini`:

```conf
# Cloudflare API token used by Certbot
dns_cloudflare_api_token = <token secret>
```

Multiple `.ini` files will have to be created, one for each zone:

* `~/.config/letsencrypt/cloudflare-andromedant.com.ini`
* `~/.config/letsencrypt/cloudflare-andronautic.com.ini`

And we will give them very restrictive permissions:

```bash
chmod 400 ~/.config/letsencrypt/cloudflare-*.ini
```

To create an API token for a zone with permissions to edit a DNS zone, we will be following the instructions on the [Creating API tokens page](https://developers.cloudflare.com/api/tokens/create) of Cloudflare's documentation. The creation of the token is done by using the [My Profile: API Tokens page](https://dash.cloudflare.com/profile/api-tokens) on Cloudflare's dashboard. The token should be restricted to the specific zone and only accessible from the public IP range of the cluster.

Only the superadministrator of the account can access such option. Procedure:

* Visit the [API Tokens page](https://dash.cloudflare.com/profile/api-tokens).
* Click on the "Create token" button.
* Select the "Edit zone DNS" template.
* In the "Zone resources" section, select the zone to include from the list.
* In the "Client IP address filtering"", add the public IP range (e.g. `116.202.120.32/28`).
* Copy the generated token and save it into the appropriate `.ini` file.

### Issuing the certificate

We are going to issue a wildcart certificate both for the `andromedant.com` domain and all its subdomains:

```bash
certbot certonly --dns-cloudflare --dns-cloudflare-credentials ~/.config/letsencrypt/cloudflare-andromedant.com.ini \
--preferred-challenges dns-01 --dns-cloudflare-propagation-seconds 30 --domain andromedant.com --domain '*.andromedant.com'
```

The new certificate will be located inside `~/letsencrypt/etc/live/andromedant.com/`.

The `README` file in this directory contains information about each of these files, but the two files we are going to have to deploy to all our containers are:

* `privkey.pem`: The private key of the certificate.
* `fullchain.pem`: The public key of the certificate, bundled with all the intermediate certificates.

We will repeat the operation for the `andronautic.com` domain and all its subdomains (a wildcard certificate `*.andronautic.com`):

```bash
certbot certonly --dns-cloudflare --dns-cloudflare-credentials ~/.config/letsencrypt/cloudflare-andronautic.com.ini \
--preferred-challenges dns-01 --dns-cloudflare-propagation-seconds 30 --domain andronautic.com --domain '*.andronautic.com'
```

Note: If we want to test the process before actually issuing the certificates, we can add the `--dry-run` option to the command.

### Deploying a certificate

Once the certificates have been issued, and every time they are (automatically) renewed, we need to deploy them to the appropriate containers in the cluster. This is done via an Ansible playbook. So, let's add the following content to the deploy hook `~/.config/letsencrypt/ansible.deploy`:

```bash
#!/bin/bash

# Documentation:
# https://eff-certbot.readthedocs.io/en/stable/using.html#certbot-command-line-options
#
# Available environment variables:
# RENEWED_LINEAGE: Points to the config live subdirectory, e.g. ~/letsencrypt/etc/live/example.com
# RENEWED_DOMAINS: Space-delimited list of renewed certificate domains, eg. "example.com www.example.com"

# export ANSIBLE_STDOUT_CALLBACK="dense"
ANSIBLE_DIR="$HOME/ansible/proxmox/guests"
VENV_BIN="$HOME/venv/ansible/bin"
DEPLOY_PLAYBOOK="plays/certs-deploy.yml"

# Import helpers and configuration variables
source $HOME/configs/.slack-config
source $HOME/ansible/proxmox/guests/scripts/slack.bash

echo "Executing Certbot's deploy hook for domain(s) $RENEWED_DOMAINS..."

if [ ! -x "$VENV_BIN/ansible-playbook" ]
then
  echo "$VENV_BIN/ansible-playbook not found or not executable"
  exit 126
fi

if [ ! -f "$ANSIBLE_DIR/$DEPLOY_PLAYBOOK" ]
then
  echo "Playbook $ANSIBLE_DIR/$DEPLOY_PLAYBOOK not found"
  exit 126
fi

echo "Deploying the just-renewed certificates $RENEWED_DOMAINS just renewed across the Proxmox cluster."
slack_send "warning" "Deploying the just-renewed certificates $RENEWED_DOMAINS across the Proxmox cluster."
cd $ANSIBLE_DIR
$VENV_BIN/ansible-playbook $ANSIBLE_DIR/$DEPLOY_PLAYBOOK
```

> Note that the deploy playbook is being executed by the `ansible-playbook` command, which is installed in a different virtual environment.

If we want to test that the renewal hook works, we can always execute it manually, as `certbot` user:

```
~/.config/letsencrypt/ansible.deploy
```

## Useful commands

Some useful commands to help with administration.

### Status check

We can check the status of the services with the following commands:

```systemctl status certbot.service```

### Plug-ins

Available plug-ins can be listed with the following command:

```certbot plugins```

### List timers

Available timers in *Systemd* can also be listed with the following command:

```systemctl list-timers```

### List certificates

Once a certificate has been issued, it's good practice to check that it's actually been generated:

```certbot certificates```

### Test the renewal process

After setting everything up it is good practice to test the renewal process, which can be done with the following command:

```certbot renew --dry-run```

### Force the renewal process

If needed, the renewal process can be force without waiting for the certificate expiration date to arrive:

```certbot renew --force-renewal```

This will also execute the deploy hook, so you can test it.

### Update CA certificates

The `ca-certificates` package must be installed for the *Let's Encrypt* root certificate to be present.

In case any of the certificates in [Let's Encrypt chain of trust](https://letsencrypt.org/certificates/) were to expire, the certificates included in the package can be updated with the following command:

```update-ca-certificates```

### Check the validity of a certificate

Using *OpenSSL* we can check the validity of a certificate by executing the following commands on the Ansible Controller:

```
openssl x509 -in ~/letsencrypt/etc/live/andromedant.com/fullchain.pem -noout -dates
openssl x509 -in ~/letsencrypt/etc/live/andronautic.com/fullchain.pem -noout -dates
```

The certificate is only valid during the period shown (betwen `notBefore` and `notAfter`).

In any guest where the certificates have been deployed, the commands would be:

```
openssl x509 -in /etc/ssl/certs/andromedant.com.crt -noout -dates
openssl x509 -in /etc/ssl/certs/andronautic.com.crt -noout -dates
```

### Check the subject alt names of a certificate

Using *OpenSSL* we can check the subject alt names included in the certificate by executing the following command:

```openssl x509 -in ~/letsencrypt/etc/live/andromedant.com/fullchain.pem -noout -ext subjectAltName```

### Extract the issuer of a certificate

Using *OpenSSL* we can check the issuer of a certificate by executing the following command:

```openssl x509 -in ~/letsencrypt/etc/live/andromedant.com/fullchain.pem -noout -issuer```

### Extract the subject of a certificate

Using *OpenSSL* we can check the subject (the common name) of a certificate by executing the following command:

```openssl x509 -in ~/letsencrypt/etc/live/andromedant.com/fullchain.pem -noout -subject```

### Check that CSR, key and public cert match

```
openssl pkey -in ~/letsencrypt/etc/live/andromedant.com/privkey.pem -pubout -outform pem | sha256sum
openssl x509 -in ~/letsencrypt/etc/live/andromedant.com/fullchain.pem -pubkey -noout -outform pem | sha256sum
openssl req -in ~/letsencrypt/etc/csr/0005_csr-certbot.pem -pubkey -noout -outform pem | sha256sum
```

Deployed certificate:

```
openssl pkey -in /etc/ssl/private/andromedant.com.key -pubout -outform pem | sha256sum
openssl x509 -in /etc/ssl/certs/andromedant.com.crt -pubkey -noout -outform pem | sha256sum
```

### Decode a certificate

Using *OpenSSL* we can decode an entire certificate into plain text by executing the following command:

```openssl x509 -in ~/letsencrypt/etc/live/andromedant.com/fullchain.pem -noout -text```

### Check a Certificate Signing Request (CSR)

```openssl req -text -noout -verify -in ~/letsencrypt/etc/csr/domain.com.csr```

### Check a private key

```openssl rsa -in ~/letsencrypt/etc/live/domain.com/privkey.pem -check```

### Check a certificate

```openssl x509 -in ~/letsencrypt/etc/live/domain.com/fullchain.pem -text -noout```

### Follow the log

```journalctl --unit=certbot.service --since yesterday --follow```
