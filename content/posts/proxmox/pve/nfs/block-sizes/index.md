---
title: "Aligning block sizes of VM disks on Proxmox"
date: 2025-07-19
lastmod: 2025-07-19
description: "How to find the right block size for all I/O layers up to the VM running an NFS server"
summary: "Get I/O statistics and decide the most convenient block size for your NFS server on a VM on Proxmox"
categories: ["virtualisation"]
tags: ["proxmox", "pve", "nfs", "zfs", "vm"]
series: ["NFS"]
series_order: 3
weight: 30
draft: true
---

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

## Debian 13

This is perfect timing! Having xfsprogs 6.13.0-2 in Debian 13 means you'll have:

Full userspace support for LBS filesystems
All the maintenance tools (xfs_repair, xfs_check, etc.) that understand larger block sizes
Proper compatibility between kernel and userspace tools

## XFS 8K

We are aligning the same block size that Proxmox used to create the ZVOL (`volblocksize`) to the block size of XFS.

Because `volblocksize` can change depending on your version of ZFS, before formatting the disk, check it out using the host shell:


```bash
zfs get volblocksize zfspool/vm-104-data
```

If your `volblocksize` is 16K, then adapt how you format the data disk:

```bash
mkfs.xfs -b size=16384 /dev/sdc
```

> ZFS version 2.2 brings in a new default block size of 16K.


## ZFS volumes

ZFS volumes (zvols) are an alternative to traditional virtual disks for VM data storage in Proxmox. While the Proxmox VM creation wizard typically provisions disk images in formats like `qcow2` (QEMU Copy On Write) or `raw`, these are still files sitting atop a filesystem. By contrast, zvols offer native block-level storage managed directly by ZFS, eliminating the file layer entirely. This provides performance benefits, block-level snapshots, and more seamless resizing that are particularly relevant when exporting data over NFS.

To clarify, zvols do not provide "raw image format", like `/var/lib/vz/images/104/vm-104-disk-1.raw`, but rather the disk is a ZFS-managed block device, such as `/dev/zvol/zfspool/vm-104-data` (actually, `/dev/zd0`), i.e., no file, no virtual layer. Therefore, with a zvol, you avoid writing to a file sitting inside a ZFS dataset[^3] and QEMU going through file I/O layers and, instead, you get native block device backed directly by ZFS. This means better synchronisation and performance, specially for workloads that require frequent writes.

[^3]: There are three types of datasets in ZFS: a filesystem following POSIX rules, a volume (zvol) existing as a true block device under `/dev`, and snapshots thereof.

It is important to emphasise that we are not using ZFS as a filesystem inside the VM. Instead, we are using [*](ZFS) to back a block device and, inside the VM, we will format it using [*](EXT4) or [*](XFS).

In our scenario, we chose to use a zvol for the data disk when we chose `zfspool` as storage, which allows us to take advantage of features such as snapshots and compression. It will behave exactly like a physical disk: no filesystem or partition table until we create one. Inside the VM, the zvol will appear as a new physical disk (e.g., `/dev/sdc`), and it will be completely blank until we format it.

Furthermore, if you create a partition inside the VM, like most OS installers do, then resizing later will still involve partition math (e.g., using `sfdisk` to adjust size). If, instead, you use the whole device directly (i.e., format `/dev/sdc` without a partition table), then resizing becomes simpler.

Therefore, inside the VM, all that is left is to format the data disk. As the `root` user, identify the disk using the `lsblk` command (e.g., `sdc`) , then format it:

```bash
mkfs.ext4 /dev/sdc
```

Finally, create the mount point, get the UUID of the new disk with the `blkid /dev/sdc` command and configure the `/etc/fstab` file to mount it automatically at boot:

```bash
mkdir /srv/nfs
blkid /dev/sdc
echo 'UUID=333e6175[..] /srv/nfs ext4 discard,noatime,nodiratime 0 2' >> /etc/fstab
mount /srv/nfs
```

## Aligning block sizes

Generally speaking, the easiest way to improve performance, minimise fragmentation, and make the most of our disk's physical layout is, on the one hand, to align the physical sector size of our disk with the block size of our ZFS storage pool, and on the other, to align block sizes of the ZVOL and the filesystem inside the VM.

Yes, aligning volblocksize=8K on the ZVOL with XFS block size = 8K inside the VM is efficient and recommended for most workloads with 8K+ writes.

ZFS does not mix metadata and file data in the same volblocksize block, so metadata always incurs its own overhead, no matter how small the file is.

For small files (e.g. 6K or 4K), the data uses one 8K ZVOL block, and ZFS metadata uses additional space, i.e., it is not co-located within the same 8K.

For larger files (e.g. 14K), ZFS uses 2× volblocksize blocks, regardless of the filesystem block size, since the ZVOL is just a virtual block device.

By following the steps described so far in this article, at the moment we may have the following sector and block sizes:

| Layer                | Option name    | Value | Command                                     | Notes            |
|----------------------|:--------------:|:-----:|---------------------------------------------|------------------|
| Physical sector size | `PHY-SEC`      | 4096  | `lsblk -o NAME,SIZE,PHY-SEC,LOG-SEC`        |                  |
| ZFS storage pool     | `ashift`       | 12    | `zdb -C zfspool \| grep ashift`             | 2¹² = 4096 bytes |
| ZVOL                 | `volblocksize` | 8K    | `zfs get volblocksize zfspool/vm-104-data`  |                  |
| EXT4                 | Block size     | 4096  | `tune2fs -l /dev/sdc \| grep 'Block size'`  |                  |

Default values of `ashift` and `volblocksize` may differ depending on your hardware, the version of Proxmox you are using, and the version of ZFS it shipped with. For instance, ZFS version 2.2 brings in a new default block size of 16K.

> Most modern SSDs, particularly enterprise-grade ones, use 8KB logical sectors.

While the table above shows a disparity in the block size of our ZVOL, this if fine for most use cases. Furthermore, the specifics of each filesytem need to be considered in the equation. In the case of ZFS, setting the block size of 4K may not make it perform better because ZFS operates a lot of metadata, therefore the data-to-metadata ratio could be worse. Besides, when using 4K sector disks, this could waste space and prevent compression from being used.

For example, let's say there are 2× 4K writes of metadata for each record when the default `ashift=12` and `redundant_metadata=all` (default) is used. When doing a single 8K write, it will store 1× 8K data plus 2× 4K metadata, for a total of 16K. However, when doing 2x 4K writes, it will store 2× 4K of data plus 4× 4K of metadata, for a total of 24K.

Regarding the value of `ashift` used when creating a ZFS pool, Proxmox offers a recommended value on the WebGUI which depends on the logical sector size of the disks. A general guideline would be:

* `ashift=9` for older HDD disks with 512-byte sectors.
* `ashift=12` for newer HDD disks with 4KB sectors.
* `ashift=13` for SSD disks with 8KB sectors.

> Once a ZFS vdev is created with a specific `ashift` value, it cannot be changed: it is immutable.

Our HDD has a physical sector size of 4096 bytes, then setting `ashift=12` is correct (4096 bytes). However, using `ashift=13` (8192 bytes) can still be a good idea, given our use case.

Given that `ashift` controls the minimum block size ZFS will use for physical I/O on disk, a value of `12` means ZFS will issue writes in 4K blocks, whereas a value of `13` means ZFS will issue writes in 8K blocks.

Therefore, an `ashift=13` (8K) is a good idea, even on 4K-sector drives, when working with:

* Workloads with larger I/O (like our NFS server), which can benefit from the reduced metadata overhead and fewer IOPS required.
* Applications that typically write in chunks larger than 4K, as the 8K `ashift` will not waste space and may perform better.

## Write amplification

Write amplification in ZFS refers to the phenomenon where the file system ends up writing more data to the storage device than the amount of data originally intended to be written by the user or application.

This can happen because ZFS is a copy-on-write file system and uses a larger record size than the data being written, requiring it to rewrite larger blocks even when only a small portion of the data needs to be changed.

But how does write amplification happen? Suppose our application writes 8K at a time (on our NFS server) and our ZFS pool has `ashift=12` (4K). Then ZFS tries to write two 4K blocks (to match 8K) but, due to misalignment or COW, ZFS might read-modify-write more 4K blocks than needed, leading to write amplification.

But if `ashift=13` (8K), then ZFS treats each 8K write as one atomic block. This leads to better alignment with our I/O patterns, less overhead, less fragmentation, and less metadata churn.

Therefore, even though our disk sectors are 4K, aligning ZFS to 8K avoids extra work when the application's write size exceeds 4K.

In conclusion, if we observe, or predict, I/O patterns happening mostly in the range of 8K-16K, we are better off creating our ZFS storage pool with an `ashift` value of 13 instead of the default 12 offered by the WebGUI.

## Bigger block sizes

Choosing a bigger block size when formatting a filesystem can offer a performance sweet spot for workloads that commonly read or write in chunks larger than the standard 4K. It can reduce internal fragmentation and improve I/O efficiency, specially on spinning disks or workloads where sequential throughput is valuable.

However, as with any optimisation, the effectiveness of using 8K+ blocks ultimately depends on the typical request sizes and access patterns in your environment, and the specifics of the filesystem, as discussed in previous sections. So, how do we figure it out?

We are interested in historical I/O stats, not just real time. And because we have different layers involved, we need to measure at each level.

### At the host level

Using the terminal at the host, we can observer logical and physical I/O stats of our ZFS pool storage, including metadata and ZFS overhead (checksumming, compression, etc.), and all ZVOLs and datasets underneath,.

To see logical I/O stats, we can use the `zpool` command, from the `zfsutils-linux` package. The output table shows the average request size, including ZFS metadata overhead (not just raw application reads/writes), since boot.

```bash
zpool iostat -r zfspool
```

Although not relevant to calculating the right block size of our ZVOL, it is convenient to understand the suffixes and prefixes being used in the output table.

Regarding the `ind` and `agg` suffixes:

| Suffix | Short for  | Meaning                  | Example                                                                |
|:------:|------------|--------------------------|------------------------------------------------------------------------|
| `ind`  | Individual | Average size of each I/O | `sync_read_ind` tells the average size of each synchronous read        |
| `agg`  | Aggregate  | Total bytes per second   | `sync_read_agg` is the total bandwidth of synchronous reads per second |

And regarding the `sync` and `async` prefixes.

| Type        | Meaning                                                   | Use case or trigger                             |
|-------------|-----------------------------------------------------------|-------------------------------------------------|
| Sync read   | App waits until data is fetched from disk                 | `O_DIRECT`, explicit `fsync`, or uncached reads |
| Async read  | OS can prefetch or return from cache                      | Normal file reads, when data is in memory       |
| Sync write  | Data must be committed to stable storage before returning | Database commits, `fsync()`, `fdatasync()`      |
| Async write | OS acknowledges write before data hits disk               | Normal buffered writes                          |

Besides, given that the ZVOL is exposed as a block device, we can also use `iostat`, from the `sysstat` package, to observe physical I/O statistics:

```bash
iostat -xd /dev/zvol/zfspool/vm-104-data
```

This tool shows kernel block-level I/O to the ZVOL device. Since our ZVOL is used by a VM, this shows how the host handles actual I/O coming from the guest. Relevant columns:

| Column     | Description                         | Units |
|------------|-------------------------------------|:-----:|
| `rareq-sz` | Read average request size           | kB    |
| `wareq-sz` | Write average request size          | kB    |
| `dareq-sz` | Average discard request size        | kB    |
| `f_await`  | Flush request average wait time     | ms    |

If `rareq-sz` and `wareq-sz` are much smaller than the `volblocksize` of our ZVOL, then the VM is issuing small reads/writes. This could increase IOPS load on the pool, result in write amplification and undermine compression and coalescing.

However, if `rareq-sz` and `wareq-sz` are much larger than the `volblocksize` of our ZVOL, then the VM is issuing large, efficient I/O ops, which is good. Larger I/O operations are more efficient and tend to align better with ZFS's recordsize (defaults to 128K). Also, they allow ZFS to compress or dedup data more effectively and reduce write amplification on underlying disks.

```
# zfs get recordsize zfspool
NAME     PROPERTY    VALUE    SOURCE
zfspool  recordsize  128K     default
```

Additionally, high `f_await` can mean that the VM (i.e., our NFS server) is using `fsync()` often, and that our pool is not optimized for sync writes (e.g., no Separate LOG device, or SLOG, on a fast NVMe or SSD). This can point to sync bottlenecks.

### At the guest level

Next, we need to get closer to the actual workload and its I/O patterns, so we need to measure from within the [*](VM). For that, we can use `iostat` for real-time measuring, and `sar` for historical data, both in the `sysstat` package:

```bash
apt-get install --yes sysstat
```

Use `iostat` for real-time statistics with average request size:

```bash
iostat -xd /dev/sdc
```

Relevant columns:

| Column     | Description                         | Units |
|------------|-------------------------------------|:-----:|
| `rareq-sz` | Read average request size           | kB    |
| `wareq-sz` | Write average request size          | kB    |
| `dareq-sz` | Average discard request size[^4]    | kB    |
| `f_await`  | Flush request average wait time[^5] | ms    |

[^4]: Large discard sizes might suggest benefit from larger block sizes, but they do not usually dominate performance.
[^5]: Tells you how long it takes to flush buffers, but not how big the data chunks are.

For historical data, we need to enable `sar`. Start by editing the `/etc/default/sysstat` configuration file:

```ini
ENABLED="true"
```

And continue by enabling and starting the systemd timer:

```bash
systemctl enable sysstat
systemctl start sysstat
```

The daily files (`saXX`) will start populating (the number matches the day of the month):

```bash
ls -lh /var/log/sysstat/
```

The `sysstat-collect.timer` timer runs every 10 minutes, whereas the `sysstat-summary.timer` runs once a day. Let some time go by, then see the results using the `sar` command:

```bash
sar -d --dev=sdc
```

If you want to check a particular day, use the following command:

```bash
sar -d --dev=sdc -f /var/log/sysstat/saXX
```

You will notice that the default behaviour is to display a list of intervals and a last line with the average. Should you be intersted in a particular moment in time, you can filter the intervals:

```bash
sar -d --dev=sdc -s 00:00:00 -e 23:59:59
```

> In the long run, we are mostly interested in the average.

Relevant columns:

| Column    | Description              | Units |
|-----------|--------------------------|:-----:|
| `areq-sz` | Average request size     | kB    |
| `rkB/s`   | Read throughput          | kB/s  |
| `wkB/s`   | Write throughput         | kB/s  |
| `await`   | Average wait time[^6]    | ms    |
| `%util`   | Device utilization[^7]   | %     |

[^6]: High latency may suggest mismatch in I/O size vs block size.
[^7]: Near 100% could mean saturation; optimizing block size may help.

>  Throughtput is useful for understanding workload volume, in context with request size.

If most requests are 8 KB or larger, it may make sense to align `volblocksize` and filesystem block size to 8K or more, which reduces write amplification and fragmentation. Conversely, too small blocks increase metadata and IOPS load.

## Mapping metrics

A number of metrics can be taken into consideration when tuning block sizes. 

| Metric               | Why it matters                                                                           | HDD | SSD | Notes                                                                         |
|----------------------|------------------------------------------------------------------------------------------|:---:|:---:|-------------------------------------------------------------------------------|
| Average request size | Helps choose optimal block size at filesystem and ZVOL layers                            | Yes | Yes | Crucial for both, as mismatched sizes reduce throughput or increase latency   |
| IOPS vs bandwidth    | Small, random I/O favours smaller blocks; sequential workloads benefit from large blocks | Yes | Yes | SSDs can handle much higher IOPS than HDDs, but pattern still matters         |
| Write amplification  | High when block sizes are misaligned                                                     | No  | Yes | Critical for SSDs (due to erase/write cycles)                                 |
| Fragmentation        | Smaller blocks reduce internal fragmentation, but increase metadata overhead             | Yes | No  | HDDs suffer more from fragmentation; SSDs less so but metadata load increases |
| CPU usage            | Larger blocks may reduce CPU load per byte transferred.                                  | Yes | Yes | Larger I/O sizes reduce syscalls and context switches, benefiting both        |

Let's try to map these metrics to the output provided by `sar` and `zpool iostat`:

**Average request size**

| Tool           | Columns   | Units | Notes                                       |
|----------------|-----------|:-----:|---------------------------------------------|
| `sar`          | `areq-sz` | kB    | Combined average request size               |

To estimate a good ZVOL `volblocksize`, find a typical average request size from these and align it, e.g., if it is consistently 8-16K, set `volblocksize` accordingly.

The columns of the `zpool iostat` tool show counts of I/O operations categorised by I/O size and type (sync/async read/write, scrub and trim). The suffixes `K` and `M` represent kilo and mega, in base 1024.

**IOPS vs bandwidth**

| Tool           | Columns                | Units | Notes                             |
| -------------- | -----------------------|:-----:|-----------------------------------|
| `sar`          | `tps`                  | ops/s | Total I/O operations              |
| `sar`          | `rkB/s`, `wkB/s`       | kB/s  | Total bandwidth                   |
| `zpool iostat` | `r/s`, `w/s`           | ops/s | Total I/O operations at ZFS layer |
| `zpool iostat` | `rbytes/s`, `wbytes/s` | kB/s  | Total bandwidth at ZFS layer      |

To infer the type of workload:

* High IOPS and low bandwidth means small block sizes (random I/O) of workload.
* Low IOPS and high bandwidth means large block sizes (sequential I/O).

| Observation              | Interpretation                                     | Implication                                                                                |
| ------------------------ | -------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| High IOPS, low bandwidth | Many small ops (e.g., 4K, 8K), probably random I/O | Tuning for low latency matters more than throughput; small block size might be appropriate |
| Low IOPS, high bandwidth | Fewer, large ops (e.g., 128K, 256K)                | Good for sequential I/O, maybe increase block size for efficiency                          |

**Write amplification**

| Tool           | Column     | Units  | Notes                                                  s|
| -------------- | -----------|:------:|--------------------------------------------------------|
| `zpool iostat` | `writes`   | ops    | Number of logical write operations issued to ZFS       |
| `zpool iostat` | `nwritten` | bytes  | Amount of data written by ZFS in bytes                 |

> `writes` shows what app is doing. `nwritten` and `asize` are what ZFS actually pushes to disk.

This allows us to extract the following details:

* `ẁrites` shows how many write operations the workload made.
* `nwritten/writes` gives the average write size per operation (your workload block size).
* `asize/nwritten` gives the write amplification at the ZFS level (due to metadata, padding, fragmentation, etc.).

So, what indicates the need for a larger block size? You compare `nwritten/writes` (your workload block size) to your `volblocksize` and:

* If your workload is writing 128K per operations, but your `volblocksize` is 4K, ZFS will break it into many chunks, leading to overhead, metadata, and more IOPS.
* If ZFS writes (`nwritten`) are significantly smaller or larger than the workload size, there is a mismatch, leading to write amplification or underutilization.

**Internal fragmentation**

Fragmentation is more about matching request size to block size to avoid unused padding. If `areq-sz` is smaller than `volblocksize`, internal fragmentation is likely.

**CPU usage per byte transferred**

You cannot measure CPU per-byte directly in `sar`, but you can infer:

{{< katex >}}
$$
  \text{CPU usage per MB} = \frac{\text{\%CPU used}}{\text{MB transferred}}
$$

On the one hand, using `sar -u` provides information about CPU utilisation:

| Column    | Meaning                                                                  |
|-----------|--------------------------------------------------------------------------|
| `%user`   | Time spent running processes in user space (non-kernel code)             |
| `%nice`   | Time spent on user-level processes with a positive nice value            |
| `%system` | Time spent running kernel processes                                      |
| `%iowait` | Time the CPU was idle waiting for I/O (disk/network)                     |
| `%steal`  | Time stolen by the hypervisor for other VMs (only in virtualized setups) |
| `%idle`   | Time the CPU was completely idle                                         |

Let's calculate `%CPU used`:

$$
  \text{\%CPU used} = 100 - \text{\%idle}
$$

Let's say we have the following last line in the output of our `sar -u` command (excerpt):

```
                CPU     %user     %nice   %system   %iowait    %steal     %idle
Average:        all      0.01      0.00      0.01      0.02      0.00     99.96
```

Then, we would have:

$$
  \text{\%CPU used} = 100 - 99.96 = \text{0.04\%}
$$

If you are more interested in application CPU usage, you can sum `%user` and `%system`:

$$
  \text{\%CPU (user + system)} = 0.01 + 0.01 = \text{0.02\%}
$$

> This excludes I/O wait time, which could be useful when tuning I/O-specific workloads.

On the other hand, using `sar -d --dev=sdc` provides disk I/O stats:

| Column    | Description                                                                                             |
|-----------|---------------------------------------------------------------------------------------------------------|
| `tps`     | Transfers per second (IOPS) — how many I/O operations were issued to the device per second.             |
| `rkB/s`   | Kilobytes read from the device per second.                                                              |
| `wkB/s`   | Kilobytes written to the device per second.                                                             |
| `dkB/s`   | Kilobytes discarded (e.g., TRIM/UNMAP) per second. Often 0 unless on SSDs with discard enabled.         |
| `areq-sz` | Average request size in kilobytes.                                                                      |
| `aqu-sz`  | Average queue length — how many I/O requests were waiting on average during the interval.               |
| `await`   | Average wait time (in milliseconds) for I/O requests to complete. Includes both queue and service time. |
| `%util`   | Percentage of time the device was busy doing I/O. 100% means fully saturated.                           |

Let's calculate `MB transferred`.

$$
  \text{CPU\ usage\ per\ MB} = \frac{100 - \% \text{idle}}{(\text{rkB/s} + \text{wkB/s} + \text{dkB/s}) / 1024}
$$

Let's say we have the following last line in the output of our `sar -d --dev=sdc` command (excerpt):

```
                  DEV       tps     rkB/s     wkB/s     dkB/s   areq-sz    aqu-sz     await     %util
Average:          sdc      0.27      0.08      1.35      0.00      5.29      0.00     11.04      0.10
```

Then, we would have:

$$
  \text{MB transferred} = \frac{0.08 + 1.35 + 0.00}{1024} ≈ \text{0.001 MB/s}
$$

So, the CPU usage per MB would be:

$$
  \text{CPU usage per MB} = \frac{0.04}{0.001} = \text{0.4 CPU cores per MB/s}
$$

This means the device used 40% of one CPU core to transfer 1 MB per second on average. In other words, for each 1 MB/s of throughput, the device consumes 40% of a CPU core, which suggests poor efficiency. Ideally, this number should be much lower (e.g., well below 1% per MB).

**Interpretation**

Let's say we have guest our guest issuing fairly large I/O sizes (`rareq-sz` ≈ 616 KB, `wareq-sz` ≈ 83 KB) and a ZVOL block size of 8K. This means each guest I/O is split across multiple 8K ZVOL blocks.

And let's say that the block distribution displayed by `zpool iostat` tells us that there is a lot of I/O at 8K and 16K, which includes our ZVOL and others in the same node, and very few 512K or 1M I/O actually reach the disks (probably because of ZFS ARC and transaction group aggregation).

Should we increase the `volblocksize` of our ZVOL to 16K to get fewer IOPS, reduce metadata overhead and write amplification, and better align it with actual guest workload sizes? It seems likely beneficial given these I/O patterns but, as always, it is about trade-offs.

* Snapshots happen at the `volblocksize` level. Therefore, increasing it increases delta size.
* We would need to recreate the ZVOL, as `volblocksize` cannot be changed live.
* We need to align the filesystem used in the VM. The maximum block size of EXT4 is 4K.

Time to change to XFS.

## Using XFS

XFS is a high-performance journaling filesystem optimized for large files and high-throughput workloads, making it a strong choice inside virtual machines where data integrity, scalability, and efficiency matter. Its robustness under concurrent write-heavy operations and support for advanced features like online defragmentation and resizing make it particularly well-suited for use cases such as NFS shares, backup storage, and databases. When used within a VM, XFS's maturity and reliability offer peace of mind, while its ability to handle large files and parallel I/O workloads gracefully helps ensure that the virtualized environment doesn’t become a bottleneck in your storage stack.

```bash
# Destroy the old ZVOL (after backup!)
zfs destroy zfspool/vm-104-data

# Recreate with 16K volblocksize
zfs create -V 100G -b 16K zfspool/vm-104-data
```

Then, inside the VM:

```bash
mkfs.xfs -b size=16384 /dev/vdX
```

So, just for the sake of experimenting, having your ZVOL use 4-kilobyte block size would require the following steps:

1. Unmount the disk inside the VM.
2. Dettach the data disk from the VM.
3. Destroy the disk.
4. Create a new ZVOL with 4K block size.
5. Attach the disk to the VM.
6. Format the new disk.
7. Update the `/etc/fstab` file.

We will use the terminal to perform these tasks. Switch to the VM console to unmount the disk:

```bash
umount /srv/nfs
```

Now switch back to the node shell where the VM is hosted. First, dettach and destroy the data disk:

```bash
qm set 104 -delete scsi2
zfs destroy zfspool/vm-104-data
```

> Dettaching a disk is an operation that can be reverted. Destroying a disk is not.

Second, create a new zvol, using the 4-kilobyte block size, and attach it to the VM:

```bash
zfs create -V 100G -b 4K zfspool/vm-104-data
qm set 104 -scsi2 zfspool:vm-104-data,discard=on,iothread=1,cache=none,aio=io_uring
```

Optionally, confirm that the new disk was attached to the VM:

```bash
qm config 104
```

> The information displayed at the `Hardware` menu option of the VM in the Proxmox WebGUI should be the same.

Inside the VM, confirm that the disk showed up with the `lsblk` command (the OS should see the new disk automatically). However, you can force a rescan of the SCSI bus inside the VM, then try the `lsblk` command again:

```bash
for host in /sys/class/scsi_host/host*; do
  echo "- - -" > "$host/scan"
done
```

Still inside the VM, format the new disk:

```bash
mkfs.ext4 -b 4096 /dev/sdc
```





XFS is an excellent choice inside the VM:

    Mature, stable, widely used.

    Scales well with large files and large IO.

    Great for NFS backing or general-purpose large file storag

Format disk with 8K or 16K block size:

# For 8K
mkfs.xfs -b size=8192 /dev/sdX

# For 16K
mkfs.xfs -b size=16384 /dev/sdX

🔹 Check disk (read-only):

xfs_check /dev/sdX   # deprecated, use `xfs_repair -n`

🔹 Repair filesystem (non-destructive check):

xfs_repair -n /dev/sdX   # -n is a dry run, remove it to actually repair

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

Is ZFS over ZFS a bad idea?

In general, yes, avoid ZFS on ZFS, unless:

    You explicitly disable compression, dedup, and caching in the inner layer to prevent weird behavior.

    You need snapshots inside the VM for data integrity (e.g., database inside VM), and you're managing them carefully.

    Better: Use XFS inside the VM, and ZFS at the host level for snapshots, compression, and resilience.
