---
title: "Using XFS on a Proxmox VM with NFS"
date: 2025-07-27
lastmod: 2025-08-03
description: "Using XFS as the filesystem for a Proxmox VM with NFS, including block size considerations and performance optimizations"
summary: "Explore the benefits of using XFS on a Proxmox VM with NFS, including optimal block size settings and performance tips"
categories: ["virtualisation"]
tags: ["proxmox", "pve", "nfs", "xfs", "vm"]
series: ["NFS"]
series_order: 4
weight: 40
draft: true
---


## Using XFS

XFS is a high-performance journaling filesystem optimized for large files and high-throughput workloads, making it a strong choice inside virtual machines.

Its robustness under concurrent write-heavy operations and support for advanced features like online defragmentation and resizing make it particularly well-suited for use cases such as NFS shares, backup storage, and databases.



## XFS parametres

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

## Debian 13

Debian 13 (and newer) kernels, with XFS, can support block sizes larger than the default 4KB, including 8KB, through the Large Block Size (LBS) feature. This feature allows for better performance, especially with large files and databases. 
Here's a more detailed explanation:

    Large Block Size (LBS) Support:
    The Linux kernel has added support for LBS in XFS, enabling block sizes larger than the system's page size (typically 4KB). 

Why 8KB?
PostgreSQL, for example, uses an 8KB page size internally. With LBS, you can now create an XFS filesystem with an 8KB block size, matching the database's internal page size, which can improve performance and reduce overhead when writing data. 
Benefits of Larger Block Sizes:
Larger block sizes can lead to fewer I/O operations for larger files, potentially improving performance, particularly with high-capacity storage like QLC SSDs. 
How to use it:
When formatting an XFS filesystem, you can specify the desired block size using the mkfs.xfs command with the -b size=8192 option, according to the Gentoo Forums. 
Kernel Limitations:
While you can create an XFS partition with a larger block size, the kernel's page size might still be a limiting factor when mounting the partition. However, the LBS support addresses this limitation. 
Potential Optimizations:
Databases and other applications that work with large data chunks can leverage this feature to optimize their I/O operations and potentially see performance gains


This is perfect timing! Having xfsprogs 6.13.0-2 in Debian 13 means you'll have:

Full userspace support for LBS filesystems
All the maintenance tools (xfs_repair, xfs_check, etc.) that understand larger block sizes
Proper compatibility between kernel and userspace tools

## Kernel 6.12 vs 6.13

LBS is marked as experimental in kernel 6.12 LTS, but it is marked as stable in version 6.13.

In essence:

* Kernel 6.12 introduced the fundamental VFS infrastructure and initial XFS support for Large Block Sizes, making the concept viable.
* Kernel 6.13 built upon this foundation by adding critical features like atomic write support for major filesystems (EXT4, XFS), improving general large file handling, and incorporating the usual wave of bug fixes and optimizations that are essential for a feature to be considered truly stable and production-ready.

Kernel.org maintenance of 6.12.y is restricted to patches that fix security issues, bugs or regressions, or provide stability. Thus, any new capability introduced in 6.13 stays exclusive to the 6.13 mainline tree and beyond.

Once a more modern kernel, version 6.13+, is backported to Trixie, we will have to check it out.

## XFS 8K

We are aligning the same block size that Proxmox used to create the ZVOL (`volblocksize`) to the block size of XFS.

Because `volblocksize` can change depending on your version of ZFS, before formatting the disk, check it out using the host shell:


```bash
zfs get volblocksize zfspool/vm-104-disk-0
```

If your `volblocksize` is 16K, then adapt how you format the data disk:

```bash
mkfs.xfs -b size=16384 /dev/sdc
```

> ZFS version 2.2 brings in a new default block size of 16K.

> Dettaching a disk is an operation that can be reverted. Destroying a disk is not.

Second, create a new zvol, using the 4-kilobyte block size, and attach it to the VM:

```bash
zfs create -V 100G -b 4K zfspool/vm-104-disk-0
qm set 104 -scsi2 zfspool:vm-104-disk-0,discard=on,iothread=1,cache=none,aio=io_uring
```

Optionally, confirm that the new disk was attached to the VM:

```bash
qm config 104
```


Format disk with 8K or 16K block size:

# For 8K
mkfs.xfs -b size=8192 /dev/sdX

# For 16K
mkfs.xfs -b size=16384 /dev/sdX

🔹 Repair filesystem (non-destructive check):

```bash
# -n is a dry run, remove it to actually repair
xfs_repair -n /dev/sdX
```

🔹 Mounting:

mount -o noatime,logbufs=8 /dev/sdX /mnt/data

🔹 Grow filesystem after increasing virtual disk or zvol:

    Rescan disk inside VM (if using virtio/scsi):

echo 1 > /sys/class/block/sdX/device/rescan

Resize partition (if needed):

growpart /dev/sdX 1   # if using GPT + parted

Grow XFS filesystem:

    xfs_growfs /mnt/data

    Note: XFS can grow online, but cannot shrink.

