# Installation of a Proxmox Virtual Environment 7 cluster on Hetzner

*Created on 2021-10-18. Last updated on 2025-03-24.*

We are going to set up a Proxmox cluster with serveral nodes (named `proxmox1`, `proxmox2`, etc.) using Hetzner's dedicated servers and virtual switches (vSwitch).

# Design

We will be using three VLANs:

* Id `4001` , Proxmox guests public network (`116.202.120.32/28`), for the guests public addresses.
* Id `4002` , Proxmox guests private network (`192.168.0.0/16`), used for the application running in the virtual machines to communicate.
* Id `4003` , Proxmox hosts private network (`10.0.0.0/8`), used for the nodes (hosts) of the cluster to communicate among themselves (Corosync, VM migration, etc.)

Given the naming conventions for device names described in the [Host System Administration: Network Configuration](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysadmin_network_configuration) section of the [Proxmox VE Administration Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.html), we are going to use the following convention for our single-NIC servers:

| **Type**        | **Device name** | **Used by** | **Type**       | **IP range**       | **Description**                                                                |
|-----------------|-----------------|-------------|----------------|--------------------|--------------------------------------------------------------------------------|
| Ethernet device | `eno1`          | The host    | Public IP      |                    | Public IP address assigned to the server when ordered                          |
| Bridge          | `vmbr4001`      | Guests      | Public subnet  |`116.202.120.32/28`<br>`49.13.106.48/28` | Holds the public subnet assigned to the vSwitch with id 4001                   |
| Bridge          | `vmbr4002`      | Guests      | Private subnet |`192.168.0.0/16`    | Used for communication among guests through vSwitch with id 4002               |
| VLAN            | `eno1.4003`     | Hosts       | Private subnet |`10.0.0.0/8`        | Used for communication among nodes of the cluster through vSwitch with id 4003 |

Guests will be having one or two virtual network devices:

* `eno1` will be mandatory and will have an IP address of the private network `192.168.0.0/16`, where the last digit will be the number of the container or virtual machine, thus starting at 100 (i.e. `192.168.0.100`, `192.168.0.101`, etc.).
* `eno2` will be optional and will have an IP address of the public subnet assigned to the vSwitch with VLAN id `4001`.

Each host will have an IP address of the private network of the guests that will act as gateway for the latter, where the last digit will be the same as the one in the private network used by the hosts to communicate among themselves via the vSwitch with VLAN id `4003` (i.e. `10.0.0.1`, `10.0.0.2`, etc.).

# OS installation

We will use Hetzner's rescue system to install Debian 11 Bullseye. Then we will install Proxmox on top of it.

Access the [Hetzner control panel](https://accounts.hetzner.com/login), go to the [Robot control panel](https://robot.hetzner.com/), then go to the [server list](https://robot.hetzner.com/server). Then follow these steps:

* Identify the server and click on the server id (e.g., `EX52-NVMe #1569272`) to unfold the server details and management options.
* Go to the `Rescue` tab, select your public key and click on the `Activate rescue` button.
* Go to the `Reset` tab and select the `Send CTRL+ALT+DEL to the server` radiobutton, then click the `Send` button. Alternatively, use the `Execute an automatic hardware reset` option.
* Go to the `Firewall` tab and apply the template "Proxmox Virtual Environment". Before saving the changes, manually add the port number 22 via the TCP protocol. This is because the newly-installed OS will have its `sshd` daemon listening to port 22 until we change such default port.

Wait for a minute, then try to connect to the [rescue system](https://docs.hetzner.com/robot/dedicated-server/troubleshooting/hetzner-rescue-system/) using the `root` user, port 22 and the key you selected before. We will be using [InstallImage](https://docs.hetzner.com/robot/dedicated-server/operating-systems/installimage) to install the operating system with a custom configuration but, first, we need to stop currently active software RAIDs and delete the current partitions to prevent possible issues during the installation:

```bash
mdadm --stop /dev/md/*
wipefs -fa /dev/sd*
wipefs -fa /dev/nvme*n1
```

Note: Should you wish to check the current configuration of the drives, you can do so using the `lsblk` command.

Finally, let's install the operating system via `installimage` by following these steps:

* Execute the `installimage` command.
* Choose `Debian`.
* Choose `Debian-1111-bullseye-amd64-base`

By default, `installimage` will use all available disks to create a software RAID, for a server with disks dedicated to the OS and disks dedicated to a ZFS pool, this is not the right configuration. So, in the [Midnight Commander](https://midnight-commander.org/) user interface that will show next, change the level for the software RAID (`SWRAIDLEVEL`) and comment the hard disk drives that will not be used for the RAID of the disks dedicated to the operating system. The following  (this example is for a system with two NVMe disks for the OS and to HHD disks for the ZFS pool):

```
DRIVE1 /dev/nvme0n1
DRIVE2 /dev/nvme1n1
# DRIVE3 /dev/sda
# DRIVE4 /dev/sdb

SWRAIDLEVEL 1
```

Optionally, also set the hostname:

```
HOSTNAME proxmox1.andromedant.com
```

Press `F10` and select `Yes` to save the changes. Confirm that data on the drives assigned to the RAID for the OS will be deleted and wait until the process finishes, monitoring the progress in the console. When the process finishes, type `reboot` to reboot the system into the newly-installed operating system.

# OS configuration

Initial server set-up after the default installation of Hetzner’s Debian Bullseye distribution on a dedicated server.

The base installation is a Debian Bullseye AMD64, Hetzner’s version. Default packages include `sudo`, `locales`, `net-tools`and `vim-tiny`. Some extra packages worth installing.

```bash
apt-get update
apt-get purge nano vim-tiny
apt-get install ccze dnsutils net-tools nmap tcpdump vim
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

## Host name and hosts file

Configure `/etc/hostname`:

```
hostnamectl set-hostname proxmox1
hostnamectl set-deployment production
hostnamectl set-location "Data Center Park Falkenstein, Germany"
```

Currently used locations are:

* "Data Center Park Falkenstein, Germany"
* "Data Center Park Helsinki, Finland"

Configure `/etc/hosts`:

```
# IPv4
127.0.0.1 localhost.localdomain localhost
88.99.93.182 proxmox1.andromedant.com proxmox1

# IPv6
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
2a01:4f8:10a:1def::2 proxmox1.andromedant.com proxmox1
```

> For future reference, before setting up the cluster we will be changing these entries, once the VLAN among hosts has been set up, into something like this:

```conf
# IPv4
127.0.0.1 localhost.localdomain localhost

192.168.1.9 pbs2.andromedant.com pbs2

192.168.1.11 proxmox1.andromedant.com  proxmox1
192.168.1.12 proxmox2.andromedant.com  proxmox2
192.168.1.13 proxmox3.andromedant.com  proxmox3
192.168.1.14 proxmox4.andromedant.com  proxmox4
192.168.1.15 proxmox5.andromedant.com  proxmox5
192.168.1.16 proxmox6.andromedant.com  proxmox6
192.168.1.17 proxmox7.andromedant.com  proxmox7
192.168.1.18 proxmox8.andromedant.com  proxmox8
192.168.1.19 proxmox9.andromedant.com  proxmox9
192.168.1.20 proxmox10.andromedant.com proxmox10
```

> For future reference, when migrating to Proxmox 8 in a new cluster, nodes will communicate among themselves using a completely different subnet, so the file will look like this:

```conf
# IPv4
127.0.0.1 localhost.localdomain localhost

10.0.0.1  proxmox1.andromedant.com  proxmox1
10.0.0.2  proxmox2.andromedant.com  proxmox2
10.0.0.3  proxmox3.andromedant.com  proxmox3
10.0.0.4  proxmox4.andromedant.com  proxmox4
10.0.0.5  proxmox5.andromedant.com  proxmox5
10.0.0.6  proxmox6.andromedant.com  proxmox6
10.0.0.7  proxmox7.andromedant.com  proxmox7
10.0.0.8  proxmox8.andromedant.com  proxmox8
10.0.0.9  proxmox9.andromedant.com  proxmox9
10.0.0.10 proxmox10.andromedant.com proxmox10

10.0.0.100 pbs2.andromedant.com pbs2
```

So the first node will use IP address `.1` , the second node `.2` , the third node `.3` , and so on.

## Network configuration

Make a copy of the default network configuration before editing anything:

```
cp --archive /etc/network/interfaces /etc/network/interfaces.orig
```

Now set up A and AAAA entries in the `andromedant.com` DNS zone so that the host can be accessed through a FQDN:

```
proxmox1 IN A 88.99.93.182
proxmox1 IN AAAA 2a01:4f8:10a:1def::2
```

## Locale

Configure the locale:

```
localectl set-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8
```

Generate locales:

```
locale-gen
```

The default system-wide locale can be checked with the following command:

```
$ cat /etc/default/locale
LANG=en_US.UTF-8
```

In Debian 11 Bullseye it seems to be enough to set up the locale, so adding regional configuration variables to `/etc/environment` seems not to be needed anymore. Anyway, the commands are left here for reference:

```
echo "LC_ALL=en_US.UTF-8" > /etc/environment 
echo "LANG=en_US.UTF-8" >> /etc/environment
echo "LANGUAGE=en_US.UTF-8" >> /etc/environment
```

Reboot.

## Time zone and Network Time Protocol

Debian 11 Bullseye uses `systemd-timesyncd` by default. Hetzner’s version of Debian 11 includes three NTP servers provided by Hetzner:

```
# cat /etc/systemd/timesyncd.conf.d/hetzner.conf 
[Time]
NTP=ntp1.hetzner.de ntp2.hetzner.com ntp3.hetzner.net
```

To check that the service is running correctly, use the following command:

```
systemctl status systemd-timesyncd
```

The Proxmox VE cluster stack itself relies heavily on the fact that all the nodes have precisely synchronized time (mainly Corosync and RRDC for the `pvestatd` service). In order to check the status of the time synchronization, we can use the following commands:

```
timedatectl status
```

To see verbose service information, use:

```
timedatectl timesync-status
```

Note: Proxmox [recommends using Chrony with Proxomox 7](https://pve.proxmox.com/wiki/Time_Synchronization).

Server nodes should have the `Etc/UTC` time zone configured. This can be checked with the following command:

    timedatectl status

The available time zones can be listed with the following command:

    timedatectl list-timezones

The time zone can be changed with the following command:

    timedatectl set-timezone Etc/UTC

Note: It can also be done via the old-fashioned `dpkg-reconfigure tzdata` command.

The system clock (software) and the hardware real-time clock (RTC) can be set using the following commands:

    timedatectl set-ntp false
    timedatectl set-time "2022-08-25 09:00:45"
    timedatectl set-ntp true

The date and time have to be in the time zone of the system clock. The value of the hardware clock will be updated accordingly.

Should this command fail, the commands `hwclock` and `date` can also be used to check and set the hardware and software clocks:

    hwclock -r
    date +%Y%m%d --set "20220825"
    date +%T --set "07:40:40"

## Debian packages mirror

Configure the mirror to get packages from in the `/etc/apt/sources.list` file:

```
# Packages and security updates from the Hetzner Debian mirror
deb http://mirror.hetzner.de/debian/packages bullseye main contrib non-free
deb http://mirror.hetzner.de/debian/packages bullseye-updates main contrib non-free
deb http://mirror.hetzner.de/debian/packages bullseye-backports main contrib non-free

# Debian mirror
deb http://ftp.de.debian.org/debian bullseye main contrib non-free
deb http://ftp.de.debian.org/debian bullseye-updates main contrib non-free
deb http://ftp.de.debian.org/debian bullseye-backports main contrib non-free

# Security updates
deb http://mirror.hetzner.de/debian/security bullseye-security main contrib non-free
deb http://security.debian.org/debian-security bullseye-security main contrib non-free
```

Delete the file `/etc/apt/sources.list.d/hetzner-security-updates.list`:

```
rm /etc/apt/sources.list.d/hetzner-security-updates.list
```

Upgrade existing packages to the latest version:

```
apt-get update
apt-get dist-upgrade
apt-get clean
```

Reboot.

After reboot, purge unused dependency packages:

```
apt-get autopurge
```

## ~~Sudo user (deprecated)~~

Since we will be restricting access to the root account via SSH later on this tutorial, create a user the `devops` username:

```
adduser devops
```

Make the user a sudoer:

```
adduser devops sudo
```

Allow access through SSH with the company’s RSA key, available at [Bitwarden](https://vault.birwarden.com/):

```
su - devops
mkdir --mode=0700 ~/.ssh
echo "ssh-rsa [..] user@hostname" > ~/.ssh/authorized_keys
```

Make sure that you can acess through SSH with your usual key and that you can use sudo.

## OpenSSH

Edit the `/etc/ssh/sshd_config` file and make the following changes:

```
# Port 22
# Listen on port 2231 for external connections and port 22 for internal connections
ListenAddress 88.99.93.182:2231
ListenAddress 192.168.1.11:22

PermitRootLogin prohibit-password
PasswordAuthentication no
X11Forwarding no
AllowTcpForwarding yes
AllowAgentForwarding no
AuthorizedKeysFile .ssh/authorized_keys
```

Use port 2231 for `proxmox1` , 2232 for `proxmox2` , 2233 for `proxmox3` , and so on, and use the corresponding public IP address of each server.

Use port 22 on the corresponding private IP address of each server (e.g., `192.168.1.11/24` ) to let the Proxmox VE establish an SSH tunnel among nodes.

> TCP Forwarding is required when migrating VMs

Check for errors in the configuration before restarting the service:

```bash
sshd -t
```

Restart the *OpenSSH* service:

```bash
systemctl restart sshd
```

You can check that the OpenSSH service is now listening at the 2231 port (only on the public IP address) with this command:

```bash
netstat --program -all --numeric | grep --word-regexp LISTEN
```

Optionally, configure your local `.ssh/config` file as follows:

```ssh
Host proxmox1
    ControlMaster auto
    User root
    Hostname proxmox1.andromedant.com
    Port 2231
    IdentityFile ~/.ssh/id_rsa

Host proxmox2
    ControlMaster auto
    User root
    Hostname proxmox2.andromedant.com
    Port 2232
    IdentityFile ~/.ssh/id_rsa

[..]
```
Check that you can now connect to the server via SSH on port 2231 before exiting the current session on the default port.

## Fail2Ban on OpenSSH

**TO-DO:** Update this with the up-to-date version available in the [[Installation of a Proxmox Backup Server on Hetzner]] document.

This software offers protection against so-called brute force attacks. The IP address of the user is blocked for a certain period of time after several incorrect passwords have been entered. This is to prevent the attacker from trying out a large password list in a short time.

Install the `fail2ban` package:

```
apt-get install fail2ban
```

Enable the service:

```
systemctl enable fail2ban
```

Create a configuration file from one the given templates:

```
cp --archive /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

Edit the `/etc/fail2ban/jail.local` and make the following changes in the `[sshd]` section:

```
port = 2231
```

Restart the service to apply the changes:

```
systemctl restart fail2ban
```

# Proxmox

Proxmox will be installed on top of the existing Debian installation, which currently has a single, public IPv4 and IPv6 address with a MAC address.

## Packages and installation

Add the Proxmox repository to `/etc/apt/sources.list.d/` and its key to `/etc/apt/trusted.gpg.d/`:

```bash
echo "deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
wget http://download.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg
```

Since Proxmox includes its own firmware, installed packages should automatically be removed when installing `pve-firmware` and `pve-edk2-firmware`, which are dependencies of `proxmox-ve`. Example of packages that should be automatically removed:

* `firmware-bnx2x`
* `firmware-realtek`
* `firmware-linux-free`

Update the packages information and install Proxmox:

```bash
apt-get update
apt-get install proxmox-ve open-iscsi mailutils zfsutils-linux
```

Note: `proxmox-ve` installs `postfix` as a dependency. For now, configure Postfix as *local only* and leave the *system mail name* as is (e.g. `proxmox1.andromedant.com`). In the future, when instlaling Proxmox Mail Gateway, all Postfix installations will be configured as *satellite systems*, using it as relayhost.

Note: `proxmox-ve` has `ifupdown2` as dependency, which will uninstall `ifupdown`. This may cause losing connection for a minute or so, from the moment the current `ifupdown` is removed package until the new `ifupdown2` package is set up (which restarts the network configuration).

Reboot the system.

The new Proxmox VE kernel should be automatically selected in the GRUB menu. If you want to check the GRUB entries before rebooting, use the following command:

```
awk -F\' '/menuentry / {print $2}' /boot/grub/grub.cfg
```

If you want to check the new kernel version after reboot, use the following command:

```
uname --all
```

Check that the `kvm` kernel module has been loaded:

```
lsmod | grep kvm
```

If the module has not been loaded, do it manually. For Intel CPUs:

```
modprobe kvm
modprobe kvm_intel
```

For AMD CPUs:

```
modprobe kvm
modprobe kvm_amd
```

Check that the `os-prober`, an utility to detect other OSes on a set of drives, is not installed:

```
dpkg --list os-prober
```

If it is, uninstall it:

```
apt-get purge os-prober
```

Optionally, remove the Debian kernels, which we will not be using anymore:

```
apt-get purge linux-image-amd64 'linux-image-5.10*'
```

GRUB configuration can be updated and checked afterwards:

```
update-grub
```

Disable the PVE Enterprise repository that has been added by the Proxmox packages:

```bash
rm /etc/apt/sources.list.d/pve-enterprise.list
```

The enterprise repository is usually behind the community one, so run one last update of the list of packages and upgrade them to their latest versions:

```
apt-get update
apt-get dist-upgrade
```

Finally, clean the downloaded packages:

```
apt-get clean
```

And, depending on which packages were upgraded last, perform one final reboot:

```
reboot
```

## Fail2Ban on Proxmox WebGUI

We are going to use Fail2Ban to protect access to Proxmox’s web interface as well. In order to do that, we are going to add the following options at the bottom of our existing `/etc/fail2ban/jail.local` file, which we created before to secure access through SSH:

```
[proxmox]
enabled = true
port = 8006
filter = proxmox
logpath = %(syslog_daemon)s
maxretry = 3
bantime = 3600
```

Note: `syslog_daemon` is defined in `/etc/fail2ban/paths-debian.conf` as an alias to `/var/log/daemon.log`.

And we are also going to create the file `/etc/fail2ban/filter.d/proxmox.conf` with the following content:

```
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
```

Vanilla Debian Bullseye uses [nftables](https://wiki.debian.org/nftables) by default, but Proxmox 7 still uses *iptables*. Since Fail2Ban uses *iptables* by default, we will not need to instruct it to use *nftables* instead of *iptables*. Anyhow, if we were in need to do so, we would by editing the file `/etc/fail2ban/jail.d/defaults-debian.conf` and adding the following code at the beginning:

```
[DEFAULT]
banaction = nftables-multiport
banaction_allports = nftables-allports
```

And restart the service for the changes to take effect:

```
systemctl restart fail2ban
```

You can use `fail2ban-client` to check the status of the jail:

```
~$ fail2ban-client status proxmox
Status for the jail: proxmox
|- Filter
|  |- Currently failed: 2
|  |- Total failed:     5
|  `- File list:        /var/log/daemon.log
`- Actions
   |- Currently banned: 0
   |- Total banned:     0
   `- Banned IP list:
```

You can use `fail2ban-regex` to test the filter:

```
~$ fail2ban-regex /var/log/daemon.log /etc/fail2ban/filter.d/proxmox.conf 

Running tests
=============

Use   failregex filter file : proxmox, basedir: /etc/fail2ban
Use         log file : /var/log/daemon.log
Use         encoding : UTF-8


Results
=======

Failregex: 0 total

Ignoreregex: 0 total

Date template hits:
|- [# of hits] date format
|  [206] {^LN-BEG}(?:DAY )?MON Day %k:Minute:Second(?:\.Microseconds)?(?: ExYear)?
`-

Lines: 206 lines, 0 ignored, 0 matched, 206 missed
[processed in 0.01 sec]

Missed line(s): too many to print.  Use --print-all-missed to print all 206 lines
```

You can check the `nftables` rules status with the following command:

```
nft list table inet f2b-table
```

The table is dynamic, so it may not exist at the time the command is executed:

```
Error: No such file or directory
```

You can list the existing tables with the following command:

```
nft list tables
```

Note: `f2b-table` table is defined in `/etc/fail2ban/action.d/nftables.conf`.

# Proxmox network configuration

This section elaborates from the ground up on different ways of configuring the network in a Proxmox cluster until reaching the final configuration used in the production servers on Hetzner’s data centers using vSwitches.

Proxmox installs `ifupdown2` as a dependency, thus it is convenient to purge the previously used, default `ifupdown` package:

    dpkg --purge ifupdown

Make sure that the `networking` service stays enabled after purging the `ifupdown` package:

    systemctl enable networking

## Nameservers

The *Proxmox Virtual Environment* expects to manage the DNS and will no longer take its DNS settings from `/etc/network/interfaces`. Any package that auto-generates (overwrites) `/etc/resolv.conf` will cause the DNS to fail, so make sure that `resolvconf` and `rdnssd` are not installed:

```
dpkg --list | grep -e resolvconf -e rdnssd
```

Also note that the default Debian installation left by [Hetzner’s Installimage](https://docs.hetzner.com/robot/dedicated-server/operating-systems/installimage/) statically sets Hetzner’s nameservers in the `/etc/resolv.conf` file:

```
### Hetzner Online GmbH installimage
# nameserver config
nameserver 185.12.64.1
nameserver 2a01:4ff:ff00::add:2
nameserver 185.12.64.2
nameserver 2a01:4ff:ff00::add:1
```

## Bridged vs routed setup

Proxmox allows the network to be configured either in bridged or routed mode.

If we were to have just one node, with one public IP address (the one provided with the host) and LXC with private IP addresses (e.g. 192.168.0.0/24), we would be using a routed setup and use NAT and masquerading to allow traffic in and out of our LXC.

But our final design using vSwitches will be done using the bridged mode due to the following advantages:

1.  The host is transparent and not part of the route.
2.  Guests can directly communicate with the gateway of the assigned IP address.

With just one node using the bridged mode, we would be requesting Hetzner for additional public IP addresses to be configured in the LXC’s virtual network interfaces. This would be the example configuration of the file `/etc/network/interfaces` on the `proxmox1` host:

```conf
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
iface lo inet6 loopback

iface eno1 inet manual
iface eno1 inet6 manual

auto vmbr0
iface vmbr0 inet static
    address 88.99.93.182/24
    hwaddress b4:2e:99:cd:03:fd
    gateway 88.99.93.129
    pointopoint 88.99.93.129
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-disable-mac-learning 1

iface vmbr0 inet6 static
    address 2a01:4f8:10a:1def::2/64
    hwaddress b4:2e:99:cd:03:fd
    gateway fe80::1
    pointopoint fe80::1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-disable-mac-learning 1
```

As per the [Hetzner's network configuration on Debian-based systems documentation](https://docs.hetzner.com/robot/dedicated-server/network/net-config-debian-ubuntu/), a point-to-point configuration needs to be used. This is because the main IP of the dedicated server is usually located in a /26 or /27 subnet and this mechanism prevents the accidental use of a foreign IP address (their infrastructure rejects any Ethernet packets that are not addressed to the gateway address).

Regarding IPv4 and IPv6 mixed configurations, we are omitting entries in the IPv6 that are already present in the IPv4 configuration so that they are not duplicated.

We would have to restart the networking service for the new configuration to take effect:

```
systemctl restart networking
```

Then guests would be configured with one network device using the `vmbr0` bridge and the additional public IP address, network and gateway provided by Hetzner.

Make a copy of this simple configuration with just a `vmbr0` bridge for future reference:

```bash
cp /etc/network/interfaces /etc/network/interfaces.vmbr0
```

## Virtual LAN setup

There are two ways to set up the necessary bridges in each host:

-   VLAN-aware bridges.
-   Linux traditional bridges.

When using VLAN-aware bridges:

* The host has just one bridge (`vmbr0`), who is aware (via the `vlan-aware` and `vlan-vids` options) of all the configured VLANs.  
* The host's bridge does not check the packages travelling through it, as it is the kernel's reponsibility (at the guest's side) to add the proper VLAN tag to each package.  
* Each guest's virtual network card is assigned to the host's only bridge (`vmbr0`).
* Each guest's virtual network card is assigned a VLAN tag, which is transparently supported by the host bridge.

When using traditional bridges:

* The host has one VLAN interface and one bridge for each VLAN tag.  
* Each guest's virtual network card is assigned a specific bridge from the host, but no VLAN tag is associated.  
* The VLAN tag is added by the bridge at the host.

We are going to use traditional bridges on the host due to the following reasons:

1. Each bridge can have a specific, self-explanatory name (private, public, etc.) that helps prevent human errors when configuring guests.
2. The VLAN tag is assigned by the bridge at the host, thus making sure that all traffic going through that bridge is properly tagged.
3. Future migrations between virtualisation platforms should be easier to automate.

### Transparent bridges

Example configuration with VLAN-aware, transparent bridges, for reference:

    auto lo
    iface lo inet loopback

    iface eno1 inet manual

    auto vmbr0
    iface vmbr0 inet static
            hwaddress b4:2e:99:cd:03:fd
            address 88.99.93.182/24
            gateway 88.99.93.129
            pointtopoint 88.99.93.129
            bridge-ports eno1
            bridge-stp off
            bridge-fd 0
            bridge-disable-mac-learning 1
            bridge-vlan-aware yes
            bridge-vids 4001 4002 4003
    # Proxmox host

    auto vmbr0.4003
    iface vmbr0.4003 inet static
            address 192.168.1.11/24
            mtu 1400
    # Proxmox hosts private network

### Traditional bridges

Example configuration with traditional Linux bridges, for reference:

    auto lo
    iface lo inet loopback

    iface eno1 inet manual

    auto vmbr0
    iface vmbr0 inet static
            hwaddress b4:2e:99:cd:03:fd
            address 88.99.93.182/24
            gateway 88.99.93.129
            pointtopoint 88.99.93.129
            bridge-ports eno1
            bridge-stp off
            bridge-fd 0
            bridge-disable-mac-learning 1
    # Proxmox host

    auto vmbr4001
    iface vmbr4001 inet manual
            bridge-ports eno1.4001
            bridge-stp off
            bridge-fd 0
            mtu 1400
    # Proxmox guests public network

    auto vmbr4002
    iface vmbr4002 inet static
            bridge-ports eno1.4002
            bridge-stp off
            bridge-fd 0
            mtu 1400
    # Proxmox guests private network 192.168.0.0/24

    auto vmbr4003
    iface vmbr4003 inet static
            address 192.168.1.11/24
            bridge-ports eno1.4003
            bridge-stp off
            bridge-fd 0
            mtu 1400
    # Proxmox hosts private network 192.168.1.0/24

## Final network configuration

The network configuration we will be finally applying to the hosts will have three diferences:

1.  It will not use bridge `vmbr4003` but instead a VLAN, so that it cannot be selected on the containers when these are being configured.
2.  It will not use bridge `vmbr0` but instead the default network interface `eno1`, so that it cannot be selected on the containers when these are being configured.
3.  It will have an additional network interface to act as gateway for the guests that only have a private IP address.

```conf
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto eno1
iface eno1 inet static
    hwaddress b4:2e:99:cd:03:fd
    address 88.99.93.182/24
    gateway 88.99.93.129
    pointopoint 88.99.93.129
# Proxmox host

iface eno1.4001 inet manual
    mtu 1400

auto vmbr4001
iface vmbr4001 inet manual
    bridge-ports eno1.4001
    bridge-stp off
    bridge-fd 0
    mtu 1400
    bridge-disable-mac-learning 1
# Proxmox guests public network

iface eno1.4002 inet manual
    mtu 1400

auto vmbr4002
iface vmbr4002 inet static
    bridge-ports eno1.4002
    bridge-stp off
    bridge-fd 0
    mtu 1400
# Proxmox guests private network 192.168.0.0/24

auto eno1.4003
iface eno1.4003 inet static
    address 192.168.1.11/24
    vlan-raw-device eno1
    mtu 1400
# Proxmox hosts private network 192.168.1.0/24
```

We need to restart the system for the changes to take effect:

```
reboot
```

## Web interface

Given that we’ll be using the `root` user credentials to access the web interface, first of all make sure that the `root` use has a (strong) password:

```
passwd
```

> Use Bitwarden's password generator to create a new password and store the credentials there as well.

Access the web interface available at https://proxmox1.andromedant.com:8006/ by using the `root` user credentials and the `PAM authentication` mechanism. You will have to accept the self-signed certificate as valid.

To check the existing network configuration, in the left pane, select the `proxmox1` node and, in the main view, go to the `System: Network` menu option.

> Two-Factor Authentication (2FA) will be set up once the cluster has been created and the nodes have been added.

## Certificates for the hosts

> This section only applies the first time a new cluster is configured. Skip it when adding a new node to an existing cluster.

By default, Proxmox [installs a self-signed certificate](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysadmin_certificate_management). We will be using [Let’s Encrypt](http://letsencrypt.org/) through the [ACME protocol](https://datatracker.ietf.org/doc/html/rfc8555) (Automatic Certificate Management Environment) to obtain a valid certificate for the node, which will be renewed automatically by Proxmox from then onwards.

### Account

First of all, at the first server (not yet a node since we have not created the cluster yet) we will configure the account, then the challenge plug-in. Using the WebGUI, at the `Datacenter` node, go to the `ACME` menu option and add the account using the button on the top. All that’s needed is a name (e.g. Andromeda) and an email (e.g. `sysadmin@andromedant.com`).

### Challenge plug-in

The default challenge plugin is HTTP, which is already installed. For it to work, the following conditions must be met:

-   Port 80 of the node needs to be reachable from the internet (i.e. firewall rule needs to be added).
-   There must be no other listener on port 80.
-   The requested (sub)domain needs to resolve to the public IP of the node.

We will be adding an additional challenge using DNS by using the button labelled “Add” right below the “Challenge Plugins” section:

-   Plugin id: cloudflare
-   Validation delay: 30
-   DNS API: Cloudflare Managed DNS
-   Account id: \[..\]
-   Token: \[..\]
-   Zone id: \[..\] (not necessary in theory)

The account id and zone id can be copied from the bottom right corner of the `andromedant.com` domain overview page at [Cloudflare’s dashboard](https://dash.cloudflare.com/). The API token can be obtained (with finegrained permissions) at the [API Tokens menu option](https://dash.cloudflare.com/profile/api-tokens) of the user’s profile.

### Issuing the certificate

Then at the node level, go to the `System: Certificates` menu option and, in the `ACME` section, use the “Add” button to add the certificate request data:

-   Challenge type: DNS
-   Plug-in: cloudflare
-   Domain: proxmox1.andromedant.com

Choose the account by clicking the `Edit` button next to the “Using account” label, select the account created before and click `Apply`. Finally, click the `Order Certificates Now` button.

The process will place the order, which will consist of:

1.  Validating the ownership of the domain.
2.  Sending the CSR (certificate request)
3.  Waiting for the certificate to be issued.
4.  Installing the certificate and restarting the PVE Proxy.

Proxmox will take care of renewing the certificate automatically.

Unfortunately, wildcard certificates cannot be issued through the user interface so we will have to repeat the process for each node once it’s become part of the cluster.

## Creating the cluster

> This section only applies the first time a new cluster is configured. Skip it when adding a new node to an existing cluster.

Before creating the cluster we are going to run through the following steps.

1.  Create the virtual switches and add the servers to them
2.  Change the file `/etc/hosts` to resolve each node to its local IP address.
3.  Make OpenSSH listen on the local IP address of the node.
4.  Make sure that the nodes can ping each other.
5.  Make sure that no guests exist in the servers yet.
6.  Make sure that the firewall is disabled at the datacentre level.
7.  Make sure 2FA is not enabled for the root user.

### Creating the vSwitches

Log into the [Hetzner's accounts page](https://accounts.hetzner.com/), then navigate to the [Hetzner's robot page](https://robot.your-server.de/), then navigate to the [servers list](https://robot.hetzner.com/server). Click on the `vSwitches` button on the menu section and create the following three virtual switches:

| Name                           | VLAN id     | Notes                                                                           |
|--------------------------------|-------------|---------------------------------------------------------------------------------|
| Proxmox guests public network  | 4001        | Currently 116.202.120.32/28 and 49.13.106.48/28                                 |
| Proxmox guests private network | 4002        | 192.168.0.0/24, starting at 100 and using the id assigned by Proxmox to the LXC |
| Proxmox hosts private network  | 4003        | 192.168.1.0/24, starting at 11 and incrementing by one                          |

Then add the three servers to each vSwitch.

### Modifying the mapping of the hostnames

> This section applies both the first time a new cluster is configured and when a new node is added to an existing cluster.

On each server, already in the cluster or being added to it, edit the file `/etc/hosts` and change the mapping of the hostnames to the private IP addresses of all the hosts:

```
# IPv4
127.0.0.1 localhost.localdomain localhost

# 88.99.93.182  proxmox1.andromedant.com  proxmox1
# 46.4.119.240  proxmox2.andromedant.com  proxmox2
# 78.46.88.45   proxmox3.andromedant.com  proxmox3
# 178.63.0.104  proxmox4.andromedant.com  proxmox4
# 95.216.23.53  proxmox5.andromedant.com  proxmox5
# 178.63.41.48  proxmox6.andromedant.com  proxmox6
# 159.69.66.197 proxmox7.andromedant.com  proxmox7
# 46.4.84.154   proxmox8.andromedant.com  proxmox8
# 162.55.95.85  proxmox9.andromedant.com  proxmox9
# 95.216.246.50 proxmox10.andromedant.com proxmox10

192.168.1.9  pbs2.andromedant.com      pbs2
192.168.1.11 proxmox1.andromedant.com  proxmox1
192.168.1.12 proxmox2.andromedant.com  proxmox2
192.168.1.13 proxmox3.andromedant.com  proxmox3
192.168.1.14 proxmox4.andromedant.com  proxmox4
192.168.1.15 proxmox5.andromedant.com  proxmox5
192.168.1.16 proxmox6.andromedant.com  proxmox6
192.168.1.17 proxmox7.andromedant.com  proxmox7
192.168.1.18 proxmox8.andromedant.com  proxmox8
192.168.1.19 proxmox9.andromedant.com  proxmox9
192.168.1.20 proxmox10.andromedant.com proxmox10

# IPv6
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts

# 2a01:4f8:172:1729::2 pbs2.andromedant.com      pbs2
# 2a01:4f8:10a:1def::2 proxmox1.andromedant.com  proxmox1 
# 2a01:4f8:141:20c2::2 proxmox2.andromedant.com  proxmox2 
# 2a01:4f8:120:211f::2 proxmox3.andromedant.com  proxmox3 
# 2a01:4f8:201:432e::2 proxmox4.andromedant.com  proxmox4 
# 2a01:4f9:2a:174e::2  proxmox5.andromedant.com  proxmox5 
# 2a01:4f8:120:2416::2 proxmox6.andromedant.com  proxmox6
# 2a01:4f8:231:1215::2 proxmox7.andromedant.com  proxmox7
# 2a01:4f8:141:6206::2 proxmox8.andromedant.com  proxmox8
# 2a01:4f8:271:281e::2 proxmox9.andromedant.com  proxmox9
# 2a01:4f9:2b:284a::2  proxmox10.andromedant.com proxmox10
```

### Testing connectivity

From each node we should be able to ping the other two nodes via the 192.168.1.0/24 network.

### Cluster creation

The cluster will be created on the first node, then the second and third nodes will join it.

To create a cluster go to “Datacenter: Cluster” and click on “Create cluster”. Use this information:

* Cluster name: Andromeda
* Cluster network: choose the node private address 192.168.1.11 from the list

Hit “Create” and wait for the process to finish. After that, use the “Join information” button to get the necessary information for the other two servers:

* IP address: 192.168.1.11
* Join information: eyJpcEF \[..\]

Hint: Use the “Copy information” button to ease the process.

Go to any of the other servers, navigate to `Datacenter: Cluster` and click the `Join cluster` button. Paste the just-copied information and insert these values:

* Password: <password of the root user on the proxmox1 node>
* Cluster network: choose the node private address 192.168.1X from the list

We will see the node being added at the existing cluster (i.e. `proxmox1` ) and we will be losing connection to the server we were adding as a new node, so we will have to refresh the page. We will be getting a security warning due to the change in the certificate.

\> Note: If we are adding a node to an existing cluster, we will lose connection via SSH to port 223X until we add the firewall rule at the node level.

### Additional certificates

Via the WebGUI of the `proxmox1` server, navigate to the second (`proxmox2`) node, go to `System: Certificates` and follow these steps to issue the certificates for these two new nodes:

1.  Click on the `Edit` button next to the `Using account` label.
2.  Select the previously created account (e.g. `sysadmin` ) and click the `Apply` button.
3.  Click the `Add` button and follow the steps described above in this tutorial.

> Note: If the API Token from Cloudflare is filtered by IP address, when adding a new node to the cluster we are going to have to add the new public IP address of the node before attempting to issue the certificate. Otherwise we won’t be able to set the DNS record of type TXT that is required by Let’s Encrypt.

### Activate 2FA

Go to the menu option “Datacenter: Users: Two Factor” and click the button “Add: TOTP”. Follow the usual steps.

Note: For it to work it requires the exact same software versions on all nodes.

## Firewall

We are going to use two firewalls, Proxmox’s and Hetzner’s.

### Proxmox’s Firewall

We are going to do a basic configuration of the cluster firewall using the web interface.

Proxmox 7 on Debian Bullseye uses `iptables`. By default, the firewall is disabled at the datacenter and VM levels and enabled at node level. We can check this by going to the `Datacenter: Firewall: Options` menu option.

When the firewall is disabled at datacenter level, even if it is enabled at node level, it will stay disabled until it is enabled both at datacenter and node level. Likewise, to be able to enable the firewall for a given VM, we must first enable the firewall both at the datacenter and node levels.

The default policies are to accept all outgoing traffic and drop all incoming traffic.

IP aliases allow us to associate a network or IP addresses to a name. IP sets allow us to associate a number of IP addresses or networks to a name. Both are used to make firewall management easier. IPv4 and IPv6 aliases are added separately at the `Datacenter: Firewall : Alias` menu option. We will be creating:

- One IP alias for the private network of the nodes.
- One IP alias per node.
- One IP alias per private network range.
- An alias for the Storage Box.

| Name                 | IP/CIDR        | Comment                       |
|----------------------|----------------|-------------------------------|
| ipv4_private_hosts   | 192.168.1.0/24 | Hosts private network         |
| ipv4_public_proxmox1 | 88.99.93.182   | Proxmox 1 public IPv4 address |
| ipv4_public_proxmox2 | 46.4.119.240   | Proxmox 2 public IPv4 address |
| ipv4_public_proxmox3 | 78.46.88.45    | Proxmox 3 public IPv4 address |
| ipv4_public_proxmox4 | 178.63.0.104   | Proxmox 4 public IPv4 address |
| ipv4_public_proxmox5 | 95.216.23.53   | Proxmox 5 public IPv4 address |
| ipv4_public_proxmox6 | 178.63.41.48   | Proxmox 6 public IPv4 address |
| ipv4_public_proxmox7 | 159.69.66.197  | Proxmox 7 public IPv4 address |
| ipv4_public_proxmox8 | 46.4.84.154    | Proxmox 8 public IPv4 address |
| ipv4_link_local_169  | 169.254.0.0/16 | RFC3927                       |
| ipv4_private_10      | 10.0.0.0/8     | RFC1918                       |
| ipv4_private_172     | 172.16.0.0/12  | RFC1918                       |
| ipv4_private_192     | 192.168.0.0/16 | RFC1918                       |
| ipv4_shared_100      | 100.64.0.0/10  | RFC6598                       |
| ipv4_your_storage_de | 185.53.177.54  | your-storage.de backup space  |

Using the `Datacenter: Firewall: IPSet` menu option we will be creating:

- One IPSet for the private networks
- One IPSet for Hetzner’s System Monitor
- One IPSet for the cluster nodes public addresses, using the alias we created before

| Name                | Comment                     | Aliases                                                                                   |
|---------------------|-----------------------------|-------------------------------------------------------------------------------------------|
| ipv4_private        | IPv4 private networks       | IPv4_Link_Local_169, IPv4_Private_10, IPv4_Private_172, IPv4_Private_192, IPv4_Shared_100 |
| ipv4_hetzner_sysmon | Hetzner’s System Monitor    | 188.40.24.211, 213.133.113.82, 213.133.113.83, 213.133.113.84, 213.133.113.86             |
| ipv4_public_hosts   | IPv4 hosts public addresses | ipv4_public_proxmox1, ipv4_public_proxmox2, ipv4_public_proxmox3, ipv4_public_proxmox4    |

If we enable the firewall, traffic to all hosts is blocked by default, with the only exceptions being the web interface (WebGUI) on port 8006 and the secure shell (OpenSSH) on port 22, but only from the local network.

At the moment, after installation, we will have the following ports open in all hosts:

| Service            | Description                                                                                  | Port       | Protocols     | Interface       |
|--------------------|----------------------------------------------------------------------------------------------|------------|---------------|-----------------|
| WebGUI             | Web interface                                                                                | 8006       | TCP           | All interfaces  |
| SPICE proxy        | [Simple Protocol for Independent Computing Environments](https://pve.proxmox.com/wiki/SPICE) | 3128       | TCP           | All interfaces  |
| SSH                | Secure Shell                                                                                 | 22         | TCP           | All interfaces  |
| rpcbind            |                                                                                              | 111        | TCP and UDP   | All interfaces  |
| smtp               | Simple Mail Transfer Protocol                                                                | 25         | TCP           | Local interface |
| pvedaemon          | Proxmox VE API Daemon                                                                        | 85         | TCP           | Local interface |
| corosync multicast | [Corosync Cluster Network](https://pve.proxmox.com/wiki/Cluster_Manager)                     | 5404, 5405 | UDP           | Private IP      |

In short, we are going to use the PVE Firewall to set up rules as follows:

| Level      | Type     | Action     | Macro     | Interface     | Protocol     | Source               | Source port     | Destination        | Destination port     | Log level     | Comment                                      |
|------------|----------|------------|-----------|---------------|--------------|----------------------|-----------------|--------------------|----------------------|---------------|----------------------------------------------|
| Datacentre | in       | ACCEPT     | Ping      |               |              | +ipv4_hetzner_sysmon |                 | +ipv4_public_hosts |                      | nolog         | Allow ping from Hetzner’s SysMon             |
| Datacentre | in       | ACCEPT     | Ping      |               |              | ipv4_private_hosts   |                 | ipv4_private_hosts |                      | nolog         | Allow ping among nodes                       |
| Datacentre | in       | ACCEPT     |           |               | tcp          |                      |                 |                    | 8006                 | nolog         | Allow inbound traffic to WebGUI on all hosts |

We do not require allowing SSH traffic among nodes because that is automatically set by the PVE Firewall.

At each node we will be adding the following rule via `Datacenter: Node (e.g. proxmox1): Firewall`:

| Level     | Type     | Action     | Macro     | Interface     | Protocol     | Source     | Source port     | Destination     | Destination port     | Log level     | Comment                           |
|-----------|----------|------------|-----------|---------------|--------------|------------|-----------------|-----------------|----------------------|---------------|-----------------------------------|
| Node      | in       | ACCEPT     |           |               | tcp          |            |                 |                 | 2231                 | nolog         | Allow inbound SSH traffic to node |

Port will start at 2231 for the first node `proxmox1` and increment in one on each node.

Open a SSH connection to one of your Proxmox VE hosts before enabling the firewall so that you still have access to the host if something goes wrong, then enable the firewall at the datacentre level by using the `Datacenter: Firewall: Options: Firewall` menu option.

> Note: If we are adding a node to an existing cluster, we will lose connection via SSH to port 223X until we add the firewall rule at the node level.

From here more firewall rules will be added at the LXC level to allow access to specific services from specific locations, such as 27017 for MongoDB, 5432 for PostgreSQL, etc.

### Hetzner’s Firewall

[Hetzner’s firewall](https://docs.hetzner.com/robot/dedicated-server/firewall/) only takes care of incoming traffic and its rules are processed before the packets arrive at our Proxmox installation, including the packets that travel through the vSwitches (VLAN), including the public IP subnet. It is a secondary layer of protection but it does not protect against DDoS attacks. For that, Hetzner offers an [automated tool](https://www.hetzner.com/unternehmen/ddos-schutz), which is always active and included with the server fees.

The number of rules are limited to 10. Rule *number 11* is to drop all incoming traffic (not allowed before). Since we have all sorts of traffic among our hosts and guests, and the Internet, we are going to be more generalistic here:

| Host     | #  | Name                 | Source IP      | Destination IP    | Source port | Destination port | Protocol | TCP flags | Action |
|----------|----|----------------------|----------------|-------------------|-------------|------------------|----------|-----------|--------|
| proxmox1 | 1  | Ping                 |                |                   |             |                  | icmp     |           | accept |
| proxmox1 | 2  | Proxmox WebGUI       |                |                   |             | 8006             | tcp      |           | accept |
| proxmox1 | 3  | OpenSSH              |                |                   |             | 2231-2240        | tcp      |           | accept |
| proxmox1 | 4  | HTTP                 |                |                   |             | 80,443           | tcp      |           | accept |
| proxmox1 | 5  | Proxmox hosts        | 192.168.1.0/24 | 192.168.1.0/24    |             |                  |          |           | accept |
| proxmox1 | 6  | Proxmox guests       | 192.168.0.0/24 | 192.168.0.0/24    |             |                  |          |           | accept |
| proxmox1 | 7  | Public subnet        |                | 116.202.120.32/28 |             |                  |          |           | accept |
| proxmox1 | 8  | Ephemeral port range |                |                   |             | 32768-65535      | tcp      | ack       | accept |

The only actual difference is the OpenSSH port, which changes among hosts.

To ease management, a template can be added via the menu option [Servers: Firewall templates](https://robot.your-server.de/firewall/templateIndex) in the *Your Robot* control panel. Once the template has been created, it can be selected and applied via the \_Firewall” option of each server.

**Note:** In the ruleset above all traffic to the public IP addresses is allowed, which means it’s only filtered by the [PVE Firewall](https://pve.proxmox.com/wiki/Firewall). Once all the services in the cluster have been set up it may be a good idea to revisit rule number 7.

# ZFS pool

Each node of the cluster should have a pair of SSD disks, set up with RAID 1 upon installation, that hold the operating system and offer space for containers as well. Moreover, if they have additional HDD or SSD we can set a ZFS pool on them and use it for LXC to benefit from the extra features that this filesystem offers.

First of all, we need to install the ZFS utils in the server:

```bash
apt-get install zfsutils-linux
```

Then load the ZFS kernel module:

```
modprobe zfs
```

We are now ready to navigate to the Disks: ZFS menu option of the node with the spare disks in the WebGUI and click on the “Create ZFS” button and fill in the necessary details:

* Name: `zfspool`
* RAID level: Mirror
* Compression: on
* ashift: 12

Select the two disks from the list below and click the “Create” button. If you left the “Add storage” checkbox ticked, you will also get it added to the Proxmox VE Storage, available at “Datacenter: Storage”.

## Disk is busy when creating the ZFS pool

In case that the WebGUI shows an error when creating the ZFS pool such as “disk has a holder” or “disk is busy”, use the following commands to wipe the disk clean:

```bash
$ sgdisk --zap-all /dev/sdX
$ readlink /sys/block/sdX
../devices/pci0000:00/0000:00:01.1/0000:01:00.0/host5/port-5:10/end_device-5:10/target5:0:10/5:0:10:0/block/sdx
$ echo 1 > /sys/block/sdX/device/delete
$ echo "- - -" > /sys/class/scsi_host/host5/scan
```

Where `host5` in the last command is taken from the result of the `readlink` command.

Reference: https://forum.proxmox.com/threads/sda-has-a-holder.97771/

# LXC containers

Containers are a lightweight alternative to fully virtualized machines (VMs). They use the kernel of the host system that they run on, instead of emulating a full operating system (OS). Check the [Linux Container wiki page](https://pve.proxmox.com/wiki/Linux_Container) on the Proxmox website.

## Installing a LXC container

We are going to use the base Debian Bullseye 11 template provided by Proxmox and install services on top of it. First of all, we need to upload the template to the node where we will be creating our guest. For that, follow these steps:

1.  On the menu, go to any Proxmox node, then select the “local” storage.
2.  On the submenu, go to “CT Templates”.
3.  Click on the “Templates” button.
4.  In the listing, filter by “bullseye”, select the “debian-11-standard” package and lick “Download”.

This process needs to be repeated for each node of the cluster so that the template is available when selecting such node when creating a container.

The next step in the initial setup is to create a pool, which we will use to group a set of virtual machines and data stores to then set permissions on, which will be inherited by all pool members. Follow these steps:

1.  On the menu, go to the “Datacenter” node.
2.  On the submenu, go to Permissions: Pools.
3.  Click on the “Create” button.
4.  In the form, add a name (e.g. “sysadmins”) and a comment (e.g. “System Administrators”).

These steps only need to be done once.

Now each time we want to create a new Linux Container (LXC), we will use the “Create CT” button on the top bar.

## Networking

As described at the beginning of this document, our LinuX Containers (LXC) will all have a first network device with a private IP address, configured as follows:

-   ID: net0
-   Name: eth0
-   MAC address: leave empty for a random one to be automatically generated
-   Bridge: vmbr4002
-   VLAN tag: no VLAN
-   Rate limit (MB/s): unlimited
-   IPv4: Static
-   IPv4/CIDR: 192.168.0.<ctid>/24
-   Gateway (IPv4): 192.168.0.13 (if needed)

Those containers that require a public IP address will have an additional network device, configured as follows:

-   ID: net1
-   Name: eth1
-   MAC address: leave empty for a random one to be automatically generated
-   Bridge: vmbr4001
-   VLAN tag: no VLAN
-   Rate limit (MB/s): unlimited
-   IPv4: Static
-   IPv4/CIDR: 116.202.120.32/28 subnet
-   Gateway (IPv4): 116.202.120.33

# Postfix

The nodes of the PVE (PRoxmox Virtual Environment) and PBS (Proxmox Backup Server) clusters will not be using the Proxmox Mail Gateway as relayhost or smarthost. Instead, they will be using Google's directly.

We will use the command `dpkg-reconfigure postfix` to change the initial configuration to the following:

* Configuration type: Satellite system
* System mail name: `$(hostname -f)`
* SMTP relay host: `smtp-relay.gmail.com:25`
* Root and postmaster mail recipient: sysadmin@andromedant.com
* Other destinations to accept mail for: `$(hostname -f), localhost.andromedant.com, localhost`
* Force synchronous updates on mail queue?: No
* Local networks: `127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128`
* Mailbox size limit (bytes): 0
* Local address extension character: `+`
* Internet protocols to use: all

Make sure the file `/etc/aliases` contains the following entries:

```
postmaster: root
admin: root
debian: root
root: sysadmin@andromedant.com
```

Each time the `/etc/aliases` file is changed we will need to execute the following command:

```
newaliases
```

To test that the email sent by the node is reaching its destination, we can use the `mail` command. For that, install the `mailutils` package:

```
apt-get install mailutils
```

Also make sure that no other mail package is installed, such as `bsd-mailx`:

```
apt-get purge bsd-mailx
```

Now compose and send a test email with the following command:

```
mail --subject="Test from $(hostname)" --append="From: <root@$(hostname -f)>" root@$(hostname -f) <<< "This is a test message"
```

By default, all nodes send notifications by email using the `root@$hostname` address, so we should be receiving notifications from now onward.

Finally, add the TLS options to the `/etc/postfix/main.cf`:

```
smtpd_tls_cert_file = /etc/ssl/certs/andromedant.com.crt
smtpd_tls_key_file = /etc/ssl/private/andromedant.com.key
smtpd_tls_security_level = may
smtp_tls_CAfile = /etc/ssl/certs/ISRG_Root_X1.pem
```

# Backups

Proxmox Backup Server is installed in a separate server located in a separate data center:

* FQDN: pbs2.andromedant.com
* IP address: 192.168.1.9

Add the entry in the `/etc/hosts` file of all PVE nodes:

```
192.168.1.9 pbs2.andromedant.com pbs2
```

To add the storage pool offered by the *Proxmox Backup Server* (PBS) go to `Datacenter: Storage` and click on the `Add` button and select “Proxmox Backup Server”. Use the following or similar details:

* ID: pbs2
* Server: pbs2.andromedant.com
* Username: backupuser@pbs
* Password: <password>
* Nodes: All (No restrictions)
* Enable: Yes
* Content: backup
* Datastore: `zfslocal`

Backup retention will be configured on the Proxmox Backup Server, so leave the defaults as they are.

# ZFS useful commands

Some nodes may be using a ZFS pool on additional hard drives, which is created through the `Node: Disks: ZFS: Create ZFS` menu option, using mirror RAID mode and usually named `zfspool`. Here are some useful commands to manage this pool:

List the available pools:

    # zpool list
    NAME      SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
    zfspool  3.62T  8.80G  3.62T        -         -     0%     0%  1.00x    ONLINE  -

Check the status of a pool:

    # zpool status -v
      pool: zfspool
     state: ONLINE
      scan: scrub repaired 0B in 00:03:41 with 0 errors on Mon Apr  3 06:57:14 2023
    config:

            NAME                                  STATE     READ WRITE CKSUM
            zfspool                               ONLINE       0     0     0
              mirror-0                            ONLINE       0     0     0
                ata-ST4000NM0245-1Z2107_ZC13613C  ONLINE       0     0     0
                ata-ST4000NM0245-1Z2107_ZC139JR7  ONLINE       0     0     0

    errors: No known data errors

Check for errors and other stuff:

    zpool scrub zfspool

The scrub examines all data in the specified pools to verify that it checksums correctly. For replicated (mirror, raidz, or draid) devices, ZFS automatically repairs any damage discovered during the scrub. The `zpool status` command reports the progress of the scrub and summarizes the results of the scrub upon completion.

Display the properties of a pool (a.k.a. dataset) used on a LXC, such as compression ratio and a lot more:

    zfs get all zfspool/subvol-106-disk-0

# Useful commands

List virtual machines:

    pvesh get /cluster/resources --type vm
    pvesh get /cluster/resources -type vm --output-format yaml | egrep -i 'vmid|name' | sed 's@.*:@@' | paste - - -d ""

Check cluster status:

    sudo systemctl status corosync
    sudo systemctl status pve-cluster
    sudo pvecm status

Access the terminal of a container:

    sudo pct console 100

Command reference: https://pve.proxmox.com/pve-docs/pve-admin-guide.html#chapter_pct

Temporarily change MTU in a given interface:

    sudo ifconfig eno1 mtu 1400 up

Stopping a VM:

    cat /etc/pve/.vmlist
    qm stop <vmid>

Unlock a VM:

    cat /etc/pve/.vmlist
    qm unlock <VMID>

Kill a VM to fix the timeout error when trying to stop or unlock a VM:

    cat /etc/pve/.vmlist
    ps aux | grep "/usr/bin/kvm -id <VMID>"
    kill -9 <PID>

# Change the IP address of a clustered node to a new subnet

*e.g. 192.168.1.0/24 to 192.168.2.0/24*

Stop the cluster services:

```bash
systemctl stop pve-cluster
systemctl stop corosync
```

Mount the filesystem locally:

```bash
pmxcfs -l
```

Edit the network interfaces file to have the new IP information. Be sure to replace both the address and gateway:

```bash
vi /etc/network/interfaces
```

Replace any host entries with the new IP addresses:

```bash
vi /etc/hosts
```

Change the DNS server as necessary:

```bash
vi /etc/resolv.conf
```

Edit the corosync file and replace the old IPs with the new IPs for all hosts:

```bash
# :%s/192\.168\.1\./192.168.2./g   <- vi command to replace all instances
# BE SURE TO INCREMENT THE config_version: x LINE BY ONE TO ENSURE THE CONFIG IS NOT OVERWRITTEN
vi /etc/pve/corosync.conf
```

Edit the known hosts file to have the correct IP addresses:

```bash
# :%s/192\.168\.1\./192.168.2./g   <- vi command to replace all instances
/etc/pve/priv/known_hosts
```

Fix the IP in `/etc/issue`:

```bash
vi /etc/issue
```

Verify there aren’t any stragglers with the old IP hanging around:

```bash
cd /etc
grep -R '192\.168\.1\.' *
cd /var
grep -R '192\.168\.1\.' *
```

Reboot the system to cleanly restart all the networking and services:

```bash
reboot
```

# Remove a node from the cluster

The official documentation of Proxmox describes the [procedure to remove a cluster node](https://pve.proxmox.com/wiki/Cluster_Manager#_remove_a_cluster_node). This guide includes some additional steps.

First of all, the node needs to:

1. Be empty. That is, all containers and virtual machines need to be moved to other nodes.
2. Have no replication jobs. Go to the `Replication` menu entry of the node and make sure it is empty.
3. Optionally, be offline.

Let's assume we have a cluster with 7 nodes, named `proxmox1` to `proxmox7`, and we want to remove the `proxmox5` node. You need to have SSH sessions open with both the node to be deleted (e.g., `proxmox5`) and any other node (e.g., `proxmox1`). In the `proxmox1` node, use the `pvecm nodes` command list the nodes and identify the one to be removed:

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
         6          1 proxmox6
         7          1 proxmox7
```

Remove the node from the cluster by issuing the following command:

```bash
# pvecm delnode proxmox5

Killing node 5
```

If the node was down while you issued the command, you will receive the message `Could not kill node (error = CS_ERR_NOT_EXIST)`, which can be safely ignored as it does not report an actual failure in the deletion of the node, but rather a failure in `corosync` trying to kill an offline node.

Check the node list again:

```bash
# pvecm nodes

Membership information
----------------------
    Nodeid      Votes Name
         1          1 proxmox1 (local)
         2          1 proxmox2
         3          1 proxmox3
         4          1 proxmox4
         6          1 proxmox6
         7          1 proxmox7
```

Using the SSH session in the now-removed node (e.g., `proxmox5`), shut it down:

```bash
shutdown -h now
```

Back to the `proxmox1` SSH session, remove the configuration files of the node from the cluster. Removal of the configuration directory and fingerprint of the node will automatically be replicated to the rest of nodes.

```bash
rm --recursive --force /etc/pve/nodes/proxmox5
```

At this point, a number of SSH-related files still have the fingerprint of the just-deleted node (e.g., `proxmox5` or `192.168.1.15`):

| Path to file                    | Linked by                  |
|---------------------------------|----------------------------|
| `/etc/pve/priv/known_hosts`     | `/etc/ssh/ssh_known_hosts` |
| `/etc/pve/priv/authorized_keys` | `/root/authorized_keys`    |
| `/root/.ssh/known_hosts`        |                            |

To clean it up, execute the following commands on the SSH session of the `proxmox1` node:

```
sed -i.bak '/proxmox7\|\b192.168.1.17\b/d' /etc/pve/priv/known_hosts
sed -i.bak '/proxmox7\|\b192.168.1.17\b/d' /etc/pve/priv/authorized_keys
ssh-keygen -f "/root/.ssh/known_hosts" -R "proxmox5"
ssh-keygen -f "/root/.ssh/known_hosts" -R "192.168.1.15"

```

These changes in the files inside `/etc/pve/priv/` will be replicated across the cluster. The changes in the `/root/.ssh/known_hosts` file will not.

We cannot use `ssh-keygen -R` on the files inside `/etc/pve/priv/` because there are hardlinks pointing at them and the command would fail with the following error:

```bash
# ssh-keygen -f "/etc/pve/priv/known_hosts" -R "192.168.1.17"

# Host 192.168.1.17 found: line 25
link /etc/pve/priv/known_hosts to /etc/pve/priv/known_hosts.old: Function not implemented
```

Note:

* In Proxmox 8, the link `/etc/ssh/ssh_known_hosts` no longer exists and, if it does, it can be safely removed using `pvecm updatecerts --unmerge-known-hosts`.
* If you receive an SSH error after rejoining a node with the same IP or hostname, run `pvecm updatecerts` once on each node to update its fingerprint cluster wide.

> For later reference: `ssh -e none -o 'HostKeyAlias=proxmox5' root@192.168.1.15 /bin/true`

If the node that was deleted had a ZFS pool, we need to edit the `/etc/pve/storage.cfg` file and remove the node name from the `nodes` key of the `zfspool` entry.

# Adding a new node later on

Further down the life cycle of the existing cluster, when adding a new node, we need to follow these steps after configuring the `root` user password and accessing the WebGUI:

* Add the node to the *vSwitches* `4001` , `4002` and `4003` using [Hetzner's vSwitches UI](https://robot.hetzner.com/vswitch/index).
* Edit the `/etc/hosts` file on all nodes, existing and new, to match the version above (should include all `192.168.1.0/24` static addresses, including the new node being added).
* Test connectivity among nodes, including the not-yet-added new node, on the `192.168.1.0/24` network.
* Add the public IP address of the new node to the API Token on Cloudflare, so a valid TLS certificate can be issued.
* Disable TFA in the existing cluster.
* Add the node to the cluster.
* Edit the Hetzner firewall to remove access to port 22 on the public IP address, as the traffic will now go through the VLAN of the network `192.168.1.10/24`.
* Edit the Proxmox firewall on the newly added node to allow access to the port where the SSH daemon is listening to on the public IP address, e.g., 2231, 2232, etc.

> In the new node we will neither configure the ACME account, nor issue a valid certificate, as this will all be done when in the new cluster.

## Disable 2FA

To disable the Two-Factor Authentication (2FA) in the existing cluster, log in to `proxmox1`, or any other existing node in the cluster, and run the following command:

```
mv /etc/pve/priv/tfa.cfg /etc/pve/priv/tfa.cfg.bak
```

### Join the cluster

Once the local network and the `/etc/hosts` file is properly configured, go through the usual steps:

1. In any of the existing nodes of the cluster, e.g., `proxmox1`, go to `Datacenter: Cluster` and click the `Join information` button. Use the `Copy information` button.
2. In the new node, go to `Datacenter: Cluster` and click the `Join cluster` button. Paste the information you just copied.
3. Type in the password of the `root` user from the node you used to copy the information and confirm.

A log of the steps being worked on will be displayed on a modal window, but we will not see them all. Once the new node appears in the WebGUI or console (`pvecm nodes`) of a existing node:

1. Close the browser window or tab with the WebGUI of the new node.
2. Using the WebGUI on any of the nodes, e.g., `proxmox1`, go to the `System: Certificates` in the new node and follow the steps described above in this tutorial to issue a valid certificate.
3. In a new tab or window, load the WebGUI of the new node and enter the credentials again. No error regarding an invalid certificate should appear.

## Re-enable 2FA

Now we can restore the 2FA using the console we opened before, e.g., on `proxmox1`:

```
mv /etc/pve/priv/tfa.cfg.bak /etc/pve/priv/tfa.cfg
```

## Configuration of the firewall of the new node

We need to add the firewall rule in the new node to allow access via SSH on the port we are showing to the outside world:

* Direction: `in`
* Action: `ACCEPT`
* Interface: `eno1`
* Enable: `True`
* Protocol: `tcp`
* Dest. port: `2236`
* Comment: Allow inbound SSH traffic to node

> Some nodes may use a different interface name, e.g., `enp0s31f6`. The `Interface` field can be safely left empty, as the `ssh` daemon is only listening on that port on the public IP address.
