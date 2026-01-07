---
title: "Displaying metric data with Grafana dashboards"
date: 2024-09-24
lastmod: 2025-03-15
description: "Install and configure Grafana, then create dashboards to visualise metrics"
summary: "Query and visualise collected metric data using Grafana dashboards."
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus", "loki"]
series: ["Grafana"]
series_order: 20
draft: true
---

## Grafana configuration

https://grafana.com/docs/grafana/latest/datasources/prometheus/configure-prometheus-data-source/

Access https://grafana.domain.com/ and log in with your admin username and password.

## Data sources

See: https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources

In `/etc/grafana/grafana.ini` modify:

```
[paths]
provisioning = /etc/grafana/provisioning
```

Create the file `/etc/grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1

datasources:
  - name: prometheus
    type: prometheus                
    access: proxy
    url: https://prometheus1.domain.com:8080
    isDefault: true
    basicAuth: false
    jsonData:
      manageAlerts: false
      prometheusType: Prometheus
      prometheusVersion: "2.50.1"
      cacheLevel: High
      httpMethod: POST
    version: 1
    editable: true
```

And create the file `/etc/grafana/provisioning/datasources/loki.yml`:

```yaml
apiVersion: 1

datasources:
  - name: loki
    type: loki
    access: proxy
    url: https://loki1.domain.com:8080
    basicAuth: false
    jsonData:
      manageAlerts: false
      timeout: 60
      maxLines: 1000
    version: 1
    editable: true
```

Restart Grafana for the changes to take effect.

## Plug-ins

https://grafana.com/grafana/plugins/grafana-lokiexplore-app/
https://github.com/grafana/explore-logs/

## Metrics

Browse available metrics by going to `Home > Explore > Metrics` and click on the `New metric exploration` button.

## Dashboards

We will start by importing a pre-made dashboard that visualises the most important metrics of the Prometheus server, which we started monitoring in our 

https://grafana.com/grafana/dashboards/3662-prometheus-2-0-overview/

## NGINX logs from Loki

Requests for last 60 Seconds:

count_over_time( {job="nginx"} [60s])

Rate over 60s:

rate( ( {env="production", job="nginx"} ) [60s])

Show metrics with filter patterns:

rate( ( {env="production", job="nginx"} |~ "GET (/er|/ax)" ) [10s])

Access Log:

172.16.4.86 - - [04/Jun/2022:07:58:38 +0000] "GET / HTTP/2.0" 301 280 "-" "curl"

Query in Grafana / Loki:

{job="prod/nginx"} |= "GET / " 
| regexp `(?P<ip>\S+) (?P<identd>\S+) (?P<user>\S+) \[(?P<timestamp>[\w:\/]+\s[+\\-]\d{4})\] "(?P<action>\S+)\s?(?P<path>\S+)\s?(?P<protocol>\S+)?" (?P<status>\d{3}|-) (?P<size>\d+|-)\s?"?(?P<referrer>[^\"]*)"?\s?"?(?P<useragent>[^\"]*)?"?`

More examples:

https://github.com/ruanbekker/cheatsheets/blob/master/loki/logql/README.md


## Custom dashboard

Left menu, `Dashboards > New dashboard`. Use button from the toolbar `Add > Row`. Use the settings cog icon to set the title, e.g., _First row_, and click `Update`. Use the `Add` button to add a visualization.

About `$__rate_interval` and using the same scrape interval throughout your organization:

https://grafana.com/blog/2020/09/28/new-in-grafana-7.2-__rate_interval-for-prometheus-rate-queries-that-just-work/