# Configuration of a PostgreSQL 15 server on Debian 11 Bullseye

*Created on 2021-11-17. Last updated on 2022-10-19.*

**This document is now deprecated. Installation is done via Ansible playbook.**

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC).

This tutorial installs the [PostgreSQL](http://www.postgresql.org/), the world’s most advanced open source delational database. *PostgreSQL* is a powerful, open source object-relational database system with over 30 years of active development that has earned it a strong reputation for reliability, feature robustness, and performance.

## Base system configuration

Follow the steps in the \[\[Debian Bullseye 11 LXC base system configuration\]\] tutorial.

## Installation

We will be installing the packages from the [PostgreSQL Apt Repository](https://apt.postgresql.org/). Follow these steps to configure it, as `root`:

    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    apt update

Note: Alternative solution to using the deprecated `apt-key` utility could be:

    wget --quiet --output-document=/etc/apt/trusted.gpg.d/ https://www.postgresql.org/media/keys/ACCC4CF8.asc

Now we are ready to install the packages:

    apt install postgresql postgresql-client

This will install the most recent version of PostgreSQL, which is 15 at the time of this writing. Depending on the needs, you may want to install these additional packages as well:

    apt install postgresql-15-postgis-3 postgresql-15-pgrouting

## Configuration

Edit the `/etc/postgresql/15/main/postgresql.conf` file and adapt the configuration. We will be including three blocks, all at once:

- Address where the server will be listening.
- Performance tuning.
- Security via a SSL certificate.

We will be making PostgreSQL listen on all available addresses, for simplicity. Since there is just a local IP address, this presents no problem:

    listen_addresses = '*'

Using [pgTune](https://pgtune.leopard.in.ua/) we will calculate initial configuration values for PostgreSQL based on the maximum performance for a given hardware configuration. It is not a silver bullet, therefore further finetuning will be required and will depend on size of the database, the number of clients and the complexity of the queries.

    # DB Version: 15
    # OS Type: linux
    # DB Type: web
    # Total Memory (RAM): 8 GB
    # CPUs num: 6
    # Connections num: 1000
    # Data Storage: hdd

    max_connections = 1000
    shared_buffers = 2GB
    effective_cache_size = 6GB
    maintenance_work_mem = 512MB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 4
    effective_io_concurrency = 2
    work_mem = 699kB
    min_wal_size = 1GB
    max_wal_size = 4GB
    max_worker_processes = 6
    max_parallel_workers_per_gather = 3
    max_parallel_workers = 6
    max_parallel_maintenance_workers = 3

Finally, the certificates. Given that our containers are not in a private, secure network, we are going to use a valid certificate and force clients to use an encrypted channel.

By default, the *PostgreSQL* packages use the `/etc/ssl/certs/ssl-cert-snakeoil.pem` self-signed certificate but it does not force its use. We will be using a certificate issued the Certificate Authority [Let’s Encrypt](https://letsencrypt.org/), issued by a centralised installation of *Certbot*, as described in the \[\[Configuration of Let’s Encrypt’s Certbot on Debian 11 Bullseye\]\] guide. In order to deploy the issued wildcard certificate, we will be using *Ansible*, as described in the \[\[Configuration of Ansible on Debian 11 Bullseye\]\].

What we need to do regarding our PostgreSQL installation is to configure the use of the SSL certificate the way it’s expected. So, edit `/etc/postgresql/13/main/postgresql.conf`:

    ssl = on
    ssl_ca_file = '/etc/ssl/certs/ISRG_Root_X1.pem'
    ssl_cert_file = '/etc/ssl/certs/andromedant.com.crt'
    ssl_key_file = '/etc/ssl/private/andromedant.com.key'
    ssl_prefer_server_ciphers = on
    ssl_min_protocol_version = 'TLSv1.2'

Note: The `ca-certificates` package must be installed for the *Let’s Encrypt* root certificate to be present.

Add the `postgres` user to the `ssl-cert` group so that it can read the private key:

    adduser postgres ssl-cert

The CA root certificate is already included in the `fullchain.pem` file, but the configuration option `ssl_ca_file` is used to be more explicit about which root certificate is used. The same needs to be done in the client side when connecting.

And restart the database to make the configuration take effect:

    systemctl restart postgresql

From now onwards we will configure access to our databases to be allowed only via secure connections and from a single IP address. Example:

    # IPv4 local connections:
    hostssl blackpearl_base blackpearl_base 192.168.0.112/32        md5
    host    all             all             127.0.0.1/32            md5

## Superuser root

As we will not be using the `postgres` user in order to keep `/var/lib/postgresql` tidy, let’s create a `root` superuser. As `postgres` user:

    createuser --superuser root

This new `root` user already has access to all databases through the localhost socket as per the existing configuration in `/etc/postgresql/13/main/pg_hba.conf`:

    # TYPE  DATABASE        USER            ADDRESS                 METHOD

    # "local" is for Unix domain socket connections only
    local   all             all                                     peer

You can test that, as `root` user:

    ~# psql --dbname=popeyelive
    psql (13.5 (Debian 13.5-0+deb11u1))
    Type "help" for help.

    popeyelive=#
