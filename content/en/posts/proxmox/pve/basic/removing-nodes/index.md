---
title: "Removing nodes from a Proxmox cluster"
date: 2023-08-01
lastmod: 2024-09-21
description: "Remove nodes from a Proxmox cluster following a set of well-defined steps to avoid human errors"
summary: "Remove nodes by following a set of well-defined steps that prevent human errors"
categories: ["virtualisation"]
tags: ["proxmox", "pve"]
series: ["PVE7"]
series_order: 6
weight: 60
---

The official documentation of Proxmox describes the [procedure to remove a cluster node](https://pve.proxmox.com/wiki/Cluster_Manager#_remove_a_cluster_node). This article includes some additional steps.

## Prerequisites

The node needs to:

1. Be empty. That is, all containers and virtual machines need to be migrated to other nodes.
2. Have no replication jobs. Go to the `Replication` menu entry of the node and make sure it is empty.
3. Optionally, be offline [^1].

[^1]: This is how the official documentation recommends to do it.

## Removing the node

Let's assume we have a cluster with five nodes, named `proxmox1` to `proxmox5`, and we want to remove the `proxmox5` node. We will need to have SSH sessions open with both the node to be deleted (i.e., `proxmox5`) and any other node (e.g., `proxmox1`).

In the `proxmox1` node, use the `pvecm nodes` command to list the nodes and identify the one to be removed.

```bash
# pvecm nodes

Membership information
----------------------
    Nodeid      Votes Name
         1          1 proxmox1 (local)
         2          1 proxmox2
         3          1 proxmox3
         4          1 proxmox4
         5          1 proxmox5
```

Remove the node from the cluster by issuing the `pvecm delnode proxmox5` command.

```bash
# pvecm delnode proxmox5

Killing node 5
```

If the node was down while you issued the command, you will receive the message `Could not kill node (error = CS_ERR_NOT_EXIST)`, which can be safely ignored as it does not report an actual failure in the deletion of the node, but rather a failure in `corosync` trying to kill an offline node.

Check the node list again using the `pvecm nodes` command.

```bash
# pvecm nodes

Membership information
----------------------
    Nodeid      Votes Name
         1          1 proxmox1 (local)
         2          1 proxmox2
         3          1 proxmox3
         4          1 proxmox4
```

Using the SSH session in the now-removed node (e.g., `proxmox5`), shut it down:

```bash
shutdown -h now
```

The official documentation emphasises that the node, once removed and shut down, should never come back online again (in the same network). To quickly achieve this, you can:

* Remove the server from the virtual switches.
* Use Hetzner's rescue system to wipe the disks.

Should you need to reinstall it and reuse the same hostname or IP address, make sure you have cleaned up first, as described in the next section.

## Cleaning up

Back to the `proxmox1` SSH session, remove the configuration files of the node from the cluster. Because the `/etc/pve` directory is a cluster-wide filesystem, removal of the configuration directory and fingerprint of the node will automatically be replicated to the rest of nodes.

```bash
rm --recursive --force /etc/pve/nodes/proxmox5
```

At this point, a number of SSH-related files still have the fingerprint of the just-deleted node (e.g., `proxmox5` or `10.0.0.5`):

| Path to file                    | Linked by                  |
|---------------------------------|----------------------------|
| `/etc/pve/priv/known_hosts`     | `/etc/ssh/ssh_known_hosts` |
| `/etc/pve/priv/authorized_keys` | `/root/authorized_keys`    |
| `/root/.ssh/known_hosts`        |                            |

To clean it up, execute the following commands on the SSH session of the `proxmox1` node:

```
sed -i.bak '/proxmox5\|\b10.0.0.5\b/d' /etc/pve/priv/known_hosts
sed -i.bak '/proxmox5\|\b10.0.0.5\b/d' /etc/pve/priv/authorized_keys
ssh-keygen -f "/root/.ssh/known_hosts" -R "proxmox5"
ssh-keygen -f "/root/.ssh/known_hosts" -R "10.0.0.5"
```

Again, changes in the files inside `/etc/pve/priv/` will be replicated across the cluster. However, changes in the `/root/.ssh/known_hosts` file will not.

We cannot use `ssh-keygen -R` on the files inside `/etc/pve/priv/` because there are hardlinks pointing at them and the command would fail with the following error:

```bash
# ssh-keygen -f "/etc/pve/priv/known_hosts" -R "10.0.0.5"

# Host 10.0.0.5 found: line 25
link /etc/pve/priv/known_hosts to /etc/pve/priv/known_hosts.old: Function not implemented
```

## Final notes

In Proxmox 8, the link `/etc/ssh/ssh_known_hosts` no longer exists and, if it does, it can be safely removed using `pvecm updatecerts --unmerge-known-hosts`.

If you receive an SSH error after rejoining a node with the same IP or hostname, run `pvecm updatecerts` once on each node to update its fingerprint cluster wide.

If the node that was deleted had a ZFS pool, you need to edit the `/etc/pve/storage.cfg` file and remove the node name from the `nodes` key of the `zfspool` entry.
