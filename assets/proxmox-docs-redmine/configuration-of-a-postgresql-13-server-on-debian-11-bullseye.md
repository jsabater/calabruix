# Configuration of a PostgreSQL 13 server on Debian 11 Bullseye

*Created on 2021-11-17. Last updated on 2022-10-19.*

**This document is now deprecated. Installation is done via Ansible playbook.**

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC).

This tutorial installs the [PostgreSQL](http://www.postgresql.org/), the world’s most advanced open source delational database. *PostgreSQL* is a powerful, open source object-relational database system with over 30 years of active development that has earned it a strong reputation for reliability, feature robustness, and performance.

## Base system configuration

Follow the steps in the \[\[Debian Bullseye 11 LXC base system configuration\]\] tutorial.

## Installation

Install the packages from the main repository:

    apt install postgresql postgresql-client postgresql-13-postgis-3 postgresql-13-cron postgresql-13-pgrouting

## Configuration

Edit the `/etc/postgresql/13/main/postgresql.conf` file and adapt the configuration. The following values are conservative, based on a LXC with 4 cores and 4 GB of RAM with a single, large test database and will be finetuned later on this tutorial:

    listen_addresses = '*'
    max_connections = 400
    shared_buffers = 2048MB
    temp_buffers = 32MB
    work_mem = 4MB
    maintenance_work_mem = 128MB
    max_stack_depth = 4MB
    checkpoint_completion_target = 0.9
    random_page_cost = 4.0
    default_statistics_target = 1000

And restart the database to make the configuration take effect:

    systemctl restart postgresql

If, when needed, edit the `/etc/postgresql/13/main/pg_hba.conf` file to allow access to specific databases (e.g. `popeyetest`):

    <code class="bash">
    # IPv4 local connections:
    host    popeyetest      popeyetest      195.201.170.119/32      md5
    host    popeyetest      popeyetest      127.0.0.1/32            trust   
    host    all             all             127.0.0.1/32            md5
    </code>

And reload the configuration:

    systemctl reload postgresql

## Certificates

By default, the *PostgreSQL* packages use the `/etc/ssl/certs/ssl-cert-snakeoil.pem` self-signed certificate but it does not force its use.

This self-signed certificate is created by the post-installation script of the `ssl-cert` package, a dependency of the `postgresql-13` package that enables unattended installs of packages that need to create SSL certificates and it is a simple wrapper for OpenSSL’s certificate request utility that feeds it with the correct user variables.

Given that our containers are not in a private, secure network, we are going to use a valid certificate and force clients to use an encrypted channel.

In order to have a certificate issued by a valid Certificate Authority, we will use the [Certbot](https://certbot.eff.org/) to create a valid SSL certificate signed by [Let’s Encrypt](https://letsencrypt.org/). We will be using a centralised installation of *Certbot*, as described in the \[\[Configuration of Let’s Encrypt’s Certbot on Debian 11 Bullseye\]\] guide. In order to deploy the issued wildcard certificate, we will be using *Ansible*, as described in the \[\[Configuration of Ansible on Debian 11 Bullseye\]\].

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

Configure `/etc/postgresql/13/main/pg_hba.conf` to only allow secure connections unless using the `localhost`:

    # IPv4 local connections:
    hostssl popeyedevel     popeyedevel     0.0.0.0/0               md5
    host    popeyedevel     popeyedevel     127.0.0.1/32            trust
    host    all             all             127.0.0.1/32            md5
    # IPv6 local connections:
    hostssl popeyedevel     popeyedevel     ::0/0                   md5
    host    popeyedevel     popeyedevel     ::1/128                 trust
    host    all             all             ::1/128                 md5

Do not restart *PostgreSQL* yet, as that will be done by *Ansible* once the certificates have been distributed.

### Connecting

Once the certificate has been deployed, we will only be able to connect using a secure transport (unless through the `localhost`). This is how we do that:

    ~# PGSSLROOTCERT=/etc/ssl/certs/ISRG_Root_X1.pem PGSSLMODE=verify-full psql --host=postgresql3.andromedant.com --user=popeyedevel --password --dbname=popeyedevel --port=5432
    Password: 
    psql (13.5 (Debian 13.5-0+deb11u1))
    SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
    Type "help" for help.

Note: Compression was disabled many versions ago because of the CRIME issue in SSL. Compression was dropped from TLS v1.3 because it is considered obsolete.

The connection URI will now [require additional parameters via query string](https://www.postgresql.org/docs/13/libpq-connect.html):

    postgresql://popeyetest:<password>@postgresql1.andromedant.com:5432/popeyetest?sslmode=verify-full&sslrootcert=/etc/ssl/certs/ISRG_Root_X1.pem

If `sslmode` is not used, the default mode “require” will be used, which will use the certificate but won’t check its authenticity. The different SSL modes available are documented in table 33.1, [SSL Mode Descriptions](https://www.postgresql.org/docs/13/libpq-ssl.html#LIBPQ-SSL-SSLMODE-STATEMENTS), of the official documentation.

Howevery, using `verify-full` will make `libpq`:

- Verify that the server is trustworthy by checking the certificate chain up to the root certificate stored on the client.
- Verify that the server host name matches the name stored in the server certificate.

`sslmode=verify-full` is a client-side feature. It benefits a client by ensuring that it connects to the intended server. It does not benefit a server as it’s the server that is being checked.

Note: the `ca-certificates` package must be installed for the *Let’s Encrypt* root certificate to be present.

## Firewall

Enable traffic to port 5432 for the container using the PostgreSQL macro:

|  |  |  |  |  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|----|----|----|----|
| **Level** | **Type** | **Action** | **Macro** | **Interface** | **Protocol** | **Source** | **Source port** | **Destination** | **Destination port** | **Log level** | **Comment** |
| Container | in | ACCEPT | PostgreSQL | net0 |  | IPv4_Private_Storm |  |  |  | nolog | Allow access from Storm |
| Container | in | ACCEPT | PostgreSQL | net1 |  |  |  |  |  | nolog | Allow access from everywhere |

Note: Adapt the rules as needed.

## Finetuning configuration values

Using [pgTune](https://pgtune.leopard.in.ua/) we will calculate initial configuration values for PostgreSQL based on the maximum performance for a given hardware configuration. It is not a silver bullet, therefore further finetuning will be required and will depend on size of the database, the number of clients and the complexity of the queries.

For 8 GB of RAM:

    # DB Version: 13
    # OS Type: linux
    # DB Type: oltp
    # Total Memory (RAM): 8 GB
    # CPUs num: 8
    # Connections num: 1000
    # Data Storage: ssd

    max_connections = 1000
    shared_buffers = 2GB
    effective_cache_size = 6GB
    maintenance_work_mem = 512MB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 1.1
    effective_io_concurrency = 200
    work_mem = 524kB
    min_wal_size = 2GB
    max_wal_size = 8GB
    max_worker_processes = 8
    max_parallel_workers_per_gather = 4
    max_parallel_workers = 8
    max_parallel_maintenance_workers = 4

For 24 GB of RAM:

    # DB Version: 13
    # OS Type: linux
    # DB Type: oltp
    # Total Memory (RAM): 24 GB
    # CPUs num: 10
    # Connections num: 1000
    # Data Storage: ssd

    max_connections = 1000
    shared_buffers = 6GB
    effective_cache_size = 18GB
    maintenance_work_mem = 1536MB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 1.1
    effective_io_concurrency = 200
    work_mem = 1572kB
    huge_pages = off
    min_wal_size = 2GB
    max_wal_size = 8GB
    max_worker_processes = 10
    max_parallel_workers_per_gather = 4
    max_parallel_workers = 10
    max_parallel_maintenance_workers = 4

*oltp* stands for online transaction processing system and somehow takes the following scenario into consideration:

- Typically CPU or I/O-bound
- DB slightly larger than RAM to 1TB
- 20-40% small data write queries
- Some long transactions and complex read queries

For a database using HDD over ZFS server holding small databases, like a Django app, which are very small, and which runs also on an 8 GB RAM LXC but on HDD instead of SSD, these would be the recommended values:

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

Bibliography: https://www.crunchydata.com/blog/optimize-postgresql-server-performance

## Dump

Use the following command as `postgres` user to make a backup of the database:

    pg_dump --format=c --host=127.0.0.1 --dbname=popeyelive --file=popeyelive.bak

## Restoration

As `postgres` user, create the database user:

    createuser --no-createdb --no-createrole --no-superuser --pwprompt popeyetest
    Enter password for new role: <password>
    Enter it again: <password>

Also create the `popeyelive` user if you are restoring a dump from the live version onto the test database server:

    createuser --no-createdb --no-createrole --no-superuser popeyelive

Note: there is no need for the `popeyelive` user to have a password since it will never be used or be given access to anything. It is created only so that database objects in the dump of the live database (i.e. `popeyelive`) can be restored to its owner (i.e. `popeyelive`) before ownership is changed to `popeyetest`).

Now create the database:

    createdb --template=template1 --encoding=UTF8 --owner=popeyetest popeyetest

Use the `psql` client to connect to the newly created database:

    ~$ psql --dbname=popeyetest
    psql (13.5 (Debian 13.5-0+deb11u1))
    Type "help" for help.

    popeyetest=#

Then execute the following commands to create the necessary schemas:

    CREATE SCHEMA tiger;
    ALTER SCHEMA tiger OWNER TO popeyetest;
    CREATE SCHEMA tiger_data;
    ALTER SCHEMA tiger_data OWNER TO popeyetest;
    CREATE SCHEMA topology;
    ALTER SCHEMA topology OWNER TO popeyetest;

Now execute the following commands to create the necessary extensions:

    CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA public;
    CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA public;
    CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;
    CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
    CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;
    CREATE EXTENSION IF NOT EXISTS postgis_raster WITH SCHEMA public;
    CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;
    CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;

Use the `\dn` command to list the schemas:

    popeyetest=# \dn
         List of schemas
        Name    |   Owner    
    ------------+------------
     cron       | postgres
     public     | postgres
     tiger      | popeyetest
     tiger_data | popeyetest
     topology   | popeyetest
    (5 rows)

Use the `\dx` command to list the extensions:

    popeyetest-# \dx
                                            List of installed extensions
           Name       | Version |   Schema   |                            Description                            
    ------------------+---------+------------+-------------------------------------------------------------------
     hstore           | 1.7     | public     | data type for storing sets of (key, value) pairs
     pg_cron          | 1.3     | public     | Job scheduler for PostgreSQL
     pg_trgm          | 1.5     | public     | text similarity measurement and index searching based on trigrams
     plpgsql          | 1.0     | pg_catalog | PL/pgSQL procedural language
     postgis          | 3.1.1   | public     | PostGIS geometry and geography spatial types and functions
     postgis_raster   | 3.1.1   | public     | PostGIS raster types and functions
     postgis_topology | 3.1.1   | topology   | PostGIS topology spatial types and functions
     unaccent         | 1.1     | public     | text search dictionary that removes accents
     uuid-ossp        | 1.1     | public     | generate universally unique identifiers (UUIDs)
    (9 rows)

Note: The `plpgsql` language (extension) is already installed in the `template1` database by default, which is used when creating the `popeyetest` database.

All these extensions could be added to the `template1` database so that they are already available in every database we create, but the `pg_cron` is an exception so we will have to create it directly in the `popeyetest` database.

Finally, restore the dump into it:

    pg_restore --dbname=popeyetest --format=c --clean --if-exists popeyelive.bak

Now reassign all objects owned by the user `popeyelive` to the user `popeyetest`:

    ~$ psql --dbname=popeyetest
    psql (13.5 (Debian 13.5-0+deb11u1))
    Type "help" for help.

    popeyetest=# REASSIGN OWNED BY popeyelive TO popeyetest;
    REASSIGN

Now, if you do not plan on ever restoring another dump in the server, the `popeyelive` user is no longer needed and can be safely deleted:

    dropuser popeyelive

## Restore a dump from `live` to `local`

This procedure is to be followed when restoring a dump of `popeyelive` to an already existing (local) server with a `popeyelocal` database. In doing so, it is assumed that:

1.  The `popeyelocal` user and database already exist.
2.  A `popeyelive` user exists.
3.  The `cron` schema, owned by the `postgres` superuser, already exists \[1\].
4.  The `tiger`, `tiger_data` and `topology` schemas, owned by `popeyelocal`, already exist \[1\].
5.  The `hstore`, `pg_cron`, `pg_trgm`, `postgis`, `postgis_raster`, `postgis_topology`, `unaccent` and `uuid-ossp` extensions are already installed \[2\].
6.  The `template1` database, which has the `pgplsql` extension installed, already exists.

If the above requirements are not met, then you must do the whole restoration procedure, as described in this very same wiki page.

Backups from the live databases are stored in Hetzner’s Storage Box. The first thing we have to do is to bring in the desired dump. For that, first we’ll make sure the destination subdirectory exists:

    mkdir --parents /var/backups/postgresql

Then we will copy the dump from the remote server to the local subdirectory:

    scp -q -i /root/.ssh/androsol -P 23 -r u224360@u224360.your-storagebox.de:proxmox7/postgresql/popeyelive_YYYYMMDD.bak /var/backups/postgresql/

Restore the dump into the existing `popeyelocal` database:

    pg_restore --dbname=popeyelocal --clean --if-exists --role=popeyelocal --format=c /var/backups/postgresql/popeyelive_YYYYMMDD.bak

Note: Check whether the option `--role=popeyelocal` is actually necessary.

The following two errors are expected:

    pg_restore: error: could not execute query: ERROR:  policy "cron_job_policy" for table "job" already exists
    Command was: CREATE POLICY cron_job_policy ON cron.job USING ((username = CURRENT_USER));

    pg_restore: error: could not execute query: ERROR:  policy "cron_job_run_details_policy" for table "job_run_details" already exists
    Command was: CREATE POLICY cron_job_run_details_policy ON cron.job_run_details USING ((username = CURRENT_USER));

They can be safely ignored.

Finally, reassign all objects owned by the user `popeyelive` to the user `popeyelocal`. As `postgres` or `root` user:

    ~$ psql --dbname=popeyelocal
    psql (13.5 (Debian 13.5-0+deb11u1))
    Type "help" for help.

    popeyetest=# REASSIGN OWNED BY popeyelive TO popeyelocal;
    REASSIGN

## Backup

In spite of the backup tool being used, we first need to generate a dump of the database using `pg_dump`.

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

Create a `~/bin` directory for the `root` user where we will store our backup script:

    mkdir ~/bin

Create the file `/root/bin/backup_postgresql` with the following content:

    #!/bin/bash

    BCKDIR="/var/backups/postgresql"
    DB="popeyelive"
    TODAY=`/bin/date +%Y%m%d`

    echo "Starting PostgreSQL backup."
    echo "Dumping contents of database popeyelive."
    /usr/bin/pg_dump --dbname=${DB} --format=c --file=${BCKDIR}/${DB}_${TODAY}.bak
    echo "Calculating checksum."
    /bin/echo $(/bin/date +"%Y-%m-%d" && /usr/bin/sha256sum ${BCKDIR}/popeyelive_${TODAY}.bak) >> ${BCKDIR}/checksum.txt
    echo "Copying dump to remote storage."
    /usr/bin/scp -q -i /root/.ssh/androsol -P 23 ${BCKDIR}/popeyelive_${TODAY}.bak ${BCKDIR}/checksum.txt u224360@u224360.your-storagebox.de:proxmox7/postgresql/
    echo "Removing dump."
    /bin/rm --force ${BCKDIR}/popeyelive_${TODAY}.bak

And give it execution permissions:

    chmod +x /root/bin/popeye_pgbackup

Create the directory `/var/backups/postgresql` where our dumps will be stored:

    mkdir --mode=0750 --parents /var/backups/postgresql

Edit the `crontab` for the `root` user:

    # m h  dom mon dow   command
    0 3 * * * /root/bin/popeye_pgbackup 2>&1 | /usr/bin/logger -t backup

## Useful utilities

    apt install pgtop pg-activity

## Useful commands

Some useful commands to help with administration. These are the distro packages containing the `psql` client tool:

|              |                   |             |
|--------------|-------------------|-------------|
| **Distro**   | **Package name**  | **Version** |
| Ubuntu 20.04 | postgresql-client | 12          |
| Ubuntu 18.04 | postgresql-client | 10          |
| Debian 11    | postgresql-client | 13          |

On Ubuntu 18.04 and 20.04, follow the instructions on [PostgreSQL’s wiki](https://wiki.postgresql.org/wiki/Apt) to install a more modern version (at least 13.x).

For your convenience, edit the `/etc/hosts` file and add the relevant hosts:

    # IPv4
    116.202.120.36   postgresql1.andromedant.com postgresql1
    116.202.120.38   postgresql2.andromedant.com postgresql2

### Connect to a database

The connection from the client to the database server can be tested with the following command:

    psql --host=postgresql1.andromedant.com --user=popeyetest --password --dbname=popeyetest --port=5432

When certificates are in use, we are going to need this:

    PGSSLROOTCERT=/etc/ssl/certs/ISRG_Root_X1.pem PGSSLMODE=verify-full psql --host=postgresql3.andromedant.com --user=popeyedevel --password --dbname=popeyedevel --port=5432

### All connections

To check the connections to the database and which ciphers they are using, execute the following SQL query:

    SELECT ssl.pid, usename, datname, ssl, ssl.version, ssl.cipher, ssl.bits, ssl.compression, client_addr
      FROM pg_catalog.pg_stat_ssl ssl, pg_catalog.pg_stat_activity activity
     WHERE ssl.pid = activity.pid;

### Active connections

To check the active connections to all databases, execute the following query:

      SELECT pid, usename, datname as database, client_addr, 
             application_name, backend_start, state, state_change
        FROM pg_stat_activity
    ORDER BY backend_start, state_change;

Explanation of columns:

- pid: process ID of this backend
- username: name of the user logged into this backend
- database: name of the database this backend is connected to
- client_addr: IP address of the client connected to this backend
- application_name: name of the application that is connected to this backend
- backend_start: time when this process was started. For client backends, this is the time the client connected to the server.
- state: current overall state of this backend. Possible values are: active, idle, idle in transaction, idle in transaction (aborted), fastpath function call, disabled.
- state_change: time when the state was last changed

One row represents one active connection. The total amount of rows represent all active connections.

If you just want to count the connections, use this other query:

    SELECT SUM(numbackends) FROM pg_stat_database;

### Extensions

To check the installed extensions, use the `\dx` on `psql` or execute the following query:

    SELECT * FROM pg_extension;

### Schemas

To check the available schemas, use `\dn` on `psql` or the following query:

    SELECT schema_name FROM information_schema.schemata;

### Functions

To list the available functions, use the `\df` command on `psql` or the following query:

       SELECT n.nspname as function_schema, p.proname as function_name
         FROM pg_proc p
    LEFT JOIN pg_namespace n ON p.pronamespace = n.oid
    LEFT JOIN pg_language l ON p.prolang = l.oid
    LEFT JOIN pg_type t on t.oid = p.prorettype 
        WHERE n.nspname not in ('pg_catalog', 'information_schema')
     ORDER BY function_schema, function_name;

### Operators

To list the available operators, use the `\do` command on `psql`.

### Drop all connections to a database

To terminate all connections to a specific database, connect using the `psql` client as `postgres` user with no parametres, then execute the following query:

    SELECT pg_terminate_backend(pid)
      FROM pg_stat_get_activity(NULL::integer)
     WHERE datid=(SELECT oid FROM pg_database WHERE datname = 'popeyetest');

### List the PIDs of all connections to a database

Connect using the `psql` client as `postgres` user with no parametres, then execute the following query:

    SELECT pg_terminate_backend(pg_stat_activity.pid)
      FROM pg_stat_activity
     WHERE pg_stat_activity.datname = 'popeyetest'
       AND pid <> pg_backend_pid();

If you want to terminate them, you would now issue `SELECT pg_terminate_backend(<pid>)` to all of them.

### Drop a database

When a database has users connected to it, it cannot be dropped unless forced. From the console, as `postgres` user:

    dropdb --force popeyetest

### Check database owner

To check the owner of the databases, use the `\l` command on `psql`. To check the owner of the database currently in use, execute this query:

    SELECT u.usename 
      FROM pg_database d
      JOIN pg_user u ON (d.datdba = u.usesysid)
     WHERE d.datname = (SELECT current_database());

To check the owner of a specific database, use the following command:

      SELECT d.datname as "Name", pg_catalog.pg_get_userbyid(d.datdba) as "Owner"
        FROM pg_catalog.pg_database d
       WHERE d.datname = 'popeyetest'
    ORDER BY 1;

### Change ownership of a function

    ALTER FUNCTION public.ascii_clean(character varying) OWNER TO popeyetest;

### Check owner of a relationship

    SELECT relowner::regrole FROM pg_class WHERE relname = 'provider';

### Show all the privileges for a concrete user

**Table permissions**

      SELECT *
        FROM information_schema.role_table_grants 
       WHERE grantee = 'metabasero'
    ORDER BY table_name;

**Ownership**

    SELECT *
      FROM pg_tables 
     WHERE tableowner = 'metabasero';

**Schema permissions**

          SELECT r.usename AS grantor,
                 e.usename AS grantee,
                 nspname,
                 privilege_type,
                 is_grantable
            FROM pg_namespace
    JOIN LATERAL (SELECT *
                    FROM aclexplode(nspacl) AS x) a
              ON true
            JOIN pg_user e
              ON a.grantee = e.usesysid
            JOIN pg_user r
              ON a.grantor = r.usesysid 
           WHERE e.usename = 'metabasero';

### Table size

To check the size of the biggest 5 relations in a database, use the following query:

       SELECT relname AS "relation", pg_size_pretty (pg_total_relation_size (C .oid)) AS "total_size"
         FROM pg_class C
    LEFT JOIN pg_namespace N ON (N.oid = C .relnamespace)
        WHERE nspname NOT IN ('pg_catalog', 'information_schema')
          AND C .relkind <> 'i'
          AND nspname !~ '^pg_toast'
     ORDER BY pg_total_relation_size (C .oid) DESC
        LIMIT 5;

To check the size of a given table in the current database or schema, use the following query:

    SELECT pg_size_pretty(pg_total_relation_size('tablename'));

### Database size

To check the size of a database use the following query:

    SELECT pg_size_pretty(pg_database_size('popeyelive'));

### Rename a user

To change the name of a database user (or role), issue the following query:

    ALTER USER django_oasis RENAME TO blackpearl_oasis

Objects owned by the old user will now be owned by the new user. MD5 user password will be cleared as part of the rename.

Don’t forget to edit the file `pg_hba.conf` to udpate the permissions.

### Change the password of a user

After renaming a username, the password will be reset. In order to set a password we will use the following command:

    ALTER USER blackpearl_oasis WITH PASSWORD '<password>'

### Rename a database

To change the name of a database use the following query:

    ALTER DATABASE django_oasis RENAME TO blackpearl_oasis

Don’t forget to edit the file `pg_hba.conf` to udpate the permissions.
