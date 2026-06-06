# Installation of a Proxmox Backup Server

*Created on 2021-11-28. Last updated on 2024-08-23.*

We are going to set up a Proxmox Backup Server 3.e on top of a Debian 12 Bookworm using a dedicated server. Two providers are used at the moment:

1. Hetzner, where the server has a public IPv4 and a public IPv6 address, with one MAC address, a couple of SSD disks for the OS and a couple of HDD disks for the backup storage. This acts as the primary backup server, connected to the Proxmox Virtual Environment via a local network, though a virtual switch (vSwitch `#4003`).
2. OVH, where the server has a public IPv4 address, with one MAC address, one SSD disk for the OS and four HDD disks for the backup storage. This acts as a replica of the primary backup server.

In case of Hetzner, installation will be performed via the [installimage](https://docs.hetzner.com/robot/dedicated-server/operating-systems/installimage/) command on the rescue system. In the configuration editor of the installer we will comment out the extra HDD disks and set the `SWRAIDLEVEL` to 1 so that the installer only uses the two SSD disks for the operating system.

In case of OVH, installation is performed through the control panel, using its Debian 12 template.

# Design

We will be using two Proxmox Backup Servers. One is where all snapshots and dumps of containers and virtual machines from the PVE will be sent to, hosted at Hetzner, and the second is where the first will replicate backups to, for safety, using the [remotes feature](https://pbs1.andromedant.com:8007/docs/managing-remotes.html#backup-remote). This second one will be on a different hosting provider and country.

The Proxmox cluster uses three VLANs:

* Id `4001` , Proxmox guests public network (`116.202.120.32/28`), for the guests public addresses.
* Id `4002` , Proxmox guests private network (`192.168.0.0/16`), used for the application running in the virtual machines to communicate.
* Id `4003` , Proxmox hosts private network (`10.0.0.0/8`), used for the nodes (hosts) of the cluster to communicate among themselves (Corosync, VM migration, etc.)

We will be using the VLAN with id `4003` so that the cluster nodes and the backup server are in the same local network.

Note: See [[Installation_of_a_Proxmox_Backup_Server_on_Hetzner]] for more information.

# Base packages installation

The base installation is a Debian 12 Bookworm AMD64, Hetzner's version. Default packages include `sudo`, `locales`, `net-tools` and `vim-tiny`, among others. Some extra packages worth installling:

```
apt-get update
apt-get purge vim-common vim-tiny nano
apt-get install ccze dnsutils net-tools nmap tcpdump tree vim
```

# Base system configuration

Initial server set-up after the default installation of Hetzner's Debian 12 Bookworm distribution on a dedicated server.

Set `vim` as the system-wide default editor:

```
update-alternatives --set editor /usr/bin/vim.basic
```

And set `vim` as the `root` user's default editor:

```
echo 'SELECTED_EDITOR="/usr/bin/vim.basic"' > ~/.selected_editor
```

Create the Vim configuration file `~/.vimrc` for the `root` user:

```
" Load defaults from /etc/vim/vimrc
runtime defaults.vim

" On pressing tab, insert 2 spaces
" Show existing tabs with 2 spaces width
" When indenting with '>', use 2 spaces width
set tabstop=2 softtabstop=0 expandtab shiftwidth=2 smarttab

" Switch betwen paste and nopaste modes using F3
set pastetoggle=<F3>

" Disable visual mode set in the defaults file
" /usr/share/vim/vim82/defaults.vim, line 82
set mouse=
set ttymouse=
```

Configure `/etc/hostname`:

```
hostnamectl set-hostname pbs2
hostnamectl set-deployment production
hostnamectl set-location "Data Center Park Helsinki, Finland"
```

Currently used locations are:

* "Data Center Park Falkenstein, Germany"
* "Data Center Park Helsinki, Finland"
* "OVH Roubaix Data Center, France"

Configure `/etc/hosts`:

```
# IPv4
127.0.0.1 localhost.localdomain localhost
217.182.132.141 pbs1.andromedant.com pbs1
95.216.226.36 pbs2.andromedant.com pbs2

# IPv6

2a01:4f9:2b:1f5b::2 pbs2.andromedant.com pbs2
```

Set up A and AAAA entries in the `andromedant.com` DNS zone so that the host can be accessed through a FQDN:

```
pbs2 IN A    95.216.226.36
pbs2 IN AAAA 2a01:4f9:2b:1f5b::2
```

Configure the locale:

```
localectl set-locale LANG=en_US.UTF-8
```

Generate locales:

```
locale-gen
```

Reboot.

# Time zone and Network Time Protocol

The system uses `systemd-timesyncd` by default. Hetzner’s version of Debian includes three NTP servers provided by Hetzner:

```
# cat /etc/systemd/timesyncd.conf.d/hetzner.conf 
[Time]
NTP=ntp1.hetzner.de ntp2.hetzner.com ntp3.hetzner.net
```

For servers at OVH create the directory `/etc/systemd/timesync.conf.d/`:

```
mkdir --mode=0755 --parents /etc/systemd/timesyncd.conf.d/
```

Then create the file `/etc/systemd/timesyncd.conf.d/ovh.conf` with the following content:

```
[Time]
NTP=ntp.ovh.net
```

To check that the service is running correctly, use the following command:

```
systemctl status systemd-timesyncd
```

All Proxmox nodes should have the `UTC` time zone configured. This can be checked with the following command:

```
timedatectl status
```

It can be changed to `UTC` with the following command:

```
timedatectl set-timezone UTC
```

# Debian packages mirror

At Hetzner, configure either the German or Finnish Debian mirror as well as Hetzner's in the `/etc/apt/sources.list` file:

```
# Packages and security updates from the Hetzner Debian mirror
deb http://mirror.hetzner.de/debian/packages bookworm main contrib non-free-firmware
deb http://mirror.hetzner.de/debian/packages bookworm-updates main contrib non-free-firmware
deb http://mirror.hetzner.de/debian/packages bookworm-backports main contrib non-free-firmware

# Debian mirror
deb http://ftp.fi.debian.org/debian bookworm main contrib non-free-firmware
deb http://ftp.fi.debian.org/debian bookworm-updates main contrib non-free-firmware
deb http://ftp.fi.debian.org/debian bookworm-backports main contrib non-free-firmware

# Security updates
deb http://mirror.hetzner.de/debian/security bookworm-security main contrib non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware
```

And delete the file `/etc/apt/sources.list.d/hetzner-security-updates.list`:

```
rm /etc/apt/sources.list.d/hetzner-security-updates.list
```

OVH uses the [deb822](https://repolib.readthedocs.io/en/latest/deb822-format.html) format, therefore we need to create the file `/etc/apt/sources.list.d/ovh.sources` to include the OVH Debian mirror:

```
Types: deb
URIs: http://debian.mirrors.ovh.net/debian
Suites: bookworm bookworm-updates bookworm-backports
Components: main contrib non-free-firmware

Types: deb
URIs: http://debian.mirrors.ovh.net/debian-security
Suites: bookworm-security
Components: main contrib non-free-firmware
```

Entries in the file `/etc/apt/sources.list.d/debian.sources` can now be commented out so only the internal OVH mirror will be used, or we can change that file into using the appropriate mirror in the [Debian CDN](https://deb.debian.org/):

```
Types: deb
URIs: http://deb.debian.org/debian
Suites: bookworm bookworm-updates bookworm-backports
Components: main contrib non-free-firmware

Types: deb
URIs: http://security.debian.org/debian-security
Suites: bookworm-security
Components: main contrib non-free-firmware
```

Finally, upgrade existing packages to the latest version:

```
apt-get update
apt-get dist-upgrade
```

Reboot.

# OpenSSH

When selecting the operating system to install in the server, a public SSH key will have been added to the `root` user, so the `~/.ssh/authorized_keys` file already exists. Add the Andromeda master key to the file, available at Bitwarden, by editing the file:

```
echo "ssh-ed25519 AAAA[..]KhC Andromeda Solutions" >> ~/.ssh/authorized_keys
```

And you also probably want to add the Ansible key as well.

In case of a server at OVH, also clean up the delayed root login code before the existing key, so that the line starts with `ssh-rsa [..]` or similar. 

Test access with the key:

```
ssh -i ~/.ssh/andromedant -p 22 root@pbs2.andromedant.com
```

Next edit the @/etc/ssh/sshd_config@ file and make the following changes:

```
Port 2222
PermitRootLogin prohibit-password
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
AuthorizedKeysFile .ssh/authorized_keys
# AcceptEnv LANG LC_*
```

Note: `pbs1` uses port 2221, `pbs2` uses port 2222, and so on.

Check for errors in the configuration before restarting the service:

```
sshd -t
```

Restart the OpenSSH service:

```
systemctl restart ssh
```

You can check that the OpenSSH service is now listening at the new port on all addresses:

```
netstat --program -all --numeric | grep --word-regexp LISTEN
```

Optionally, configure your local `.ssh/config` file as follows:

```
# Keep connections alive
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 2
    ControlMaster auto
    ControlPath /tmp/%r@%h:%p
    TCPKeepAlive yes

# Proxmox Backup Server 1
Host pbs1
    User root
    Hostname pbs1.andromedant.com
    Port 2221
    IdentityFile ~/.ssh/id_rsa

# Proxmox Backup Server 2
Host pbs2
    User root
    Hostname pbs2.andromedant.com
    Port 2222
    IdentityFile ~/.ssh/id_rsa
```

# Fail2Ban

This software offers protection against so-called brute force attacks. The IP address of the user is blocked for a certain period of time after several incorrect passwords have been entered. This is to prevent the attacker from trying out a large password list in a short time.

The kernel installed by Proxmox uses *iptables*, which is used by *Fail2Ban* by default. Unfortunately, the `fail2ban` package in Debian 12 Bookworm comes with a [serious bug](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=770171) (also [available upstream](https://github.com/fail2ban/fail2ban/issues/3292)) that prevents it from working out of the box.

Install the `fail2ban` and `python3-systemd` packages:

```
apt-get install fail2ban python3-systemd
```

Check that the service is enabled:

```
systemctl status fail2ban
```

If it is not, enable it:

```
systemctl enable fail2ban
```

Create the local configuration file `/etc/fail2ban/fail2ban.local` with the following content:

```
[DEFAULT]

# Allows the IPv6 interface
# Prevents the 'allowipv6' not defined in 'Definition' warning
allowipv6 = yes
```

Create a local configuration file `/etc/fail2ban/jail.local` with the following content:

```
[DEFAULT]

# Debian 12 has no log files, just journalctl
default_backend = systemd
logtarget = SYSTEMD-JOURNAL

# A list of IP addresses, CIDR masks or DNS hosts that Fail2ban will not ban
ignoreip = 127.0.0.1/8 ::1

# The number of seconds that a host is banned
bantime  = 1d

# The number of failures before a host get banned
maxretry = 5

# A host is banned if it has generated "maxretry" during the last "findtime"
findtime  = 1h

[sshd]
# As per /etc/ssh/sshd_config port configuration
port = 2222

[pam-generic]
# Default values of pam-generic already use the default backend,
# but we need to enable the jail
enabled = yes
```

Note: adjust the port as necessary.

SSH is the only service that is enabled by default, which can be checked at the `/etc/fail2ban/jail.d/defaults-debian.conf` file:

```
# cat /etc/fail2ban/jail.d/defaults-debian.conf
[sshd]
enabled = true
```

Restart the service to apply the changes:

```
systemctl restart fail2ban
```

Right now the only active jail is the `sshd` one, which can be checked with the following command:

```
fail2ban-client status sshd
```

## Fail2Ban on Proxmox WebGUI

We are also going to use Fail2Ban to protect access to Proxmox's web interface as well, both via the PVE and PAM realms. The PAM realm is already covered by the `/etc/fail2ban/filter.d/pam-generic.conf`, which is configured to use the default backend, which we previously set to `systemd` in our `/etc/fail2ban/jail.local`file. So we only need to take care of the PVE realm, which we will do next.

First, create the file `/etc/fail2ban/jail.d/proxmox.conf` with the following content:

```
[proxmox]
enabled = true
port = https,http,8007
filter = proxmox
backend = systemd
banaction = iptables
maxretry = 3
findtime = 7d
bantime = 1h
```

And last, create the file `/etc/fail2ban/filter.d/proxmox.conf` with the following content:

```
[INCLUDES]
before = common.conf

[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =

[Init]
journalmatch = _SYSTEMD_UNIT=pvedaemon.service
```

Restart the service for the changes to take effect:

```
systemctl restart fail2ban
```

Use the following command to check the status of the jail:

```
fail2ban-client status proxmox
```

Use the following command to test the Proxmox jail:

```
fail2ban-regex systemd-journal /etc/fail2ban/filter.d/proxmox.conf
```

# Proxmox packages and installation

Add the Proxmox repository key to `/etc/apt/trusted.gpg.d/`:

```
wget http://download.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
```

Then add the Proxmox repository to `/etc/apt/sources.list.d/`:

```
echo "deb [arch=amd64] http://download.proxmox.com/debian/pbs bookworm pbs-no-subscription" > /etc/apt/sources.list.d/pbs-install-repo.list
```

Or, if you want to add them in deb8xx format, then create the file `/etc/apt/sources.list.d/proxmox.sources` with the following content:

```
Types: deb
URIs: http://download.proxmox.com/debian/pbs
Suites: bookworm
Components: pbs-no-subscription
```

Update the packages information:

```
apt-get update
```

Before installing the Proxmox Backup Server, we are going to manually install the `ifupdown2` package, which is a tricky requirement located at the Proxmox APT mirror:

```
apt-get install ifupdown2
dpkg --purge ifupdown
systemctl enable networking.service
```

We are now ready to install Proxmox Backup Server:

```
apt-get install proxmox-backup zfsutils-linux mailutils
```

Firmware package `firmware-bnx2x` was installed with Hetzner's version of Debian 12 Bookworm, but is automatically removed when installing the @proxmox-backup@ package and its dependencies, which in turn installed @pve-firmware@.

Note: `proxmox-backup-server` installs `postfix` as a dependency. For now, configure Postfix as *local only* and leave the *system mail name* as is (e.g., `pbs2.andromedant.com`). Further down the installation, all Postfix installations will be configured as *satellite systems*, using a relay host.

Reboot the system.

Note: The new Proxmox VE kernel should be automatically selected in the GRUB menu. If you want to check the GRUB entries before rebooting, use the following command:

```
awk -F\' '/menuentry / {print $2}' /boot/grub/grub.cfg
```

Note: If you want to check the new kernel version after reboot, use the following command:

```
uname --all
```

You can now remove old, non-PVE kernels:

```
apt-get purge linux-image-6.1.0-??-amd64 linux-image-amd64
```

And also remove the PBS entreprise repository, which was added by the packages we installed before:

```
rm /etc/apt/sources.list.d/pbs-enterprise.list
```

# Nameservers

*Proxmox Backup Server* expects to manage the DNS and will no longer take its DNS settings from `/etc/network/interfaces`. Any package that auto-generates (overwrites) `/etc/resolv.conf` will cause the DNS to fail, so make sure that `resolvconf` and `rdnssd` are not installed:

```
dpkg --list | grep -e resolvconf -e rdnssd
```

Also note that the default Debian installation left by [Hetzner’s Installimage](https://docs.hetzner.com/robot/dedicated-server/operating-systems/installimage/) statically sets Hetzner’s nameservers in the `/etc/resolv.conf` file:

```
nameserver 185.12.64.1
nameserver 2a01:4ff:ff00::add:2
nameserver 185.12.64.2
nameserver 2a01:4ff:ff00::add:1
```

And so does OVH:

```
nameserver 2001:41d0:3:163::1
nameserver 213.186.33.99
search .
```

# Network configuration

OVH's installation uses Netplan, which sets up IPv4 addresses via DHCP, as configured in the `/etc/netplan/50-cloud-init.yaml` file. IPv6 is statically configured, though, in that same file.

Hetzner's installation uses static configurations in the `/etc/network/interfaces` file.

## OVH network configuration

First, make a backup copy of the default network configuratin provided by OVH's installer:

```
cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak
```

Edit the `/etc/netplan/50-cloud-init.yaml` file and add the static IPv4 address:

```
network:
    version: 2
    ethernets:
      eno3:
        accept-ra: false
        addresses:
          - 217.182.132.141/24
        # - 2001:41d0:203:58d::/64
        dhcp4: false
        dhcp6: false
        gateway4: 217.182.132.254
        # gateway6: 2001:41d0:203:5ff:ff:ff:ff:ff
        match:
          macaddress: 0c:c4:7a:96:0a:b6
        nameservers:
          addresses:
            - 213.186.33.99
        #   - 2001:41d0:3:163::1
        # Previous routes when using DHCP
        # 213.186.33.99 via 217.182.132.254 dev eno3 proto dhcp src 217.182.132.141 metric 100
        # 217.182.132.0/24 dev eno3 proto kernel scope link src 217.182.132.141 metric 100
        # 217.182.132.254 dev eno3 proto dhcp scope link src 217.182.132.141 metric 100
        # routes:
        # - to: 213.186.33.99
        #   via: 217.182.132.254
        # - to: 2001:41d0:203:5ff:ff:ff:ff:ff/128
        #   via: '::'
        set-name: eno3
```

## Hetzner network configuration

First, make a backup copy of the default network configuration provided by Hetzner's installer:

```
cp /etc/network/interfaces /etc/network/interfaces.bak
```

Edit the `/etc/network/interfaces` file and configure the network and the VLAN with id `4003`:

```
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
iface lo inet6 loopback

auto enp0s31f6
iface enp0s31f6 inet static
  hwaddress 90:1b:0e:fe:30:62
  address 95.216.226.36
  netmask 255.255.255.192
  gateway 95.216.226.1
  up route add -net 95.216.226.0 netmask 255.255.255.192 gw 95.216.226.1 dev enp0s31f6
# Proxmox host

auto enp0s31f6.4003
iface enp0s31f6.4003 inet static
        address 192.168.1.9/24
        vlan-raw-device enp0s31f6
        mtu 1400
# Proxmox hosts private network 192.168.1.0/24

iface enp0s31f6 inet6 static
  address 2a01:4f8:172:1729::2
  netmask 64
  gateway fe80::1
```

Restart the networking service for the new configuration to take effect:

```
systemctl restart networking
```

# Control panel

Go to the Hetzner's control panel and complete the following tasks:

1. Set the server name to `pbs2`.
2. Set the reverse DNS entry to `pbs2.andromedant.com`.
3. Add the _Proxmox Backup Server_ firewall template to the server
4. Add the server to the vSwitch with id `4003`.

Go to OVH's control panel, navigate to the dedicated server dashboard and complete the following tasks:

1. Go to `Dedicated servers: <server>: General information: Name` and set the server name to `pbs1.andromedant.com`.
2. Go to `Dedicated servers: <server>: Network: Reverse DNS` and set the reverse DNS entry to `pbs1.andromedant.com`.

## OVH's firewall

To configure the edge network firewall, go to `Network: IP: <IPv4>`and use the `Create firewall` menu option. Then, on the same menu, choose the `Edge network firewall configuration` option. Using the `Add a rule` button, add the following rules:

| #  | Mode      | Protocol | Source IP      | Source port | Destination port | TCP status  | Status |
|----|-----------|----------|----------------|-------------|------------------|-------------|--------|
| 0  | Authorise | TCP      | all            |             |                  | established | Active |
| 1  | Authorise | TCP      | all            |             | 8007             |             | Active |
| 2  | Authorise | TCP      | all            |             | 2221             |             | Active |
| 3  | Authorise | ICMP     | all            |             |                  |             | Active |
| 4  | Refuse    | IPv4     | all            |             |                  |             | Active |

Then click the switch on the top-right corner of the table of rules to enable the firewall.

## Hetzner’s Firewall

[Hetzner’s firewall](https://docs.hetzner.com/robot/dedicated-server/firewall/) only takes care of incoming traffic and its rules are processed before the packets arrive at our Proxmox installation, including the packets that travel through the vSwitches (VLAN), including the public IP subnet. It is a secondary layer of protection but it does not protect against DDoS attacks. For that, Hetzner offers “another tool:https://www.hetzner.com/unternehmen/ddos-schutz, which is always active and included with the server fees.

The number of rules are limited to 10. Rule *number 11* is to drop all incoming traffic (not allowed before). Since we have all sorts of traffic among our hosts and guests, and the Internet, we are going to be more generalistic here. Set up a firewall template with the following data by going to the [templates index on the Robot control panel](https://robot.hetzner.com/firewall/templateIndex):

* Name: Proxmox Backup Server
* Use by default: False
* Filter IPv6 packets: No
* Hetzner services (incoming): Yes

Rules (incoming):

| #  | Name                 | Version | Protocol | Source IP      | Destination IP    | Source port | Destination port | TCP flags | Action |
|----|----------------------|---------|----------|----------------|-------------------|-------------|------------------|-----------|--------|
| 1  | Ping                 | ipv4    | icmp     |                |                   |             |                  |           | accept |
| 2  | Proxmox WebGUI       | ipv4    | tcp      |                |                   |             | 8007             |           | accept |
| 3  | OpenSSH              | ipv4    | tcp      |                |                   |             | 2220-2222        |           | accept |
| 4  | Proxmox hosts        | ipv4    | *        | 192.168.1.0/24 | 192.168.1.0/24    |             |                  |           | accept |
| 5  | Ephemeral port range | ipv4    | tcp      |                |                   |             | 32768-65535      | ack       | accept |

Rules (outgoing):

| #  | Name                 | Version | Protocol | Source IP      | Destination IP    | Source port | Destination port | TCP flags | Action |
|----|----------------------|---------|----------|----------------|-------------------|-------------|------------------|-----------|--------|
| 1  | Allow all            | *       |          |                |                   |             |                  |           | accept |

Then go to the `Firewall` tab of the `pbs2` server and apply the template, making sure the firewall is active for the server.

# Proxmox configuration

Set a password for the `root` user from the console using the `passwd` command, save it to [Bitwarden](https://vault.bitwarden.com/), then access the WebGUI over HTTPS at the 8007 port using the `PAM authentication` mechanism. You will have to accept the self-signed certificate as valid:

* [pbs1 at OVH](https://pbs1.andromedant.com:8007/)
* [pbs2 at Hetzner](https://pbs2.andromedant.com:8007/)

At the `Configuration: Network/Time: Time zone` menu option, check that the time zone is set to `Etc/UTC`.

## Certificate for the host

By default, Proxmox [installs a self-signed certificate](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysadmin_certificate_management). We will be using [Let’s Encrypt](http://letsencrypt.org/) through the [ACME protocol](https://datatracker.ietf.org/doc/html/rfc8555) (Automatic Certificate Management Environment) to obtain a valid certificate for the node, which will be renewed automatically by Proxmox from then onwards.

### Account

We will first configure the account, then the challenge plug-in. Using the WebGUI, at the `Configuration: Certificates` menu entry, go to the `ACME` section and add the account using the `Add ACME account` button. All that’s needed is a name (e.g. Andromeda) and an email (e.g. `sysadmin@andromedant.com`). Make sure you check the `Accept TOS` option and click on the `Register` button.

### Challenge plug-in

The default challenge plugin is HTTP, which is already installed. For reference, for it to work, the following conditions must be met:

* Port 80 of the node needs to be reachable from the internet (i.e. firewall rule needs to be added).
* There must be no other listener on port 80.
* The requested (sub)domain needs to resolve to the public IP of the node.

We will be adding an additional challenge by using the `Add` button right below the `Challenge plugins` section title in the `Configuration: Certificates: ACME accounts` menu option:

* Plugin id: cloudflare
* Validation delay: 30
* DNS API: Cloudflare Managed DNS
* Account id: [..]
* Token: [..]

The account id and zone id can be copied from the bottom right corner of the `andromedant.com` domain overview page at [Cloudflare’s dashboard](https://dash.cloudflare.com/). The API token can be obtained (with finegrained permissions) at the [API Tokens menu option](https://dash.cloudflare.com/profile/api-tokens) of the user’s profile. These values are also stored at the [Bitwarden vault](https://vault.bitwarden.com/).

The IP address of the host needs to be added to the list of accepted IP addresses using the [Cloudflare control panel](https://dash.cloudflare.com/profile/api-tokens).

### Domain

Next we need to add the domain by using the `Add` button right below the `ACME` section title in the `Configuration: Certificates: Certificates` menu option:

* Challenge type: DNS
* Plug-in: cloudflare
* Domain: `pbs1.andromedant.com` or `pbs2.andromedant.com`

### Issuing the certificate

Choose the account by clicking the pencil icon next to the “Using account” label, select the account created before and click on the check icon. Finally, click the `Order Certificates Now` button.

The process will place the order, which will consist of:

1. Validating the ownership of the domain.
2. Sending the CSR (certificate request)
3. Waiting for the certificate to be issued.
4. Installing the certificate and restarting the PVE Proxy.

Proxmox will take care of renewing the certificate automatically.

## Datastores

We will create a ZFS storage pool using the two additional HDD disks. Go to the `Administration: Storage/Disks: ZFS` menu option and use the `Create: ZFS` button:

* Name: zfspool
* RAID level:
  * `Mirror` with 2 drives (RAID 1, one drive can fail)
  * `RAIDZ2` with 4 drives (RAID 6-ish, two drives can fail, double the space of one drive).
* Compression: On
* ashift: 12
* Add as datastore: Yes
* Device: Select all HDD disks

This will also create a `zfspool` datastore, where our backups will be stored.

Reference:

* [Host System Administration](https://pbs2.andromedant.com:8007/docs/sysadmin.html#chapter-zfs)
* [Growing - Linux Raid Wiki](https://raid.wiki.kernel.org/index.php/Growing)
* [Remove drive from soft RAID](https://unix.stackexchange.com/questions/332061/remove-drive-from-soft-raid/342112#342112)

## Retention policy

By default, Proxmox Backup Server keeps all the backups that are sent to it. We are going to define a custom, default retention policy that keeps backups for five years via a prune job that periodically (daily) will prune the `zfspool` datastore.

Go to the `Datastore: zfspool: Prune & GC` menu option and use the `Add` button in the `Prune jobs` section:

* Prune schedule: `Every day 00:00`
* Namespace: `Root`
* Max. depth: `Full`
* Keep last: 3
* Keep hourly:
* Keep daily: 13
* Keep weekly: 8
* Keep monthly: 11
* Keep yearly: 5
* Comment: Default 5-year retention policy for all backups

Explanation of the above settings:

* Keep last 3, in a daily backup scenario, ensures that manually created backups (e.g. before or after a big upgrade) are kept.
* Keep hourly is not relevant in a daily backup scenario.
* Keep daily 13, together with `keep-last`, which covers at least one day, ensures that we have two weeks of backups.
* Keep weekly 8 ensures that we have at least two full months of weekly backups.
* Keep monthly 11 ensures that we have at least a year of monthly backups.
* Keep yearly 5 ensures that we have at least the latest backup of each year for the last 5 years beyond the current one, which is covered by the previous options.

If we are using a `RAIDZ2` on 4 drives and have more disk space available, we can modify the following settings:

* Keep monthly: 23
* Comment: Extended 5-year retention policy for all backups

The Proxmox website provides a [retention policy simulator](https://pbs.proxmox.com/docs/prune-simulator/) which can be used to help configure and adapt these settings.

## Garbage collection

Proxmox Backup Server does not save backup data directly, but rather as chunks that are referred to by the indexes of each backup snapshot. This approach enables reuse of chunks through deduplication, among other benefits. When deleting a backup snapshot, Proxmox Backup Server cannot directly remove the chunks associated with it because other backups, even ones that are still running, may have references to those chunks. Therefore, Proxmox Backup Server uses a garbage collection (GC) process to identify and remove the unused backup chunks that are no longer needed by any snapshot in the datastore.

Go to the `Datastore: zfspool: Prune & GC` menu option, select the only record in the `Garbage collection` section, labelled `Garbage collection schedule`, and use the `Edit` button to modify it:

* GC schedule: Every day 21:00"

And save the changes.

## Job verification

Through this option we will instruct Proxmox Backup Server to ensure that the data is intact. It is recommended to reverify all backups at least monthly, even if a previous verification was successful. This is because physical drives are susceptible to damage over time.

Go to the `Datastore: zfspool: Verify jobs` menu option and use the `Add` button to create a verification job:

* Namespace: Root
* Max. depth: Full
* Schedule: Every day 22:00
* Skip verified: Yes
* Re-verify after: 30 days
* Comment: Daily verification of all backups older than 30 days

And save the changes.

## Backup user

Go to the `Configuration: Access control: User management` menu option and use the Àdd` button to add the user that the Proxmox Virtual Environment will use to send the backups to the Proxmox Backup Server:

* User name: `backupuser`
* Realm: Proxmox Backup authentication server
* Password: *password*
* Confirm password: *password*
* Expire: *never*
* First name: Backup
* Last name: User
* E-mail: root@pbs2.andromedant.com
* Comment: Backup user to be used by the PVE

Add the account to [Bitwarden](https://vault.bitwarden.com/), which will also be used to generate the password.

Before leaving this menu option, edit the `root@pam` user and set the following values:

* First name: System
* Last name: Administrator
* E-mail: root@pbs2.andromedant.com

Now go to the `Configuration: Access control: Permissions` menu option and use the `Add: User permission` button to allow the user access to the just-created data store:

* Path: `/datastore/zfspool`
* User: `backupuser@pbs`
* Role: `DatastoreAdmin`

Reference:

* [User Management: Access Control](https://pbs2.andromedant.com:8007/docs/user-management.html#user-acl)

Note: We will not be needing a backup user in the replica backup server (see below), only on the primary one, where the PVE sends dumps and snapshots to.

## Replicas

As described in the design section of this document, we will be having a primary backup server, where the Proxmox Virtual Environment will be sending dumps and snapshots to, then a replica or secondary backup server, that will store a copy of suck backups.

A remote, or replica, refers to a Proxmox Backup Server from which datastores are sync'ed to, via a sync job. So, in short:

* The primary (`pbs2.andromedant.com`) configures a `sync` user with `DatastoreReader` permissions.
* The secondary (`pbs1.andromedant.com`) configures a remote (`pbs2.andromedant.com`), using the `sync` user.
* The secondary (`pbs1.andromedant.com`) configures a sync job to pull the contents of a remote datastore to its local datastore.

On the primary server `pbs2.andromedant.com`, go to the `Configuration: Access control: User management` menu option and use the `Add` button to add the `sync` user:

* User name: `syncuser`
* Realm: Proxmox Backup authentication server
* Password: *password*
* Confirm password: *password*
* Expire: *never*
* First name: Sync
* Last name: User
* E-mail: root@pbs2.andromedant.com
* Comment: Sync user to be used by the secondary backup server

Add the account to [Bitwarden](https://vault.bitwarden.com/), which will also be used to generate the password.

Now go to the `Configuration: Access control: Permissions` menu option and use the `Add: User permission` button to allow the `sync` user access to the datastore:

* Path: `/datastore/zfspool`
* User: `syncuser@pbs`
* Role: `DatastoreReader`

On the secondary server `pbs1.andromedant.com`, go to the `Configuration: Remotes` menu option. Click on the `Add` button and fill in the form with the following data:

* Remote id: `pbs2`
* Host: `pbs2.andromedant.com`
* Auth id: `syncuser@pbs`
* Password: *password*
* Comment: Primary backup server at Hetzner

Finally, on the secondary server `pbs1.andromedant.com`, go to the `Datastore: zfspool: Sync jobs` menu option and use the `Add` button to add a job:

* Local namespace: Root
* Local owner: `root@pam`
* Sync schedule: Every day 08:00
* Location: Remote
* Source remote: `pbs2`
* Source datastore: `/datastore/zfspool`
* Source namespace: Root
* Max. depth: Full
* Remove vanished: False
* Comment: Daily pull of snapshots from primary backup server

References:

* [Proxmox forums](https://forum.proxmox.com/threads/need-some-help-with-remotes-and-sync-jobs.82582/)
* [Managing Remotes & Sync](https://pbs1.andromedant.com:8007/docs/managing-remotes.html)

## Postfix

The nodes of the PVE (PRoxmox Virtual Environment) and PBS (Proxmox Backup Server) clusters will not be using the Proxmox Mail Gateway as relayhost or smarthost. Instead, they will be using Google's SMTP directly.

We will use the command `dpkg-reconfigure postfix` to change the initial configuration to the following:

* Mail server configuration type: Satellite system
* System mail name: pbs2.andromedant.com
* SMTP relay host: smtp-relay.gmail.com:25
* Root and postmaster mail recipient: sysadmin@andromedant.com
* Other destinations to accept mail for: pbs2.andromedant.com, localhost.andromedant.com, localhost
* Force synchronous updates on mail queue?: No
* Local networks: 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
* Mailbox size limit (bytes): 0
* Local address extension character: +
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

Add the IP address of the Proxmox Backup Server to the list of allowed senders in the [Routing option](https://admin.google.com/u/1/ac/apps/gmail/routing?hl=en) of the [Google Admin console](https://admin.google.com/), as described in the [Configuration of a Proxmox Mail Gateway](https://redmine3.andromedant.com/projects/comeoncharter/wiki/Configuration_of_a_Proxmox_Mail_Gateway_7_on_Debian_11_Bullseye#Google-Mail-configuration) guide.

To test that the email sent by the node is reaching its destination, we can use the `mail` command from the `mailutils` package:

```
mail --subject="Test from $(hostname)" --append="From: <root@$(hostname -f)>" root@$(hostname -f) <<< "This is a test message from $(hostname -f) using mail"
```

By default, all nodes send notifications by email using the `root@$hostname` address. The datastore `zfspool` is already configured to send notifications to the `root@pam` user[1], whose email address we configured earlier. Through the just-configured aliases we will be receiving emails at a valid email account outside of the server.

[1] `Datastore: zfspool: Options: Notify user`

By default, Proxmox Backup Server sends eḿail notifications upon completion of any of the following events:

* Verification jobs
* Sync jobs
* Prune jobs (only in case of error)
* Garbage collection

If we want to be notified only when there has been an error, we need to edit the datastore options at `Datastore: zfspool: Options: Notify`.

Next, deploy the wildcard certificate for `andromedant.com` from the Ansible Controller to the server:

```
scp -i ~/.ssh/ansible -P 2222 /home/ansible/letsencrypt/etc/live/andromedant.com/fullchain.pem root@pbs2.andromedant.com:/etc/ssl/certs/andromedant.com.crt
scp -i ~/.ssh/ansible -P 2222 /home/ansible/letsencrypt/etc/live/andromedant.com/privkey.pem root@pbs2.andromedant.com:/etc/ssl/private/andromedant.com.key
ssh -i ~/.ssh/ansible -p 2222 root@pbs2.andromedant.com 'chmod 640 /etc/ssl/private/andromedant.com.key'
ssh -i ~/.ssh/ansible -p 2222 root@pbs2.andromedant.com 'chgrp ssl-cert /etc/ssl/private/andromedant.com.key'
```

And set the following parametres in the `/etc/postfix/main.cf` configuration file:

```
smtpd_tls_cert_file=/etc/ssl/certs/andromedant.com.crt
smtpd_tls_key_file=/etc/ssl/private/andromedant.com.key
```

Restart Postfix for the changes to take effect:

```
systemctl restart postfix
```

You can check the logs with the following command:

```
journalctl --follow --unit=postfix* | ccze
```

## Two-Factor Authentication

Set up two factor authentication at the `Configuration: Access control: Two factor authentication` menu option. Use the `Add: TOTP` button and follow the process:

* User: `root@pam`
* Description: System Administrator
* Issuer name: `PBS 2` for `pbs2` and `PBS 1` for `pbs1`

Use a new, private browsing window to test the newly-set system before closing the current session.

# Configuring backups on the PVE

First of all, go to all the nodes of the PVE cluster and add the following entry to the `/etc/hosts` file:

```
192.168.1.9  pbs2.andromedant.com pbs2
```

Once the backup user has been added to the Proxmox Backup Server, go to the `Datacenter: Storage` menu option in the Proxmox Virtual Environment and use the `Add: Proxmox Backup Server` to add the remote storage:

* ID: `pbs2`
* Server: `pbs2.andromedant.com`
* Username: backupuser@pbs
* Password: `<password>`
* Nodes: All (No restrictions)
* Enable: Yes
* Content: backup
* Datastore: zfspool

Finally, go to the `Datacenter: Backup` menu option and use the `Add` button to add as many backup jobs as necessary:

* Storage: `pbs2`
* Schedule: `*/12:00`
* Selection mode: Include selected VMs
* Send email to: `sysadmin@andromedant.com`
* Email: On failure only
* Mode: Snapshot
* Enable: Yes
* Job comment: Daily backup of some service

Select the VMs that need to be included in this job from the list below and click OK. The retention policy will be the one configured at the backup server.

Note: Use the `Node` field to filter by node, if necessary.

References:

* [Proxmox VE Storage](https://proxmox5.andromedant.com:8006/pve-docs/chapter-pvesm.html#storage_pbs)
* [Backup and Restore](https://proxmox5.andromedant.com:8006/pve-docs/chapter-vzdump.html#chapter_vzdump)
