---
title: "Creating and managing LinuX Containers"
date: 2023-08-01
lastmod: 2024-09-21
description: "Create and manage LinuX Containers (LXC), a lightweight alternative to fully virtualized machines (VMs), in your Proxmox cluster"
summary: "How to create and manage LinuX Containers (LXC) in a Proxmox cluster"
categories: ["virtualisation"]
tags: ["proxmox", "pve"]
series: ["PVE7"]
series_order: 7
weight: 70
draft: true
---

LinuX Containers (LXC) are a lightweight alternative to fully virtualized machines (VM). They use the kernel of the host system that they run on, instead of emulating a full operating system (OS). Check the [Linux Container wiki page](https://pve.proxmox.com/wiki/Linux_Container) on the Proxmox website.

## Installing a LXC container

We are going to use the base Debian Bullseye 11 template provided by Proxmox and install services on top of it. First of all, we need to upload the template to the node where we will be creating our guest. For that, follow these steps:

1.  On the menu, go to any Proxmox node, then select the “local” storage.
2.  On the submenu, go to “CT Templates”.
3.  Click on the “Templates” button.
4.  In the listing, filter by “bullseye”, select the “debian-11-standard” package and lick “Download”.

This process needs to be repeated for each node of the cluster so that the template is available when selecting such node when creating a container.

The next step in the initial setup is to create a pool, which we will use to group a set of virtual machines and data stores to then set permissions on, which will be inherited by all pool members. Follow these steps:

1.  On the menu, go to the “Datacenter” node.
2.  On the submenu, go to Permissions: Pools.
3.  Click on the “Create” button.
4.  In the form, add a name (e.g. “sysadmins”) and a comment (e.g. “System Administrators”).

These steps only need to be done once.

Now each time we want to create a new Linux Container (LXC), we will use the “Create CT” button on the top bar.

## Networking

As described at the beginning of this document, our LinuX Containers (LXC) will all have a first network device with a private IP address, configured as follows:

-   ID: net0
-   Name: eth0
-   MAC address: leave empty for a random one to be automatically generated
-   Bridge: vmbr4002
-   VLAN tag: no VLAN
-   Rate limit (MB/s): unlimited
-   IPv4: Static
-   IPv4/CIDR: 192.168.0.<ctid>/24
-   Gateway (IPv4): 192.168.0.13 (if needed)

Those containers that require a public IP address will have an additional network device, configured as follows:

-   ID: net1
-   Name: eth1
-   MAC address: leave empty for a random one to be automatically generated
-   Bridge: vmbr4001
-   VLAN tag: no VLAN
-   Rate limit (MB/s): unlimited
-   IPv4: Static
-   IPv4/CIDR: 116.202.120.32/28 subnet
-   Gateway (IPv4): 116.202.120.33


## ZFS volumes

| Feature                  | VM (zvol)                | LXC (ZFS dataset/subvol)    |
|--------------------------|--------------------------|-----------------------------|
| Backed by ZFS?           | Yes (zvol)               | Yes (dataset)               |
| Appears as block device? | `/dev/sdX`               | (uses ZFS dataset directly) |
| Has its own ext4 inside? | Yes (created by you)     | Uses ZFS natively           |
| Can be resized?          | Yes (zvol + `resize2fs`) | Yes (`zfs set quota`)       |
| Snapshot support?        | Yes                      | Yes                         |
| Uses ZFS directly as fs? | No                       | Yes                         |
