---
title: "Gathering cluster and node metrics with Proxmox VE Exporter"
date: 2024-09-24
lastmod: 2025-03-15
description: "Install and configure Prometheus Proxmox VE Exporter"
summary: "Collect cluster and node metric data using the Proxmox VE Exporter."
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus", "proxmox", "pve"]
series: ["Grafana"]
series_order: 16
draft: true
---

The Proxmox VE Exporter for Prometheus collects Proxmox metrics from its nodes and the cluster.

https://pywkt.com/post/20230302-prometheus-and-grafana-on-proxmox

## Installation

We will install [prometheus-pve-exporter](https://github.com/prometheus-pve/prometheus-pve-exporter)

