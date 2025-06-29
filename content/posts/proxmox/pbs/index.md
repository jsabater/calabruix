---
title: "Install and configure Proxmox Backup Server"
date: 2024-08-23
description: "Install and configure a primary and a replica backup servers using Proxmox Backup Servers on dedicated servers at Hetzner and OVH."
summary: "Efficiently back up nodes, LXC and VM in your Proxmox VE using Proxmox Backup Server."
categories: ["virtualisation"]
tags: ["proxmox", "pbs"]
series: ["Proxmox Backup Server"]
series_order: 1
draft: true
---

We are going to set up a Proxmox Backup Server 3.4 on top of a Debian 12 Bookworm using a dedicated server. Two providers are used at the moment:

1. Hetzner, where the server has a public IPv4 and a public IPv6 address, with one MAC address, a couple of SSD disks for the OS and a couple of HDD disks for the backup storage. This acts as the primary backup server, connected to the Proxmox Virtual Environment via a local network, though a virtual switch (vSwitch `#4003`).
2. OVH, where the server has a public IPv4 address, with one MAC address, one SSD disk for the OS and four HDD disks for the backup storage. This acts as a replica of the primary backup server.

In case of Hetzner, installation will be performed via the [installimage](https://docs.hetzner.com/robot/dedicated-server/operating-systems/installimage/) command on the rescue system. In the configuration editor of the installer we will comment out the extra HDD disks and set the `SWRAIDLEVEL` to 1 so that the installer only uses the two SSD disks for the operating system.

In case of OVH, installation is performed through the control panel, using its Debian 12 template.

# Design

We will be using two Proxmox Backup Servers. One is where all snapshots and dumps of containers and virtual machines from the PVE will be sent to, hosted at Hetzner, and the second is where the first will replicate backups to, for safety, using the [remotes feature](https://pbs.proxmox.com/docs/managing-remotes.html). This second one will be on a different hosting provider and country.

The Proxmox cluster uses three VLANs:

* Id `4001` , Proxmox guests public network (`116.202.120.32/28`), for the guests public addresses.
* Id `4002` , Proxmox guests private network (`192.168.0.0/16`), used for the application running in the virtual machines to communicate.
* Id `4003` , Proxmox hosts private network (`10.0.0.0/8`), used for the nodes (hosts) of the cluster to communicate among themselves (Corosync, VM migration, etc.)

We will be using the VLAN with id `4003` so that the cluster nodes and the backup server are in the same local network.

> Note: See the [Proxmox VE design]({{< ref "/posts/proxmox/pve/basic/introduction" >}}) article for more information.
