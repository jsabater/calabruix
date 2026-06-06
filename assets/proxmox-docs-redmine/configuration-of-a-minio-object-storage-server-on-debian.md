# Configuration of MinIO Object Storage server on Debian

*Created on 2022-12-03. Last updated on 2024-09-19.*

**This document is now deprecated. Installation is done via Ansible playbook.**

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC).

## Base system configuration

Follow the steps in the \[\[Debian Bullseye 11 LXC base system configuration\]\] tutorial.

## Installation

Download and install the latest version of the server from [*MinIO*'s official packages repository](https://dl.min.io/):

```bash
wget https://dl.min.io/server/minio/release/linux-amd64/minio.deb
wget https://dl.min.io/client/mc/release/linux-amd64/mc.deb
dpkg -i minio.deb mc.deb
```

You can check for the latest version at the [downloads page](https://min.io/download#/linux) and you can browse the source code at their [Github repository](https://github.com/minio/minio).

For security reasons, we'll be running *MinIO* under a normal user account, not `root`. So let's create a `minio-user` system account, which includes the user and group, without the ability to log in:

    useradd --system minio-user --shell /sbin/nologin

Change ownership of the `minio` executable to the newly-created user:

    chown minio-user:minio-user /usr/local/bin/minio

Now we will create a directory where *MinIO* will store its files and we will give ownership of it to the `minio` user. This will be the storage location for the buckets that we will use later to organize the objects we store on our server:

    mkdir /usr/local/share/minio
    chown minio-user:minio-user /usr/local/share/minio

Create the configuration directory and give it ownership to the `minio-user` user:

    mkdir /etc/minio
    chown minio-user:minio-user /etc/minio

This configuration directory will not be used to store actual configuration files, since they are stored in the backend, but just to later create the `certs/` subdirectory inside it. The only options *MinIO* will take into consideration at launch are those set as environment variables in `/etc/default/minio`.

## Configuration

Create the `/etc/default/minio` environment file with the parameters needed to start the service:

```bash
MINIO_SERVER_URL="https://minio1.andromedant.com:9000"
MINIO_BROWSER_REDIRECT_URL="https://minio.andromedant.com"
MINIO_BROWSER=on
MINIO_ROOT_USER="minio"
MINIO_ROOT_PASSWORD="lw19dPsdKPrJisJtkFIo0OSb6EAkOqkC"
MINIO_VOLUMES="/usr/local/share/minio/"
MINIO_OPTS="--certs-dir /etc/minio/certs --address ':9000' --console-address ':9090'"

# Data compression disabled as ZFS will take care of that
MINIO_COMPRESSION_ENABLE=off

# Enable public access to Prometheus metrics
MINIO_PROMETHEUS_AUTH_TYPE="public"

# Virtual Host-style requests to the MinIO deployment
# See: https://min.io/docs/minio/linux/reference/minio-server/settings/core.html#domain
# MINIO_DOMAIN=s3.andronautic.com

# See https://min.io/docs/minio/linux/operations/install-deploy-manage/deploy-minio-multi-node-multi-drive.html#deploy-distributed-minio
# MINIO_SERVER_URL="https://minio.andromedant.com:9000"
# MINIO_VOLUMES="https://minio{1...2}.andromedant.com:9000/usr/local/share/minio/"
# MINIO_OPTS="--certs-dir /etc/minio/certs --address :9000 --console-address :9090"
```

Make sure access to the file we just created is restricted:

```bash
chmod 640 /etc/default/minio
```

The *Systemd* service file `/lib/systemd/system/minio.service` starts the *MinIO* server using the `minio-user` user that we created earlier. It also implements the environment variables that we set in `/etc/default/minio` and allows the server to run automatically on startup.

Enable *MinIO* to start on boot:

```bash
systemctl enable minio
```

Verify *MinIO*'s status, the IP address it's bound to, its memory usage and more by running this command:

```bash
systemctl status minio
```

Regarding `MINIO_BROWSER_REDIRECT_URL`, we will be using two different addresses to server content and to access the admin console:

  ------------------------------- ------------------------------------- ------------------------------------------------
  **URL**                         **Proxied to**                        **Description**
  https://s3.andronautic.com      https://minio1.andromedant.com:9000   Public URL to serve content from
  https://minio.andromedant.com   https://minio1.andromedant.com:9090   Public URL address to access the admin console
  ------------------------------- ------------------------------------- ------------------------------------------------

### Server package update

Every time we install an update via `wget` and `dpkg`, we will have to request *Systemd* to reload the manager configuration:

    systemctl daemon-reload

After that we can restart the daemon for the new version to take effect:

    systemctl restart minio

## Certificates

By default, the *MiniIO* does not encrypt the communication channel. Given that our containers are not in a private, secure network, we are going to use a valid certificate and force clients to use an encrypted channel.

In order to have a certificate issued by a valid Certificate Authority, we will use the [Certbot](https://certbot.eff.org/) to create a valid SSL certificate signed by [Let's Encrypt](https://letsencrypt.org/). We will be using a centralised installation of *Certbot*, as described in the \[\[Configuration of Let's Encrypt's Certbot on Debian 11 Bullseye\]\] guide. In order to deploy the issued wildcard certificate, we will be using *Ansible*, as described in the \[\[Configuration of Ansible on Debian 11 Bullseye\]\].

Since we used the `--certs-dir` flag in the `/etc/default/minio` config file, *MinIO* expects the certificates to be located at `/etc/minio/certs/`. Inside this directory, the private key must by named `private.key` and the public key must be named `public.crt`.

When the certificate is deployed via *Ansible*, it will restart the service and *MinIO* will automatically detect and use them.

## Firewall

Make sure access to ports 9000 and 9090 is enabled. On the LXC firewall, add this rule:

  ----------------- ---------- ------------ ----------- --------------- -------------- ------------------------- ----------------- ----------------- ---------------------- --------------- -----------------------------------------
  **Level**         **Type**   **Action**   **Macro**   **Interface**   **Protocol**   **Source**                **Source port**   **Destination**   **Destination port**   **Log level**   **Comment**
  CT`<id>`{=html}   in         ACCEPT                   net0            tcp            ipv4_private_webservers                                       9000,9090              nolog           Allow traffic to MiniIO from webservers
  ----------------- ---------- ------------ ----------- --------------- -------------- ------------------------- ----------------- ----------------- ---------------------- --------------- -----------------------------------------

## Nginx as proxy

*Nginx* is a web and reverse proxy server that we will use to proxy petitions to our *MinIO* server so that:

1.  It is not directly exposed to the Internet.
2.  We don't need a public IP in the container.

Refer to the \[\[Configuration of an Nginx proxy server for MinIO on Debian 11 Bullseye\]\] to set it up.

## Web object browser

Since we installed the SSL certificate, any attempt at accessing the location http://minio1.andromedant.com:9000/ should return the following error:

    Client sent an HTTP request to an HTTPS server.

So, to access the web based object browser point the browser at the location https://minio1.andromedant.com:9000/. You should be redirected to the address https://minio1.andromedant.com:9090/login, where you will use the root user and root password previously set up in the `/etc/default/minio` file to log in.

## Client

*MinIO* Client (`mcli`) provides a fully-featured console command tool to administrate the server, which also offers a modern alternative to classic Linux commands like `ls`, `cat`, `cp`, `mirror`, `diff` or `find`. And it can work both on the local filesystem and remotely (on S3-compatible cloud storage services).

To install it, follow these steps:

    https_proxy=http://proxy.andromedant.com:8080  wget https://dl.min.io/client/mc/release/linux-amd64/mcli_<version>_amd64.deb
    dpkg -i mcli_<version>_amd64.deb

The first step we are going to take is to configure an alias to be able to log into the server with just one quick `alias` command:

    mcli alias set <alias> <host> <user> <password>

Where `user` and `password` are the `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` set up earlier in the `/etc/default/minio` file. So, the end command would be something like:

    ~# mcli alias set minio1 https://minio1.andromedant.com:9000/ minio <password>
    Added `minio1` successfully.

Note: `<host>` cannot be the localhost because the SSL certificate was issued for the host `minio1.andromedant.com`.

Note: Make sure that the environment variable `HTTP_PROXY` is not set when running the console client, otherwise it will try to use it and the behaviour can be erratic.

We can now operate on the server from the console without the need to provide credentials, using the `minio1` alias instead:

    mcli ls minio1

Check the [list of available commands](https://min.io/docs/minio/linux/reference/minio-mc.html) of the console client:

    mcli --help

We can enable shell autocompletion for the console client with the following command:

    ~# mcli --autocompletion
    mcli: Your shell is set to '/bin/bash', by env var 'SHELL'.
    mcli: enabled autocompletion in your 'bash' rc file. Please restart your shell.

Log out, then log back in and autocompletion will be active.

## Buckets

As per the [Amazon S3 REST API](https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html), objects are stored inside buckets, access to which can be public or private (only through an API key). Inside each bucket a classic UNIX structure of subdirectories and files can be created.

Let's create our first bucket:

    ~# mcli mb minio1/wallpapers
    Bucket created successfully `minio1/wallpapers`.

We can enable [versioning](https://min.io/docs/minio/linux/administration/object-management/object-versioning.html#minio-bucket-versioning) on the bucket so that files will not be deleted or overwritten accidentally:

    ~# mcli version enable minio1/wallpapers
    minio1/wallpapers versioning is enabled

Now we will be able to delete versions older than a number of days:

    mcli rm --recursive --dangerous --force --older-than 90d minio1

Now let's create a subdirectory inside it:

    mcli mb minio1/wallpapers/linux
    Bucket created successfully `minio1/wallpapers/linux`.

The default policy on buckets is `none` (private). We can can change that using the `anonymous` command:

    ~# mcli anonymous set download minio1/wallpapers
    Access permission for `minio1/wallpapers` is set to `download`

Now unauthenticated users can execute a GET operation on the objects inside that bucket, but only authenticated users can execute PUT operations.

We can check the policy of the bucket:

    ~# mcli stat minio1/wallpapers
    Name      : wallpapers/
    Size      : 0 B    
    Type      : folder 
    Metadata  :
      Versioning: Enabled
      Location: Europe
      Policy: readonly

## Working with objects

Let's now add some images in. Let's say they have been temporarily extracted into `/tmp/` from an archive. We are going to use the `cp` command to copy the file into the object repository and also take the chance to tag it:

    ~# mcli cp --tags "os=Linux&year=2001" /tmp/TuXperience.jpg minio1/wallpapers/linux/
    ...TuXperience.jpg:  60.70 KiB / 60.70 KiB ┃▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓┃ 3.26 MiB/s 0s

The file is now accessible from the following URL: https://s3.andronautic.com/wallpapers/linux/TuXperience.jpg

We can list the file in the console client with the following command:

    ~# mcli ls minio1/wallpapers/linux/
    [2022-10-26 19:23:54 UTC]  72KiB STANDARD TuXperience.jpg

We can overwrite the tags on an object with the following command:

    ~# mcli tag set minio1/wallpapers/linux/TuXperience.jpg "os=Windows&year=2001"
    Tags set for https://minio1.andromedant.com:9000/wallpapers/linux/TuXperience.jpg.

We can check the tags on an object with the following command:

    ~# mcli tag list minio1/wallpapers/linux/TuXperience.jpg
    Name    : https://minio1.andromedant.com:9000/wallpapers/linux/TuXperience.jpg ()
    os   : Windows
    year : 2001

We can rename the object using the `mv` command:

    ~# mcli mv minio1/wallpapers/linux/TuXperience.jpg "minio1/wallpapers/linux/penguin-sucking-windows-box.jpg"
    ...TuXperience.jpg:  60.70 KiB / 60.70 KiB ┃▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓┃ 3.85 MiB/s 0s

Existing tags will be preserved.

We can delete an object using the `rm` command:

    ~# mcli rm "minio1/wallpapers/linux/penguin-sucking-windows-box.jpg"
    Removing `minio1/wallpapers/linux/penguin-sucking-windows-box.jpg`.

## Integration with Prometheus

By default, *MinIO* requires authentication for requests made to the metrics endpoints. Use the following command to generate a JWT bearer token for use by Prometheus in making authenticated scraping requests:

    ~# mcli admin prometheus generate minio1
    scrape_configs:
    - job_name: minio-job
      bearer_token: TOKEN
      metrics_path: /minio/v2/metrics/cluster
      scheme: https
      static_configs:
      - targets: ['minio1.andromedant.com:9000']

Where *minio1* is the alias set using the `mcli alias` command before in this guide. In case it's been forgotten, existing aliases can be listed with the following command:

    mcli alias list

The *targets* array can contain the hostname for any node in the deployment. For clusters with a load balancer managing connections between *MinIO* nodes, we will specify the address of the load balancer.

Add the output block to the *scrape_config* section in the Prometheus configuration file, located at `/etc/prometheus/prometheus.yml` in the Prometheus LXC:

    <code class="yaml">
    scrape_configs:
    - job_name: minio1
      bearer_token: eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJleHAiOjQ3OTY3MzkyOTcsImlzcyI6InByb21ldGhldXMiLCJzdWIiOiJtaW5pbyJ9.iccm5kiF-i8ZSzPMqCoaGFnBhQLKamP47E-jIeTgwYGpyrG5BLahv93zkorRKhXrHe-x78CPARhnuv9yyBYpcw
      metrics_path: /minio/v2/metrics/cluster
      scheme: https
      static_configs:
      - targets: ['minio1.andromedant.com:9000']
    </code>

Make sure that the LXC where *MinIO* runs (`minio1.andromedant.com`) allows access to port 9000 from the local IP of the Prometheus LXC:

  ----------------- ---------- ------------ ----------- -------------- ------------------------- ----------------- ----------------- ---------------------- --------------- -------------------------------
  **Level**         **Type**   **Action**   **Macro**   **Protocol**   **Source**                **Source port**   **Destination**   **Destination port**   **Log level**   **Comment**
  CT`<id>`{=html}   in         ACCEPT                   tcp            ipv4_private_prometheus                                       9000                   nolog           Allow traffic from Prometheus
  ----------------- ---------- ------------ ----------- -------------- ------------------------- ----------------- ----------------- ---------------------- --------------- -------------------------------
