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

In this article, we will install and configure an NFS server in a [*](VM) on a Proxmox cluster, optionally using our [*](ZFS) pool on [*](HDD) disks. The NFS server will be used to share files between multiple clients, such as web servers or application servers.

This is an alternative approach to using an [*](S3) compatible object storage, such as [MinIO](https://min.io/), [Garage](https://garagehq.deuxfleurs.fr/) or [SeaweedFS](https://seaweedfs.com/). Both approaches have their own advantages and disadvantages, and the choice between them depends on the specific use case, requirements and limitations.

## ISO download

Visit the [Downloading Debian](https://www.debian.org/download) page and its linked [SHA512SUMS](https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS) page. You are for looking for latest Debian 12 Bookworm Netinst ISO and its SHA-512 checksum.

Click on the node where you want to install the VM, go to the `local` storage, go to the `ISO Images` menu option and click the `Download from URL` button:

* Paste the URL of the [latest Debian 12 Bookworm Netinst ISO](https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso) into the `URL` field and click on `Query URL`. `File size` and `MIME type` will be filled in.
* Select the hash algorithm `SHA-512` and paste the checksum for the image.

The image will be downloaded and verified. Once the download is complete, you will notice the ISO image in the `local` storage on the node.

Alternatively, if you want to use the terminal, these are the commands you have to execute at the node where you will be installing the VM:

```bash
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso \
     --output-document=/var/lib/vz/template/iso/debian-12.11.0-amd64-netinst.iso
```

For security, calculate its SHA 512 checksum and compare it with the one from the SHA512SUMS file:

```bash
sha512sum /var/lib/vz/template/iso/debian-12.11.0-amd64-netinst.iso
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS -O- | grep debian-12.11.0-amd64-netinst.iso
```

## VM creation

We will be using three separate virtual disks for the VM:

* **OS disk**: A small disk on our local pool that will hold the operating system.
* **Swap disk**: A small disk on our local pool that will hold the swap space.
* **Data disk**: A larger disk on our ZFS pool that will hold the data to be shared via NFS.

This is to simplify the setup and prevent us from running into issues with disk space management on multiple partitions. Both the OS and the data disks will be formatted using `ext4`, which will allow us to extend them later, if needed.

Therefore, we will be using manual partitioning during the OS installation to create a DOS partition table and a primary partition on the OS and swap disks.

### Using the GUI

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

> Regarding the data disk, by choosing `zfspool` as storage, the assistant creates a ZFS volume (zvol) instead of a virtual disk.

Incidentally, in the node where this VM is being provisioned we have allocated 4-8 GB for ZFS ARC via `/etc/modprobe.d/zfs.conf`:

```conf
options zfs zfs_arc_max=8589934592
options zfs zfs_arc_min=4294967296
```

This will allow the VM to use up to 8 GB of memory for caching, which is a good amount for a moderate usage NFS server. The `Min. memory` setting will ensure that the VM has at least 4 GB of memory available, which is enough for the OS and the NFS server.

The VM id will be automatically assigned by Proxmox, but you can change it to a specific number if you want. In this article, we will use `104` as the VM id.

> Do not forget to add the corresponding DNS records to your internal zone `localdomain.com` and to your reverse zone `168.192.in-addr.arpa`.

### Using the CLI

Alternatively, if you prefer using the terminal, follow these three steps to achieve the same results.

First, create the VM:

```bash
qm create 104 --name nfs1 --pool databases --memory 8192 --cores 4 --socket 1 --balloon 4096 --onboot 0 --agent enabled=1
```

Then, configure the VM settings:

```bash
qm set 104 --scsihw virtio-scsi-pci --ide2 local:iso/debian-12.11.0-amd64-netinst.iso,media=cdrom --boot order=scsi0
qm set 104 --net0 virtio,bridge=vmbr4002,mtu=1400
```

Finally, create and attach the OS, swap and data disks:

```bash
qm set 104 --scsi0 local:104/vm-104-disk-os.qcow2,format=qcow2,iothread=1,discard=on,backup=1,async_io=io_uring,size=3G
qm set 104 --scsi1 local:104/vm-104-disk-swap.raw,format=raw,discard=on,async_io=io_uring,size=1G
qm set 104 --scsi2 zfspool:vm-104-disk-data,format=raw,iothread=1,discard=on,backup=1,async_io=io_uring,size=100G
```

> Note that the WebGUI would have named the disks `vm-104-disk-0.qcow2`, `vm-104-disk-1.raw` and `vm-104-disk-2`, respectively, whereas via the terminal we are being more explicit about their intended usage.

Optionally, verify the configuration:

```bash
qm config 104
```

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

Partitioning is next. Choose the "Manual" option and set up the OS and swap disks. Ignore the data disk for now.

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

## OS configuration

Some basic configuration of the OS.

Add your cluster public key to the `~/.ssh/authorized_keys` file of the `root` user and check that you can connect from your Ansible Controller, through your bastion host, or equivalent.

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

Some extra packages worth installing:

```bash
apt-get update
apt-get install --yes ccze dnsutils jq net-tools nmap rsync tcpdump
```

Configure the system hostname and related settings:

```
hostnamectl set-hostname nfs1
hostnamectl set-deployment staging
hostnamectl set-chassis "vm"
hostnamectl set-location "Data Center Park Helsinki, Finland"
```

Servers should always store [*](UTC). Local time is a presentation layer issue that only humans need to see. You can check the time zone in your server using the `timedatectl status` command, then set the time zone to `UTC`, if needed:

```bash
timedatectl set-timezone Etc/UTC
```

## Format the data disk

We chose to use a ZFS volume (zvol) for the data disk when we chose `zfspool` as storage, which will allow us to take advantage of features such as snapshots and compression. It will behave exactly like a physical disk: no filesystem or partition table until we create one. Inside the VM, the zvol will appear as a new physical disk (e.g., `/dev/sdc`), and it will be completely blank until we format it.

We are not using ZFS as a filesystem inside the VM. Instead, we are using [*](ZFS) to back a block device (our data disk) and, inside the VM, we will format it using [*](XFS).

Furthermore, if you create a partition inside the VM, like most OS installers do, then resizing later will still involve partition math (e.g., using `sfdisk` to adjust size). If, instead, you use the whole device directly (i.e., format `/dev/sdc` without a partition table), then resizing becomes simpler.

Therefore, inside the VM, all that is left is to format the data disk. As the `root` user, identify the disk using the `lsblk` command (e.g., `sdc`) , then format it:

```bash
mkfs.xfs -b size=8192 -d su=8k,sw=1 /dev/sdc
```

We are aligning the same block size that Proxmox used to create the ZVOL (`volblocksize`) with the block size of XFS. Also, we are telling XFS that the underlying storage works best when it writes in 8K blocks via the `su=8k` (stripe unit = 8K) and the `sw=1` (one stripe = 8K, because ZVOL is not a RAID stripe) arguments.

Because `volblocksize` can change depending on your version of ZFS, before formatting the disk, check it out using the host shell:

```bash
zfs get volblocksize zfspool/vm-104-data
```

If your `volblocksize` is 16K, then adapt how you format the data disk:

```bash
mkfs.xfs -b size=16384 -d su=16k,sw=1 /dev/sdc
```

Aligning the block size of XFS with the block size of the ZVOL is always beneficial, no matter what value of `ashift` your ZFS storage pool has.

> ZFS version 2.2 brings in a new default block size of 16K.

Finally, create the mount point, get the UUID of the new disk with the `blkid /dev/sdc` command and configure the `/etc/fstab` file to mount it automatically at boot:

```bash
mkdir /srv/nfs
blkid /dev/sdc
echo 'UUID=333e6175[..] /srv/nfs xfs noatime 0 2' >> /etc/fstab
mount /srv/nfs
```

> In the future, use `xfs_info /srv/nfs` to check the arguments used when formatting.

To get better performance and control, we are not using the `discard` mount option. Instead, we will run `fstrim` periodically:

```
systemctl enable fstrim.timer
```

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
/srv/nfs       myapp1.localdomain.com(rw,async,no_subtree_check,root_squash,fsid=0) \
               myapp1.localdomain.com(rw,async,no_subtree_check,root_squash,fsid=0)

/srv/nfs/myapp myapp1.localdomain.com(rw,async,no_subtree_check,root_squash) \
               myapp2.localdomain.com(rw,async,no_subtree_check,root_squash)
```

Let's review each of the options:

* `rw`: Gives the client permission to both read and write to the volume.
* `async`: Forces NFS to reply to write requests from clients as soon as the data is received, without waiting for the data to be written to disk. This leads to better performance but there is a trade-off with data integrity.
* `no_subtree_check`: Prevents the process where, for every request, the host must check whether a given file is actually still available in the exported tree, e.g., when a client requests renaming a file that is still open by another client.
* `root_squash`: Map client's `root` user to `nobody`, for security (default behaviour).
* `fsid=0`: Defines the NFSv4 root export.

If your workload is not sensitive to latency, it is recommended to use `sync` (default) instead of `async`, which will force NFS to write changes to disk before replying. This reduces the speed of operations but results in a more stable and consistent interaction.

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

## Bulk load of files

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
