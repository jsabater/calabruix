---
title: "Monitoring Gunicorn using StatsD Exporter"
date: 2025-01-08
description: "Monitor Gunicorn through its built-in, statsd-based instrumentation feature using Prometheus StatsD Exporter"
summary: "Collect Gunicorn metric data as using the StatsD Exporter."
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus", "gunicorn", "statsd"]
series: ["Grafana"]
series_order: 18
draft: true
---

References:

* https://medium.com/@damianmyerscough/monitoring-gunicorn-with-prometheus-789954150069
* https://github.com/prometheus/statsd_exporter
* https://github.com/statsd/statsd/blob/master/docs/metric_types.md
* https://github.com/blueswen/gunicorn-monitoring
* https://github.com/benoitc/gunicorn/blob/master/gunicorn/instrument/statsd.py


Gunicorn provides instrumentation of the arbiter (master) and workers using the [StatsD protocol](https://github.com/etsy/statsd) over UDP. This means that Gunicorn becomes a StatsD client that uses UDP to send metrics to a StatsD consumer.

1. Gunicorn instrumentation sends StatsD format metrics by UDP to statsd_exporter
2. Prometheus scrapes prometheus format metrics from statsd_exporter 
3. Grafana queries data from Prometheus

```txt
+--------------------+                     +-------------------+                        +--------------+               +-----------+
|  Gunicorn(StatsD)  |---(UDP repeater)--->|  statsd_exporter  |<---(scrape /metrics)---|  Prometheus  | <---(query)---|  Grafana  |
+--------------------+                     +-------------------+                        +--------------+               +-----------+
```

statsd exporter receives StatsD-style metrics and exports them as Prometheus metrics.

Ports:

    9125: default StatsD request listen port, send StatsD request to this port
    9102: Web expose port, get prometheus metrics from this port

Prometheus metrics is available on http://localhost:9102/metrics.

For a better usability in Prometheus, we use the [StatsD exporter mapping](https://github.com/prometheus/statsd_exporter#metric-mapping-and-configuration) feature to processing these metrics. Because Gunicorn StatsD-style metrics are defined in [Gunicorn codebase](https://github.com/benoitc/gunicorn/blob/master/gunicorn/instrument/statsd.py), and unable to change.

Gunicorn generates the [following metrics](https://docs.gunicorn.org/en/stable/instrumentation.html):

| Metric                           | Description                              | Type      |
|----------------------------------|------------------------------------------|-----------|
| `gunicorn.requests`              | Requests per second                      | Counter   |
| `gunicorn.request.duration`      | Request duration in milliseconds         | Histogram |
| `gunicorn.request.status.<code>` | Requests per second per status code      | Counter   |
| `gunicorn.workers`               | Amount of workers handled by the arbiter | Gauge     |
| `gunicorn.log.warning`           | Warning log messages per second          | Counter   |
| `gunicorn.log.error`             | Error log messages per second            | Counter   |
| `gunicorn.log.critical`          | Critical log messages per second         | Counter   |
| `gunicorn.log.exception`         | Exceptional log messages per second      | Counter   |

StatsD and Prometheus metric types, for the values shown above, match exactly. StatsD includes [a variety of metric types](https://github.com/statsd/statsd/blob/master/docs/metric_types.md), but only the following are used by Gunicorn:

* **Gauge**. A gauge will take on the arbitrary value assigned to it, and will maintain such value until it is next set. If the gauge is not updated at the next flush, it will send the previous value.
* **Counter**. A simple counter that will add the given value to the current count. At each flush, the current count is sent and reset to 0.
* **Histogram**. A histogram is a representation of the distribution of quantitative data. To construct a histogram, the first step is to "bin" or "bucket" the range of values, i.e., divide the entire range of values into a series of intervals, and then count how many values fall into each interval. Using a histogram instructs StatsD to maintain data values over time.

When using a histogram, the [default Prometheus client bucket values](https://github.com/prometheus/client_golang/blob/main/prometheus/histogram.go) are used unless set in the mappings file, i.e., `[.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10]`. `+Inf` is added automatically.

When using a histogram, the `count` and `sum` additional metrics are automatically created.

## Enable Gunicorn to generate and send stats

To enable this optional feature, Gunicorn provides two parametres:

| Parametre       | Description                                                        |
|-----------------|--------------------------------------------------------------------|
| `statsd-host`   | The address of the StatsD consumer to send metrics to              |
| `statsd-prefix` | The prefix to add to metrics (trailing dot is added automatically) |

When passing `myapp` to the `statsd-prefix` argument, the generated metrics acquire the format `myapp.gunicorn.requests`, `myapp.gunicorn.workers`, and so on.

Main configuration file at `/etc/default/prometheus-statsd-exporter`:

```bash
# Command-line arguments to pass to the server.
# See: https://github.com/prometheus/statsd_exporter
# See: https://github.com/CtrlZvi/statsd_exporter
ARGS="--no-web.enable-lifecycle \
      --web.listen-address=':9102' \
      --web.telemetry-path='/metrics' \
      --log.level=info \
      --log.format=logfmt \
      --statsd.mapping-config='/etc/prometheus/statsd_mappings.yml' \
      --statsd.relay.packet-length=1400"
#     --web.config.file='/etc/prometheus/statsd_exporter.yml'"
```

Support for `web.config.file` via the Prometheus Exporter Toolkit [has been requested](https://github.com/prometheus/statsd_exporter/issues/413) but not added yet. 

When support is added, we will be adding the file `/etc/prometheus/statsd_exporter.yml` to the setup:

```yaml
# Prometheus Exporter web configuration
# See: https://github.com/prometheus/exporter-toolkit/blob/master/docs/web-configuration.md

# Allow TLS connections
tls_server_config:
  cert_file: /etc/ssl/certs/domain.crt
  key_file: /etc/ssl/private/domain.key
  min_version: TLS12

http_server_config:
  http2: true
```

Mappings in the `/etc/prometheus/statsd_mappings.yml` file.

The statsd_exporter can be configured to translate specific dot-separated StatsD metrics into labeled Prometheus metrics via a simple mapping language. The config file is reloaded on `SIGHUP`.

A mapping definition starts with a line matching the StatsD metric in question, with `*`s acting as wildcards for each dot-separated metric component. The lines following the matching expression must contain one `label="value"` pair each, and at least define the metric name (label name `name`). The Prometheus metric is then constructed from these labels. `$n`-style references in the label value are replaced by the n-th wildcard match in the matching line, starting at 1.

The default (and fastest) `glob` mapping style uses `*` to denote parts of the statsd metric name that may vary. These varying parts can then be referenced in the construction of the Prometheus metric name and labels.

```yaml
# Mappings
# $1: First wildcard: group name, e.g., 'blackpearl', 'cepheus', 'popeye'
# $2: Second wildcard: app name, e.g., 'website', 'cetus', 'revolution'
# $3: Third wildcard: status code or log level
mappings:
  - match: "*.*.gunicorn.requests"
    name: "gunicorn_requests"
    help: "Requests per second"
    labels:
      service_name: "$1"
      app: "$2"
  - match: "*.*.gunicorn.request.duration"
    name: "gunicorn_request_duration"
    help: "Request duration (ms)"
    labels:
      service_name: "$1"
      app: "$2"
  - match: "*.*.gunicorn.request.status.*"
    name: "gunicorn_response_code"
    help: "Requests per second per status code"
    labels:
      service_name: "$1"
      app: "$2"
      status: "$3"
  - match: "*.*.gunicorn.workers"
    name: "gunicorn_workers"
    help: "Amount of workers handled by the arbiter"
    labels:
      service_name: "$1"
      app: "$2"
  - match: "*.*.gunicorn.workers.busy"
    name: "gunicorn_workers_busy"
    help: "Amount of busy workers"
    labels:
      service_name: "$1"
      app: "$2"
  - match: "*.*.gunicorn.log.*"
    name: "gunicorn_log"
    help: "Log messages per second per level"
    labels:
      service_name: "$1"
      app: "$2"
      level: "$3"
```

TODO: Add mappings for the metrics related to warning, error and exception messages.

## PromQL

```promql
sum by (group, status) (gunicorn_response_code{group="blackpearl", status=~"2.."})
```

## systemd

Service file `/etc/systemd/system/prometheus-statsd-exporter.service` to run the StatsD Exporter:

```systemd
[Unit]
Description=Prometheus StatsD exporter
Documentation=https://github.com/prometheus/statsd_exporter

[Service]
Restart=on-failure
User=prometheus
EnvironmentFile=/etc/default/prometheus-statsd-exporter
ExecStart=/usr/bin/prometheus-statsd-exporter $ARGS
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=20s
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
```


Run Gunicorn from systemd service file:

```systemd
ExecStart={{ blackpearl_venv }}/bin/gunicorn black_pearl.wsgi \
  --bind=0.0.0.0:8080 \
  --pid={{ blackpearl_run }}/gunicorn.pid \
  --workers={{ ((proxmox_cores | int) * 2) + 1 }} \
  --worker-class=gthread \
  --worker-tmp-dir=/dev/shm \
  --threads=4 \
  --timeout=60 \
  --certfile={{ dest_localdomain_fullchain }} \
  --keyfile={{ dest_localdomain_privkey }} \
  --log-level=info \
  --error-logfile={{ blackpearl_log }}/gunicorn.error.log \
  --access-logfile={{ blackpearl_log }}/gunicorn.access.log \
  --access-logformat='%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(L)s %(p)s %({x-request-id}i)s' \
  --keep-alive=60 \
  --statsd-host=localhost:9125 \
  --statsd-prefix=blackpearl
  ```


### rate() vs. avg_over_time()

1. rate()

    Purpose: Calculates the per-second rate of change of a counter over a specified window.
    Use Case: Best suited for counters, especially metrics that continuously increase (like gunicorn_request_duration_sum and gunicorn_request_duration_count).
    Result:
        rate(gunicorn_request_duration_sum[1m]): Returns the per-second rate of change for total request duration.
        rate(gunicorn_request_duration_count[1m]): Returns the per-second rate of change for the number of requests.
    Aggregation: rate() inherently works with rates (derivatives), so it is well-suited for metrics where the goal is to measure activity over time (e.g., requests/second).
    Granularity: More accurate for analyzing high-frequency changes or trends.

2. avg_over_time()

    Purpose: Computes the simple average of all raw samples within a range.
    Use Case: Best suited for gauges (e.g., CPU usage, memory usage) or when you want an unweighted average of raw values over a time window.
    Result:
        avg_over_time(gunicorn_request_duration_sum[1m]): Would compute the average of the sum values over the last minute.
        avg_over_time(gunicorn_request_duration_count[1m]): Would compute the average of the count values over the last minute.
    Aggregation: Unlike rate(), it doesn’t calculate per-second changes; instead, it provides an average over a time window.
    Granularity: Less dynamic, as it depends directly on the raw sample values.



NGINX and Gunicorn log files:

In this case, the correct method depends on your goal and the nature of the request_time data:

    rate() is typically used for metrics that are counters or cumulative values, where you're interested in the rate of change over time.
    avg_over_time() is better suited for metrics that are gauges or instantaneous values, where you're analyzing averages over a time range.

Since request_time is a gauge-like value (it represents an individual duration and isn't cumulative), avg_over_time() is the most appropriate choice here.

```promql
avg_over_time(({job="nginx", environment="production", service_name="blackpearl"} 
| pattern `<_> - <_> [<_>] "<_>" <_> <request_time> <_> <_> <_> <_> "<_>" "<_>" "<_>" <_> <_> <_> <_> <_> <_> <_> <_> <_> <_> <_>` 
| unwrap request_time) [1m]) by (service_name)
```

Gunicorn StatsD exporter:

When to Use rate()

    Counters: Metrics like *_sum and *_count are counters, which rate() is specifically designed for.
    Precision: It accurately measures the rate of change per second, which aligns with the purpose of monitoring request times over time.
    Better for Dashboards: In a time series panel, rate() ensures smooth and real-time trends without spikes caused by raw averages.

When to Use avg_over_time()

    Gauges: When working with metrics that are not counters (e.g., CPU usage or temperature).
    Raw Data Analysis: If you want to focus on the raw averages over time without considering the rate of change.
    Rare Use for Counters: For counters like gunicorn_request_duration_*, it is less effective because counters are meant to increase, and avg_over_time() doesn't provide insights into the rate of increase.

Stick with rate() for counters like gunicorn_request_duration_sum and gunicorn_request_duration_count. It's more accurate and meaningful for understanding request durations over time.