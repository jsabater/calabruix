---
title: "Gathering system and hardware metrics with Node Exporter"
date: 2025-11-18
lastmod: 2025-11-19
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

## Available metrics

This configuration would provide the following metrics in Prometheus, among many others:

* Total CPU time spent waiting for I/O operations `node_cpu_seconds_total{mode="iowait"}`.
* Total physical memory: `node_memory_MemTotal_bytes`.
* Estimated memory available for new workloads: `node_memory_MemAvailable_bytes`.
* Memory used for I/O buffering and caching: `node_memory_Buffers_bytes`, `node_memory_Cached_bytes`.
* Bytes read/written to disk: `node_disk_read_bytes_total`, `node_disk_written_bytes_total`.
* Number of completed read/write operations: `node_disk_reads_completed_total`, `node_disk_writes_completed_total`.
* Number of available bytes in disk: `node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs"}`.
* Bytes received/transmitted per interface: `node_network_receive_bytes_total`, `node_network_transmit_bytes_total`.
* System load averages: `node_load1`, `node_load5`, `node_load15`.
* Timestamp of last boot: `node_boot_time_seconds`

When configuring alerts, the following expression would let us know of a reboot of a VM during the last 10 minutes:

```promql
(
  (pve_uptime_seconds{job="pve-cluster", id=~"qemu/.+"} < 300)
  and
  (pve_uptime_seconds{job="pve-cluster", id=~"qemu/.+"} offset 10m > 600)
  and on(id)
  pve_guest_info{job="pve-cluster", template="0"}
) > 0
or
(
  pve_uptime_seconds{job="pve-cluster", id=~"qemu/.+"} * 0
  and on(id)
  pve_guest_info{job="pve-cluster", template="0"}
)
```

> Do not forget to allow traffic to port 9100 of your guests in your firewall.

You can use `curl` to test connectivity and obtain a list of the available metrics:

```bash
curl -k https://webapp1.localdomain.com:9100/metrics
```

## Collectors

As per the README file in its [Github repository](https://github.com/prometheus/node_exporter), Node Exporter provides a huge amount of collectors. This is the list of collectors that are enabled by default and are available in the Linux platform:

| Collector          | Description                                                                              |
|--------------------|------------------------------------------------------------------------------------------|
| `arp`              | Exposes ARP statistics from `/proc/net/arp`                                              |
| `bcache`           | Exposes bcache statistics from `/sys/fs/bcache/`                                         |
| `bonding`          | Exposes network bonding statistics from `/sys/class/net/*/bonding/`                      |
| `boottime`         | Exposes system boot time derived from `/proc/stat`                                       |
| `conntrack`        | Exposes conntrack statistics (connections, memory usage)                                 |
| `cpu`              | Exposes CPU usage metrics from `/proc/stat`                                              |
| `cpufreq`          | Exposes CPU frequency information                                                        |
| `diskstats`        | Exposes disk I/O statistics from `/proc/diskstats`                                       |
| `edac`             | Exposes error detection and correction (EDAC) statistics                                 |
| `entropy`          | Exposes available entropy from `/proc/sys/kernel/random/entropy_avail`                   |
| `exec`             | Exposes process execution statistics                                                     |
| `fibrechannel`     | Exposes Fibre Channel device statistics                                                  |
| `filesystem`       | Exposes filesystem usage (space, inodes) from `/proc/mounts` and `/proc/self/mountstats` |
| `hwmon`            | Exposes hardware monitoring metrics from `/sys/class/hwmon/`                             |
| `infiniband`       | Exposes InfiniBand statistics from `/sys/class/infiniband/`                              |
| `ipvs`             | Exposes IPVS connection statistics                                                       |
| `loadavg`          | Exposes load average from `/proc/loadavg`                                                |
| `logind`           | Exposes user session counts from logind                                                  |
| `mdadm`            | Exposes RAID status from `/proc/mdstat`                                                  |
| `meminfo`          | Exposes memory usage from `/proc/meminfo`                                                |
| `netclass`         | Exposes network interface info from `/sys/class/net/`                                    |
| `netdev`           | Exposes network device statistics from `/proc/net/dev`                                   |
| `netstat`          | Exposes network statistics from `/proc/net/netstat`, `/proc/net/snmp`, etc.              |
| `nfs`              | Exposes NFS client statistics from `/proc/net/rpc/nfs`                                   |
| `nfsd`             | Exposes NFS server statistics from `/proc/net/rpc/nfsd`                                  |
| `os`               | Exposes OS-level information                                                             |
| `powersupplyclass` | Exposes power supply state from `/sys/class/power_supply/`                               |
| `schedstat`        | Exposes scheduler statistics from `/proc/schedstat`                                      |
| `sockstat`         | Exposes socket statistics from `/proc/net/sockstat`                                      |
| `stat`             | Exposes various system statistics from `/proc/stat`                                      |
| `textfile`         | Exposes metrics read from a text file (directory configured via flag)                    |
| `thermal_zone`     | Exposes thermal zone info from `/sys/class/thermal/`                                     |
| `time`             | Exposes the current system time                                                          |
| `timex`            | Exposes time synchronization status from `adjtimex()`                                    |
| `uname`            | Exposes system information from `uname()`                                                |
| `vmstat`           | Exposes virtual memory statistics from `/proc/vmstat`                                    |
| `xfs`              | Exposes XFS filesystem statistics from `/proc/fs/xfs/stat`                               |
| `zfs`              | Exposes ZFS performance and status metrics                                               |
| `zswap`            | Exposes zswap statistics from `/sys/module/zswap/parameters/`                            |

In the example above, we enabled two additional collectors, `systemd` and `processes`, but the list of collectors disabled by default is much more extensive. This is the list of available collectors for the Linux platform:

| Collector             | Description                                                                                        |
|-----------------------|----------------------------------------------------------------------------------------------------|
| `buddyinfo`           | Exposes memory fragmentation stats from `/proc/buddyinfo`                                          |
| `cgroups`             | Exposes cgroup summary (active/enabled)                                                            |
| `cpu_vulnerabilities` | Exposes CPU vulnerability info (Spectre, Meltdown) from `/sys/devices/system/cpu/vulnerabilities/` |
| `drm`                 | Exposes GPU metrics via DRM (e.g., amdgpu)                                                         |
| `drbd`                | Exposes DRBD (Distributed Replicated Block Device) stats                                           |
| `ethtool`             | Exposes network driver stats via `ethtool -S`                                                      |
| `interrupts`          | Exposes detailed interrupt statistics                                                              |
| `kernel_hung`         | Exposes hung task count from `/proc/sys/kernel/hung_task_detect_count`                             |
| `ksmd`                | Exposes Kernel Same-page Merging stats                                                             |
| `lnstat`              | Exposes netlink statistics from `/proc/net/stat/`                                                  |
| `meminfo_numa`        | Exposes NUMA memory stats from `/sys/devices/system/node/`                                         |
| `mountstats`          | Exposes detailed NFS client stats from `/proc/self/mountstats`                                     |
| `network_route`       | Exposes routing table as metrics                                                                   |
| `pcidevice`           | Exposes PCI device info and link status                                                            |
| `perf`                | Exposes performance counter metrics (kernel-dependent)                                             |
| `processes`           | Exposes aggregate process stats from `/proc`                                                       |
| `qdisc`               | Exposes queuing discipline statistics                                                              |
| `slabinfo`            | Exposes kernel slab allocator stats from `/proc/slabinfo`                                          |
| `softirqs`            | Exposes softirq statistics from `/proc/softirqs`                                                   |
| `sysctl`              | Exposes arbitrary sysctl values                                                                    |
| `swap`                | Exposes swap usage from `/proc/swaps`                                                              |
| `systemd`             | Exposes systemd service and unit status                                                            |
| `tcpstat`             | Exposes TCP connection state from `/proc/net/tcp`                                                  |
| `wifi`                | Exposes WiFi device and station stats                                                              |
| `xfrm`                | Exposes IPsec statistics from `/proc/net/xfrm_stat`                                                |
| `zoneinfo`            | Exposes NUMA memory zone metrics                                                                   |

All these collectors can be controlled via command-line flags in our `/etc/default/prometheus-node-exporter` file:

* To enable a collector, use `--collector.<name>`.
* To disable a collector, use `--no-collector.<name>`.
* To disable all default collectors, use `--collector.disable-defaults`, then enable the ones you want one by one.

For example, to enable only CPU and memory collectors, you would configure your `/etc/default/prometheus-node-exporter` file as follows:

```ini
# Set the command-line arguments to pass to the server.
ARGS="--web.config.file=/etc/prometheus/node.yml \
      --collector.disable-defaults \
      ---collector.cpu \
      --collector.meminfo"
```

You need to restart the exporter for these changes to take effect:

```bash
systemctl restart prometheus-node-exporter.service
```
