---
title: "Hyperconverged Proxmox VE 8 cluster at Hetzner"
date: 2025-06-08
lastmod: 2025-06-08
description: "Install and configure a multi-node, hyperconverged Proxmox Virtual Environment cluster using dedicated servers at Hetzner."
summary: "Plan, install and configure an hyperconverged Proxmox VE cluster using dedicated servers at Hetzner"
categories: ["virtualisation"]
tags: ["proxmox", "pve"]
slug: introduction
series: ["PVE8"]
series_order: 1
weight: 100
draft: true
---

Hyperconverged means combining compute, storage, networking, and virtualization into a single, software-defined system.

In a traditional data center, you have separate servers for computing, storage arrays for storage, and networking devices for connecting everything. Hyperconverged infrastructure (HCI) combines all these into a single system.

HCI typically includes a hypervisor for virtualization, software-defined storage, and network virtualization.



https://stormagic.com/company/blog/converged-and-hyperconverged-infrastructure/


You will not need virtual switches for your private networks when using a physical network switch (see the advanced setup below).

## Advanced setup

The advanced setup consists of at least three custom-tailored dedicated servers, a [hardware switch](https://docs.hetzner.com/robot/dedicated-server/general-information/root-server-hardware#miscellaneous) for the LAN of our guests, and one virtual switch. You need to place a [custom order](https://www.hetzner.com/custom-solutions/) for this.

| Name                   | Description                                            |
|------------------------|--------------------------------------------------------|
| CPU                    | Intel or AMD, 12 cores or more                         |
| Disks                  | 2x NVMe SSD for the OS and local storage, using RAID 1 |
| Disks                  | 2x HDD for the local and shared storage, using ZFS     |
| RAM                    | 128 GB ECC or more                                     |
| NIC                    | 1 Gbps, the default with any server                    |
| NIC                    | 10 Gbps, e.g., Intel X520-DA1                          |
| 12-port 10 Gbps switch | Minimum amount of ports available                      |
| LAN Connection 10 Gbit | For our local network using the hardware switch        |

In this scenario, administrative traffic among nodes[^2] and traffic among guests would happen in a 10G LAN via the hardware switch, and traffic to and from the Internet would happen through the default 1G [*](NIC) via a virtual switch.

[^2]: Includes backups and migration of guests and the [Corosync Cluster Engine](http://corosync.github.io/corosync/) traffic.

## Very heavy Internet traffic

If you plan on serving a lot of traffic through the Internet and you think that a 1 [*](Gbps) [*](NIC) will not be enough, then you could order a dual 10G [*](NIC), such as the Intel X520-DA2, and an additional 1 [*](Gbps) hardware switch.

| Name                   | Description                                      |
|------------------------|--------------------------------------------------|
| 8-port 1 Gbps switch   | Minimum amount of ports is 5                     |
| LAN Connection 1 Gbit  | For our local network using the hardware switch  |
| NIC                    | Dual 10G NIC (Intel X520-DA2)                    |
| 10G Uplink             | Outbound Internet traffic                        |

In this scenario, you would use the 1G [*](NIC) in a LAN for the administrative communication among nodes, a 10G [*](NIC) for the [*](LAN) of the guests and another 10G [*](NIC) for the Internet connection via the virtual switch.

## Types of nodes

The nodes in the basic setup will be of mixed type, that is, will have local storage for guests (same [*](NVMe) disks where the [*](OS) was installed or on separate [*](HDD) disks with ZFS) and will run applications, e.g., a Django web application or a PostgreSQL server.

Some of the nodes in the advanced setup will be of mixed type (compute and storage) and some others will solely be of storage type. The latter will be used for shared storage via [Ceph](https://ceph.io/), an open-source, distributed storage system, which will, in turn, allow us high availability.

Proxmox VE allows using the same physical nodes within a cluster for both computing and replicated storage, provided they are powerful enough. This is called a hyper-converged Ceph cluster.

```conf
# Packages and security updates from the Hetzner Debian mirror
deb http://mirror.hetzner.de/debian/packages bookworm main contrib non-free
deb http://mirror.hetzner.de/debian/packages bookworm-updates main contrib non-free
deb http://mirror.hetzner.de/debian/packages bookworm-backports main contrib non-free

# Debian mirror
deb http://ftp.de.debian.org/debian bookworm main contrib non-free
deb http://ftp.de.debian.org/debian bookworm-updates main contrib non-free
deb http://ftp.de.debian.org/debian bookworm-backports main contrib non-free

# Security updates
deb http://mirror.hetzner.de/debian/security bookworm-security main contrib non-free
deb http://security.debian.org/debian-security bookworm-security main contrib non-free
```

## Fail2ban

Debian Bookworm ships with version 1.0.2-2, which includes [a serious bug](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=770171) (also [reported upstream](https://github.com/fail2ban/fail2ban/issues/3292)) that prevents it from working out of the box. This bug has been finally fixed in version 1.0.2-3, which has not made it yet into Bookworm.

Install the `fail2ban` and `python3-systemd` packages with the `apt-get install fail2ban python3-systemd` command, then check that the service is enabled using `systemctl status fail2ban` and, if not, enable it using `systemctl enable fail2ban`.

Create a local configuration file `/etc/fail2ban/jail.local` with the following content, adjusting the port and the rest of parametres to your needs:

```ini
[DEFAULT]

# Debian 12 defaults to systemd-journald
backend = systemd
logtarget = SYSTEMD-JOURNAL

# A list of IP addresses, CIDR masks or DNS hosts that Fail2ban will not ban
ignoreip = 127.0.0.1/8 ::1

# The number of seconds that a host is banned
bantime  = 1d

# The number of failures before a host get banned
maxretry = 5

# A host is banned if it has generated "maxretry" during the last "findtime"
findtime  = 1h

[sshd]
# As per /etc/ssh/sshd_config port configuration
port = 2001

[pam-generic]
# Default values of pam-generic already use the default backend,
# but we need to enable the jail
enabled = yes
```

Create the local configuration file `/etc/fail2ban/fail2ban.local` with the following content:

```ini
[DEFAULT]

# Allows the IPv6 interface
# Prevents the 'allowipv6' not defined in 'Definition' warning
allowipv6 = yes
```

Add the Proxmox APT source to the system by creating the file `/etc/apt/sources.list.d/proxmox.sources` with the following content in [DEB822-style format](https://manpages.debian.org/unstable/apt/sources.list.5.en.html#DEB822-STYLE_FORMAT):

```properties
X-Repolib-Name: Proxmox VE
Enabled: yes
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: bookworm
Components: pve-no-subscription
Signed-By: http://download.proxmox.com/debian/proxmox-release-bookworm.gpg
Architectures: amd64
```


## ZFS

https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysadmin_zfs_limit_memory_usage
https://forum.proxmox.com/threads/limit-zfs-memory.140803/
arc_summary -s arc