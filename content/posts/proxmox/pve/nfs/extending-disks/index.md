---
title: "Extend virtual disks and ZVOLs on Proxmox"
date: 2025-07-19
lastmod: 2025-08-19
description: "Extend the virtual disks and ZVOLs used in a Proxmox VM without data loss, whether it has a partition table or not"
summary: "Extend the virtual disks and ZVOLs of your VM running an NFS server without data loss"
categories: ["virtualisation"]
tags: ["proxmox", "pve", "nfs", "zfs", "vm"]
series: ["NFS"]
series_order: 2
weight: 20
---

On our Proxmox cluster we have configured an NFS server on a [*](VM), and for that we have used three virtual disks:

1. A 3 GB virtual disk using QCOW2 format, on our `local` storage, for the OS, which we formatted using EXT4.
2. A 1 GB virtual disk using RAW format, on our `local` storage, for the swap.
3. A 100 GB  virtual disk using a block device (ZVOL), on our `zfspool` storage, for the data, mounted on `/srv/nfs`.

Inside the VM, these disk correspond to `/dev/sda`, `/dev/sdb` and `/dev/sdc`, respectively, and are mounted using UUID in the `/etc/fstab` file.

Eventually, the time to extend a disk will come. Extending a ZFS volume differs from extending a virtual disk in `qcow2` or `raw` format. Moreover, having a partition table will involve partition math.

## ZFS volume

To extend the ZVOL holding the data disk, follow these steps:

1. Resize the disk image or block device.
2. Resize the filesystem inside the VM.

To perform the first step, you can either use the WebGUI or the terminal. If you prefer the former, go to the `Hardware` menu option of the VM, select the data disk and use the `Disk action > Resize` button, input the number of extra gigabytes you need and click `Resize disk`. If you prefer the latter, execute the following command from the terminal of the host (adapt the value to your needs):

```bash
zfs set volsize=+100G zfspool/vm-104-disk-0
```

After resizing the disk, use `lsblk` to check that the OS has already detected the new size. If it does not show the new size, use the following command to instruct the OS to rescan the block device:

```bash
echo 1 > /sys/class/block/sdc/device/rescan
```

To perform the second step you need to use the VM console:

```bash
xfs_growfs /dev/sdc
```

> Make sure the disk is mounted before running `xfs_growfs`.

XFS supports online resizing, while mounted and even while actively being used. However, if the disk is under heavy load, you might want to temporarily reduce I/O to avoid unpredictable behaviour.

## OS disk

To extend the size of your OS disk (a virtual disk using QCOW2 format), follow these steps:

1. Resize the virtual disk using the Proxmox CLI (or GUI, if you prefer).
2. Grow the partition.
3. Resize the filesystem inside the VM.

First of all, start by installing `growpart`, the tool of choice for resizing mounted disks when no LVM is involved:

```bash
apt-get install --yes cloud-guest-utils
```

> In Debian, the `growpart` command is part of the `cloud-guest-utils` package, which is pre-installed on cloud images but not on ISO Netinst images.

Use the terminal of the host to execute the following command (adapt the value to your needs):

```bash
qm resize 104 scsi0 +1G
```

If you check the kernel messages using `dmesg`, you will notice the following messages (numbers will vary depending on your previous size and how much space you added):

```console
sd 0:0:0:0: Capacity data has changed
sd 0:0:0:0: [sda] 8388608 512-byte logical blocks: (4.29 GB/4.00 GiB)
sda: detected capacity change from 6291456 to 8388608
```

If you now log into the VM via SSH, you can use `lsblk` to realise that the new disk size has already been caught up by the kernel. However, the `/dev/sda1` partition still shows the old size:

```console
# lsblk /dev/sda
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   4G  0 disk 
└─sda1   8:1    0   3G  0 part /
```

Use `growpart` in the console of the VM to resize the partition:

```bash
growpart /dev/sda 1
```

We can now see the changes in the partition using `lsblk`:

```console
# lsblk /dev/sdb
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
sda      8:16   0   4G  0 disk 
└─sda1   8:17   0   4G  0 part /
```

However, the filesystem still shows the previous value:

```console
# df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       2.9G  1.4G  1.5G  48% /
```

Therefore, all that is left is to use the EXT4 resizer to resize the filesystem:

```bash
resize2fs /dev/sda1
```

And verify the results:

```console
# df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       3.9G  1.4G  2.5G  36% /
```

> You can also perform the procedure using `fdisk` and `sfdisk`, but it is more error-prone and cannot be automated.

## Swap disk

Resizing a swap disk can be simpler than resizing an OS or data partition because swap does not have a traditional filesystem. Furthermore, we do not need to preserve data.

To extend the size of your swap disk (a virtual disk using RAW format), follow these steps:

1. Resize the virtual disk in Proxmox GUI or CLI.
2. Turn off swap temporarily
3. Make the new swap area.
4. Enable swap again.

Use the WebGUI or the terminal to extend the disk. If you prefer the former, use the `Hardware > Disk action > Resize` button on the appropriate disk (e.g., SCSI-1), set the additional size in gigabytes and confirm. If you prefer the latter, execute the following command from the terminal of the host (adapt the value to your needs):

```bash
qm resize 104 scsi1 +1G
```

Inside the VM, turn off swap temporarily:

```bash
swapoff -a
```

Now make a new swap area:

```bash
mkswap /dev/sdb
```

And enable swap again:

```bash
swapon /dev/sdb
```

Optionally, ensure `/etc/fstab` is still pointing at the correct UUID:

```bash
swapon --show
```
