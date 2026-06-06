# Configuration of Grafana Prometheus on Debian

*Created on: 2022-01-23. Last updated on: 2023-03-29.*

**This document is now deprecated. Installation is done via Ansible playbook.**

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC).

*Prometheus* is a monitoring system that collects metrics from services and stores them in a time-series database. It offers a multi-dimensional data model, a flexible query language, and diverse visualization possibilities through tools like *Grafana*.

By default, Prometheus only exports metrics about itself (e.g. requests received, memory consumption, etc.), but through the installation of exporters additional metrics can be generated. Exporters, both official and community-generated, provide information about everything from infrastructure, databases, and web servers to messaging systems, APIs, and more. Some of the most popular are:

-   **node_exporter.** Produces metrics about infrastructure, including the current CPU, memory and disk usage, as well as I/O and network statistics, such as the number of bytes read from a disk or a server's average load.
-   **blackbox_exporter.** This generates metrics derived from probing protocols like HTTP and HTTPS to determine endpoint availability, response time, and more.
-   **mysqld_exporter.** This gathers metrics related to a MySQL server, such as the number of executed queries, average query response time, and cluster replication status.
-   **rabbitmq_exporter.** This outputs metrics about the RabbitMQ messaging system, including the number of messages published, the number of messages ready to be delivered, and the size of all the messages in the queue.
-   **nginx-vts-exporter.** This provides metrics about an Nginx web server using the Nginx VTS module, including the number of open connections, the number of sent responses (grouped by response codes), and the total size of sent or received requests in bytes.

## Base system configuration

Follow the steps in the \[\[Debian Bullseye 11 LXC base system configuration\]\] tutorial.

## Installation

We will be installing *Prometheus* from the distribution backports repositories:

    apt install -t bullseye-backports prometheus prometheus-node-exporter

By default, both *Prometheus* and *Prometheus Node Exporter* will be enabled and running. We can check that with the following command:

    systemctl status prometheus prometheus-node-exporter

By default, *Prometheus* will be listening to ports 9090 (`prometheus`) *Prometheus Node Exporter* will be listening to port 9100 (`prometheus-node-exporter`). We can check that with the following command:

    netstat --program -all --numeric | grep --word-regexp LISTEN

## Configuration

Configuration directory of *Prometheus* is `/etc/prometheus`. Edit the main configuration file, `/etc/prometheus/prometheus.yml` (YAML format), to adapt the default configuration:

    <code class="yaml">
    # Prometheus configuration 
    # See: https://prometheus.io/docs/prometheus/latest/configuration/configuration/

    global:
      scrape_interval:     15s # Default is every 1 minute
      evaluation_interval: 15s # Default is every 1 minute
      scrape_timeout: 10s      # Default is every 10 seconds

      # Labels to add to any time series or alerts when communicating with
      # external systems (federation, remote storage, Alertmanager).
      external_labels:
        monitor: 'proxmox'

    # Alertmanager configuration
    alerting:
      # Specifies Alertmanager instances the Prometheus server sends alerts to.
      # Also provides parameters to configure how to communicate with these Alertmanagers.
      alertmanagers:
      - static_configs:
        - targets: ['localhost:9093']

    # A list of globs, i.e. patterns specifying sets of filenames with wildcard characters.
    # Rules and alerts are read from all matching files.
    rule_files:
      # - "first_rules.yml"
      # - "second_rules.yml"

    # Scrapers configuration.
    # This section specifies a set of targets and parameters describing how to scrape them.
    # Each list item contains exactly one endpoint to scrape.
    # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
    scrape_configs:

      # Prometheus itself
      - job_name: 'prometheus'
        # Override the global defaults
        scrape_interval: 5s
        scrape_timeout: 5s
        # 'scheme' defaults to 'http'.
        scheme: https
        tls_config:
          ca_file: /etc/ssl/certs/ISRG_Root_X1.pem
          # server_name: prometheus1.andromedant.com
          # insecure_skip_verify: false
        # metrics_path defaults to '/metrics'
        static_configs:
          - targets: ['localhost:9090']

      # Node exporter on LXC 'prometheus1.andromedant.com'
      - job_name: prometheus1
        static_configs:
          - targets: ['localhost:9100']
    </code>

We can check the configuration file for syntax errors with the following command:

    promtool check config /etc/prometheus/prometheus.yml

Create the file `/etc/prometheus/web.yml` to add the configuration details of the web console:

    <code class="yaml">
    # Prometheus web configuration
    # See: https://prometheus.io/docs/prometheus/latest/configuration/https/

    # Allow TLS connections
    tls_server_config:
      cert_file: /etc/ssl/certs/andromedant.com.crt
      key_file: /etc/ssl/private/andromedant.com.key
      min_version: TLS12

    # Usernames and hashed passwords that have full access to the web
    # server via basic authentication. If empty, no basic authentication is
    # required. Passwords are hashed with bcrypt.
    # See: https://o11y.tools/pwgen/
    # XXX: Do this on NGINX?
    # basic_auth_users:
    # prometheus: $2a$10$neiblp2sp7id1BXhi1Ep/.nlieWUh.EaU7d5O8j.5OtM8rg/zbppa
    </code>

We can check the configuration file for syntax errors with the following command:

    promtool check web-config /etc/prometheus/web.yml

Edit the file `/etc/default/prometheus` to instruct the daemon to load the web configuration we just created:

    ARGS="--web.config.file=/etc/prometheus/web.yml"

From now onwards, every container we want to monitor will require a node exporter (i.e. an agent) to collect the metrics and feed them to the *Prometheus* server, and every service we want to monitor will either:

-   Include the ability to publish Prometheus-compatible scraping endpoint data (i.e. the *agent* is integrated into the service).
-   Require a compatible [exporter](https://prometheus.io/docs/instrumenting/exporters/), either official or contributed.

On the *Prometheus* server side, each of this publishers or exporters will be configured as a *scrape* in the *scrape_configs* section of the `/etc/prometheus/prometheus.yml` configuration file.

## Security

*Prometheus* does not include built-in authentication or any other general purpose security mechanism. We will configure *Nginx* as a reverse proxy for *Prometheus* and add basic HTTP authentication to our installation, which both *Prometheus* and its preferred data visualization tool, *Grafana*, fully support.

At any existing webserver container, install `apache2-utils` to have access to the `htpasswd` utility to generate password files:

    apt install apache2-utils

Create a set of credentials in a password file:

```bash
htpasswd -B -b -n grafana <mypasswd>
```

Add it to `/etc/prometheus/web.yml`.

Add firewall rule



## Prometheus on PostgreSQL

We will install the [Prometheus PostgreSQL Server Exporter](https://github.com/prometheus-community/postgres_exporter) in the LXC to feed our \[\[Configuration_of_Grafana_Prometheus_on_Debian_11_Bullseye\|Prometheus installation\]\] with data about our PostgreSQL installation.

The Prometheus exporter daemon runs under the `prometheus` system user. We are going to create a (non-superuser) `prometheus` database user with no password and let it connect to the database using UNIX domain sockets. We will also grant it the appropriate permissions to allow it to read the data it needs to do its job.

As `postgres` user:

    createuser --no-createdb --no-createrole --no-superuser prometheus

Connect to the server (as `postgres` user) and execute the following sentences to grant the necessary permissions to the newly-created user:

    <code class="sql">
    -- The default search path of a newly created user is "$user", public.
    -- Adapt it to where the prometheus user will be reading from (pg_catalog).
    -- Helps speed up queries using unqualified names and prevents conflicts.
    ALTER USER prometheus SET SEARCH_PATH TO "$user", pg_catalog;

    -- Allow the prometheus user to connect to the postgres database,
    -- where the pg_stat_replication and pg_stat_activity are located
    GRANT CONNECT ON DATABASE postgres TO prometheus;

    -- Grant the built-in role pg_monitor to allow read-only access to the necessary tables and views.
    GRANT pg_monitor TO prometheus;
    </code>

The `prometheus` system user will be connecting to the `postgres` database using the `prometheus` database user and the `peer` (UNIX socket) method. This is already allowed by the default client authentication configuration file `/etc/postgresql/13/main/pg_hba.conf`:

    # TYPE  DATABASE        USER            ADDRESS                 METHOD

    # "local" is for Unix domain socket connections only
    local   all             all                                     peer

Next we will install the package from the main repositories:

    apt install prometheus-postgres-exporter

Edit the configuration file `/etc/default/prometheus-postgres-exporter` to define the connection string:

    DATA_SOURCE_NAME='user=prometheus host=/run/postgresql dbname=postgres'

From this file, we can also take the chance to check that, by default, the daemon is:

-   Listening on port 9187 on all interfaces.
-   Offering telemetry information at the `/metrics` path.

### Built-in metrics and custom metrics

The *Prometheus PostgreSQL Exporter* includes some built-in metrics and also allows the user to add custom-made ones. This is the list of metrics we will be using:

1.  Check that PostgreSQL is running.
2.  Postmaster service uptime, in seconds.
3.  Replication lag, in seconds, because a high replication lag rate can lead to coherence problems if the master goes down.
4.  Database size, in bytes, to watch the storage usage of each of the PostgreSQL databases in our instance.
5.  Available disk storage, in bytes, to be able to tell when we are running out of space.
6.  Number of available connections, to be able to tell when we are running out of connections.
7.  Transaction duration, in seconds, to measure performance and latency.
8.  Cache hit rate, as a percentage, to be able to tell when we have problems with cache in memory.
9.  Available memory, in bytes, so that we know we can increase memory usage when having a low hit rate of our cache.
10. Requested buffer checkpoints, to know whether we need to increase the database buffer size because too many checkpoints are requested on demand.

In order to export the metrics we require we will be creating a file `/etc/prometheus/postgres-queries.yml` file, which we will be referencing in this file:

    ARGS='--extend.query-path="/etc/prometheus/postgres-queries.yml"'

Now we need to create the abovementioned queries file `/etc/prometheus/postgres-queries.yml` with the following content:

mkdir /etc/prometheus

Create `/etc/prometheus/postgres-queries.yml`

    <code class="yaml">

    pg_replication:
      query: "SELECT CASE WHEN NOT pg_is_in_recovery() THEN 0 ELSE GREATEST (0, EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))) END AS lag"
      master: true
      metrics:
        - lag:
            usage: "GAUGE"
            description: "Replication lag behind master in seconds"
    </code>

### Alerts

We will be configuring the following alerts in the *Prometheus* server:

1.  Replication lag greater than 10 seconds.

<!-- -->

    <code class="yaml">
      - alert: PostgresqlDown
        expr: pg_up == 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: Postgresql down (instance {{ $labels.instance }})
          description: "Postgresql instance is down\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"

      - alert: PostgresqlRestarted
        expr: time() - pg_postmaster_start_time_seconds < 60
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: Postgresql restarted (instance {{ $labels.instance }})
          description: "Postgresql restarted\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"

      - alert: PostgresqlReplicationLag
        expr: pg_replication_lag > 30 and ON(instance) pg_replication_is_replica == 1
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: Postgresql replication lag (instance {{ $labels.instance }})
          description: "PostgreSQL replication lag is going up (> 30s)\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"

      - alert: PostgresqlTooManyConnections
        expr: sum by (datname) (pg_stat_activity_count{datname!~"template.*|postgres"}) > pg_settings_max_connections * 0.8
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: Postgresql too many connections (instance {{ $labels.instance }})
          description: "PostgreSQL instance has too many connections (> 80%).\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
    </code>

## Prometheus on NGINX

We will use the [NGINX log exporter for Prometheus](https://github.com/martin-helmich/prometheus-nginxlog-exporter) to feed the logs produced by NGINX into Prometheus.

https://github.com/martin-helmich/prometheus-nginxlog-exporter/releases/download/v1.10.0/prometheus-nginxlog-exporter_1.10.0_linux_amd64.deb
