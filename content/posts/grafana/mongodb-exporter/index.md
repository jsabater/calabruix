---
title: "Gathering database metrics with MongoDB Exporter"
date: 2024-12-20
lastmod: 2025-03-15
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
