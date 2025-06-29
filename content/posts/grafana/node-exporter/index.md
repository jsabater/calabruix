---
title: "Gathering system and hardware metrics with Node Exporter"
date: 2024-09-24
lastmod: 2025-03-15
description: "Install and configure Prometheus Node Exporter"
summary: "Collect system and hardware metric data as using Prometheus Node Exporter"
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus"]
series: ["Grafana"]
series_order: 10
draft: true
---

The Prometheus Node Exporter exposes a wide variety of hardware and kernel-related metrics. This article is aimed at installing this agent on containers and virtual machines running Debian 12 Bookworm on a Proxmox cluster. You want to install this exporter in all guests running in your Proxmox cluster, including where the Prometheus server is running.

## Installation

We will install it from the Debian repository, then manually update the binary from the [Prometheus Node Exporter releases page at Github](https://github.com/prometheus/node_exporter/releases).

```bash
apt-get update
apt-get install prometheus-node-exporter ssl-cert
adduser prometheus ssl-cert
```

Optionally, update the binary file with the more modern version from Github:

```bash
export NODE_EXPORTER_VERSION="1.8.2"
wget hhttps://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz \
     --output-document=/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar --directory=/tmp --extract --gzip --file=/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cp /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/bin/prometheus-node-exporter
```

## Configuration

Edit the main configuration file `/etc/prometheus/node.yml`.

```yaml
# Prometheus Node Exporter configuration
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

Edit the command-line arguments file `/etc/default/prometheus-node-exporter`.

```yaml
# Set the command-line arguments to pass to the server.
ARGS="--web.config.file=/etc/prometheus/node.yml \
      --collector.systemd \
      --collector.processes"
```

Create the directories for the file-based discovery configuration files:

```bash
mkdir --mode=0755 /etc/prometheus/file_sd_configs \
mkdir --mode=0755 /etc/prometheus/file_sd_configs/node_exporter
mkdir --mode=0755 /etc/prometheus/file_sd_configs/minio_metrics
mkdir --mode=0755 /etc/prometheus/file_sd_configs/postgres_exporter
```

At this point, the service file should be enabled and the daemon started, so all you need is to restart the server, then check its status.

```bash
systemctl restart prometheus-node-exporter
systemctl status prometheus-node-exporter
```

## Prometheus

Edit the `/etc/prometheus/prometheus.yml` configuration file in the `prometheus1.localdomain.com` LXC to instruct the Prometheus server to pull metrics from the Node Exporter.



```yaml
  # LXC and VM of the Proxmox cluster
  - job_name: 'node_exporter'
    # Encrypt communications between guests
    scheme: https
    # Do not use the HTTP proxy for internal communication
    proxy_from_environment: false
    tls_config:
      ca_file: /etc/ssl/certs/ISRG_Root_X1.pem
      # Only needed when using self-signed certificates.
      # server_name: prometheus1.domain.com
      insecure_skip_verify: false
    file_sd_configs:
      - files:
        - file_sd_configs/node_exporter/grafana.yml
        - file_sd_configs/node_exporter/loki.yml
        - file_sd_configs/node_exporter/minio.yml
        - file_sd_configs/node_exporter/nginx.yml
        - file_sd_configs/node_exporter/postgresql.yml
        - file_sd_configs/node_exporter/prometheus.yml
```
