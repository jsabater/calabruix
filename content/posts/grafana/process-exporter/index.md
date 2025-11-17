---
title: "Gathering process metrics with Process Exporter"
date: 2025-10-30
lastmod: 2025-10-30
description: "Install and configure Process Exporter for Prometheus"
summary: "Collect process metric data as using Prometheus Process Exporter"
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus"]
series: ["Grafana"]
series_order: 10
draft: true
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

The configuration of the Process Exporter requires three files. Begin by editing the configuration file `/etc/prometheus/process_exporter.yml`, which contains the web configuration for the exporter.

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

> The `localdomain.com` certificate in the example is a wildcard certificate for the local domain of the cluster, managed internally via PowerDNS, and issued via Let's Encrypt. Adapt it to your scenario.

Continue with the `/etc/default/prometheus-process-exporter` file, that contains the the command-line arguments given to the binary:

```ini
# Set the command-line arguments to pass to the server.
ARGS="--web.config.file /etc/prometheus/process_exporter.yml \
      --web.listen-address ':9256' \
      --web.telemetry-path '/metrics' \
      --config.path /etc/prometheus/process_mappings.yml \
      --recheck-with-time-limit 3s \
      --threads"
```

> In Gos `flag` library, duration flags expect values like `30s`, `5m`, `1h`, etc.

One last file is required, the mappings file where we will specify the processes we want to monitor.

## Mappings

As you can see in our `/etc/default/prometheus-process-exporter` file, we are instructing the Process Exporter to load the mappings from the `/etc/prometheus/process_mappings.yml` file via the `--config-path` argument. This file allows us to specify which processes and under which rules the exporter must capture information about, using YAML format.

The contents of this file will vary depending on what processes we want to capture information about.

### Groups

A Group is a collection of one or more running processes that the exporter monitors and reports on under a common metric label.

Named groups are the entries you define under the `process_names` key in the YAML configuration. Each entry provides a `name` (the group name) and a matching rule (`comm`, `exe`, or `cmdline`).

********** REFACTOR *****************

The <default> group is a special, implicit catch-all group that is automatically created by the Process Exporter.

    Purpose: Any process running on the system that does not match any of the named groups defined in your process_names list is automatically placed into the <default> group.

    The Problem: By default, the <default> group's metrics will be labeled with the raw process command name (e.g., sshd, cron, systemd). If you have a large number of unique, low-value processes (like temporary shell scripts or various background services), the <default> group can quickly generate a huge number of time series (high cardinality), overwhelming your Prometheus server and database.

    Best Practice: The goal of a good Process Exporter configuration is to explicitly monitor only the high-value application processes (like your Gunicorn workers, databases, agents) and exclude/ignore the rest to keep the metrics endpoint clean.

********** REFACTOR *****************

### Gunicorn

Let's say that we want to monitor Gunicorn, which is running our Django-based web application using the `gthread` model in a number of LXCs. Our `/etc/prometheus/process_mappings.yml` could look like this:

```yaml
process_names:

  # Gunicorn master process
  - name: gunicorn_master
    cmdline: 'gunicorn: master .*'

  # Gunicorn worker processes
  - name: gunicorn_worker
    cmdline: 'gunicorn: worker .*'
```

> We are defining two named groups in this configuration.

Key takeaways for this setup:

* The `gunicorn_master` entry explicitly targets the single master process using the full command line text.
* The `gunicorn_worker` group explicitly targets all workers.
* The `.*` expression (any character, zero or more times) matches the variable customer code that is part of the process name, making the group code-agnostic.
* We use `cmdline` for because it contains the descriptive parts (master, worker, `[code]`). The `comm` field is just the executable name, i.e.,`gunicorn`, which is too general for distinguishing master from worker.

Let's say that we customised the command-line arguments of our Gunicorn systemd service file, or the `config.py` file in our project, and we included the app name in the process. Let's also say that we want to return the environment. We would, then, modify the `process_mappings.yml` file as follows:

```yaml
process_names:

  - name: gunicorn_master
    cmdline:
      - 'gunicorn: master \[webapp\]'
    labels:
      environment: "production"
      service_name: "webapp"
      app: "webapp1"

  # Black Pearl Gunicorn worker
  - name: gunicorn_worker
    cmdline:
      - 'gunicorn: worker \[webapp\]'
    labels:
      environment: "production"
      service_name: "webapp"
      app: "webapp1"
```

We could also include labels such as `role: "frontend"` or similar. There is more than one way to skin a cat, they say.

After restart, this configuration would provide the following metrics in Prometheus, among others:

* Number of workers: `namedprocess_namegroup_num_procs{groupname="gunicorn_worker"}`
* Resident RAM usage of workers: `namedprocess_namegroup_memory_bytes{groupname="gunicorn_worker",memtype="resident"}`
* Number of zombie processes: `namedprocess_namegroup_states{state="Zombie"}`

When configuring alerts, the expression `namedprocess_namegroup_num_procs{groupname="gunicorn_master"} == 0` would indicate that the master process is stopped, and the expression `namedprocess_namegroup_num_procs{groupname="gunicorn_worker"} < X` would indicate that there are less worker processes than intended, where `X` corresponds to the value of the `--workers` parametre in your systemd service file, or `config.py` file.

## Prometheus

Test connectivity and find out the available metrics:

```bash
curl -k https://webapp1.localdomain.com:9256/metrics
```

`/etc/prometheus/file_sd_configs/process_exporter.yml`

```yaml
- targets:
  - 'webapp1.localdomain.com:9256'
  - 'webapp2.localdomain.com:9256'
  - 'webapp3.localdomain.com:9256'
  labels:
    group: 'webapp'
```

`/etc/prometheus/prometheus.yml`

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
        - file_sd_configs/process_exporter.yml
    relabel_configs:
      - source_labels: [__address__]
        regex: '(\w+)\.localdomain\.com:.*'
        target_label: host
        replacement: '$1'
```

Good observability practice: choose a consistent label schema early
like host, service, app, job, env, cluster.

We are adding the host label to almost every exporter[^4] because, in our scenario, usually there are multple services per guest (e.g., Gunicorn and Redis), so there are more than exporter per guest. This is exactly the case where the host label helps, as the `instance` label includes different ports, so the `host` label makes it easier to group metrics per guest.

[^4]: Prometheus itself and the PVE Exporter are excluded.

Reload Prometheus for the changes to take effect:

```bash
systemctl reload prometheus
```

## Heterogeneos guests

Keep in mind that the `process_exporter` mappings cannot be one-size-fits-all if we have a heterogeneous estate. For example:

|

* Multiple LXC running Gunicorn for the same big web application, load balanced. Same service_name, same `app`, different `host`.
* Multiple LXC running Gunicorn for different web applications.
* Multiple LXC running Gunicorn for the same application, but for different customers.

In this scenario.

Moreover, 

## PromQL

To discover what labels are being returned and, incidentally, the number of Gunicorn workers in a specific instance, run this directly in Prometheus:

```promql
namedprocess_namegroup_num_procs{group="webapp",groupname="gunicorn_worker",host="webapp1"}
```

The labels returned should be `group`, `groupname`, `host`, `instance` and `job`. The returned value should match the number of configured Gunicorn workers for that instance.



