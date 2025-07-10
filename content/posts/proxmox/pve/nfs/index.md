---
title: "NFS server on Proxmox VE"
date: 2025-06-19
lastmod: 2025-06-30
description: "Install and configure a Network File System (NFS) server in a VM on a Proxmox using ZFS for optimal performance"
summary: "Install and configure an NFS server in a VM on a Proxmox cluster using ZFS"
categories: ["virtualisation"]
tags: ["proxmox", "pve", "nfs", "zfs"]
draft: true
---

[*](NFS) is a distributed file system protocol that allows clients to access files over a network as if they were local. It is commonly used for sharing files between servers and clients in a networked environment.

In this article, we will install and configure an NFS server in a VM on a Proxmox cluster, optionally using our [*](ZFS) pool. The NFS server will be used to share files between multiple clients, such as web servers or application servers.

This is an alternative approach to using an [*](S3) compatible object storage, such as [MinIO](https://min.io/), [Garage](https://garagehq.deuxfleurs.fr/) or [SeaweedFS](https://seaweedfs.com/). Both approaches have their own advantages and disadvantages, and the choice between them depends on the specific use case, requirements and limitations.

## ISO download

Visit the [Downloading Debian](https://www.debian.org/download) page and its linked [SHA512SUMS](https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS) page. We are looking for latest Debian 12 Bookworm Netinst ISO and its SHA-512 checksum.

Click on the node where you want to install the VM, go to the `local` storage, go to the `ISO Images` menu option and click the `Download from URL` button:

* Paste the URL of the [latest Debian 12 Bookworm Netinst ISO](https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso) into the `URL` field and click on `Query URL`. `File size` and `MIME type` will be filled in.
* Select the hash algorithm `SHA-512` and paste the checksum for the image.

The image will be downloaded and verified. Once the download is complete, you will notice the ISO image in the `local` storage on the node.

## VM creation

We will be using three separate virtual disks for the VM:

* **OS disk**: A small disk on our local pool that will hold the operating system.
* **Swap disk**: A small disk on our local pool that will hold the swap space.
* **Data disk**: A larger disk on our ZFS pool that will hold the data to be shared via NFS.

This is to simplify the setup and prevent us from running into issues with disk space management on multiple partitions. Both the OS and the data disks will be formatted using `ext4`, which will allow us to extend them later, if needed.

Therefore, we will be using manual partitioning during the OS installation to:

* Create a DOS partition table on each disk.
* Create a single, primary partition on each disk.

Select the node where you want to install the VM on, then click on the `Create VM` button on the top-right corner of the Proxmox VE WebGUI and follow the assistant.

| Tab     | Attribute         | Value                          | Note                                        |
|---------|-------------------|--------------------------------|---------------------------------------------|
| General | Name              | `nfs1`                         | Usually, but not necessarily, its hostname  |
| General | Resource pool     | `databases`                    | Logical group of guests of your choice [^1] |
| General | Start at boot     | No                             | Will be switched to `Yes` once we are done  |
| OS      | Storage           | `local`                        |                                             |
| OS      | ISO image         | `debian-12.11.0-amd64-netinst` |                                             |
| System  | Graphic card      | Default                        |                                             |
| System  | Machine           | Default (i440fx)               |                                             |
| System  | BIOS              | Default (SeaBIOS)              |                                             |
| System  | SCSI controller   | VirtIO SCSI single             | Match with `IO thread` for performance [^2] |
| System  | Qemu agent        | Yes                            |                                             |
| CPU     | Cores             | 4                              | Moderate concurrency                        |
| Memory  | Memory (MiB)      | 8192                           | Moderate usage, matches ZFS ARC config      |
| Memory  | Min. memory (MiB) | 4096                           | Moderate usage, matches ZFS ARC config      |
| Memory  | Ballooning device | Yes                            | Dynamically adjust the VM's memorory usage  |
| Network | Bridge            | `vmbr4002`                     | Proxmox guests private network              |
| Network | Model             | VirtIO (paravirtualized)       | Best performance and low overhead for Linux |
| Network | MTU               | 1400                           | Matches the Proxmox host network MTU        |

[^1]: Managed via the `Datacenter > Permissions > Pools` menu option.
[^2]: Default for newly created Linux VMs since Proxmox VE 7.3. Each disk will have its own VirtIO SCSI controller, and QEMU will handle the disks IO in a dedicated thread.

On the `Disks` tab, we will be creating three disks, as described above. Use the `Add` button on the bottom-left corner to add disks.

| Option            | OS disk    | Swap disk  | Data disk  | Notes                                      |
|-------------------|:----------:|:----------:|:----------:|--------------------------------------------|
| `Bus/Device`      | `SCSI 0`   | `SCSI 1`   | `SCSI 2`   | VirtIO SCSI driver works well with discard |
| `Storage`         | `local`    | `local`    | `zfspool`  |                                            |
| `Disk size (GiB)` | 3          | 1          | 100        |                                            |
| `Format`          | `qcow2`    | `raw`      | `raw`      | Snapshots enabled                          |
| `Cache`           | No cache   | No cache   | No cache   | Avoid double caching with ZFS              |
| `IO thread`       | Yes        | No         | Yes        | Parallel NFS access                        |
| `Backup`          | Yes        | No         | Yes        | Include disk in backup jobs                |
| `Async IO`        | `io_uring` | `io_uring` | `io_uring` | Most compatible and reliable               |
| `Discard`         | Yes        | Yes        | Yes        | Enable TRIM/UNMAP                          |

> Regarding the data disk, by choosing `zfspool` as storage, the assistant creates a ZFS volume (zvol) instead of a virtual disk. More on that later.

Incidentally, in the node where this VM is being provisioned we have allocated 4-8 GB for ZFS ARC via `/etc/modprobe.d/zfs.conf`:

```conf
options zfs zfs_arc_max=8589934592
options zfs zfs_arc_min=4294967296
```

This will allow the VM to use up to 8 GB of memory for caching, which is a good amount for a moderate usage NFS server. The `Min. memory` setting will ensure that the VM has at least 4 GB of memory available, which is enough for the OS and the NFS server.

The VM id will be automatically assigned by Proxmox, but you can change it to a specific number if you want. In this article, we will use `104` as the VM id.

> Do not forget to add the corresponding DNS records to your internal zone `localdomain.com` and to your reverse DNS zone `0.168.192.in-addr.arpa`.

## OS install

Once the VM has been created, click on its `Console` menu option and click the `Start` button. Once booted, the graphical installer will appear. Select the second option, `Install`, to change into the text mode.

Proceed with the configuration of the language and keyboard layout. Example options:

* Language: English
* Location: Europe, Spain
* Locale: United States (`en_US.UTC-8`)
* Keymap: Spanish

Next, network configuration via DHCP auto configuration will be attempted. If you do not use HDCP, it will time out and display an error message. Select `Continue` and, in the next screen, select `Configure network manually`.  Example options:

* IP address: `192.168.0.4/24`
* Gateway: <leave blank>
* Name server addresses: `192.168.0.239 192.168.0.241`
* Hostname: `nfs1`
* Domain name: `localdomain.com`
* Root password: <password>
* Full name for the new user: Systems Administrator
* Username for your account: `devops`
* Password for the new user: <password>
* Time zone: Madrid

> The guests in the cluster use an HTTP proxy to access the Debian package repositories, therefore the gateway is left blank.

Partitioning is next. Choose the "Manual" option. Example steps for the OS, swap and data disks (unless you want to use a zvol).

First disk (OS):

* Select the `SCSI (0,0,0)` disk (e.g., `sda`).
* Accept creating a new empty partition table on the device.
* Select the `pri/log free space` UI placeholder showing the available unallocated space.
* Select `Create a new partition`. Use all available space (default option) and select `Primary` as the partition type.
* Set the following options:
  * Use as: `Ext4 journaling file system`.
  * Mount point: `/`
  * Mount options: `discard`, `noatime`, `nodiratime`
  * Label: `os`
  * Reserved blocks: 1%
  * Typical usage: `standard`
  * Bootable flag: `on`
* Select `Done setting up the partition`.

Second disk (swap):

* Select the `SCSI (0,0,1)` disk (e.g., `sdb`).
* Accept creating a new empty partition table on the device.
* Select the `pri/log free space` UI placeholder showing the available unallocated space.
* Select `Create a new partition`. Use all available space (default option) and select `Primary` as the partition type.
* Set the following options:
  * Use as: `swap area`.
  * Bootable flag: `off`
* Select `Done setting up the partition`.

Third disk (data):

* Ignore the third `SCSI (0,0,2)` disk (e.g., `sdc`) during the installation.

Select the `Finish partitioning and write changes to disk` option and accept writing the changes to disk. The installer will install the base system.

> The correspondence between SCSI disks and the `/dev/sdX` device names used above is not guaranteed. The installer will display the disk size, which can help you identify them.

The next step in the installer is to configure the package manager. When prompted `Scan extra installation media?`, select `No`. Then set the following options:

* Debian archive mirror country: Germany
* Debian archive mirror: `deb.debian.org`
* HTTP proxy information: `http://apt.localdomain.com:8080/`

Proxy detection will be followed up by packages index update. Then, the installer will upgrade the base system with new packages, if any. Once complete, decide whether you want to participate in the package usage survey, then choose `SSH server` and `Standard system utilities` (default values) in the software selection screen, and continue.

The final step is to install the GRUB boot loader. Choose to install the GRUB boot loader to the primary drive `/dev/sda (scsi-0QEMU_QEMU_HARDDISK_drive-scsi0)`. Once its installation is complete, choose `Continue` to reboot.

Use the WebGUI to stop the VM once it has rebooted, then visit the `Options > Boot order` menu option of the VM and make sure that the `scsi0` disk is the first in the list and, optionally, the only one enabled. Then visit the `Hardware > CD/DVD Drive (ide2)` entry and select the `Do not use any media` option.

You can now start the VM.

## ZFS volumes

ZFS volumes (zvols) are an alternative to traditional virtual disks for VM data storage in Proxmox. While the Proxmox VM creation wizard typically provisions disk images in formats like `qcow2` (QEMU Copy On Write) or `raw`, these are still files sitting atop a ZFS dataset[^4]. By contrast, zvols offer native block-level storage managed directly by ZFS, eliminating the file layer entirely. This provides performance benefits, block-level snapshots, and more seamless resizing that are particularly relevant when exporting data over NFS.

[^4]: There are three types of datasets in ZFS: a filesystem following POSIX rules, a volume (zvol) existing as a true block device under `/dev`, and snapshots thereof.

To clarify, zvols do not provide "raw image format", like `vm-104-disk-1.raw`, but rather the disk is a ZFS-managed block device, such as `/dev/zvol/zfspool/vm-104-data`, i.e., no file, no virtual layer. Therefore, with a zvol, you avoid writing to a file sitting inside a ZFS dataset and QEMU going through file I/O layers and, instead, you get native block device backed directly by ZFS. This means better synchronisation and performance, especially for workloads that require frequent writes.

It is important to emphasise that we are not using ZFS as a filesystem inside the VM. Instead, we are using [*](ZFS) to back a block device and, inside the VM, we will format it, e.g., to [*](EXT4) or [*](XFS).

In our scenario, we chose to use a zvol for the data disk when we chose `zfspool` as storage, which will allow us to take advantage of features such as snapshots and compression. It will behave exactly like a physical disk: no filesystem or partition table until we create one. Inside the VM, the zvol will appear as a new physical disk (e.g., `/dev/sdc`), and it will be completely blank until we format it.

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

By following the steps described so far in this article, we now have the following sector and block sizes:

| Layer                | Option name    | Value | Notes            | Command                                     |
|----------------------|:--------------:|:-----:|------------------|---------------------------------------------|
| Physical sector size | `PHY-SEC`      | 4096  |                  | `lsblk -o NAME,SIZE,PHY-SEC,LOG-SEC`        |
| ZFS storage pool     | `ashift`       | 12    | 2¹² = 4096 bytes | `zdb -C zfspool \| grep ashift`             |
| ZVOL                 | `volblocksize` | 8K    |                  | `zfs get volblocksize zfspool/vm-104-data`  |
| ext4                 | Block size     | 4096  |                  | `tune2fs -l /dev/sdc \| grep 'Block size'`  |




The easiest way to improve performance, minimise fragmentation, and make the most of our disk's physical layout, is to align the physical sector size of our disk with the block sizes of the three layers involved: the ZFS storage pool, the zvol, and the filesystem inside the VM.


So, once you have finished installing the OS, create and attach the zvol from the terminal of the Proxmox host:

```bash
zfs create -V 100G -b 4K zfspool/vm-104-data
qm set 104 -scsi2 zfspool:vm-104-data,discard=on,iothread=1,cache=none,aio=io_uring
```

You can confirm that the new disk was attached to the VM via the `qm config 104` command, or via the `Hardware` menu option of the VM in the Proxmox WebGUI, where you can also change its flags, such as `Discard`, `IO thread`, `Cache`, and `Async IO`.

Inside the VM, confirm that the disk showed up with the `lsblk` command. Even if the VM was on when you attached the zvol, the OS should see the new disk automatically. However, you can force a rescan of the SCSI bus inside the VM, then try the `lsblk` command again:

```bash
for host in /sys/class/scsi_host/host*; do
  echo "- - -" > "$host/scan"
done
```

Now, inside the VM, as `root` user, you can format the new disk:

```bash
mkfs.ext4 -b 4096 /dev/sdc
```


Later, to resize:

1. On the Proxmox host: `zfs set volsize=400G zfspool/vm-104-data`.
2. Inside the VM: `resize2fs /dev/sdc`.

In the VM, force rescan of the SCSI bus to see the new zvol:

```bash
echo "- - -" > /sys/class/scsi_host/hostX/scan
```


Summary of the steps we went through:

| Virtual Disk                                                                | Zvol                                                                                      |
| --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Stored as a file on ZFS (qcow2 or raw format)                               | Stored as a ZFS block volume (`/dev/zvol/zfspool/vm-260-data`)                            |
| Resizing involves dealing with partition table changes (if not pre-planned) | Resizing is faster and cleaner — especially if you use the full disk (no partition table) |
| Snapshots work at the file level                                            | Snapshots are native ZFS snapshots — extremely fast and efficient                         |


If you ever need to recreate a zvol, e.g., to change the block size, use the following commands:

```bash
qm set 104 -delete scsi2
zfs destroy zfspool/vm-104-data
qm set 104 -scsi2 zfspool:vm-104-data,discard=on,iothread=1,cache=none,aio=io_uring
```


## Using 8k block size

https://forum.proxmox.com/threads/default-block-size-8k.126103/

Choosing an 8k block size when formatting a filesystem can offer a performance sweet spot for workloads that commonly read or write in chunks larger than the standard 4k, but not excessively so. This setting is particularly useful for applications such as NFS shares, databases (like PostgreSQL), or logging systems that often deal with 8k pages or I/O patterns. It can reduce internal fragmentation compared to larger block sizes while still improving I/O efficiency over 4k blocks, especially on spinning disks or workloads where sequential throughput is valuable. However, as with any optimization, the effectiveness of using 8k blocks ultimately depends on the typical request sizes and access patterns in your environment.



zpool iostat -r

| Component           | Suggested Value                                                                  |
| ------------------- | -------------------------------------------------------------------------------- |
| ZFS pool            | `ashift=13` (8K sector alignment)                                                |
| ZVOL                | Default block size (8K)                                                          |
| Guest FS            | XFS with 8K block size (`mkfs.xfs -b size=8192`)                                 |

Why Use XFS Inside the VM

XFS is a high-performance journaling filesystem optimized for large files and high-throughput workloads, making it a strong choice inside virtual machines where data integrity, scalability, and efficiency matter. Its robustness under concurrent write-heavy operations and support for advanced features like online defragmentation and resizing make it particularly well-suited for use cases such as NFS shares, backup storage, and databases. When used within a VM, XFS's maturity and reliability offer peace of mind, while its ability to handle large files and parallel I/O workloads gracefully helps ensure that the virtualized environment doesn’t become a bottleneck in your storage stack.

The physical sector size of your HDD is a hardware attribute, set by the manufacturer, not something that is decided when formatting the drive. To determine the physical sector size of your HDD drives, use `lsblk -o NAME,SIZE,PHY-SEC,LOG-SEC`:

* PHY-SEC shows the physical sector size
* LOG-SEC shows the logical sector size

If your HDD has a physical sector size of 4096 bytes, then setting ashift=12 is correct (because 2¹² = 4096). However, using ashift=13 (which equals 8192 bytes) can still be a good idea, depending on your use case.

 What ashift Does

    ashift controls the minimum block size ZFS will use for physical I/O on disk.

    It must be set at pool creation time and cannot be changed later.

    ashift=12 means ZFS will issue writes in 4K blocks.

    ashift=13 means ZFS will issue writes in 8K blocks.

When ashift=13 (8K) Is a Good Idea — Even on 4K Drives

    Workloads with larger I/O (like databases, VM images, backup servers) can benefit from the reduced metadata overhead and fewer IOPS required.

    If your applications typically write in chunks larger than 4K, the 8K ashift won't waste space and may perform better.

    Some modern drives are actually more efficient when aligned to 8K I/O boundaries, especially if they have internal 8K page sizes (common in some SSDs or SMR drives).



ashift=13 (block size = 8K) makes sense if your drives have a physical sector size of 4K, and you’re mostly working with larger files (like VM images, NFS storage, MinIO object storage, databases).

    It avoids write amplification from misalignment when the actual IO size is larger than ZFS’s internal block size.

    But once you set ashift, it’s permanent for the pool. Use zdb -C to confirm current ashift.

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


## Converting the disk to a ZFS volume

If we already have a virtual disk created during the VM creation, we can unlink it using the Proxmox WebGUI or the command line, then convert it to a ZFS volume.


```bash
qm disk unlink 104 scsi2 --delete 1
zfs create -V 300G zfspool/vm-104-data
qm set 104 -scsi2 zfspool:vm-104-data
qm config 104
```

## OS configuration

Some basic configuration of the OS.

Add your cluster public key to the `~/.ssh/authorized_keys` file of the `root` user and check that you can connect from the Ansible Controller.

Reduce swappiness to a minimum to save writes on the NVMe disk by setting `vm.swappiness` in the VM (swappiness is a kernel-level parameter controlled by the guest OS):

```bash
echo "vm.swappiness=1" | tee /etc/sysctl.d/99-swap.conf
sysctl -p /etc/sysctl.d/99-swap.conf
```

Check that support for trimming is working:

```bash
fstrim -v /
fstrim -v /srv/nfs
```

Some extra packages worth installing.

```bash
apt-get update
apt-get purge --yes nano vim-tiny
apt-get install --yes ccze dnsutils net-tools nmap rsync tcpdump vim
```

Set `vim` as the system-wide default editor:

```
update-alternatives --set editor /usr/bin/vim.basic
```

And set `vim` as the `root` user's default editor:

```
echo 'SELECTED_EDITOR="/usr/bin/vim.basic"' > ~/.selected_editor
```

Create the *Vim* configuration file `~/.vimrc` for the `root` user:

```
" Load defaults from /etc/vim/vimrc
runtime defaults.vim

" Disable mouse support which is enabled when loading upstream defaults
" in case /etc/vim/vimrc.local has not been deployed into the host.
set mouse=
set ttymouse=


" Disable swap and backup files for enhanced security
set noswapfile
set nobackup
set nowritebackup

" On pressing tab, insert 2 spaces
" Show existing tabs with 2 spaces width
" When indenting with '>', use 2 spaces width
set tabstop=2 softtabstop=0 expandtab shiftwidth=2 smarttab
set pastetoggle=<F3>
set nolist
set showbreak=↪\ 
set listchars=tab:→\ ,eol:↲,nbsp:␣,trail:•,extends:⟩,precedes:⟨
```

Configure the system hostname and related settings:

```
hostnamectl set-hostname nfs1
hostnamectl set-deployment staging
hostnamectl set-chassis "vm"
hostnamectl set-location "Data Center Park Helsinki, Finland"
```

Servers should always store [*](UTC). Local time is a presentation layer issue that only humans need to see. You can check the time zone in your server using the `timedatectl status` command. You can set the time zone to `UTC` with the `timedatectl set-timezone Etc/UTC` command.

## NFS server

Install the required packages:

```bash
apt-get install --yes nfs-kernel-server
```

NFS-mounted directories are not part of the system on which they are mounted. So, by default, the NFS server refuses to perform operations that require superuser privileges (e.g., reassign ownership).

NFS can be configured to allow trusted users on the client system to perform superuser tasks, but this introduces an element of risk, as such a user could gain root access to the entire host system.

In our example, we will create a general purpose NFS mount that uses default NFS behaviour to store files that were uploaded using a content management system. Since NFS operates using the `nobody:nogroup` credentials, we will assign those to the subdirectory.

```bash
mkdir --parents /srv/nfs/myapp
chown nobody:nogroup /srv/nfs/myapp
```

NFS will translate any `root` operations on the client to the `nobody:nogroup` credentials as a security measure. Therefore, we need to change the directory ownership to match those credentials.

`nfs-kernel-server` 2.6.2 on Debian 12 Bookworm supports NFSv2, v3 and v4. NFSv4 was standardized in 2003, so we will assume that all clients will be using this version of the protocol.

NFSv4 exports typically live under a common pseudo-root, `/srv/nfs` in our case. The host exports such top-level directory with `fsid=0`, and clients mount subpaths, e.g., `/myapp`.

We are now ready to export the share by editing the `/etc/exports` file:

```
/srv/nfs       myapp1.localdomain.com(rw,sync,no_subtree_check,root_squash,fsid=0) \
               myapp1.localdomain.com(rw,sync,no_subtree_check,root_squash,fsid=0)

/srv/nfs/myapp myapp1.localdomain.com(rw,sync,no_subtree_check,root_squash) \
               myapp2.localdomain.com(rw,sync,no_subtree_check,root_squash)
```

Let's review each of the options:

* `rw`: Gives the client permission to both read and write to the volume.
* `sync`: Forces NFS to write changes to disk before replying. This reduces the speed of operations but results in a more stable and consistent interaction.
* `no_subtree_check`: Prevents the process where, for every request, the host must check whether a given file is actually still available in the exported tree, e.g., when a client requests renaming a file that is still open by another client.
* `root_squash`: Map client's `root` user to `nobody`, for security (default behaviour).
* `fsid=0`: Defines the NFSv4 root export.

> The `fsid=0` option is not required for root access, but to define the NFSv4 root export.

Ensure that the NFSv4 domain matches by editing the `/etc/idmapd.conf` file:

```ini
[General]
Domain = localdomain.com
```

> This is the default behaviour. We are just being explicit about it.

And restart the daemon with `systemctl restart nfs-idmapd`.

Run `exportfs -ra` to export the changes. Confirm the exports with `exportfs -v`. Finally, verify the setup is working fine with `showmount -e nfs1.localdomain.com`.

We now need to adjust the firewall rules on the VM. At the moment you should already have aliases for both the client and the host, created via the `Datacenter > Firewall > Alias` menu option.

```ini
# /etc/pve/firewall/cluster.fw

[ALIASES]

ipv4_private_ansible1 192.168.0.1 # Ansible Controller
ipv4_private_nfs1 192.168.0.4 # NFS: Staging)
ipv4_private_myapp1 192.168.0.5 # My app: Staging)
ipv4_private_myapp2 1291.68.0.6 # My app: Staging)
```

And you should probably have an IP set for the two LXC running your app:

```ini
# /etc/pve/firewall/cluster.fw

[IPSET private_myapp_staging] # My App guests

ipv4_private_myapp1
ipv4_private_myapp2
```

Therefore, you would create a security group for the NFS server host:

```ini
# /etc/pve/firewall/cluster.fw

[group nfs_staging] # Default rules for NFS servers

IN ACCEPT -source +private_myapp_staging -p udp -dport 2049 -log nolog # Allow NFS traffic
IN ACCEPT -source +private_myapp_staging -p tcp -dport 2049 -log nolog # Allow NFS traffic
```

And, finally, add the security group to the `nfs1` guest:

```ini
# /etc/pve/firewall/<VMID>.fw

[RULES]
GROUP nfs_staging -i net0 # Allow access to NFS from guests
```


| Type  | Action      | Macro | Iface | Protocol | Source | S. port | Destination | D. port | Comment             |
|-------|-------------|-------|-------|:--------:|--------|---------|-------------|:-------:|---------------------|
| group | nfs_staging |       | net0  |          |        |         |             |         | Allow access to NFS |


## NFS client on VM

Let's asume that our application `myapp` is run by the user `myappuser`, that belongs to the group `myappgroup`. Let's create the mount point on the guest where NFS will act as client:

```bash
mkdir /mnt/files
chown myappuser:myappgroup /mnt/files
```

Then we can manually test that we can reach the NFS export:

```bash
mount --types nfs4 nfs1.localdomain.com:/myapp /mnt/files
umount /mnt/files
```

For this to work the `myappuser` user and the `myappgroup` have to exist on both server and client and the `UID` and `GID`, respectively, match across both.

In our case, running `id myappuser` in our client tells us that both the user and the group have id 1001

```bash
uid=1001(myappuser) gid=1001(myappgroup) groups=1001(myappgroup),117(ssl-cert)
```

So we need to create the same user and group in the `nfs1` guest:

```bash
groupadd --gid 1001 myappgroup
useradd --uid 1001 --gid 1001 --no-create-home --shell /bin/false myappuser
```

Then file ownership will behave correctly across the mount. No need to pass any extra options at mount time.

In order to have the remote volume mounted automatically upon reboot, we need to add the appropriate entry in the `/etc/fstab`:

```
nfs1.localdomain.com:/myapp /mnt/files nfs4 auto,rw,suid,nouser,async,_netdev,nofail,noatime,nolock 0 0
```

Explanation of options:

* `nfs4`: Use NFS version 4.
* `auto`: Allows automatic mounting at boot.
* `rw`: Mount read-write.
* `nosuid`: Disable SUID/SGID bits.
* `nouser`: Only root can mount
* `async`: Use asynchronous I/O
* `_netdev`: Ensures mount happens after the network is up.
* `nofail`: Allows the system to boot even if the NFS mount fails.
* `noatime`: Disables updates to access timestamps on files.
* `nolock`: Disable NFS file locking (avoids needing `rpc.statd` on the client side), unless your application relies on file locking internally (which is uncommon for file-based uploads like images).

Note that we are not using the `defaults` option, as it includes the `dev`, `suid` and `exec` options that do not apply to our use case:

* `suid`: Allow programs to run with set-user-identifier (SUID/SGID) bits.
* `dev`: Interpret device special files on the filesystem.
* `exec`: Allow execution of binaries.

We do not need to specify user or group, as ownership will work based on UID/GID.

Use either `umount /mnt/files` or `mount -a` to mount the volume with the options we just configured.

## Copying files to the NFS mount

Why Rsync Over NFS is Slow (and Solutions)

1. Metadata Overhead:
NFS requires a separate network round-trip for every file operation (stat, open, read, close). For small files, this creates massive overhead.

    Example: Syncing 10,000 small files = 40,000+ network requests.

2. Lack of Real Parallelism:
NFS operations are sequential by default. Rsync processes files one-by-one, amplifying latency.

3. Protocol Limitations:

    NFSv3: No compound operations (multiple actions in one request)

    NFSv4: Better, but still less efficient than native protocols like SSH

4. Write Barriers:
NFS enforces strict write ordering (sync writes), slowing small file operations.
Speeding Up Rsync Over NFS
A. Rsync Tweaks
bash

rsync --archive --no-owner --no-group --progress \
      --inplace \         # Avoid temp-file renames
      --whole-file \      # Disable delta-xfer (good for fast LANs)
      --recursive \
      --links \
      --delete \
      /src/ /mnt/nfs/dest/

Key Options:

    --inplace: Writes directly to target files (reduces rename ops)

    --whole-file: Sends whole files (bypasses slow rsync diffs)

    Avoid: --checksum (adds massive overhead)

B. NFS Server/Client Tuning

On NFS Server (VM):

    Increase NFS threads:
    bash

echo "RPCNFSDCOUNT=32" >> /etc/default/nfs-kernel-server

Use async writes (if UPS-backed):
bash

    # /etc/exports
    /export  *(rw,async,no_subtree_check,insecure)

On NFS Client (Proxmox/LXC):
Mount with performance options:
bash

mount -t nfs4 -o \
  rsize=65536,wsize=65536,noatime,nodiratime,async,tcp,hard \
  nfs-server:/share /mnt/nfs

C. Nuclear Options

    Tar Over Pipe (Best for initial sync):
    bash

tar cf - /src | ssh user@nfs-server "tar xf - -C /dest"

Parallel Rsync:
bash

find /src -type f | parallel -j 16 rsync -a {} /mnt/nfs/dest/

(Install parallel first)

Switch to SSHFS:
bash

    sshfs user@nfs-server:/share /mnt/sshfs -o \
    allow_other,cache=yes,compression=no,large_read

When to Use Rsync Over NFS

✅ Large files (video, databases)
✅ Incremental updates after initial sync
🚫 Avoid for:

    Initial sync of many small files

    High-churn directories

    Latency-sensitive operations

Performance Comparison (1GB of 10KB files)
Method	Time	Network Reqs
Rsync (default)	8m22s	~120,000
Rsync (--inplace)	4m15s	~80,000
Tar over SSH	0m48s	1
Parallel Rsync (16j)	1m12s	16,000
Recommendation:

For initial bulk transfers, use tar or parallel methods. For ongoing syncs, use tuned rsync with --inplace. For maximum speed, SSH-based transfers will always outperform NFS for rsync workloads due to lower protocol overhead.

If you need to copy or move files and folders from the current location to the mounted volume, you should use `rsync`, but make sure you do not try to change ownership:

```bash
rsync --archive --no-owner --no-group --progress /path/to/static/files/ /mnt/files/
```

If you want to do this using `rsync` over SSH, bypassing the NFS mount, you can use the following command:

```bash
rsync --archive --no-owner --no-group --progress /opt/popeye/src/www/static/ /mnt/media/
rsync --archive --no-owner --no-group --progress -e "ssh -p 22" /path/to/static/files/ user@remote:/path/to/destination/
rsync --archive --no-owner --no-group --progress --delay-updates --timeout=5 --delete --delete-delay --rsh='/usr/bin/ssh -o StrictHostKeyChecking=no' /opt/popeye/src/www/static/ nfs1.andromedant.com:/srv/nfs/popeyedevel/
```

## NFS client on LXC

When the NFS client is an unprivileged LXC, direct NFS mounting is not possible because [AppArmor](https://apparmor.net/) does not allow it. In such scenario, an alternative approach would be to mount the share on the Proxmox host first, then bind it to the container.

Aside from security risks on our multi-tenant environment, this setup reduces isolation, requires host-level privileges and increases cluster complexity (all nodes mount the same NFS paths so that guests can be migrated).

However, if we were to configure the LXC as privileged, then we could reproduce the steps performed on the client VM. Trading security for convenience, privileged LXCs are less isolated than unprivileged containers, therefore a host kernel issue or crash would affect all containers and NFS mounts inside the LXC. Moreover, NFS mounts would break during live migration or backup, or prevent these tasks from completing successfully.

All in all, when using LXC the recommended way to store files would be an S3-compatible object storage, such as [MinIO](https://min.io/), [Garage](https://garagehq.deuxfleurs.fr/) or [SeaweedFS](https://github.com/seaweedfs/seaweedfs).

## Extending the OS or data disks

When in need to extend the size of the OS or the data disks, follow these steps:

1. Shutdown the VM.
2. Select to the `Hardware > Hard Disk (scsi0)` menu option.
3. Click on the `Disk action` button and choose `Resize`. Fill in the `Size increment (GiB)` field and click the `Resize disk` button.
4.  Start the VM. In theory, `partx -u /dev/sda` should work and thus a stop/start should not be required.
5. Use `fdisk -l /dev/sda` to verify that the size of the disk (`/dev/sda`) is now bigger but the size of the partition (/dev/sda1`) is still the same size (e.g., one less gigabyte). Moreover, take note of the amount of sectors in the disk (first line) and of the partition start sector (last line), most probably 2048.
6. Dump the current partition table to a file using `sfdisk -d /dev/sda > /root/sda.partition`.
7. Calculate the new size by substracting the start sector (e.g., 2048) from the total sectors of the disk (not the partition).
8. Edit the `/root/sda.partition` file and change the size. Save the changes.
9. Write the new partition table using `sfdisk --force /dev/sda < sda.partition`.
10. Tell the kernel to reread the partition table using `partx -u /dev/sda`. Check it with `fdisk -l /dev/sda`.
11. Once the kernel sees the updated partition, resize the filesystem using `resize2fs /dev/sda1`.
12. Verify the changes with `df -h /`.

## Automating disk resizing

The following script automates the task, allegedly. It works for DOS partition tables with a single primary partition starting at 2048.

```bash
#!/bin/bash

DISK="/dev/sdb"
PART="${DISK}1"
DUMP_FILE="/root/sdb.partition"

# Step 1: Dump partition table
sfdisk -d "$DISK" > "$DUMP_FILE"

# Step 2: Extract the partition line
PART_LINE=$(grep "${PART}" "$DUMP_FILE")

# Step 3: Parse start sector
START_SECTOR=$(echo "$PART_LINE" | grep -oP 'start=\s*\K[0-9]+')

# Step 4: Get total sectors on the disk
TOTAL_SECTORS=$(blockdev --getsz "$DISK")

# Step 5: Calculate new size
NEW_SIZE=$((TOTAL_SECTORS - START_SECTOR))

# Step 6: Update the size field in the partition dump file
sed -i -E "s|(start=\s*${START_SECTOR},\s*size=\s*)[0-9]+|\1${NEW_SIZE}|" "$DUMP_FILE"

# Step 7: Apply the new partition layout
sfdisk --force "$DISK" < "$DUMP_FILE"

# Step 8: Tell the kernel to re-read the partition table
partx -u "$DISK"

# Step 9: Resize the filesystem
resize2fs "$PART"

# Step 10: Show the new size
df -h "$PART"

```


## Creating the VM with CLI

```
VMID=100                     # Replace with your chosen VM ID
VMNAME="nfs-vm"              # Replace with your VM name
STORAGE_LOCAL="local"       # Local storage for OS and swap disks
STORAGE_ZFS="zfspool"       # Your ZFS storage name for the data disk
ISO_IMAGE="local:iso/debian-12.iso"  # Replace with the correct path to your ISO image


Step 1: Create the VM

qm create $VMID --name $VMNAME --memory 512 --cores 1 --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci --boot order=scsi0 --ostype l26

    --scsihw virtio-scsi-pci: enables discard/TRIM and I/O threads.

    --ostype l26: optimized defaults for Linux guests.

💾 Step 2: Add the OS Disk (SCSI 0)

qm set $VMID --scsi0 ${STORAGE_LOCAL}:$VMID/vm-$VMID-disk-0.raw,discard=on,cache=none,format=raw,ssd=1,iothread=1

    discard=on: enables TRIM

    cache=none: avoids double caching (ZFS)

    iothread=1: enables parallel I/O

    ssd=1: sets the SSD emulation bit (helps some guests)

💾 Step 3: Add the Swap Disk (SCSI 1)

qm set $VMID --scsi1 ${STORAGE_LOCAL}:$VMID/vm-$VMID-disk-1.raw,size=1G,discard=on,cache=none,format=raw,ssd=1

    iothread intentionally omitted (swap doesn’t benefit)

    backup=0 is not needed — swap is not backed up by default

💾 Step 4: Add the Data Disk (SCSI 2)

qm set $VMID --scsi2 ${STORAGE_ZFS}:vm-$VMID-disk-2,size=100G,discard=on,cache=none,format=raw,ssd=1,iothread=1

💿 Step 5: Attach the ISO and Set Boot Order

qm set $VMID --cdrom $ISO_IMAGE

If you're using UEFI and want EFI boot:

qm set $VMID --bios ovmf --efidisk0 ${STORAGE_LOCAL}:$VMID/vm-$VMID-efi,size=1M

🏁 Step 6: Start the VM and Begin Installation

qm start $VMID

You can now access the VM via the console in the Proxmox GUI and proceed with manual partitioning during Debian installation.
🧠 Notes and Tips

    You must manually partition during Debian setup to:

        Assign / to the OS disk

        Assign swap to the swap disk

        Mount /srv/nfs on the data disk

    After install, verify TRIM support with:
```
