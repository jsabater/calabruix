---
title: "Extend virtual disks and ZVOLs on Proxmox"
date: 2025-07-19
lastmod: 2025-07-19
description: "Extend the virtual disks and ZVOLs used in a VM running an NFS server on Proxmox without data loss or downtime, whether it has a partition table or not"
summary: "Extend the virtual disks and ZVOLs of your VM running an NFS server without data loss or downtime"
categories: ["virtualisation"]
tags: ["proxmox", "pve", "nfs", "zfs", "vm"]
series: ["NFS"]
series_order: 2
weight: 20
draft: true
---

On our Proxmox cluster we have configured an NFS server on a [*](VM), and for that we have used three virtual disks:

1. A 3GB disk using EXT4 on our `local` pool.
2. A 1GB disk virtual disk for the swap, on our `local` storage pool.

Eventually, the time to extend a disk will come. Extending a ZFS volume differs from extending a virtual disk in `qcow2` or `raw` format. Moreover, having a partition table will involve partition math.

## ZFS volume

To extend the ZVOL holding your data disk, follow these steps:

1. Extend the disk, using the WebGUI or the terminal.
2. Resize the filesystem inside the VM.

To perform the first step, you can either use the WebGUI or the terminal. If you prefer the former, go to the `Hardware` menu option of the VM, select the data disk and use the `Disk action > Resize` button, input the number of extra gigabytes you need and click `Resize disk`. If you prefer the latter, execute the following command from the terminal of the host (adapt the value to your needs):

```bash
zfs set volsize=+100G zfspool/vm-104-data
```

To perform the second step you need to use the VM console:

```bash
resize2fs /dev/sdc
```

> Because the disk does not have partitions, the VM does not need to be powered off to perform this operation.

## Virtual disk

To extend the size of your OS disk (a virtual disk using QCOW2 format), follow these steps:

1. Install `parted`.
2. Shut down the VM.
3. Resize the virtual disk in Proxmox GUI or CLI.
4. Boot the VM again.
5. Resize the partition and filesystem inside the VM.

Before shutting down the VM, install `parted`, the tool of choice for resizing when no LVM is involved:

```bash
apt-get install --yes parted
```

Shut down the VM, then either use the WebGUI or the terminal. If you prefer the former, go to the `Hardware` menu option of the VM, select the data disk and use the `Disk action > Resize` button, input the number of extra gigabytes you need and click `Resize disk`. If you prefer the latter, execute the following command from the terminal of the host (adapt the value to your needs):

```bash
qm resize 104 scsi0 +1G
```

Start the VM, then use `parted` in the console to resize the partition:

```bash
parted /dev/sda --script resizepart 1 100%
```

> Use `print` while in `parted` to print the current partition table.

Now instruct the kernel re-read the partition table:

```bash
partx -u /dev/sda
```

Optionally, verify the operation:

```bash
fdisk -l /dev/sda
```

Finally, resize the filesystem:

```bash
resize2fs /dev/sda1
```

Optionally, verify the results:

```bash
df -h /
```

> You can also perform the procedure using `fdisk` and `sfdisk`, but the procedure is more error-prone and cannot be automated.

## Swap

Resizing a swap disk can be simpler than resizing an OS or data partition because swap does not have a traditional filesystem. Furthermore, we do not need to preserve data.

To extend the size of your swap disk (a virtual disk using RAW format), follow these steps:

1. Install `parted`.
2. Resize the virtual disk in Proxmox GUI or CLI.
3. Turn off swap temporarily
4. Delete and recreate the swap partition.
4. Make the new swap area.
5. Enable swap again.

Get started by installing `parted`, the tool of choice for resizing when no LVM is involved:

```bash
apt-get install --yes parted
```

Use the WebGUI or the terminal to extend the disk. If you prefer the former, use the `Hardware > Disk action > Resize` button on the appropriate disk (e.g., SCSI-1), set the additional size in gigabytes and confirm. If you prefer the latter, execute the following command from the terminal of the host (adapt the value to your needs):

```bash
qm resize 104 scsi1 +1G
```

Inside the VM, turn off swap temporarily:

```bash
sudo swapoff -a
```

Use `parted` to delete and recreate the partition using the full disk size:

```bash
parted /dev/sdb --script mklabel msdos mkpart primary linux-swap 1MiB 100%
```

Now make a new swap area:

```bash
mkswap /dev/sdb1
```

And enable swap again:

```bash
swapon /dev/sdb1
```

Optionally, ensure `/etc/fstab` is still pointing at the correct UUID:

```bash
swapon --show
```
