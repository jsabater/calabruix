---
title: "Storing metric data with Prometheus"
date: 2024-09-24
lastmod: 2025-10-30
description: "Collect and store metric data using Prometheus."
summary: "Collect and store metric data using Prometheus."
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus"]
series: ["Grafana"]
series_order: 2
weight: 20
---

This article will make use of two [*](LXC) running [Debian GNU/Linux](https://www.debian.org/) on a Proxmox cluster to get the Prometheus server installed and set up to pull and store data metrics.

1. `prometheus1.localdomain.com` will run the Prometheus server on port 8080.
2. `nginx1.localdomain.com` will run NGINX as a reverse proxy on port 443 at the public address `prometheus.publicdomain.com`.

This series assumes that an internal DNS server is installed and correctly configured. `localdomain.com` is the internal DNS zone used across the cluster, whereas `publicdomain.com` is a public DNS zone used to access services from the Internet.

## How does it work

The Prometheus server will be collecting metric data by connecting to exporters (i.e., agents), which are running inside the host or guest you want to collect data from, or directly to an application. Each exporter or application will be listening on a different port.

The Prometheus server will periodically connect to that address and port and request the agent to gather data, then store that data in its local, on-disk [time-series database](https://github.com/prometheus/prometheus/tree/main/tsdb/docs/format) located at `/var/lib/prometheus/metrics2/`.

## What can it be used for

Prometheus can be used for:

* **Monitoring**. Collect and store time series metrics from systems and applications to understand their current state.
* **Historical analysis**. Gain insights into system and application behavior over time.
* **Capacity planning**. Analyze trends in resource consumption to anticipate future needs.
* **Observability**. Correlate metric anomalies with events and deployments to debug and resolve operational issues.
* **Alerting**. Trigger alerts based on configurable conditions.
* **Service Level Objective (SLO) management**. Define and measure compliance with performance targets

## Installation

We will install the Prometheus server from the Debian repository, then manually update the binary from the [Prometheus releases page at Github](https://github.com/prometheus/prometheus/releases).

```bash
apt-get update
apt-get install prometheus ssl-cert
adduser prometheus ssl-cert
```

We will configure the Prometheus server to encrypt communications using TLS. Therefore, we are adding the `prometheus` user to the `ssl-cert` group (created by the `ssl-cert` package) so it can read the private key of the wildcard certificate at `/etc/ssl/private/localdomain.com.key`, issued by Let's Encrypt.

Finally, update the binary files with the more modern versions from Github:

```bash
export PROMETHEUS_VERSION="2.55.1"
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz \
     --output-document=/tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar --directory=/tmp --extract --gzip --file=/tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cp /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/bin/
cp /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/bin/
```

## Prometheus configuration

The configuration takes two steps:

1. Configure the Prometheus server.
2. Configure Prometheus to monitor itself.

The Prometheus server uses three main configuration files:

1. The main configuration file `/etc/prometheus/prometheus.yml`. This determines what exporters and applications the Prometheus server will be connecting ot.
2. The web configuration file `/etc/prometheus/web.yml`. This configures the HTTP server within Prometheus that the NGINX reverse proxy will be connecting to.
3. The command-line arguments file `/etc/default/prometheus`. This will determine the start-up parametres of the Prometheus daemon.

### Command-line arguments

Let's begin with the environment file `/etc/default/prometheus` used by the [systemd](https://systemd.io/) service file[^1] to pass command-line arguments to the server.

```bash
# Set the command-line arguments to pass to the server
# See: https://prometheus.io/docs/prometheus/latest/command-line/prometheus/
ARGS="--web.config.file='/etc/prometheus/web.yml' \
      --config.file='/etc/prometheus/prometheus.yml' \
      --web.listen-address=':8080' \
      --web.external-url='https://prometheus.publicdomain.com/' \
      --web.route-prefix='/' \
      --storage.tsdb.path='/var/lib/prometheus/metrics2/' \
      --storage.tsdb.retention.time='2y' \
      --web.console.libraries='/etc/prometheus/console_libraries' \
      --web.console.templates='/etc/prometheus/consoles'"
```

[^1]: Located at `/lib/systemd/system/prometheus.service`.    

The following table summarises the arguments passed to the daemon:

| Argument                      | Description                                        |
|-------------------------------|----------------------------------------------------|
| `web.config.file`             | Web configuration in YAML format                   |
| `config.file`                 | Main configuration in YAML format                  |
| `web.listen-address`          | Address and port the server will listen at         |
| `web.external-url`            | URL under which Prometheus is externally reachable |
| `web.route-prefix`            | Prefix in the path for the internal endpoints      |
| `storage.tsdb.path`           | Path to the local on-disk time-series database     |
| `storage.tsdb.retention.time` | How long to retain samples in storage              |
| `web.console.libraries`       | Path to the console library directory              |
| `web.console.templates`       | Path to the console template directory             |

> Note: Options in the `web` namespace have to do with the HTTP server.

In short, we are instructing the daemon to load the HTTP server configuration from the `/etc/prometheus/web.yml` file, to load the main configuration from the `/etc/prometheus/prometheus.yml` file, to listen to port 8080 (the default being 9090) and how to write relative and absolute links back to Prometheus itself.

### HTTP server

Let's continue with the configuration file `/etc/prometheus/web.yml`, used by the server to configure authentication and enable encryption via TLS.

```yaml
# Prometheus web configuration
# See: https://prometheus.io/docs/prometheus/latest/configuration/https/

# Allow TLS connections
tls_server_config:
  cert_file: /etc/ssl/certs/localdomain.com.crt
  key_file: /etc/ssl/private/localdomain.com.key
  min_version: TLS12

# Enable HTTP/2 support
http_server_config:
  http2: true
```

Aside from enabling TLS and use of HTTP/2.0, the `http_server_config` key can be used to set headers, which may be useful depending on the environment your server is running. Moreover, the `basic_auth_users` key can be used to enable HTTP authentication, but we will be delegating this onto NGINX later on this article.

### Main options

Finally, let's proceed to the main configuration file at `/etc/prometheus/prometheus.yml`, starting with a very basic configuration, which we will be expanding.

```yaml       
# Prometheus configuration
# See: https://prometheus.io/docs/prometheus/latest/configuration/configuration/

# Set the global defaults
global:
  # How frequently to scrape targets (default is 1m)
  scrape_interval: 15s
  # How long until a scrape request times out (default is 10s)
  scrape_timeout: 10s

# Scrapers configuration
scrape_configs:

  # Prometheus
  - job_name: 'prometheus'
    scheme: https
    proxy_from_environment: false
    tls_config:
      ca_file: /etc/ssl/certs/ISRG_Root_X1.pem
      insecure_skip_verify: false
    static_configs:
      - targets:
        - 'prometheus1.localdomain.com:8080'
        labels:
          group: 'prometheus'
    metrics_path: /metrics
```

There are two main keys, `global` and `scrape_configs`. The former define global variables whereas the latter defines a list of scrape configurations, i.e., metric exporters that the server will be querying for data.

Later on thi series, we will be adding a new entry in the `scrape_configs` key for every type of scrapper we install (e.g., PostgreSQL Exporter or NGINX Exporter) or application we want to scrape (e.g., MinIO).

For now, the example above queries the Prometheus server, which exposes Prometheus-compatible metrics itself, 

At this point, the service file should be enabled and the daemon started, so all you need is to restart the server, then check its status.

```bash
systemctl restart prometheus
systemctl status prometheus
```

Should the service file be disabled, use the `systemctl enable prometheus` command to enable, then start it using the `systemctl start prometheus` command.

## Reverse proxy  

We will use NGINX in a different container to act as reverse proxy. Check the [NGINX configuration]({{ < ref "/posts/nginx" > }}) article for a complete installation and configuration guide NGINX. For now, a basic server block configuration should get you started.

```nginx
server {
  listen 443 ssl;
  server_name prometheus.publicdomain.com;
  ssl_certificate /etc/ssl/certs/publicdomain.com.crt;
  ssl_certificate_key /etc/ssl/private/publicdomain.com.key;
  location / {
    auth_basic "Prometheus | Calabruix";
    auth_basic_user_file /etc/nginx/.prometheus.htpasswd;
    proxy_http_version 1.1;
    proxy_pass https://prometheus1.localdomain.com:8080;
  }
}
```

The following table summarises the configuration of the server block:

| Argument               | Description                                                 |
|------------------------|-------------------------------------------------------------|
| `listen 443 ssl`       | Listen on port 443 with SSL enabled                         |
| `server_name`          | Set the [*](FQDN) of the virtual server                     |
| `ssl_certificate`      | Path to the SSL certificate in PEM format                   |
| `ssl_certificate_key`  | Path to the secret key of the SSL certificate in PEM format |
| `location`             | Set configuration options depending on the request URI      |
| `auth_basic`           | Enable validation of user name and password                 |
| `auth_basic_user_file` | Path to the file that keeps the usernames and passwords     |
| `proxy_http_version`   | Set the HTTP protocol version for proxying                  |
| `proxy_pass`           | Set the protocol, address and port of the proxied server    |

We do not need to add the `nginx` user to the `ssl-cert` group because the master process of NGINX runs as `root`, therefore it can already read the secret key of the wildcard certificate at `/etc/ssl/private/publicdomain.com.key`, issued by Let's Encrypt.

As stated before in this article, we are restricting access with HTTP basic authentication. To achieve that, we need to populate the `/etc/nginx/grafna.htpasswd` file using the `htpasswd` command from the `apache2-utils` package.

The following command will create a password file (remove the `-c` flag if it already exists) with a user named `prometheus`. Type the password in the prompt, twice.

```bash
htpasswd -cB -C 10 /etc/nginx/.prometheus.htpasswd prometheus
```

The password can be generated with the following command:

```bash
openssl rand -base64 25 | tr --delete /=+ | cut --characters -32
```

Do not forget to add the records for both `prometheus1.localdomain.com` and `prometheus.public.domain` into their respective DNS zones, or your `/etc/hosts` file. Also check the firewall rules.

Use the `nginx -t` command to check for syntax errors in the configuration files and, finally, instruct NGINX to reload its configuration:

```bash
systemctl reload nginx
```

Optionally, check the status of the service using `systemctl status nginx`. Now you are ready to load the web page `https://prometheus.publicdomain.com/` in your favourite browser.

## Storage

Prometheus stores time-series data locally in a custom, efficient format by default. It is designed for reliability and fast querying but is not clustered (i.e., no built-in replication).

Data is stored in a directory, `/var/lib/prometheus/metrics2/` in our case. Ingested samples are organized into blocks, in separate subdirectories, each containing:

* A `chunks/` subdirectory with all the time series samples for that period.
* A metadata file.
* An index ile mapping metric names and labels to time series in the `chunks/` subdirectory.

To safeguard against crashes, Prometheus uses a [*](WAL) stored in segments within the `wal/` subdirectory, which can be replayed upon server restart to recover data.

```console
# tree /var/lib/prometheus/metrics2/
/var/lib/prometheus/metrics2/
├── 01JNZ6T5EMKBXZ0BPMXSMCH2CK
│   ├── chunks
│   │   ├── 000001
│   │   ├── 000002
│   │   └── 000003
│   ├── index
│   ├── meta.json
│   └── tombstones
├── 01JP14KKHT2FQFX8Q4R5G81XXQ
│   ├── chunks
│   │   ├── 000001
│   │   ├── 000002
│   │   └── 000003
│   ├── index
│   ├── meta.json
│   └── tombstones
├── [..]
├── chunks_head
│   ├── 020194
│   ├── 020195
│   ├── 020196
│   └── 020197
├── lock
├── queries.active
└── wal
    ├── 00072044
    ├── 00072045
    ├── [..]
    ├── 00072054
    └── checkpoint.00072043
        └── 00000000
```

Data is split into blocks (usually 2-hour chunks initially) and later compacted into larger blocks to reduce storage usage and improve query performance by decreasing the number of blocks that need to be queried. Deletion records are stored in separate tombstone files (instead of deleting data from the chunks). The default retention period is 15 days, after which old data is deleted. Therefore, disk speed, memory allocation and retention settings impact performance.

Managing the local storage involves configuring retention policies to control disk space usage. Prometheus offers command-line flags like `--storage.tsdb.retention.time` to set data retention durations, allowing automatic deletion of older data beyond the specified timeframe.

When disk size is a factor, we can use the `storage.tsdb.retention.size` flag to limit storage size. In such case, it is advisable to set this value to 80-85% of the allocated disk space for Prometheus. This buffer ensures that older entries are removed before the disk becomes full, preventing potential data ingestion issues.

To address scalability and durability limitations of local storage, Prometheus provides interfaces for integrating with remote storage systems, supporting remote writes (i.e., sending ingested samples to a remote endpoint) and remote reads ​(i.e., retrieving sample data from a remote endpoint). These integrations use a snappy-compressed protocol buffer encoding over HTTP.

[Grafana Mimir](https://grafana.com/oss/mimir/) is an open source, horizontally scalable, highly available, multi-tenant TSDB for long-term storage for Prometheus developed by Grafana Labs. If you have a very large installation and very long retention periods, with hundreds of thousands of active series, it is worth exploring.

Even though Prometheus compresses samples within series by default, since we made a ZFS pool available in some of the nodes of our Proxmox cluster, named `zfspool`, we will be using it for the LXC `prometheus1.localdomain.com` to take advantage of the deduplication and compression features of ZFS.

In our example, the LXC `prometheus1.localdomain.com` has id `114`. Using the console on the node where the guest resides at, we can list the pool and the subvolume where it is stored:

```console
# zfs list
NAME                        USED  AVAIL     REFER  MOUNTPOINT
zfspool/subvol-114-disk-0  15.7G  34.3G     15.7G  /zfspool/subvol-114-disk-0
```

Moreover, we can check what compression algorithm is being used:

```console
# zpool get feature@lz4_compress,feature@zstd_compress zfspool
NAME     PROPERTY               VALUE                  SOURCE
zfspool  feature@lz4_compress   active                 local
zfspool  feature@zstd_compress  enabled                local
```

> Use `man zfsprops` to check for the default compression algorithm.

Finally, we can find out the achieved compression ratio:

```console
# zfs get compression,compressratio zfspool/subvol-114-disk-0
zfspool/subvol-114-disk-0  compressratio         2.07x                       -
zfspool/subvol-114-disk-0  compression           on                          inherited from zfspool
```

Prometheus stores an average of 2 bytes per sample. Thus, to plan the capacity of the server, you can use the following formula:

```Needed disk space = Retention time in seconds * Ingested samples per second * Bytes per sample```

To lower the rate of ingested samples, you can either reduce the number of time series you scrape (fewer targets or fewer series per target), or you can increase the scrape interval. However, reducing the number of series is likely more effective, due to compression of samples within a series.

## Metric types

Prometheus defines four primary metric types to represent various forms of data:

1. **Counter**: A cumulative metric that only increases or resets to zero upon restart. It is ideal for tracking quantities like the number of requests served, tasks completed or errors encountered. Counters should not be used for values that can decrease, such as memory usage.

   *Example*: Total number of HTTP requests received by the Prometheus server.
   ```promql
   prometheus_http_requests_total{handler="/metrics"}
   ```
   *Example*: Per-second rate of HTTP requests recieved by the Prometheus server over a 1-hour window on the `/metrics` endpoint
   ```promql
   rate(prometheus_http_requests_total{handler="/metrics"}[1h])
   ```

2. **Gauge**: Represents a single numerical value that can fluctuate up or down. It is suitable for metrics such as current memory usage, active connections, queue sizes or the number of active threads.

   *Example*: Current resident memory usage of the Prometheus process.
   ```promql
   process_resident_memory_bytes{job="prometheus"}
   ```

   Use the `Graph` tab to plot memory usage as a time-series graph.

3. **Histogram**: Samples observations (e.g., request durations or response sizes) and counts them in configurable buckets, providing a sum of all observed values. Histograms are useful for analyzing the distribution and frequency of events.

   *Example*: Calculate the 95th percentile request duration over a 1-hour window, meaning *95% of requests complete within the resulting ms*. The `le` label represents the upper bounds of each histogram bucket.
   ```promql
   histogram_quantile(0.95, sum(rate(prometheus_http_request_duration_seconds_bucket[1h])) by (le))
   ```

4. **Summary**: Similar to histograms, summaries sample observations but provide configurable quantiles over a sliding time window, along with the total count and sum of observations. They are beneficial for calculating precise quantiles but have limitations in aggregating across multiple instances.

    *Example*: Summarize the duration of garbage collection (GC) pauses in seconds of the Prometheus server. The quantiles indicate how long pauses take at different percentiles. The count of garbage collection operations (`go_gc_duration_seconds_count`) and the total amount of time spent (`go_gc_duration_seconds_sum`) on garbage collection operations are also provided.
    ```promql
    go_gc_duration_seconds{job="prometheus"}
    ```

    *Example*: Retrieve the 50th percentile (median) garbage collection pause duration in seconds:
    ```promql
    go_gc_duration_seconds{job="prometheus", quantile="0.5"}
    ```
    This means that 50% of all garbage collection pauses lasted less than or equal to the result in microseconds (µs). This gives an idea of what a "normal" pause duration looks like.

    *Example*: Retrieve the 90th percentile garbage collection pause duration in seconds:
    ```promql
    go_gc_duration_seconds{job="prometheus", quantile="0.5"}
    ```
    This means that 90% of gargabe collection pauses were shorter than the result in microseconds (µs). This shows if there are occasional longer pauses, which might impact performance.

    *Example*: Calculate the average GC duration over a 1-hour window by dividing the total sum by the count:
    ```promql
    rate(go_gc_duration_seconds_sum{job="prometheus"} [1h]) /
      rate(go_gc_duration_seconds_count{job="prometheus"} [1h])
    ```

Each of these metrics provides valuable insights into Prometheus's own performance and can be adapted for monitoring other services in a Prometheus-based monitoring system. Use the PromQL prompt in the Prometheus WebGUI to execute the above examples, see the results and play with the available metrics.

![Prometheus metric types](prometheus-metric-types-788x163.webp)

## Alternative metric models

Prometheus is an observability tool (including collection, storage, and query) that uses a metric model designed to suit its own needs. It defines a [metric exposition format](https://prometheus.io/docs/instrumenting/exposition_formats/) and a [remote write protocol](https://prometheus.io/docs/specs/remote_write_spec/) that the community and many vendors have adopted to expose and collect metrics, becoming a de facto standard.

However, two [*](CNCF) projects aim at offering vendor-agnostic, standarised alternatives models:

* [OpenMetrics](https://openmetrics.io/) for the collection of metrics, which aims at being part of the [*](IETF), and
* [OpenTelemetry](https://opentelemetry.io/), which unifies the collection of metrics, traces, and logs to enable easier instrumentation and correlation across telemetry signals.

If you are interested in the subject, take a look at the [Prometheus vs. OpenTelemetry Metrics: A Complete Guide](https://www.timescale.com/blog/prometheus-vs-opentelemetry-metrics-a-complete-guide/) by Timescale.

## Metrics exported by the Prometheus server

Right now, the only service or system we are monitoring is the Prometheus server itself. We can get a complete list of available metrics by visiting the `/metrics` path of our Prometheus webserver at `prometheus.publicdomain.com`. In such page:​

* `# HELP` provides a brief description of the metric.​
* `# TYPE` specifies the metric type (e.g., gauge, counter).​
* Subsequent lines show the metric names and their current value.​

Next you will find some key Prometheus self-metrics worth monitoring. They provide insights into Prometheus performance, query execution, garbage collection, memory usage, and overall system health.

**General performance**:

| Metric Name                                | Type      | Description                                                  |
|--------------------------------------------|-----------|--------------------------------------------------------------|
| `prometheus_http_requests_total`           | Counter   | Total number of HTTP requests received by Prometheus.        |
| `prometheus_http_request_duration_seconds` | Histogram | Latency distribution of HTTP requests handled by Prometheus. |
| `prometheus_http_response_size_bytes`      | Histogram | Size distribution of HTTP responses served by Prometheus.    |

**Query engine**

| Metric Name | Type | Description |
|-------------|------|-------------|
| `prometheus_engine_queries` | Gauge | Current number of queries being executed or waiting in Prometheus. |
| `prometheus_engine_queries_concurrent_max` | Gauge | Maximum number of concurrent queries allowed in Prometheus. |
| `prometheus_engine_query_duration_seconds` | Summary | Distribution of time taken for Prometheus to process queries, categorized by different query execution phases. |

**Garbage collection (GC)**

| Metric Name | Type | Description |
|-------------|------|-------------|
| `go_gc_duration_seconds` | Summary | Duration of garbage collection pauses, measured in seconds, with quantiles for analysis. |
| `go_gc_cycles_total_gc_cycles_total` | Counter | Total number of garbage collection cycles completed. |
| `go_gc_heap_allocs_bytes_total` | Counter | Cumulative sum of memory allocated to the heap by the application. |

**Memory and resource utilization**

| Metric Name | Type | Description |
|-------------|------|-------------|
| `process_resident_memory_bytes` | Gauge | Current resident memory usage of the Prometheus process. |
| `go_memstats_heap_alloc_bytes` | Gauge | Current heap memory allocated and in use. |
| `go_memstats_heap_sys_bytes` | Gauge | Total heap memory obtained from the system. |

**Process and system information**

| Metric Name | Type | Description |
|-------------|------|-------------|
| `process_cpu_seconds_total` | Counter | Total user and system CPU time consumed by Prometheus in seconds. |
| `process_open_fds` | Gauge | Current number of open file descriptors used by Prometheus. |
| `go_goroutines` | Gauge | Number of goroutines currently running in the Prometheus process. |
