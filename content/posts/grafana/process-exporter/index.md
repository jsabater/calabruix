---
title: "Gathering process metrics with Process Exporter"
date: 2025-11-18
lastmod: 2025-11-19
description: "Install and configure Process Exporter for Prometheus"
summary: "Collect process metric data as using Prometheus Process Exporter"
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus"]
series: ["Grafana"]
series_order: 10
---

When monitoring Linux systems with Prometheus, [Node Exporter]({{< relref "/posts/grafana/node-exporter/" >}}) provides essential hardware and OS-level metrics, like overall CPU and memory usage.

However, to gain granular visibility into specific applications, such as tracking the number of Gunicorn workers, checking if a critical agent has died, or isolating which process is consuming too much RAM, we need a more specialised tool.

This is where the [Prometheus Process Exporter](https://github.com/ncabatoff/process-exporter) comes in. It mines the Linux `/proc` filesystem to report detailed metrics on groups of processes defined by their name or command, allowing us to establish precise, application-centric monitoring and alerting.

## Installation

We will install it from the Debian repository, then manually update the binary from the [Prometheus Node Exporter releases page at Github](https://github.com/ncabatoff/process-exporter/releases).

```bash
apt-get update
apt-get install prometheus-process-exporter ssl-cert
adduser prometheus ssl-cert
```

Optionally, update the binary file with the more modern version from Github:

```bash
export PROCESS_EXPORTER_VERSION="0.8.7"
wget https://github.com/ncabatoff/process-exporter/releases/download/v${PROCESS_EXPORTER_VERSION}/process-exporter-${PROCESS_EXPORTER_VERSION}.linux-amd64.tar.gz \
     --output-document=/tmp/process-exporter-${PROCESS_EXPORTER_VERSION}.linux-amd64.tar.gz
tar --directory=/tmp --extract --gzip --file=/tmp/process-exporter-${PROCESS_EXPORTER_VERSION}.linux-amd64.tar.gz
systemctl stop prometheus-process-exporter
cp /tmp/process-exporter-${PROCESS_EXPORTER_VERSION}.linux-amd64/process-exporter /usr/bin/prometheus-process-exporter
systemctl start prometheus-process-exporter
```

> You will have to repeat this installation in every VM and node, so you may want to automate it [using Ansible]({{< relref "/posts/ansible/" >}}).

## Configuration

The configuration of the Process Exporter requires three files. Let's begin by editing the file `/etc/prometheus/process_exporter.yml`, which contains the web configuration for the exporter.

```yaml
# Prometheus Process Exporter configuration
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

> The `localdomain.com` certificate in the example is a wildcard certificate for the local domain of the [Proxmox VE cluster]({{< relref "/posts/proxmox/pve/">}}), managed internally via PowerDNS, and issued via Let's Encrypt. Adapt it to your scenario.

Let's continue with the `/etc/default/prometheus-process-exporter` file, that contains the the command-line arguments passed to the binary:

```ini
# Set the command-line arguments to pass to the server.
ARGS="--web.config.file /etc/prometheus/process_exporter.yml \
      --web.listen-address ':9256' \
      --web.telemetry-path '/metrics' \
      --config.path /etc/prometheus/process_mappings.yml \
      --recheck-with-time-limit 3s"
```

> In Go's `flag` library, duration flags expect values like `30s`, `5m`, `1h`, etc.

One last file is required, the mappings file where we will specify the processes we want to monitor.

## Mappings

As you can see in our `/etc/default/prometheus-process-exporter` file, we are instructing the Process Exporter to load the mappings from the `/etc/prometheus/process_mappings.yml` file via the `--config-path` argument. This file allows us to specify which processes and under which rules the exporter must capture information about, using YAML format.

The contents of this file will vary depending on what processes we want to capture information about.

### Groups

A group is a collection of one or more running processes that the exporter monitors and reports on under a common metric label.

The goal of a good Process Exporter configuration is to explicitly monitor only the high-value application processes (e.g., Gunicorn workers, databases, agents) and ignore the rest to keep the metrics endpoint clean.

For that purpose, named groups are the entries you define under the `process_names` key in the YAML configuration. Each entry provides a `name` (the group name) and a matching rule (`comm`, `exe`, or `cmdline`).

A process may only belong to one group, the first one listen, even if multiple items would match.

### Gunicorn

Let's say that we want to monitor Gunicorn, which is running our Django-based web application using the `gthread` model in a number of LXCs. Our `/etc/prometheus/process_mappings.yml` could look like this:

```yaml
process_names:

  # Gunicorn master process
  - name: gunicorn_master
    cmdline: 'gunicorn: master \[.+\]'

  # Gunicorn worker processes
  - name: gunicorn_worker
    cmdline: 'gunicorn: worker \[.+\]'
```

> We are defining two named groups in this configuration.

Key takeaways for this setup:

* The `gunicorn_master` entry explicitly targets the single master process using the full command line text.
* The `gunicorn_worker` group explicitly targets all workers.
* The `\[.+\]` expression (any character, one or more times, inside square brackets) matches the variable `proc_name` in the `config.py` used to in the systemd service file, or its `--name` equivalent parametre, which helps identify different Gunicorn servers running in the same guest.
* We use `cmdline` for because it contains the descriptive parts (master, worker, `[proc_name]`). The `comm` field is just the executable name, i.e.,`gunicorn`, which is too general for distinguishing master from worker.

Adapt this to your needs. When you are done, restart the exporter:

```bash
systemctl restart prometheus-process-exporter.service
```

We still need to configure our Prometheus server to pull metrics from the exporter.

### Additional labels

Let's say that we want to include more labels in our metrics. Process Exporter does not allow adding additional labels to series it exports, so we will have to resort to including them in the group name. We could modify the `process_mappings.yml` file as follows:

```yaml
process_names:

  # My web project: Gunicorn master
  - name: "gunicorn_master;environment=production;service_name=webapp"
    cmdline:
      - 'gunicorn: master \[webapp\]'

  # My web project: Gunicorn worker
  - name: "gunicorn_worker;environment=production;service_name=webapp"
    cmdline:
      - 'gunicorn: worker \[webapp\]'
```

We could also include labels such as `role=frontend` or similar. Adapt this to your needs. When you are done, restart the exporter:

```bash
systemctl restart prometheus-process-exporter.service
```

Anyhow, this will require using the `metric_relabel_configs` in our `scrape_config` in the Prometheus, which we will do in the next section.

### Prometheus server

In our Prometheus server, we need to configure a new job in our scrape configuration, such as:

```yaml
scrape_configs:

  # Process Exporter
  - job_name: 'process_exporter'
    scrape_interval: 15s
    scheme: https
    metrics_path: /metrics
    tls_config:
      ca_file: /etc/ssl/certs/ISRG_Root_X1.pem
      insecure_skip_verify: false
    file_sd_configs:
      - files:
        - file_sd_configs/process_exporter/webapp.yml
    relabel_configs:
      - source_labels: [__address__]
        regex: '(\w+)\.localdomain\.com:.*'
        target_label: host
        replacement: '$1'
```

We have taken the chance to add a new `host` label, which includes the subdomain of the FQDN of our guest, useful to filter for all the metrics concerning a specific guest in the cluster. Finally, the `/etc/prometheus/file_sd_configs/process_exporter/webapp.yml` file with all the targets:

```yaml
- targets:
  - 'webapp1.localdomain.com:9256'
  - 'webapp2.localdomain.com:9256'
  - 'webapp3.localdomain.com:9256'
  labels:
    group: 'mywebproject'
```

If we decided to add additional semicolon-separated labels to the group name, we will need additional configuration:

```yaml
scrape_configs:

  # Process Exporter
  - job_name: 'process_exporter'
    [..]

    # Extract env/service from groupname (semicolon-separated)
    metric_relabel_configs:
      - source_labels: [groupname]
        regex: '.*;env=([^;]+).*'
        target_label: environment
        replacement: '$1'
      - source_labels: [groupname]
        regex: '.*;service=([^;]+).*'
        target_label: service_name
        replacement: '$1'
      # Relabeling is sequential, so we perform the cleanup last to
      # restore the original content of the groupname label
      - source_labels: [groupname]
        regex: '^([^;]+);.*'
        target_label: groupname
        replacement: '$1'
```

When done, instruct Prometheus to reload the configuration file:

```bash
systemctl reload prometheus.service
```

> A good observability practice is to choose a consistent label schema early, e.g. `host`, `service_name`, `job_name`, `environment`, `role`, etc.

## Available metrics

This configuration would provide the following metrics in Prometheus, among others:

* Number of workers: `namedprocess_namegroup_num_procs{groupname="gunicorn_worker"}`
* Resident RAM usage of workers: `namedprocess_namegroup_memory_bytes{groupname="gunicorn_worker",memtype="resident"}`
* Number of zombie processes: `namedprocess_namegroup_states{state="Zombie"}`

When configuring alerts, the expression `namedprocess_namegroup_num_procs{groupname="gunicorn_master"} == 0` would indicate that the master process is stopped, and the expression `namedprocess_namegroup_num_procs{groupname="gunicorn_worker"} < X` would indicate that there are less worker processes than intended, where `X` corresponds to the value of the `--workers` parametre in your systemd service file, or `config.py` file.

> Do not forget to allow traffic to port 9256 of your guests in your firewall.

You can use `curl` to test connectivity and obtain a list of the available metrics:

```bash
curl -k https://webapp1.localdomain.com:9256/metrics
```
