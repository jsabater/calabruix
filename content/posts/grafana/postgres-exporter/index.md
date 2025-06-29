---
title: "Gathering database metrics with PostgreSQL Exporter"
date: 2024-09-24
lastmod: 2025-03-15
description: "Install and configure Prometheus Postgres Exporter"
summary: "Collect PostgreSQL metric data as using the Postgres Exporter."
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus", "postgresql"]
series: ["Grafana"]
series_order: 14
draft: true
---

The Postgres Exporter for Prometheus collects PostgreSQL metrics, such as queries per second (QPS) and rows fetched, returned, inserted, updated or deleted per second. Postgres Exporter will expose these as Prometheus-style metrics.

This article is aimed at installing this agent on containers and virtual machines running recent versions of PostgreSQL on Debian 12 Bookworm on a Proxmox cluster.

## Installation

We will install it from the Debian repository, then manually update the binary from the [Prometheus Postgres Exporter releases page at Github](https://github.com/prometheus-community/postgres_exporter/releases).

```bash
apt-get update
apt-get install prometheus-postgres-exporter
adduser prometheus ssl-cert
```

Optionally, update the binary file with the more modern version from Github:

```bash
export POSTGRES-_EXPORTER_VERSION="0.15.0"
wget hhttps://github.com/prometheus-community/postgres_exporter/releases/download/v${POSTGRES_EXPORTER_VERSION}/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz \
     --output-document=/tmp/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz
tar --directory=/tmp --extract --gzip --file=/tmp/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz
cp /tmp/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64/postgres_exporter /usr/bin/prometheus-postgres-exporter
```

## Configuration

Edit the main configuration file `/etc/prometheus/postgres_exporter.yml`.

```yaml
# Prometheus PostgreSQL Exporter configuration
# See: https://prometheus.io/docs/prometheus/latest/configuration/https/

# Allow TLS connections
tls_server_config:
  cert_file: /etc/ssl/certs/domain.com.crt
  key_file: /etc/ssl/private/domain.com.key
  min_version: TLS12

# Enable HTTP/2 support, which is only supported with TLS
http_server_config:
  http2: true
```

Edit the command-line arguments file `/etc/default/prometheus-postgres-exporter`.

```yaml
# Connection string for the PostgreSQL database.
# See: /usr/share/doc/prometheus-postgres-exporter/README.Debian
DATA_SOURCE_NAME='user=prometheus host=/run/postgresql dbname=postgres application_name=prometheus'

# Command-line arguments to pass to the server.
# See: https://github.com/prometheus-community/postgres_exporter?tab=readme-ov-file#flags
ARGS="--web.config.file='/etc/prometheus/postgres_exporter.yml' \
      --web.listen-address=':9187' \
      --web.telemetry-path='/metrics' \
      --log.level='info'"
```

## Database user and permissions

```bash
su - postgres
psql
```

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE USER prometheus WITH NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE SCHEMA prometheus AUTHORIZATION prometheus;
ALTER USER prometheus SET SEARCH_PATH TO prometheus,pg_catalog;
GRANT pg_monitor to prometheus;
GRANT pg_read_all_stats to prometheus;
```

## Starting up

At this point, the service file should be enabled and the daemon started, so all you need is to restart the server, then check its status.

```bash
systemctl restart prometheus
systemctl status prometheus
```

## proxmox-ve-exporter

We will install [prometheus-pve-exporter](https://github.com/prometheus-pve/prometheus-pve-exporter)

