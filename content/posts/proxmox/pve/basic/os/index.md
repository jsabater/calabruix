---
title: "OS installation and configuration"
date: 2023-08-01
lastmod: 2024-09-21
description: "Base installation of Debian GNU/Linux 11 Bullseye on a dedicated server at Hetzner."
summary: "Install and configure the Debian OS using the tools provided by Hetzner"
categories: ["virtualisation"]
tags: ["proxmox", "pve"]
slug: operating-system
series: ["PVE7"]
series_order: 2
weight: 95
---

This article will lead you through the necessary steps to install the Debian GNU/Linux operating system on a dedicated server at [Hetzner](https://www.hetzner.com/).

Begin by accessing the [Hetzner control panel](https://accounts.hetzner.com/login), then navigate to the [Robot control panel](https://robot.hetzner.com/) and, finally, the [server list](https://robot.hetzner.com/server). Then, follow these steps:

* Identify the server and click on the server id (e.g., `EX52-NVMe #1569272`) to unfold the server details and management options.
* Go to the `Rescue` tab, select your public key [^1] and click on the `Activate rescue` button.
* Go to the `Reset` tab and select the `Press power button of server` radiobutton, then click the `Send` button. The server will be powered off. Repeat the process to power it on.
* Go to the `Firewall` tab and make sure it allows access to port 22 via the TCP protocol.

[^1]: Public keys can be added via the `Key management` tab of the Robot control panel.

Wait for a minute, then try to connect to the [rescue system](https://docs.hetzner.com/robot/dedicated-server/troubleshooting/hetzner-rescue-system/) on port 22 using the `root` user and the key you selected before. We will be using [InstallImage](https://docs.hetzner.com/robot/dedicated-server/operating-systems/installimage) to install the operating system with a custom configuration but, first, we need to stop currently active software RAIDs and delete the current partitions to prevent possible issues during or after the installation.

```bash
mdadm --stop /dev/md/*
wipefs -fa /dev/sd*
wipefs -fa /dev/nvme*n1
```

> You can check the current configuration with the `lsblk` command.

Finally, let's install the operating system via `installimage` by following these steps:

* Execute the `installimage` command.
* Choose `Debian`.
* Choose the most recent Debian 11 Bullseye image name.

By default, `installimage` will use all available disks to create a software RAID (RAID 1 if it finds two disks, RAID 5 if it finds four or more). This is fine for a server with just two NVMe disks for the OS and the local storage. However, this default configuration needs to be adapted when using a server with two disks dedicated to the OS and two or more disks dedicated to storage (e.g., a ZFS pool).

So, in the [Midnight Commander](https://midnight-commander.org/) user interface that will show next, change the level for the software RAID (`SWRAIDLEVEL`) from 5 to 1 and comment the hard disk drives that will not be used for the RAID of the disks dedicated to the operating system.

The following example is for a system with two NVMe disks for the OS and two HHD disks for the ZFS pool:

```ini
DRIVE1 /dev/nvme0n1
DRIVE2 /dev/nvme1n1
# DRIVE3 /dev/sda
# DRIVE4 /dev/sdb

SWRAIDLEVEL 1
```

Press `F10` and select `Yes` to save the changes. Confirm the operation and monitor progress in the console. When the process finishes, type `reboot` to reboot the system into the newly-installed operating system.

## OS configuration

The base installation is Hetzner's version of Debian AMD64 includes `sudo`, `locales`, `net-tools` and `vim-tiny`. There are some extra packages worth installing (adapt to your preferences).

```bash
apt-get update
apt-get install --yes ccze dnsutils htop nmap tcpdump
```

If you are using Vim as your text editor, remove `nano` and `vim-tiny`, then install the full version of [Vim](https://www.vim.org/).

```bash
apt-get purge --yes nano vim-tiny
apt-get install --yes vim
```

Set `vim` as the system-wide default editor and as the selected editor of the `root` user:

```bash
update-alternatives --set editor /usr/bin/vim.basic
echo 'SELECTED_EDITOR="/usr/bin/vim.basic"' > ~/.selected_editor
```

Create the *Vim* configuration file `~/.vimrc` for the `root` user (adapt to your preferences):

```vim
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
set listchars=tab:→\ ,nbsp:␣,trail:•,extends:⟩,precedes:⟨
```

## DNS entries

For your convenience, set up A and, optionally, AAAA entries in your `publicdomain.com` DNS zone so that the host can be accessed through a FQDN:

```conf
proxmox1 IN A    v4.public.ip.addr
proxmox1 IN AAAA v6:public:ip:addr::2
[..]
```

## Hostname

Configure the system hostname and related settings. Hetzner keeps [a list of their data centres](https://www.hetzner.com/unternehmen/rechenzentrum/) in their webpage. Check the end result with the `hostnamectl status` command.

```bash
hostnamectl set-hostname --static proxmox1
hostnamectl set-deployment "production"
hostnamectl set-chassis "server"
hostnamectl set-location "Data Center Park Falkenstein, Germany"
```

Adapt the list of static DNS entries at `/etc/hosts`. For simplicity, we will match the node number and the last digit of the IP address.

```conf
# IPv4
127.0.0.1 localhost.localdomain      localhost
10.0.0.1  proxmox1.localdomain.com   proxmox1
10.0.0.2  proxmox2.localdomain.com   proxmox2
10.0.0.3  proxmox3.localdomain.com   proxmox3
```

As we add nodes to the cluster beyond the first three ones, the list of mapped hosts in the `/etc/hosts` file of all nodes will have to be updated, not just on the new servers being added as nodes.

> Support for IPv6 will be addressed in a separate series.

## Locale

Configure and generate the system-wide locale:

```bash
localectl set-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8
locale-gen
```

And reboot. Check the content of the file `/etc/default/locale` to see which is the default locale.

## Debian packages mirror

Configure APT to use the German mirror as well as Hetzner's by deleting the `/etc/apt/sources.list.d/hetzner-security-updates.list` file, then editing the `/etc/apt/sources.list` file.

```conf
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

Update the packages index, then upgrade existing packages to their latest version:

```bash
apt-get update
apt-get dist-upgrade
```

Reboot.

## Server time and timezone

The Proxmox VE cluster stack relies heavily on the fact that all the nodes have precisely synchronized time. Debian uses `systemd-timesyncd` by default. Hetzner's version includes three NTP servers, configured in the `/etc/systemd/timesyncd.conf.d/hetzner.conf` file.

You can check the status of the time synchronization using the `timedatectl status` command.

Servers should always store [*](UTC). Local time is a presentation layer issue that only humans need to see. You can check the time zone in your server using the `timedatectl status` command. You can set the time zone to `UTC` with the `timedatectl set-timezone Etc/UTC` command.

Proxmox [recommends using Chrony](https://pve.proxmox.com/wiki/Time_Synchronization), so let's install and configure it.

```bash
apt-get install chrony
```

This will have removed the `systemd-timesyncd` automatically. Edit `/etc/chrony/chrony.conf` and add Hetzner's NTP servers. Also restrict requests to the hosts local network.

```properties
pool ntp1.hetzner.de ntp2.hetzner.com ntp3.hetzner.net iburst
allow 10.0.0.0/24
```

Restart Chrony with the `systemctl restart chrony` command, then check the status of time synchronisation using the `chronyc sources` command.

### Adjusting the real time clock

Should you need to adjust the system clock (software) and the real time clock (hardware), you can use the `timedatectl` command as well.

```bash
timedatectl set-ntp false
timedatectl set-time "2024-09-15 09:00:45"
timedatectl set-ntp true
```

The date and time have to be in the time zone of the system clock (UTC). The value of the hardware clock will be updated accordingly. An alternate method is to use the `hwclock` and `date` commands.

```bash
hwclock -r
date +%Y%m%d --set "20240915"
date +%T --set "09:00:45"
```

## OpenSSH

Edit the `/etc/ssh/sshd_config` file and make the following changes:

```properties
# Port 22
# Listen on port 2001 for external connections
ListenAddress v4.public.ip.addr:2001
# Listen to port 22 to let the Proxmox VE establish an SSH tunnel among hosts
ListenAddress 10.0.0.1:22
PermitRootLogin prohibit-password
PasswordAuthentication no
X11Forwarding no
# TCP Forwarding is required when migrating VMs
AllowTcpForwarding yes
AllowAgentForwarding no
AuthorizedKeysFile .ssh/authorized_keys
```

We are changing the default port 22 for the public IP address of the server and the plan is to use port 2001 for `proxmox1`, 2002 for `proxmox2`, 2003 for `proxmox3`, and so on. Choose whatever ports you fancy the most.

Proxmox requires that the node is listening on port 22 on the internal IP address of the node, hence the second `ListenAddress` directive.

Finally, TCP forwarding is required to migrate VMs. The rest is just disabling what is not needed and restricting access.

Check for syntax errors with `sshd -t` before restarting the service with the `systemctl restart sshd` command. Afterwards, check that the `sshd` daemon is now listening at the port of your choice.

```bash
netstat --program -all --numeric | grep --word-regexp LISTEN
```

Optionally, add the host to the  `.ssh/config` file in your computer.

```properties
# Keep connections alive
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 2
    ControlMaster auto
    ControlPath /tmp/%r@%h:%p
    TCPKeepAlive yes

Host proxmox1
    ControlMaster auto
    User devops
    Hostname proxmox1.publicdomain.com
    Port 2001
    IdentityFile ~/.ssh/devops

Host proxmox2
    ControlMaster auto
    User devops
    Hostname proxmox2.publicdomain.com
    Port 2002
    IdentityFile ~/.ssh/devops

Host proxmox3
    ControlMaster auto
    User devops
    Hostname proxmox3.publicdomain.com
    Port 2003
    IdentityFile ~/.ssh/devops
```

> The `devops` user will be created later in this article.

Check that you can connect to the server via SSH on port 2001 before exiting the current session on the default port. Adjust Hetzner's firewall rules.

## Fail2Ban on OpenSSH

Fail2Ban offers protection against brute force attacks by banning hosts that cause multiple authentication errors. This prevents the attacker from trying out a large password list in a short time.

As of [version 7.4 of Proxmox VE](https://pve.proxmox.com/wiki/Roadmap#Proxmox_VE_7.4), its kernel uses `iptables`, which is used by Fail2Ban by default [^2].

[^2]: Support for `nftables` landed with Proxmox VE 8.2 as an opt-in technology preview.

Install Fail2ban and enable the systemd service:
```bash
apt-get install fail2ban
systemctl enable fail2ban
```

Create a local configuration file `/etc/fail2ban/jail.local` with the following content, adjusting the port and the rest of parametres to your needs:

```ini
[DEFAULT]

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
port = 2001

[pam-generic]
# Default values of pam-generic already use the default backend,
# but we need to enable the jail
enabled = yes
```

SSH is the only service that is enabled by default, which can be checked at the `/etc/fail2ban/jail.d/defaults-debian.conf` file:

```ini
[sshd]
enabled = true
```

Restart the service to apply the changes, then check it is active over the `sshd` daemon using the `fail2ban-client` tool:

```bash
systemctl restart fail2ban
fail2ban-client status sshd
```

## Electronic mail

Proxmox uses email to send alarms and notifications, so the `proxmox-ve` package has `postfix` as a dependency. [Postfix](https://www.postfix.org/) is a hugely-popular [*](MTA) designed to determine routes and send emails.

The most sensitive and practical way to organise system email delivery in all your hosts and guests is to use a relay host, i.e., applications will use the Postfix in the localhost and it will use a relayhost to deliver the email. In practice, this means that no email is delivered locally, but relayed, hence the term. A relay host is also known as a smart host or a relay server. This structure is known as a satellite system.

Postfix daemons in the nodes of the cluster will use the relay host of your email service provider, e.g., [Zoho Mail](https://www.zoho.com/mail/), [Proton Mail](https://proton.me/mail), and so on. To match this pattern, it would be recommended for Postfix daemons in the guests to use an internal relay host, such as Proxmox Mail Gateway, which will then relay the e-mails via your e-mail service provider as well.

Install Postfix via APT:

```bash
apt-get install mailutils postfix
```

Configure it as a *satellite system*. You will need to check the documentation of your e-mail service provider to complete this process. If you do not want to go through this right now, configure Postfix as *local only* and leave the *system mail name* as is (e.g., `proxmox1.publicdomain.com`). You can later change the configuration via the `dpkg-reconfigure postfix` command.

| Parametre                                | Value                                              |
|------------------------------------------|----------------------------------------------------|
| Mail server configuration type           | Satellite system                                   |
| System mail name                         | `proxmox1.publicdomain.com`                        |
| SMTP relay host                          | `relayhost.mailprovider.com`                       |
| Root and postmaster mail recipient       | `root`                                             |
| Other destinations to accept mail for    | `proxmox1.publicdomain.com`, `localhost`          |
| Force synchronous updates on mail queue? | No                                                 |
| Local networks                           | `127.0.0.0/8` `[::ffff:127.0.0.0]/104` `[::1]/128` |
| Mailbox size limit (bytes)               | 0                                                  |
| Local address extension character        | +                                                  |
| Internet protocols to use                | all                                                |

Edit the file `/etc/aliases` to properly map aliases to local user accounts and external email addresses.

```
postmaster: root
admin: root
debian: root
root: postmaster@publicdomain.com
```

You need to run the `newaliases` command every time you change that file. Moreover, you will need to create the `postmaster` account or alias in your e-mail service provider control panel.

To test that the email sent by the node is reaching its destination, we can use the `mail` command from the `mailutils` package:

```bash
mail --subject="Test from $(hostname)" --append="From: <root@$(hostname -f)>" root@$(hostname -f) <<< "This is a test message from $(hostname -f) using the mail command."
```

By default, all nodes send notifications via email using the `root@$hostname` address.

Repeat the process in all the nodes of the cluster, as you install and configure them.

## Non-root user

You may want to create a normal user and add it to the `sudo` group for your daily maintenance routine. If so, first create a SSH key in your personal computer.

```bash
ssh-keygen -t ed25519 -a 100 -q -f ~/.ssh/devops -N '' -C "Proxmox VE DevOps"
```

Then, create the user in the server and set a password for it.

```bash
useradd --comment "DevOps User" --home /home/devops --create-home --shell /bin/bash --no-user-group --gid adm --groups sudo devops
passwd devops
```

Finally, add the key to the user and test connectivity and permissions.

```bash
su - devops
mkdir --mode=0700 ~/.ssh
echo "ssh-rsa <your '~/.ssh/devops.pub' key> devops@hostname" > ~/.ssh/authorized_keys
```

Make sure that you can acess through SSH with your usual key and that you can use `sudo`.
