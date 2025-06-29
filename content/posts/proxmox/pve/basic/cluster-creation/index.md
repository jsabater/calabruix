---
title: "Creating the Proxmox cluster"
date: 2023-08-01
lastmod: 2024-09-21
description: "Creating a Proxmox cluster, issuing the necessary certificates and configuring the firewall"
summary: "Creating a Proxmox cluster and configuring the firewall"
categories: ["virtualisation"]
tags: ["proxmox", "pve"]
series: ["PVE7"]
series_order: 4
weight: 85
---

This article will lead you through the necessary steps to create the cluster and perform its initial configuration. Both the Hetzner firewall and the Proxmox firewall will be configured to allow the necessary traffic between the cluster nodes and the guests.

In previous articles, we set up the `10.0.0.0/24` local network for our nodes by performing the following steps:

1. Configured the `eno1.4003` interface on each node.
1. Configured the `/etc/hosts` file on each node.
2. Created the vSwitch with id `4003` and added the nodes to it.

Therefore, nodes should be able to ping each other over this network.

## Certificates

By default, Proxmox [installs a self-signed certificate](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysadmin_certificate_management). We will be using [Let’s Encrypt](http://letsencrypt.org/) through the [ACME protocol](https://datatracker.ietf.org/doc/html/rfc8555) (Automatic Certificate Management Environment) to obtain a valid certificate for the node, which will be renewed automatically by Proxmox from then onwards.

> This section only applies the first time a new cluster is configured. Skip it when adding a new node to an existing cluster.

### Account

At the first server (not yet a node since we have not created the cluster yet) we will configure the account, then the challenge plug-in. Using the WebGUI, go to the `Datacenter > ACME` menu option and add the account using the button on the top:

* Account name: `<somename>`, e.g., `calabruix`.
* E-Mail: `<youremail>`, e.g., `certs@publicdomain.com`.
* ACME Directory: `Let's Encrypt V2` (production).

Accept the terms of service and click `Register`.

### Challenge plug-in

The default challenge plugin is `HTTP`, which is already installed. For it to work, the following conditions must be met:

* Port 80 of the node needs to be reachable from the internet (i.e., a firewall rule needs to be added).
* There must be no other listener on port 80.
* The requested subdomain (e.g., `proxmox1.publicdomain.com`) needs to resolve to the public IP of the node.

Optionally, if you are using Cloudflare, you can add an additional challenge using DNS by using the `Add` button right below the `Challenge Plugins` section:

* Plugin id: `cloudflare`
* Validation delay: 30
* DNS API: `Cloudflare Managed DNS`
* Account id: `[..]`
* Token: `[..]`
* Zone id: `[..]` (optional)

The account id and zone id can be copied from the bottom right corner of the `publicdomain.com` domain overview page at [Cloudflare’s dashboard](https://dash.cloudflare.com/). The API token can be obtained (with finegrained permissions) at the [API Tokens menu option](https://dash.cloudflare.com/profile/api-tokens) of your user's profile.

### Issuing the certificate

In the main menu, select the server `proxmox1`, go to the `System > Certificates` menu option and, in the `ACME` section, use the `Add` button to add the certificate request data:

* Challenge type: `DNS` or `HTTP`
* Plug-in: `cloudflare` (if you selected the DNS challenge type)
* Domain: `proxmox1.publicdomain.com`

Still in the `ACME` section of the screen, choose the account by clicking the `Edit` button next to the `Using account` label, select the account created before (e.g., `Calabruix`) and click `Apply`. Finally, click the `Order Certificates Now` button.

The process will place the order, which will consist of:

1. Validating the ownership of the domain.
2. Sending the CSR (certificate request).
3. Waiting for the certificate to be issued.
4. Installing the certificate and restarting the PVE Proxy.

Once the process is finished, you will need to close the browser tab and open a new one to access the WebGUI using the new certificate.

> Proxmox will take care of renewing the certificate automatically.

Unfortunately, wildcard certificates cannot be issued through the user interface so we will have to repeat the process for each node once it has become part of the cluster.

# Cluster creation

The cluster will be created on the first node, then the second and third nodes will join it. The following command will create the cluster and set up the necessary configuration files on the first node.

Access the WebGUI of the first node at `https://proxmox1.<publicdomain.com>:8006/` and log in with the root user:

* User name: `root`
* Password: `<yourpassword>`
* Realm: `Linux PAM standard authentication`
* Language: `English - English` (default)

To create a cluster go to `Datacenter > Cluster` and click on `Create cluster`. Use this information:

* Cluster name: `<clustername>`
* Cluster network: choose the node private address `10.0.0.1` from the list.

Hit `Create` and wait for the process to finish. The server is now a node of a single-node cluster.

Alternatively, you can create the cluster from the terminal by running the following command:

```bash
pvecm create <clustername>
```

Where `<clustername>` is the name of your cluster, e.g., `calabruix` or `staging`.

# Two-Factor Authentication

To enhance security, it is recommended to enable Two-Factor Authentication (2FA) for the root user. This can be done through the WebGUI by going to the menu option `Datacenter > Users > Two Factor` and click the button `Add: TOTP`. Follow the usual steps.

> For 2FA to work, it requires the exact same software versions on all nodes.

## Hetzner's firewall

[Hetzner's firewall](https://docs.hetzner.com/robot/dedicated-server/firewall/) only takes care of incoming traffic and its rules are processed before the packets arrive at our Proxmox installation, including the packets that travel through the vSwitches (VLAN), including the public IP subnet.

It is a secondary layer of protection but it does not protect against DDoS attacks. For that, Hetzner includes an [automated system](https://www.hetzner.com/unternehmen/ddos-schutz), which is always active and included with the server fees.

The number of rules are limited to 10. Rule number 11 is to drop all incoming traffic not allowed before. Create the firewall template using the `New template` button in the [Firewall templates](https://robot.hetzner.com/firewall/templateIndex) page of the control panel. Adapt the following proposal to your needs:

* Name: `Proxmox VE`
* Use by default: `Yes`
* Filter IPv6 packets: `No`
* Hetzner services (incoming): `Yes`

| # | Name                      | Source IP        | Destination IP           | S. port | D. port     | Protocol | TCP flags | Action |
|---|---------------------------|------------------|--------------------------|---------|-------------|:--------:|:---------:|--------|
| 1 | Ping                      |                  |                          |         |             | icmp     |           | accept |
| 2 | Proxmox WebGUI            |                  |                          |         | 8006        | tcp      |           | accept |
| 3 | OpenSSH                   |                  |                          |         | 2001-2010   | tcp      |           | accept |
| 4 | HTTP                      |                  |                          |         | 80,443      | *        |           | accept |
| 5 | Proxmox hosts             | `10.0.0.0/24`    | `10.0.0.0/24`            |         |             | *        |           | accept |
| 6 | Proxmox guests            | `192.168.0.0/16` | `192.168.0.0/16`         |         |             | *        |           | accept |
| 7 | Public subnet             |                  | `v4.public.ip.subnet/28` |         |             | *        |           | accept |
| 8 | Ephemeral port range [^1] |                  |                          |         | 32768-65535 | tcp      | ack       | accept |

[^1]: You can check the ephemeral port range of your Proxmox installation by running `sysctl net.ipv4.ip_local_port_range` on any of the nodes.

Select and apply the template to all the servers via the `Firewall` tab of each server in the [server list](https://robot.hetzner.com/server) of the control panel.

> In the ruleset above, all traffic to the floating public IP addresses is allowed, which means it is only filtered by the [PVE Firewall](https://pve.proxmox.com/wiki/Firewall). Once all the services in the cluster have been set up, it may be a good idea to revisit rule number 7.

## Proxmox's firewall

The [Proxmox VE firewall](https://pve.proxmox.com/pve-docs-7/chapter-pve-firewall.html) allows setting up firewall rules for all hosts inside a cluster, as well as for virtual machines and containers. Features like macros, security groups, IP sets and aliases help making that task easier.

All firewall related configuration is stored in the Proxmox cluster file system at `/etc/pve/`, so those files are automatically distributed to all cluster nodes, and the `pve-firewall` service updates the underlying *iptables* rules automatically on changes. Because the *iptables*-based firewall service runs on each cluster node, it provides full isolation between virtual machines.

The PVE Firewall groups the network into two logical zones:

* **Hosts**: Traffic from/to a cluster node.
* **Guests**: Traffic from/to a virtual machine or container.

By default, the firewall is disabled at the datacentre and guest levels, and enabled at the node level. We can check this by visiting the `Datacenter > Firewall > Options` menu option.

```ini
# /etc/pve/firewall/cluster.fw
[OPTIONS]

enable: 1
```

When the firewall is disabled at the datacentre level, it will remain disabled even if enabled at the node level. To enable the firewall for a node, you must first enable it at the datacentre level. To enable the firewall for a guest, you must first enable it at both the datacentre and node levels.

```ini
# /etc/pve/nodes/<node>/firewall/host.fw
[OPTIONS]

enable: 1
```

> Note: The firewall is enabled by default at the node level, so you will not see the `enable` option in the file unless you disable it first.

The default policies are to accept all outgoing traffic and to drop all incoming traffic.

### IP aliases

IP aliases allow us to associate an IP address or subnet to a name. We will be able to refer to those names inside IP set definitions and in source and destination properties of firewall rules. For example, we can create a few aliases for some guests we already have plans for.

```ini
# /etc/pve/firewall/cluster.fw

[ALIASES]

ipv4_private_ansible1 192.168.0.1 # Ansible Controller
ipv4_private_nginx1 192.168.0.2 # NGINX 1
ipv4_private_nginx2 192.168.0.3 # NGINX 2
ipv4_public_nginx1 v4.floating.ip.1 # NGINX 1
ipv4_public_nginx2 v4.floating.ip.2 # NGINX 2
ipv4_public_office v4.office.ip.addr # Work office
```

> An alias named `localnet` is automatically defined by Proxmox to represent the local network. Use the command `pve-firewall localnet` to see assigned values.

IPv4 and IPv6 aliases are added separately at the `Datacenter > Firewall > Alias` menu option, hence the prefix.

### IP sets

IP sets allow us to associate a number of aliases or subnets to a name. We will be able to refer to those names in source and destination properties of firewall rules. For example, we can create an two IP sets named `private_webservers` and `public_webservers` with their respective aliases.

```ini
# /etc/pve/firewall/cluster.fw

[IPSET private_webservers] # NGINX guests

ipv4_private_nginx1
ipv4_private_nginx2

[IPSET public_webservers] # NGINX guests

ipv4_public_nginx1
ipv4_public_nginx2
```

The following three IP sets have special meanings when **manually** created by the administrator:

| Name            | Description                                            | Zone          |
|-----------------|--------------------------------------------------------|---------------|
| `management`    | Allows IPs to do access management tasks (WebGUI, SSH) | Hosts         |
| `blacklist`     | Blocks specific IP addresses                           | Hosts, guests |
| `ipfilter-netX` | Used in every guest's firewall to prevent IP spoofing  | Guests        |

When added, they will be found in the `/etc/pve/firewall/cluster.fw` file:

```ini
# /etc/pve/firewall/cluster.fw

[IPSET management]
ipv4_public_office

[IPSET blacklist]
some.funny.ip.address
another.funny.ip.address

[IPSET ipfilter-net0] # Only allow IPs from the private network on net0
192.168.0.0/16
```

For containers with configured IP addresses, the `ipfilter-netX` sets, if they exist (or are activated via the general `IP Filter` option in the guest's `Firewall > Options` tab), implicitly contain the associated IP addresses. If such a set exists for an interface, then any outgoing traffic with a source IP not matching its interface's corresponding ipfilter set will be dropped.

### Security groups

Security groups are collection of rules, defined at cluster level, which can be used in all guests' rules. For example, we can create a security group named `webserver` with rules to open the HTTP and HTTPS ports.

```ini
# /etc/pve/firewall/cluster.fw

[group webserver] # Default rules for web servers

IN HTTP(ACCEPT) -log nolog # Allow HTTP traffic
IN HTTPS(ACCEPT) -log nolog # Allow HTTPS traffic
IN ACCEPT -p udp -dport 443 -log nolog # Allow HTTP/3 traffic
```

Then, this group can be added to a guest's firewall:

```ini
# /etc/pve/firewall/<VMID>.fw

[RULES]
GROUP webserver -i net0 # Allow access to NGINX from guests
GROUP webserver -i net1 # Allow access to NGINX from the Internet
```

### Configuration

At the moment, after installation, the following addresses and ports have services listening on them:

| Service      | Description            | Address          | Port | Protocols |
|--------------|------------------------|------------------|------|-----------|
| `pvedaemon`  | Proxmox VE API Daemon  | `127.0.0.1`      | 85   | TCP       |
| `master`     | Postfix                | `127.0.0.1`      | 25   | TCP       |
| `init`       | RPC bind               | `0.0.0.0`        | 111  | TCP, UDP  |
| `sshd`       | Secure SHell           | `v4.static.ip.1` | 2001 | TCP       |
| `sshd`       | Secure SHell           | `v4.static.ip.1` | 22   | TCP       |
| `pveproxy`   | Web interface          | `0.0.0.0`        | 8006 | TCP       |
| `spiceproxy` | [*](SPICE) [^2]        | `0.0.0.0`        | 3128 | TCP       |
| `corosync`   | Clustering Engine [^3] | `10.0.0.1`       | 5405 | UDP       |

[^2]: A remote display system used by Proxmox VE to provide access to virtual machines.
[^3]: A [cluster management](https://pve.proxmox.com/wiki/Cluster_Manager) tool used by Proxmox VE to coordinate multiple nodes.

However, this list of ports needs to be expanded with the following:

| Service    | Description       | Address          | Ports       | Protocols      |
|------------|-------------------|------------------|-------------|----------------|
| `QEMU`     | VNC Web console   | `v4.static.ip.1` | 5900-5999   | TCP, Websocket |
| `corosync` | Clustering Engine | `10.0.0.1`       | 60000-60050 | UDP            |
| `QEMU`     | Live migration    | `10.0.0.1`       | 5900-5999   | TCP            |

Before adding new nodes to the cluster, we are going to do a basic configuration of the firewall on our only node, `proxmox1`, using the web interface.

Using the `Datacenter > Firewall > Alias` menu option we will be creating aliases

* For each node.
* For the IP address of our work place.
* Per private network range, for future use (optionally).

| Name                   | IP/CIDR             | Comment     |
|------------------------|---------------------|-------------|
| `ipv4_public_proxmox1` | `v4.static.ip.1`    | Proxmox 1   |
| `ipv4_public_proxmox2` | `v4.static.ip.2`    | Proxmox 2   |
| `ipv4_public_proxmox3` | `v4.static.ip.3`    | Proxmox 3   |
| `ipv4_public_office`   | `v4.office.ip.addr` | Work office |
| `ipv4_link_local_169`  | `169.254.0.0/16`    | RFC3927     |
| `ipv4_private_10`      | `10.0.0.0/8`        | RFC1918     |
| `ipv4_private_172`     | `172.16.0.0/12`     | RFC1918     |
| `ipv4_private_192`     | `192.168.0.0/16`    | RFC1918     |
| `ipv4_shared_100`      | `100.64.0.0/10`     | RFC6598     |

> Later one we will add aliases for guests.

Using the `Datacenter > Firewall > IPSet` menu option we will be creating IP sets:

* For private networks.
* For Hetzner's System Monitor.
* For the cluster nodes public addresses, using the alias we created before.
* For the management IP addresses.

| Name                    | Comment        | Aliases                                                                                 |
|-------------------------|----------------|-----------------------------------------------------------------------------------------|
| `management`            | Management IPs | `ipv4_public_office`                                                                    |
| `private_hosts`         | Hosts          | `ipv4_private_10`                                                                       |
| `private_guests`        | Guests         | `ipv4_private_192`                                                                      |
| `public_hetzner_sysmon` | Hetzner SysMon | `188.40.24.211`, `213.133.113.82`, `213.133.113.83`, `213.133.113.84`, `213.133.113.86` |
| `public_hosts`          | HOsts          | `ipv4_public_proxmox1`, `ipv4_public_proxmox2`, `ipv4_public_proxmox3`                  |

If we enable the firewall, traffic to all hosts is blocked by default, with the only exceptions being the web interface (WebGUI) on port 8006 and the secure shell (OpenSSH) on port 22, but only from the local network and the IP addresses added to the `management` IP set.

Finally, using the `Datacenter > Firewall` menu option we will be creating rules:

* To allow ping among nodes.
* To allow ping among guests.
* To allow ping from anywhere (optionally).
* To allow inbound traffic to the WebGUI not only from management IPs (optionally).
* To allow ping from [Hetzner Server Monitoring](https://docs.hetzner.com/robot/dedicated-server/security/system-monitor/) (optionally).
* To allow connections to the public static IP addresses of the cluster nodes via SSH.

| Type | Action | Macro | Iface | Protocol | Source                   | S. port | Destination       | D. port   | Comment                              |
|------|--------|-------|-------|:--------:|--------------------------|---------|-------------------|:---------:|--------------------------------------|
| in   | ACCEPT | Ping  |       |          | `+public_hetzner_sysmon` |         | `+public_hosts`   |           | Allow ping from Hetzner's SysMon     |
| in   | ACCEPT | Ping  |       |          | `+private_hosts`         |         | `+private_hosts`  |           | Allow ping among nodes               |
| in   | ACCEPT | Ping  |       |          | `+private_guests`        |         | `+private_guests` |           | Allow ping among guests              |
| in   | ACCEPT |       |       | tcp      |                          |         | `+public_hosts`   | 8006      | Allow access to WebGUI from anywhere |
| in   | ACCEPT |       |       | tcp      |                          |         | `+public_hosts`   | 2001:2010 | Allow external SSH traffic to node |

You will want to adapt these rules to your needs. For instance, you may want to add a rule to allow some external uptime monitoring solution to access the WebGUI so that an HTTP check can be performed.

> We do not need to add a rule to allow SSH traffic among nodes (subnet `10.0.0.0/24`) because that is automatically set by the PVE Firewall.

If you want to be more explicit regarding access via SSH to the nodes, add the following rule via `Datacenter > Node > Firewall` on each node, adapting the port to each node:

| Type | Action | Macro | Interface | Protocol | Source | S. port | Destination | D. port | Comment                            |
|------|--------|-------|-----------|:--------:|--------|---------|-------------|---------|------------------------------------|
| in   | ACCEPT |       |           | tcp      |        |         |             | 2001    | Allow external SSH traffic to node |

> We previously configured our SSH daemons to listen to port 2001 and onwards on their public IP addresses.

Open a SSH connection to one of your Proxmox VE hosts before enabling the firewall so that you still have access to the host if something goes wrong, then enable the firewall at the datacentre level by using the `Datacenter > Firewall > Options > Firewall` menu option.

Later on, more firewall rules will be added at the guest level to allow access to specific services from certain locations.

### Default rules

Some traffic is automatically filtered by the default firewall configuration. This acts as a safeguard, to prevent lock-outs.

At the datacentre level, if the input or output policy is set to `DROP` or `REJECT`, the following traffic is still allowed for all hosts in the cluster:

| Protocol  | Description                                                                    |
|-----------|--------------------------------------------------------------------------------|
| Any       | Traffic over the loopback interface                                            |
| Any       | Already established connections                                                |
| [*](IGMP) | Manage multicast group memberships                                             |
| TCP       | From `management` IPSet to port 8006 (WebGUI)                                  |
| TCP       | From `management` IPSet to port range 5900-5999 (VNC web console)              |
| TCP       | From `management` IPSet to port 3128 (SPICE proxy)                             |
| TCP       | From `management` IPSet to port 22 (SSH)                                       |
| UDP       | From the cluster network to port range 5405-5412 (Corosync)                    |
| UDP       | Multicast traffic in the cluster network                                       |
| ICMP      | Type 3 (destination unreachable), 4 (congestion control) or 11 (time exceeded) |

[^4]: This allows multiple Proxmox nodes to communicate with each other efficiently by sending a single data stream to a group of recipients rather than individual unicast transmissions.

However, the following traffic is dropped, but not logged even with logging enabled:

| Protocol/Mode  | Description                                                                  |
|----------------|------------------------------------------------------------------------------|
| TCP            | Connections with invalid connection state                                    |
| Broadcast [^5] | Not related to corosync, i.e., not through ports 5405-5412                   |
| Multicast [^6] | Not related to corosync, i.e., not through ports 5405-5412                   |
| Anycast [^7]   | Not related to corosync, i.e., not through ports 5405-5412                   |
| TCP            | Traffic to port 43 (WHOIS)                                                   |
| UDP            | Traffic to ports 135 ([*](RPC) endpoint mapper) and 445 ([*](SMB))           |
| UDP            | Traffic to the port range 137-139 ([*](NetBIOS))                             |
| UDP            | Traffic form source port 137 (NetBIOS Name Service) to port range 1024-65535 |
| UDP            | Traffic to port 1900 ([*](SSDP))                                             |
| TCP            | Traffic to port 135, 139 and 445 (see above)                                 |
| UDP            | Traffic originating from source port 53 ([*](DNS))                           |

[^5]: In broadcast, a single packet is sent to all devices on a network segment. It is a one-to-all communication. 
[^6]: Multicast sends a packet to a specific group of devices, rather than all devices on the network. It is a one-to-many communication. 
[^7]: Anycast delivers a packet to the *nearest* member of a group of potential receivers. This is a one-to-nearest communication, typically used to optimise delivery and reduce latency.

At the guest level, if the input or output policy is set to `DROP` or `REJECT`, this drops or rejects all the traffic to the guests, with some exceptions for [*](DHCP), [*](NDP), router advertisement, [*](MAC) and IP filtering depending on the set configuration. The same rules for dropping/rejecting packets are inherited from the datacenter, while the exceptions for accepted incoming/outgoing traffic of the host do not apply.

### Logging

By default, all logging of traffic filtered by the firewall rules is disabled. To enable logging, the loglevel for incoming or outgoing traffic has to be set in the `Firewall > Options` menu option. This can be done individually for the host as well as for the guests.

When enabled, output of logging of Proxmox VE's standard firewall rules can be reviewed via the `Firewall > Log` menu option. However, only some dropped or rejected packets are logged for the standard rules.

## ZFS pool

[*](ZFS) is a modern, open-source filesystem and logical volume manager designed for scalability, data integrity, and simplified storage administration. Unlike traditional filesystems, ZFS integrates the following features into a single cohesive system:

* Volume management.
* Advanced RAID (software-defined redundancy).
* Snapshots.
* Compression.
* Built-in checksumming.

Each node of the cluster should have a pair of [*](SSD) disks, set up with [*](RAID) 1 upon installation, that hold the operating system and offer space for containers and virtual machines as well. If they have additional [*](HDD) or SSD we can set a ZFS pool on them and benefit from the extra features that this filesystem offers for our Proxmox cluster, the most relevant being:

1. Thin provisioning when assigning virtual disks to a [*](VM) or subvolumes to an [*](LXC).
2. No need to manage partitions, as ZFS combines volume management, filesystem, and RAID functionality into a single stack.
3. Instant snapshots and clones with near-zero storage overhead.
4. Built-in compression (LZ4), that reduces storage footprint (~2-3x) with minimal CPU impact, improving effective I/O throughput.
5. Adaptive Read Cache (ARC) optimises RAM usage. Optionally, SSD-based [*](L2ARC) boosts read performance for HDD-backed pools [^7].

[^7]: You will need to order an extra SSD disk for the server.

Provisioning generally refers to the process of making resources or services available to users, systems, or applications. In our current context, provisioning refers to how storage space is allocated to virtual disks. ZFS uses thin provisioning by default, meaning it reserves the requested space but does not immediately consume the physical space. This leads to three key benefits:

* Space efficiency. When you create a 100GB virtual disk (zvol), ZFS reserves but does not immediately consume 100GB of physical space.
* Dynamic growth. Physical storage is allocated incrementally only as data is actually written by the guest.
* Overcommitment. You can safely allocate more virtual storage than physically available (e.g., assign 2TB total to guests on a 1TB pool).

We already installed the `zfsutils-linux` package when we installed Proxmox, so the `zfs` kernel module should already be loaded. Therefore, in the WebGUI, we can navigate straight to the `Disks > ZFS` menu option of the node with the spare disks, should we have any, and click on the `Create ZFS` button. Fill in the necessary details:

* Name: `zfspool` [^8]
* RAID level: Mirror
* Compression: on
* ashift: 12

[^8]: Make sure that all your ZFS pools share the same name across the nodes of the cluster.

Select the two disks from the list below (e.g., `/dev/sda` and `/dev/sdb`) and click the `Create` button. If you left the `Add storage` checkbox ticked, you will also get it added to the Proxmox VE Storage, available at `Datacenter > Storage`.

Finally, regarding the ZFS ARC, it would be ideal if we could allocate ~1GB of [*](RAM) per TB of storage for ARC efficiency. Let's asume our node has 2x 8TB HDD assigned to the ZFS pool. Therefore, we would aim for 8GB of RAM via the `/etc/modprobe.d/zfs.conf` configuration file:

```ini
options zfs zfs_arc_max=8589934592
options zfs zfs_arc_min=4294967296
```

You will need to reboot the server for these changes to take effect.
