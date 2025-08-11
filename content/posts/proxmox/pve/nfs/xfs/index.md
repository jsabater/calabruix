---
title: "Larger block sizes with XFS on a Proxmox VM"
date: 2025-08-09
lastmod: 2025-08-09
description: "Using XFS as the filesystem for a Proxmox VM, including block size considerations and performance optimizations"
summary: "Explore the benefits of using XFS on a Proxmox VM when attempting to align block sizes of I/O layers"
categories: ["virtualisation"]
tags: ["proxmox", "pve", "nfs", "xfs", "vm"]
series: ["NFS"]
series_order: 4
weight: 40
draft: true
---

In a previous article in this series we discussed the convenience of [aligning block sizes]({{< relref "posts/proxmox/pve/nfs/block-sizes/" >}}) across different layers of the storage stack, especially when using ZFS volumes (ZVOL).

When our average workload is located beyond the typical 4K block size, using [*](XFS) becomes advantageous due to its support for larger block sizes and efficient handling of large files.

However, the kernel's page size, which defaults to 4K on Debian, will still be a limiting factor, unless we decide to compile our own kernel from sources. Fortunately, there is a way to work around this limitation via the [Large Block Sizes](https://kernelnewbies.org/KernelProjects/large-block-size) (LBS) feature in the kernel.

This feature is still marked as experimental in the 6.12 LTS kernel that Debian 13 Trixie ships with, but we can experiment with it while we wait for a more modern kernel version to be backported into it (LBS was marked stable in kernel 6.13). Moreover, Debian 13 ships with a modern-enough version of `xfsprogs` that supports LBS.

## Large Block Size

Support for Large Block Size (LBS) in the Linux kernel was marked as stable in version 6.13. This support focused on enabling larger block sizes for I/O operations, moving beyond the traditional 4kB page size default.

The goal is to improve performance and efficiency via:

* Reduced overhead, as the number of individual I/O operations is reduced.
* Hardware efficiency, as modern storage devices (e.g., NVMe drives) come with a default sector size of 8kB.
* Application needs, as some applications (e.g., databases) may have specific internal data structures that align better with larger block sizes.

This involves changes to the block layer, filesystems, and potentially memory management with folios.

[PostgreSQL](https://www.postgresql.org/), for example, uses an 8KB page size internally. With LBS, we can now create an XFS filesystem with an 8KB block size, matching the database's internal page size, which can improve performance and reduce overhead when writing data.

To use it, all we have to do is format the XFS filesystem with the desired block size using the `mkfs.xfs` command with the appropriate option.

## About XFS

XFS is a 64-bit high-performance journaling filesystem optimised for very large files[^1] and filesystems[^2], and high-throughput workloads. It is completely multi-threaded and supports extended attributes and variable block sizes, making it a strong choice inside virtual machines.

[^1]: Individual files of up to 9 exabytes.
[^2]: Volumes of up to 18 exabytes in size.

Designed from day one for computer systems with large disk arrays and many CPUs, its robustness under concurrent write-heavy operations and support for advanced features, like delayed allocations and online defragmentation and resizing, make it particularly well-suited for use cases such as NFS shares, backup storage, and databases.

XFS itself did not originate on Linux, but was first released in 1994 on IRIX, a UNIX variant for [*](SGI) workstations and servers. Starting in 1999, XFS was ported to Linux as part of SGI's push to use Linux.

As a journaling file system, XFS keeps record of modifications before they are committed to its internal structures, which ensures its overall consistency in case of a crash or power loss.

## Debian kernel

Debian 13 Trixie comes with kernel 6.12 [*](LTS) and modern userland tools (the `xfsprogs` package) that support Large Block Sizes (LBS) in XFS. Unfortunately, LBS is marked as experimental in kernel 6.12 LTS.

In essence, kernel 6.12 introduced the fundamental [Virtual File System](https://www.kernel.org/doc/html/latest/filesystems/vfs.html) (VFS) infrastructure and initial XFS support for Large Block Sizes, making the concept viable. Then kernel 6.13 added critical features like atomic write support for major filesystems ([*](EXT4), [*](XFS)), improving general large file handling, and incorporating the usual wave of bug fixes and optimizations that are essential for a feature to be considered truly stable and production-ready.

Maintenance of version 6.12 by the [Linux Kernel Organization](https://www.kernel.org/) is restricted to patches that fix security issues, bugs or regressions, or provide stability. However, while we wait for a more modern kernel (6.15+) to be backported to Trixie, we can check it out and test it.

Regarding userspace tools, Debian 13 ships with `xfsprogs` version 6.13, which means we will have:

* Full userspace support for LBS filesystems.
* All the maintenance tools that understand larger block sizes.
* Proper compatibility between kernel and userspace tools.

## Aligning block sizes

We want to match the same block size that Proxmox used to create the ZVOL (`volblocksize`) to the block size of XFS. Because `volblocksize` can change depending on the version of `zfsutils-linux`, start by checking out its value via the terminal of the host before formatting the disk of your virtual machine.

List the existing ZVOLs using `zfs list`, then use `zfs get volblocksize` to check the block size of the specific ZVOL.

```bash
# zfs get volblocksize zfspool/vm-104-disk-0
NAME                   PROPERTY      VALUE     SOURCE
zfspool/vm-104-disk-0  volblocksize  8K        default
```

Convert the value of `volblocksize` into bytes when formatting the disk. For the example above, inside the [*](VM) you would use 8192 bytes.

```bash
mkfs.xfs -b size=8192 /dev/sdc
```

The `mkfs.xfs` command returns the geometry information for the file system to make sure all parameters are set correctly. There are not many parameters that must be manually set for normal use.

> ZFS version 2.2 brings in a new default block size of 16K.

The `mkfs.xfs` command will fail if the block size is not supported by the kernel.

## Using XFS

The `xfsprogs` package provides a set of utilities for managing XFS filesystems, including tools for creating, checking, and repairing. Support 

mkfs.xfs -f -b size=16k -s size=16k → uses a 16 KiB sector size → supported as of v6.15

Mounting:

```bash
mount -o noatime,logbufs=8 /dev/sdX /mnt/data
```


A file system in use should be boring and mostly invisible to the system administrator and user. However, crashes happen, and crash recovery needs to be considered. XFS provides `xfs_repair` to repair a corrupted or damaged XFS filesystem.


Repair filesystem (non-destructive check):

```bash
# -n is a dry run, remove it to actually repair
xfs_repair -n /dev/sdX
```

But how do we know the filesystem is, indeed, damaged?

`xfs_check`






Grow filesystem after increasing virtual disk or zvol:

Rescan disk inside VM (if using virtio/scsi):

echo 1 > /sys/class/block/sdX/device/rescan

Resize partition (if needed):

growpart /dev/sdX 1   # if using GPT + parted

Grow XFS filesystem:

xfs_growfs /mnt/data

> XFS can grow online, but cannot shrink.


A command worth note is xfs_fsr. FSR stands for file system reorganizer and is the XFS equivalent to the Windows defrag tool. It allows defragmentation of the extent lists of all files in a file system and can be run in background. It may also be used on a single file.

Although all normal backup applications can be used for XFS file systems, the `xfsdump` command is specifically designed for XFS backup. It uses a special API to perform I/O based on file handles so that it does not generate inconsistent device snapshots on the raw block device.

The `xfsdump` command can perform backups to regular files on local and remote systems, and it supports incremental backups with a sophisticated inventory management system. However, since we will be using Proxmox Backup Server to backup the entire VM and its disks, this is not a tool we will be using directly.

## Diving into XFS

```bash
xfs_info /dev/sdc
```

Meta-data section

    meta-data=/dev/sdc – Device where metadata (superblock, allocation groups, inode structures) resides.
    isize=512 – The size (in bytes) of each inode. 512 is typical.
    agcount=4 – The number of allocation groups (AGs) the filesystem is divided into. Allocation groups enable parallel allocation on multi-threaded workloads.
    agsize=9830400 blks – Number of blocks in each allocation group (with bsize=8192, that's ~78.4 MB per AG).
    sectsz=512 – Sector size reported by the underlying device (or emulated by ZVOL).
    attr=2 – Extended attribute format version (v2 is current).
    projid32bit=1 – Project quotas (32-bit project IDs) are supported.
    crc=1 – Metadata checksumming (introduced in XFS v5 format).
    finobt=1 – Free inode B+tree is present, improving inode allocation speed.
    sparse=1 – Sparse inode chunk allocation.
    rmapbt=1 – Reverse mapping B+tree (used for reflink & deduplication).
    reflink=1 – Reflink (copy-on-write clone) feature enabled.
    bigtime=1 – Extended timestamp range (needed beyond year 2038).
    inobtcount=1 – Tracks inode counts per allocation group.
    nrext64=1 – 64-bit extent counters.
    exchange=0 – Online exchange (not enabled).
    metadir=0 – No separate metadata directory.

Data Section

    bsize=8192 – Data block size (8 KiB).
    blocks=39321600 – Total number of blocks (39321600 × 8 KiB ≈ 300 GiB).
    imaxpct=25 – Max % of space reserved for inodes (25% default).
    sunit=0 / swidth=0 – Stripe unit/width (relevant for RAID). Zero means no special alignment defined.

Naming Section

    version 2 – Directory structure format (v2 = efficient hashed directories).
    bsize=8192 – Directory block size (matches data bsize).
    ascii-ci=0 – Case-insensitive lookups disabled.
    ftype=1 – Filetype field in directory entries (helps performance).
    parent=0 – No parent pointer feature.

Log Section

    internal log – The journal (transaction log) is stored within the same device, not externally.
    bsize=8192 – Log block size (8 KiB).
    blocks=19200 – Size of the log area (19200 × 8 KiB = 150 MB).
    version=2 – Log format version 2.
    sectsz=512 – Log sector size.
    sunit=0 – Log stripe unit (for RAID).
    lazy-count=1 – Lazy log counter updates (performance optimization).

Realtime Section

* `none` – No separate realtime volume (used for large streaming files).
* `extsz=8192` – Default extent size (matches 8 KiB blocks).
* `blocks=0` – No realtime data blocks.
* `rtextents=0` – No realtime extents.
* `rgcount=0` – No realtime groups.

## Metadata takes space

Why Does a Fresh XFS Filesystem Show 4.3 GB Used?

```bash
mkfs.xfs -b size=8192 /dev/sdd
mount -t xfs /dev/sdd /mnt
df -h /mnt
```

And we see something like `300G total, 4.3G used, 296G available`. XFS is optimized for performance rather than minimal metadata footprint. 4.3 GB out of 300 GB is ~1.4%, which is normal.

This is normal because:

* XFS Pre-allocates metadata structures (like inode tables, allocation group headers, B+trees, journals). Unlike ext4, XFS reserves these areas upfront, so the initial "used space" reflects this reservation.
* The larger the block size, the more space reserved. An 8 KiB block size slightly increases the metadata footprint compared to 4 KiB, but it's still in the 1–2% range for large filesystems.
* The internal log (journal) – Yours is ~150 MB alone (19200 × 8 KiB).
