---
title: "Gathering cluster-wide metrics with the Prometheus PVE Exporter"
date: 2025-10-27
lastmod: 2025-10-27
description: "Install and configure the PVE Exporter for Prometheus to gather metrics from a Proxmox cluster"
summary: "Collect metric data from the cluster, its nodes and all its guests using the Proxmox VE Exporter."
categories: ["infrastructure"]
tags: ["monitoring", "grafana", "prometheus", "proxmox", "pve"]
series: ["Grafana"]
series_order: 16
---

The [Proxmox VE Exporter](https://github.com/prometheus-pve/prometheus-pve-exporter) for Prometheus collects metrics from the cluster, its nodes and its guests. Specifically, it supports the following metrics for guests (LXCs and VMs):

* CPU usage: `pve_cpu_usage_ratio` and `pve_cpu_usage_limit`.
* RAM usage: `pve_memory_usage_bytes` and `pve_memory_size_bytes` (free/used).
* Disk space: `pve_disk_usage_bytes` and `pve_disk_size_bytes` (used/total for root image).
* Network I/O: `pve_network_transmit_bytes` and `pve_network_receive_bytes` (cumulative since start).
* Disk I/O: `pve_disk_write_bytes` and `pve_disk_read_bytes` (cumulative since start).
* Status: `pve_up` (whether guests are running).
* Uptime: `pve_uptime_seconds`.
* Metadata: `pve_guest_info` (name, node, type, tags).

The PVE Exporter uses the [Proxmox VE API](https://pve.proxmox.com/wiki/Proxmox_VE_API) to collect data, which is pulled by our Prometheus server, as usual. Therefore, this exporter can sit anywhere in the cluster:

1. Alongside the existing Prometheus server, provided it has enough resources.
2. In a dedicated, small LXC.
3. In each node of the cluster.

For optimal performance, the exporter should be as close as possible (in terms of network hops) to the nodes. This is because it [executes a lot of requests]({{< relref "#network-traffic" >}}) to obtain all the data it needs.

## Installation

We will be installing the exporter in each node. Therefore, the Prometheus server will contact the exporter in each node, which will gather the required metrics by sending a number of requests to the PVE API via the `localhost`. This will reduce the amount of traffic over the network and speed things up noticeably.

Incidentally, because our Prometheus server only had access to the private network of the guests and had to go through an HTTP proxy to access the Internet, we will be adding a public IP address to the LXC where it runs. This will reduce the number of network hops requests have to go through even further.

Wherever you decide to install the PVE Exporter, make sure you have a recent enough version of Python. At the moment of writing, the PVE Exporter requires Python 3.9+, so any Debian GNU/Linux from Bullseye onwards will do.

These are the steps we will follow:

1. Create a `prometheus` user.
2. Install a virtual environment for the application.
3. Install `prometheus-pve-exporter` in the virtual environment.

Let's start by making sure we have installed the necessary packages:

```bash
apt-get update
apt-get install --yes ca-certificates curl python3 \
  python3-pip python3-venv ssl-cert
```

Now let's create the user and add it to the `ssl-cert` group, so it can read the TLS certificate used for encrypted communication between the exporter and Prometheus:

```bash
adduser --system --disabled-login --comment "Prometheus daemon" \
        --home /var/lib/prometheus --groups ssl-cert prometheus
```

We are now ready to create the virtual environment:

```bash
python3 -m venv /opt/prometheus-pve-exporter
source /opt/prometheus-pve-exporter/bin/activate
```

And, finally, we can install the `prometheus-pve-exporter` into the virtual environment:

```bash
pip install prometheus-pve-exporter
deactivate
```

So that the `prometheus` user can operate without issues, the `/opt/prometheus-pve-exporter` folder and all files and subdirectories have to be readable by everyone. This should already be the case, as the default `UMASK` is 022, as defined in the `/etc/login.defs` file. You can check it out with the following command:

```bash
grep ^UMASK /etc/login.defs
```

Optionally, you can use the `find` command to make sure:

```bash
find /opt/prometheus-pve-exporter ! -perm -o=r
```

If the above command returns no results, you are ready to start the configuration steps.

## API token

We are going to need to generate a user and a token so that the Prometheus PVE Exporter can request the data it needs to generate the metrics. The easiest way to do this is via the terminal in any of the nodes:

```bash
pveum user add prometheus@pve --comment "Prometheus Monitoring"
pveum user token add prometheus@pve monitoring --privsep=0
```

This will output a token. Save it in some vault, such as [Proton Pass](https://proton.me/pass) or [Vaultwarden](https://github.com/dani-garcia/vaultwarden), and use it later on, when configuring the `/etc/prometheus/pve_exporter.yml` file.

| Key            | Value                  
|----------------|----------------------
| `full-tokenid` | `prometheus@pve!monitoring` 
| `info`         | `{"privsep":"0"}`
| `value`        | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

Finally, grant the `PVEAuditor` role (read-only) to the user:

```bash
pveum acl modify / --user prometheus@pve --role PVEAuditor
```

## Configuration

So that we have a consistent way to deploy Prometheus exporters them across our cluster, we will mimic the way they are packaged in Debian, that is, a file with the command-line arguments at `/etc/default/` and a main configuration file inside `/etc/prometheus/`.

### Command line

Let's start with the command-line arguments file at `/etc/default/prometheus-pve-exporter`:

```ini
# Environment variables for prometheus-pve-exporter
# See: https://github.com/prometheus-pve/prometheus-pve-exporter
#
# Bind to all interfaces.
# Disable the config collector for our large deployment (100+ guests),
# as it makes one API call per guest.
#
ARGS="--config.file='/etc/prometheus/pve_exporter.yml' \
      --web.listen-address='[::]:9221' \
      --collector.status \
      --collector.version \
      --collector.node \
      --collector.cluster \
      --collector.resources \
      --collector.replication \
      --no-collector.config \
      --server.keyfile='/etc/ssl/private/localdomain.com.key' \
      --server.certfile='/etc/ssl/certs/localdomain.com.crt'"
```

> The certificate in the example is a wildcard certificate for the local domain of the cluster, managed internally via PowerDNS, and issued via Let's Encrypt. Adapt it to your scenario.

### Main options

Given that this will probably be the first Prometheus-related package installed on the node, you will need to create the configuration directory first:

```bash
mkdir --parents --mode=0755 /etc/prometheus
```

You can now create the main configuration file at `/etc/prometheus/pve_exporter.yml`, with the following content:

```yaml
# Prometheus PVE Exporter configuration
# See: https://github.com/prometheus-pve/prometheus-pve-exporter
default:
  user: prometheus@pve
  token_name: "monitoring"
  token_value: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  verify_ssl: false
```

> Since the exporter will use the localhost to connect to the API, there is no point in verifying the TLS certificate of the connection.

Do not forget to restrict permissions on the `/etc/prometheus/pve_exporter.yml` file, given that it contains sensitive information:

```bash
chown prometheus:prometheus /etc/prometheus/pve_exporter.yml
chmod 600 /etc/prometheus/pve_exporter.yml
```

### Systemd

Let's end with the systemd service file at `/etc/systemd/system/prometheus-pve-exporter.service`:

```ini
[Unit]
Description=Prometheus exporter for Proxmox VE
Documentation=https://github.com/prometheus-pve/prometheus-pve-exporter
After=network.target

[Service]
Type=simple
User=prometheus
Group=prometheus
EnvironmentFile=/etc/default/prometheus-pve-exporter
ExecStart=/opt/prometheus-pve-exporter/bin/pve_exporter $ARGS

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log

# Restart policy
Restart=on-failure
RestartSec=5s

# Resource limits
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target
```

## Starting up

Our first moment of truth, let's enable and start the service:

```bash
systemctl daemon-reload
systemctl enable --now prometheus-pve-exporter.service
```

You can check the status of the service with the following command:

```bash
systemctl status prometheus-pve-exporter.service
```

And you can monitor the logs produced by the service with this command:

```bash
journalctl --follow --unit=prometheus-pve-exporter.service
```

> Do not forget to adjust the rules of your firewall so that the LXC with the Prometheus server can access the nodes with the PVE Exporter on port 9221. Remember that firewall rules at the datacentre level apply to all nodes.

You can now test the exporter from the terminal of the node:

```bash
curl "https://proxmox1.localdomain.com:9221/pve?module=default&cluster=1&node=1"
```

The list of available metrics will be useful when configuring Alert Rules in Grafana, so you may want to save it:

```bash
curl "https://proxmox1.localdomain.com:9221/pve?module=default&cluster=1&node=1" > ~/pve_exporter_metrics.txt
```

## Network traffic

Because of how the Proxmox VE API is designed, the PVE Exporter needs to perform a fairly big amount of calls to it in order to get all the information it requires. Here you are some stats, for reference.

Let's say we have 10 nodes and 200 guests, the scrape interval is set to 30 seconds and we are using the default 29 seconds cache duration of the exporter, without enabling the config collector.

| Job type | Endpoint `GET /api2/json`         | Calls | Metrics gathered                                  |
|----------|-----------------------------------|:-----:|---------------------------------------------------|
| Cluster  | `/cluster/resources`              | 1     | Nodes, VMs, LXCs, storage, and metrics for guests |
| Cluster  | `/nodes`                          | 1     | List of nodes and HA state information            |
| Node     | `/nodes/{node}/status`            | 10    | Node status                                       |
| Node     | `/nodes/{node}/storage`           | 10    | Storage information per node                      |
| Node     | `/nodes/{node}/disks/list`        | 10    | Physical disk information and SMART status        |
| Node     | `/nodes/{node}/certificates/info` | 10    | TLS certificate expiration information            |
| Node     | `/nodes/{node}/version`           | 10    | PVE version information per node                  |
| Node     | `/nodes/{node}/replication`       | 10    | VM/LXC replication status                         |

This totals **62 calls**.

If we were to enable the config collector, assuming we had 180 LXCs and 20 VMs, we would be *adding*:

| Job type | Endpoint `GET /api2/json`          | Calls | Observations                 |
|----------|------------------------------------|:-----:|------------------------------|
| Guest    | `/nodes/{node}/qemu`               | 10    | Lists all VMs on each node   |
| Guest    | `/nodes/{node}/lxc`                | 10    | Lists all LXCs on each node  |
| Guest    | `/nodes/{node}/qemu/{vmid}/config` | 20    | Individual VM configuration  |
| Guest    | `/nodes/{node}/lxc/{ctid}/config`  | 180   | Individual LXC configuration |

This totals **220 calls**.

The config collector provides an additional metric: `pve_onboot_status`. This shows whether each VM/LXC is configured to start automatically on node boot. You need to consider whether this information is relevant enough in your case to justify an additional 220 HTTP requests to the PVE API.

## Prometheus

We will add two scrape configurations to the `/etc/prometheus/prometheus.yml` file of our Prometheus server. The first one to gather cluster-level metrics:

```yaml
scrape_configs:
  - job_name: 'pve-cluster'
    static_configs:
      - targets:
          - proxmox1.localdomain.com
    metrics_path: /pve
    params:
      module: [default]
      cluster: ['1']
      node: ['0']
```

And the second one to gather node-level metrics:

```yaml
scrape_configs:
  - job_name: 'pve-nodes'
    file_sd_configs:
      - files:
        - file_sd_configs/pve_exporter.yml
    metrics_path: /pve
    params:
      module: [default]
      cluster: ['0']
      node: ['1']
```

And our `/etc/prometheus/file_sd_configs/pve_exporter.yml` would have the following content:

```yaml
- targets:
  - 'proxmox1.localdomain.com:9221'
  - 'proxmox2.localdomain.com:9221'
  - 'proxmox3.localdomain.com:9221'
  - 'proxmox4.localdomain.com:9221'
  - 'proxmox5.localdomain.com:9221'
  - 'proxmox6.localdomain.com:9221'
  - 'proxmox7.localdomain.com:9221'
  - 'proxmox8.localdomain.com:9221'
  - 'proxmox9.localdomain.com:9221'
  - 'proxmox10.localdomain.com:9221'
  labels:
    group: 'pve'
```

We need to ask Prometheus to reload its configuration file for the changes to take effect:

```bash
systemctl reload prometheus
```

This configuration efficiently scrapes cluster and guest metrics once and node-specific metrics once per node, which is the recommended approach for large clusters. All guest (VM/LXC) metrics are included automatically in the cluster-wide scrape, so you will get metrics for all your containers without needing to scrape them individually.

## Grafana dashboard

The Prometheus PVE Exporter repository provides a link to a [Proxmox via Prometheus Grafana dashboard](https://grafana.com/grafana/dashboards/10347-proxmox-via-prometheus/), which we can use as a starting point. Follow these simple steps:

1. Visit the Grafana Dashboard webiste.
2. Download the dashboard in JSON format using the `Download JSON` button.
3. In your Grafana, navigate to the `Dashboards` menu option.
4. Use the `New > Import` button and choose the downloaded JSON file.
5. Change the default name if you wish, assign a folder and select the Prometheus data source. Click `Import`.
6. Once loaded, optionally, click on `Settings` and add some tags to it.

You are set. 
