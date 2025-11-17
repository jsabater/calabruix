---
title: "Gathering database metrics with MongoDB Exporter"
date: 2024-12-20
lastmod: 2025-10-30
description: "Install and configure Prometheus MongoDB Exporter"
summary: "Collect and visualise MongoDB metric data as using the MongoDB Exporter."
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus", "mongodb"]
series: ["Grafana"]
series_order: 15
draft: true
---

The MongoDB Exporter for Prometheus collects MongoDB metrics, such as [..]. MongoDB Exporter will expose these as Prometheus-style metrics.

This article is aimed at installing this agent on containers and virtual machines running relatively recent versions of MongoDB on Debian 11 Bullseye and Debian 12 Bookworm on a Proxmox cluster.

## Installation

We will install it from the Debian repository, then manually update the binary from the [Prometheus MongoDB Exporter releases page at Github](https://github.com/percona/mongodb_exporter/releases).

```bash
apt-get update
apt-get install prometheus-mongodb-exporter
adduser prometheus ssl-cert
```

Optionally, update the binary file with the more modern version from Github:

```bash
export MONGODB_EXPORTER_VERSION="0.43.1"
wget hhttps://github.com/percona/mongodb_exporter/releases/download/v${MONGODB_EXPORTER_VERSION}/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz \
     --output-document=/tmp/mongodb_exporter-${MONGODB_EXPORTER_VERSION}.linux-amd64.tar.gz
tar --directory=/tmp --extract --gzip --file=/tmp/mongodb_exporter-${MONGODB_EXPORTER_VERSION}.linux-amd64.tar.gz
cp /tmp/mongodb_exporter-${MONGODB_EXPORTER_VERSION}.linux-amd64/mongodb_exporter /usr/bin/prometheus-mongodb-exporter
```

## Configuration

Edit the main configuration file `/etc/prometheus/mongodb_exporter.yml`.

```yaml
# Prometheus MongoDB Exporter configuration
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

Edit the command-line arguments file `/etc/default/prometheus-mongodb-exporter`.

```yaml
```


## Grafana dashboards

https://grafana.com/grafana/dashboards/20192-mongodb-overview/
https://grafana.com/grafana/dashboards/20867-mongodb-dashboard/


## Bumping connections

The number of maximum connections that our MongoDB instance will be able to handle is determined by a combination of MongoDB configuration and operating system limits.

By default, MongoDB allows up to 65,536 connections, as can be seen in the `/lib/systemd/system/mongod.service` file:

```ini
[Service]
# open files
LimitNOFILE=64000
# processes/threads
LimitNPROC=64000
```

To check the current limits of the master process, use the following script:

```bash
pid=$(ps -C mongod -o pid --no-headers | cut -d " " -f 2)
cat /proc/$pid/limits
```

This connection limit is per process, not per thread. MongoDB is a multi-threaded application, not a multi-process one. Therefore, 65,535 connections will be supported for the parent process, i.e., for the server.

The standard maximum stack size is 8 MB (soft limit). For high concurrency scenarios, if you encounter stack overflows, increase it slightly via a `/etc/systemd/system/mongod.service.d/limits.conf` systemd override file:

```ini
[Service]
LimitSTACK=16777216
```

On the kernel side, ensure the kernel allows a sufficient number of file descriptors system-wide:

```bash
sysctl fs.file-max
```

At least a hundred thousand is required. On modern Linux systems, a value of `9223372036854775807` is expected. This number is the maximum value for a 64-bit signed integer (2⁶³−1), effectively representing "infinity" at the kernel level. It means the system imposes no practical global limit on file handles. You will hit other constraints (like memory, per-process limits, or ulimit) long before reaching this number.

