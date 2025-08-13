---
title: "Larger block sizes with XFS on a Proxmox VM"
date: 2025-08-12
lastmod: 2025-08-13
description: "Using XFS as the filesystem for a Proxmox VM, including block size considerations and performance optimizations"
summary: "Explore the benefits of using XFS on a Proxmox VM when attempting to align block sizes of I/O layers"
categories: ["virtualisation"]
tags: ["proxmox", "pve", "nfs", "xfs", "vm"]
series: ["NFS"]
series_order: 4
weight: 40
---

In a previous article in this series we discussed the convenience of [aligning block sizes]({{< relref "posts/proxmox/pve/nfs/block-sizes/" >}}) across different layers of the storage stack, especially when using ZFS volumes (ZVOL).

When our average workload is located beyond the typical 4K block size, using [*](XFS) becomes advantageous due to its support for larger block sizes and efficient handling of large files.

However, the kernel's page size, which defaults to 4K on Debian, will still be a limiting factor, unless we decide to compile our own kernel from sources. Fortunately, there is a way to work around this limitation via the [Large Block Sizes](https://kernelnewbies.org/KernelProjects/large-block-size) (LBS) feature in the kernel.

This feature is still marked as experimental in the 6.12 LTS kernel that Debian 13 Trixie ships with, but we can experiment with it while we wait for a more modern kernel version to be backported into it (LBS was marked stable in kernel 6.13). Moreover, Debian 13 ships with a modern-enough version of `xfsprogs` that supports LBS.

## Large Block Size

Support for Large Block Size (LBS) in the Linux kernel was marked as stable in version 6.13. This support focused on enabling larger block sizes for I/O operations, moving beyond the traditional 4 KB page size default.

The goal is to improve performance and efficiency via:

* Reduced overhead, as the number of individual I/O operations is reduced.
* Hardware efficiency, as modern storage devices (e.g., NVMe drives) come with a default sector size of 8 KB.
* Application needs, as some applications (e.g., databases) may have specific internal data structures that align better with larger block sizes.

This involves changes to the block layer, filesystems, and potentially memory management with folios.

[PostgreSQL](https://www.postgresql.org/), for example, uses an 8 KB page size internally. With LBS, we can now create an XFS filesystem with an 8 KB block size, matching the database's internal page size, which can improve performance and reduce overhead when writing data.

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

Maintenance of version 6.12 by the [Linux Kernel Organization](https://www.kernel.org/) is restricted to patches that fix security issues, bugs or regressions, or provide stability. However, while we wait for a more modern kernel (hopefully 6.15+) to be backported to Trixie, we can check it out and test it.

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

When formatting the disk, convert the value of `volblocksize` into bytes. For the example above, inside the [*](VM) you would use 8192 bytes.

```bash
mkfs.xfs -b size=8192 /dev/sdc
```

The `mkfs.xfs` command returns the geometry information for the file system to make sure all parameters are set correctly.

> ZFS version 2.2 brings in a new default block size of 16K.

The `mkfs.xfs` command will fail if the block size is not supported by the kernel.

## Using XFS

The `xfsprogs` package provides a set of utilities for managing XFS filesystems, including tools for creating (`mkfs.xfs`), checking and repairing (`xfs_repair`), and extending (`xfs_growfs`) a filesystem.

### Formatting

Let's say that our VM has a data disk we are using to store the files served by our [*](NFS) server, or the databases in our PostgreSQL server. When formatting the disk, we want to align the block sizes of our XFS filesystem with the underlying ZFS storage.

Recent versions of `xfsprogs` allow us to specify both the block size and the sector size when using `mkfs.xfs`. Aligning both will get us better performance.

As of Debian 13 with kernel version 6.12, the following command can be used to format the disk with an 8K block size and a 4K sector size:

```bash
mkfs.xfs -b size=8192 -s size=4096 /dev/sdc
```

When a kernel 6.15+ is available, we will be able to specify larger sector sizes. Should our `volblocksize` be 16k, the following command would make the I/O requests even more performant:

```bash
mkfs.xfs -b size=16384 -s size=16384 /dev/sdc
```

### Sector size

By default, `mkfs.xfs` uses a 512-byte sector size, which matches what the ZVOL exposes. The ZVOL defaults to such sector size mainly due to two reasons:

* **Legacy compatibility**. Many OS, boot loaders, and even BIOS/UEFI implementations historically expect 512-byte logical sectors, and may even refuse to mount or format a disk if it reports something unusual.
* **Alignment problems**. By advertising 512-byte logical sectors, ZFS makes it harder for the guest filesystem to get *misaligned* (from ZFS's point of view), as every alignment is a multiple of 512.

Although ZFS abstracts the physical layer, `volblocksize` is its true internal allocation unit. However, it does not tell the guest about it so that it can present a *safe* virtual disk that works on any OS regardless of its sector size support.

However, if the guest filesystem knows that the real storage prefers, for example, 16 KB writes, it can:

* Batch I/O so it writes in 16 KB multiples.
* Work around the [*](RMW) penalty.

Then, ZFS can directly map filesystem blocks to ZVOL blocks without fragmentation or partial-block writes.

Batching I/O requests is about how the filesystem plans writes in the first place. If XFS believes the sector size is 16 KB, it will naturally coalesce smaller logical changes into 16 KB-aligned writes before sending them to the block device.

Avoiding RMW cycles is about what happens if a write is smaller than the underlying ZFS `volblocksize` when it finally hits ZFS. If ZFS gets a sub-16 KB write:

1. It reads the whole 16 KB block from disk.
2. It modifies just the changed part (e.g., the 512-byte region).
3. It writes the whole 16 KB block back.

That is the read-modify-write penalty, which happens down in the storage layer.

Therefore, when we set, for example, `-s size=16K` in XFS, we get both:

1. Fewer small writes generated, thanks to batching/alignment.
2. No RMW cycles triggered in ZFS, because it only ever sees full 16 KB writes.

> ZFS defaults to lying for maximum compatibility, leaving it to the VM admin to override if the guest OS can handle larger sectors.

### Mounting

Once the disk has been formatted, we need to mount it:

```bash
mount -t xfs -o noatime,logbufs=8 /dev/sdc /srv/nfs
```

Given the nature of our workload, both of these options are good, low-risk optimisations:

* `noatime` tells XFS not to update the access time metadata every time a file is read. This skips extra writes for read operations, reduces metadata churn and slightly improves performance and reduces wear on [*](SSD) devices.
* `logbufs=8` tells XFS to use 8 in-memory log buffers for the journal (i.e., the write-ahead log). This increases parallelism for metadata logging, allows more outstanding metadata transactions before forcing a flush and can improve performance in metadata-heavy workloads (file creation, deletion, renaming). This option is often the default on modern systems.

### Repairing

A file system in use should be boring and mostly invisible to the system administrator and user. However, crashes happen, and crash recovery needs to be considered. XFS provides `xfs_repair` to both check and repair a corrupted or damaged XFS filesystem.

It is typically run on an unmounted file system to ensure no conflicting operations occur while it replays the journal log to correct errors that might have occurred due to improper unmounting. The `-n` option allows us to check the file system for inconsistencies without actually making any changes.

```bash
systemctl stop nfs-server.service
umount /srv/nfs
xfs_repair /dev/sdc
```

We can find out the filesystem is damaged:

1. Upon boot, when mounting the filesystem, errors will be logged in the system journal. Use `journalctl --boot` to view it.
2. During execution, logged by the kernel. Use `journalctl --dmesg` to view it.

### Resizing

XFS supports online resizing, while mounted and even while actively being used. However, if the disk is under heavy load, you might want to temporarily reduce I/O to avoid unpredictable behaviour.

> XFS can grow online, but cannot shrink.

To extend the ZVOL holding the data disk, follow these steps:

1. Resize the disk image or block device.
2. Resize the filesystem inside the VM.

Use the terminal of the Proxmox host to resize the ZVOL:

```bash
zfs set volsize=+100G zfspool/vm-104-disk-0
```

After resizing, use `lsblk` to check that the OS has already detected the new size. When using using VirtIO/SCSI, the OS sees the size change immediately. Because we did not partition the disk before formatting it, we do not need to deal with partitions.

Finally, perform the second step in the VM terminal[^3]:

[^3]: You can either use the device path `/dev/sdc` or the mount point `/srv/nfs`.

```bash
xfs_growfs /srv/nfs
```

> Make sure the disk is mounted before running `xfs_growfs`.

### Defragmenting

A command worth note is `xfs_fsr`. FSR stands for file system reorganizer and it allows defragmentation of the extent lists of all files in a file system and can be run in background. 

```bash
xfs_fsr /srv/nfs
```

By default it assigns 7200 seconds of time to perform such operations, in 10 passes, but that can be tweaked using the `-t` and `-p` options, respectively.

It may also be used on a single (large) file:

```bash
xfs_fsr /srv/nfs/myapp/pdf/file.pdf
```

### Backing up

Although all normal backup applications can be used for XFS file systems, the `xfsdump` and `xfsrestore` commands from the `xfsdump` package are specifically designed for XFS backup.

`xfsdump` uses a special API to perform I/O based on file handles so that it does not generate inconsistent device snapshots on the raw block device. This command can perform backups to regular files on local and remote systems, and it supports incremental backups with a sophisticated inventory management system.

```bash
apt-get install --yes xfsdump
```

Let's assume that we mounted a backup disk at `/mnt/backups`. We would start with a full backup (level 0):

```bash
xfsdump -l 0 -L "20250812-full-backup" -M "Full backup of NFS share" \
        -f /mnt/backups/nfs-full-backup-20250812.xfs /srv/nfs
```

 In case of interruption, backup operations can be resumed using the `-R` option:

```bash
xfsdump -l 0 -L "20250812-full-backup" -M "Full backup of NFS share" \
        -f /mnt/backups/nfs-full-backup-20250812.xfs -R /srv/nfs
```

The next week, we would perform an incremental backup using `-l 1`, which specifies a level 1 backup, meaning it would include changes since the last level 0 backup.

```bash
xfsdump -l 1 -L "20250819-incr-backup" -M "Incremental backup of NFS share week 1" \
        -f /mnt/backups/nfs-incr-backup-20250819.xfs /srv/nfs
```

This backup would contain only files changed since the level 0 backup.

The following week, we would perform another incremental backup:

```bash
xfsdump -l 2 -L "20250826-incr-backup" -M "Incremental backup of NFS share week 2" \
        -f /mnt/backups/nfs-incr-backup-20250826.xfs /srv/nfs
```

This backup would only contain files changed since the level 1 backup.

### Restoring

XFS offers a different command for restoring backups, named `xfsrestore`. We would start by listing the inventory of backups, which would provide us with a the available session IDs and session labels:

```bash
xfsrestore -I
```

Optionally, we would list the contents of a specific backup:

```bash
xfsrestore -I -f /mnt/backups/nfs-full-backup-20250812.xfs
```

When having to restore everything from scratch, we would follow these steps:

1. Stop the services using the NFS share.
2. Unmount the NFS share.
3. Format the disk again, if needed.
4. Restore the full backup.
5. Apply the incremental backups, in order.

```bash
systemctl stop nfs-server.service
umount /srv/nfs
mkfs.xfs -b size=8192 -s size=4096 /dev/sdc
xfsrestore -f /mnt/backups/nfs-full-backup-20250812.xfs /srv/nfs
xfsrestore -f /mnt/backups/nfs-incr-backup-20250819.xfs /srv/nfs
xfsrestore -f /mnt/backups/nfs-incr-backup-20250826.xfs /srv/nfs
```

If we wanted to restore a specific file at a given point in time, we would follow these steps:

1. Find which backup contains the file.
2. If found, restore just that file, using the session ID from the inventory.

```bash
xfsrestore -t -f /mnt/backups/nfs-incr-backup-20250826.xfs | grep proposal.odt
xfsrestore -S "2d129e2a-7c33-47a9-ac33-5a4862b594b1" -s myapp/docs/proposal.odt \
           -f /mnt/backups/nfs-incr-backup-20250826.xfs /srv/nfs/
```

> An entire subdirectory could also be restored by specifying the directory path instead of a single file.

Summary of which backup file to use when:

| When                   | Which                                                     |
|------------------------|-----------------------------------------------------------|
| Complete recovery      | Start with level 0, then apply all incrementals in order  |
| Point-in-time recovery | Start with level 0, apply incrementals up to desired date |
| Single file recovery   | Use the most recent backup that contains the file         |
| Recent files           | Check incremental backups first (smaller and faster)      |

We will be using Proxmox Backup Server to back up the entire VM and its disks (those marked for backup), including the NFS share. Still, `xfsdump` is a tool that can be used in specific cases to have a second, complementary backup copy of our data. For instance, the generated dumps could be sent to a different storage location for added redundancy.

### Information

The `xfs_info` utility provides detailed information about the structure and characteristics of an XFS filesystem. It displays details like the file system size, block size, sector size, inode information, and other relevant parametres.

```bash
xfs_info /srv/nfs
```

The amount of information displayed can be quite extensive, so here is a table with an explanation of the various fields.

**Meta-data section**

| Field                 | Meaning                                                                                                          |
| --------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `meta-data=/dev/sdc`  | Device where metadata (superblock, allocation groups, inode structures) resides.                                 |
| `isize=512`           | Size (in bytes) of each inode. 512 B is typical.                                                                 |
| `agcount=4`           | Number of allocation groups (AGs) in the filesystem; AGs enable parallel allocation on multi-threaded workloads. |
| `agsize=9830400 blks` | Number of blocks in each AG (\~78.4 MiB per AG with `bsize=8192`).                                               |
| `sectsz=512`          | Sector size reported by the device (or emulated by ZVOL).                                                        |
| `attr=2`              | Extended attribute format version (v2 is current).                                                               |
| `projid32bit=1`       | Project quotas with 32-bit project IDs are supported.                                                            |
| `crc=1`               | Metadata checksumming (XFS v5 format).                                                                           |
| `finobt=1`            | Free inode B+tree present, improving inode allocation speed.                                                     |
| `sparse=1`            | Sparse inode chunk allocation enabled.                                                                           |
| `rmapbt=1`            | Reverse mapping B+tree (for reflink & deduplication).                                                            |
| `reflink=1`           | Reflink (copy-on-write cloning) enabled.                                                                         |
| `bigtime=1`           | Extended timestamp range (supports dates beyond 2038).                                                           |
| `inobtcount=1`        | Tracks inode counts per AG.                                                                                      |
| `nrext64=1`           | 64-bit extent counters enabled.                                                                                  |
| `exchange=0`          | Online exchange feature not enabled.                                                                             |
| `metadir=0`           | No separate metadata directory.                                                                                  |

**Data section**

| Field             | Meaning                                          |
|-------------------|--------------------------------------------------|
| `bsize=8192`      | Data block size (8 KB)                           |
| `blocks=39321600` | Total blocks in the filesystem (\~300 GB total)  |
| `imaxpct=25`      | Max % of space reserved for inodes (25% default) |
| `sunit=0`         | Stripe unit size (0 = none defined)              |
| `swidth=0`        | Stripe width (0 = none defined)                  |

**Naming section**

| Field        | Meaning                                                           |
|--------------|-------------------------------------------------------------------|
| `version=2`  | Directory structure format (v2 = efficient hashed directories)    |
| `bsize=8192` | Directory block size (matches data `bsize`)                       |
| `ascii-ci=0` | Case-insensitive lookups disabled                                 |
| `ftype=1`    | Filetype field stored in directory entries (improves performance) |
| `parent=0`   | No parent pointer feature enabled                                 |

**Log section**

| Field          | Meaning                                                 |
|----------------|---------------------------------------------------------|
| `internal log` | Journal (transaction log) stored on same device as data |
| `bsize=8192`   | Log block size (8 KB)                                   |
| `blocks=19200` | Log size (\~150 MiB)                                    |
| `version=2`    | Log format version 2                                    |
| `sectsz=512`   | Log sector size                                         |
| `sunit=0`      | Log stripe unit (0 = none)                              |
| `lazy-count=1` | Lazy log counter updates (performance optimization)     |

**Realtime section**

| Field         | Meaning                       |
|---------------|-------------------------------|
| `none`        | No separate realtime volume   |
| `extsz=8192`  | Default extent size (8 KB)    |
| `blocks=0`    | No realtime data blocks       |
| `rtextents=0` | No realtime extents           |
| `rgcount=0`   | No realtime allocation groups |


## Metadata takes space

Let's say that we format a 300G disk using XFS, as follows:

```bash
mkfs.xfs -b size=8192 /dev/sdc
mount -t xfs /dev/sdc /srv/nfs
df -h /srv/nfs
```

We would see something like `300G total, 4.3G used, 296G available`, meaning that a our fresh filesystem already *lost* 4.3G (~1.4%, which is expected). This is because XFS is optimised for performance rather than minimal metadata footprint. Specifically:

* XFS pre-allocates metadata structures (like inode tables, allocation group headers, B+trees, journals), so the initial *used space* reflects this reservation.
* The larger the block size, the more space reserved. An 8 KB block size slightly increases the metadata footprint compared to 4 KB.
* The internal log (journal) takes space, ~150 MB in this case (19200 × 8 KB).
