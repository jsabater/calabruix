---
title: "Gathering system and hardware metrics with Node Exporter"
date: 2025-11-18
lastmod: 2025-11-18
description: "Install and configure Prometheus Node Exporter"
summary: "Collect system and hardware metric data as using Prometheus Node Exporter"
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus"]
series: ["Grafana"]
series_order: 11
---

The [Prometheus Node Exporter](https://github.com/prometheus/node_exporter/) is a fundamental component in any Prometheus monitoring stack, designed specifically to collect and expose a wide array of machine-level and operating system metrics from Linux, forming the backbone for comprehensive infrastructure monitoring and alerting.

It acts as an agent running on our Proxmox VMs and nodes (not containers), providing metrics such as CPU usage, memory consumption, disk I/O, network traffic, and filesystem capacity.

## Installation

We will install it from the Debian repository, then manually update the binary from the [Prometheus Node Exporter releases page at Github](https://github.com/prometheus/node_exporter/releases).

```bash
apt-get update
apt-get install prometheus-node-exporter ssl-cert
adduser prometheus ssl-cert
```

Optionally, update the binary file with the more modern version from Github:

```bash
export NODE_EXPORTER_VERSION="1.10.2"
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz \
     --output-document=/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar --directory=/tmp --extract --gzip --file=/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cp /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/bin/prometheus-node-exporter
```

> You will have to repeat this installation in every VM and node, so you may want to automate it using Ansible.

## Configuration

The configuration of the Node Exporter requires just two files. Begin by editing the configuration file `/etc/prometheus/node.yml`, which contains the web configuration for the exporter.

```yaml
# Prometheus Node Exporter configuration
# See: https://prometheus.io/docs/prometheus/latest/configuration/https/

# Allow TLS connections
tls_server_config:
  cert_file: /etc/ssl/certs/localdomain.com.crt
  key_file: /etc/ssl/private/localdomain.com.key
  min_version: TLS12

# Enable HTTP/2 support, which is only supported with TLS
http_server_config:
  http2: true
```

> The `localdomain.com` certificate is a wildcard certificate for the local domain of the cluster, managed internally via PowerDNS, and issued via Let's Encrypt. Adapt it to your scenario.

And let's finish with the `/etc/default/prometheus-node-exporter` file, that contains the the command-line arguments given to the binary:

```ini
# Set the command-line arguments to pass to the server.
ARGS="--web.config.file=/etc/prometheus/node.yml \
      --collector.systemd \
      --collector.processes"
```

At this point, the service file should be enabled and the daemon started, so all you need is to restart the server, then check its status.

```bash
systemctl restart prometheus-node-exporter
systemctl status prometheus-node-exporter
```

## Prometheus

Let's now switch to the LXC holding the Prometheus server. We need to configure it with all the targets where the Node Exporter is being run.

As a first step, if you have not already, create the directories for the file-based discovery configuration files: 

```bash
mkdir --parents --mode=0755 /etc/prometheus/file_sd_configs
```

The file-based service discovery is a mechanism that allows Prometheus to automatically discover and manage scrape targets by reading the necessary information from files on disk. Prometheus periodically checks these files for changes, and upon detecting modifications, it updates its list of targets without requiring a restart or reload.

This approach is particularly useful for integrating custom or third-party service discovery systems, as it enables external processes, such as configuration management tools, cron jobs, or dedicated sidecar programs, to generate the target files.

The default refresh interval for file-based discovery is 5 minutes, but this can be configured using the `refresh_interval` parameter in the Prometheus configuration.

Example `/etc/prometheus/file_sd_configs/node_exporter.yml` file:

```yaml
- targets:
  - 'mongodb1.localdomain.com:9100'
  - 'mongodb2.localdomain.com:9100'
  - 'nfs1.localdomain.com:9100'
  - 'nfs2.localdomain.com:9100'
  - 'postgresql1.localdomain.com:9100'
  - 'postgresql2.localdomain.com:9100'
  labels:
    group: 'qemu'
```

We are now ready to edit the `/etc/prometheus/prometheus.yml` configuration file of our Prometheus server to configure the new job under the `scrape_configs` key:

```yaml
scrape_configs:

  - job_name: 'node_exporter'
    scrape_interval: 15s
    scheme: https
    tls_config:
      ca_file: /etc/ssl/certs/ISRG_Root_X1.pem
      insecure_skip_verify: false
    file_sd_configs:
      - files:
        - file_sd_configs/node_exporter.yml
    relabel_configs:
      - source_labels: [__address__]
        regex: '(\w)\.localdomain\.com:.*'
        target_label: host
        replacement: '$1'
```

Note the following aspects of this configuration file:

* `scrape_interval: 15s`, to increase how often the target is scraped (its default value is `1m`).
* `scheme: https`, to encrypt communications between the Prometheus server and the Node Exporter daemons.
* `insecure_skip_verify: false`, the default value, to force Prometheus to perform a full TLS certificate validation.
* `relabel_configs`, to add the `host` label from the instance. This is done in all the jobs so that we can use it when filtering by all metrics belonging to a host, no matter the exporter that brought them in.
