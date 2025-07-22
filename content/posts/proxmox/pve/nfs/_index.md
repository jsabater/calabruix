---
title: "NFS server with optimised block sizes on Proxmox VE"
description: "Install and configure an NFS server on your Proxmox VE and optimise a variety of settings for performance"
summary: "Set up an NFS server on Proxmox VE and optimise for performance"
categories: ["virtualisation"]
tags: ["proxmox", "pve", "nfs", "zfs"]
---

This series of articles will guide you through the process of setting up an [NFS server](https://linux-nfs.org/) on your [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) cluster using [*](VM)s both for the server and the clients, then configuring it for performance. It includes finetuning the VM parametres, the block sizes of every I/O layer used and the actual NFS server and clients.
