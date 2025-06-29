---
title: "Using Grafana Alerting to notify of problems in your cluster"
date: 2025-03-22
lastmod: 2025-03-22
description: "Define, evaluate and notify issues in your infrastructure."
summary: "Define, evaluate and notify issues in your infrastructure."
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "alerting"]
series: ["Grafana"]
series_order: 21
draft: true
---


[Grafana Alerting](https://grafana.com/docs/grafana/latest/alerting/) is an integrated alert management system embedded directly within the Grafana visualization platform. Tightly coupled with Grafana's dashboarding capabilities, this alerting system allows creating alert rules based on the same metrics they already monitor and visualize. The system evaluates these rules continuously against incoming data, transitioning alerts through defined states (normal, pending, alerting) as conditions evolve, with all alert management occurring within the same familiar interface used for data exploration.

The architecture of Grafana Alerting unifies alerting across multiple data sources, allowing teams to create consistent alert definitions regardless of whether the underlying metrics come from Prometheus, InfluxDB, or other supported backends. This unified approach simplifies multi-source monitoring environments by providing a single pane of glass for alert definition, evaluation, and notification. Each alert can trigger customizable notifications through various channels, with rich context including relevant graphs and annotations to speed troubleshooting.

Grafana Alerting emphasizes usability through its visual rule editor, which helps users construct alert conditions using the same query builder they use for dashboard creation. This visual approach makes alert definition more accessible to team members without deep query language expertise. The system also includes built-in features for alert history tracking, providing valuable insights into past incidents and alert behavior patterns over time. With support for contact points, notification policies, and alert grouping, Grafana Alerting provides comprehensive alert management capabilities directly integrated with visualization workflows.

### The Loki Ruler

The Loki Ruler continuously evaluates Prometheus‑style recording and alerting rules against your log data, then:

* Generates new series (recording rules) back into Loki for fast dashboards.
* Fires alerts (alerting rules) via Alertmanager when log‑based conditions occur.
* Persists evaluation state (WAL) so “for:” durations survive restarts.

It can run locally (inside the same process) or remotely (in separate workers). For a single‑instance install, `local` mode is simplest and most reliable.


```yaml
ruler:
  # Enable the ruler API for Grafana and Alertmanager,
  # which exposes the "Manage Alert Rules" endpoints.
  enable_api: true
  # Public URL of the Grafana instance
  external_url: https://grafana.publicdomain.com
  # Datasource UID for the dashboard
  datasource_uid: loki-ds

  # Evaluate recording rules locally every minute
  evaluation:
    mode: local
    evaluation_interval: 1m
    # Spread start times
    max_jitter: 15s

  # Re-scan rule‑file directory every minute
  poll_interval: 1m

  # Re-scan rule‑file directory every minute
  poll_interval: 1m

  # In-memory hashing ring
  ring:
    kvstore:
      store: inmemory             # no external KV for single instance :contentReference[oaicite:10]{index=10}:contentReference[oaicite:11]{index=11}
    heartbeat_period: 5s
    heartbeat_timeout: 1m

  #— WAL so “for:” durations survive restarts --------------------------------
  wal:
    dir: /var/lib/loki/ruler-wal
    truncate_frequency: 1h
    min_age: 5m

  #— metrics & labels --------------------------------------------------------
  query_stats_enabled: true
  disable_rule_group_label: false

  #— tenant filtering (empty = all) ------------------------------------------
  enabled_tenants: ""
  disabled_tenants: ""

```

Why these settings

* Filesystem rule storage keeps things simple—rule files live on your ZFS dataset with compression.
* Local evaluation avoids extra network hops and dependencies.
* Jitter staggers rule‑evaluation start times to smooth CPU usage.
* WAL ensures alert “for:” timers aren’t lost if the container restarts.
* In‑memory ring is sufficient when there’s only one ruler; no external KV is needed.