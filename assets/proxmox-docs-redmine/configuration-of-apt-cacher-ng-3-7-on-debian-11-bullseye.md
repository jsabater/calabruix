# Configuration of Apt-Cacher NG 3.7 on Debian 11 Bullseye

*Created on 2022-05-05. Last updated: 2022-10-10.*

**This document is now deprecated. Installation is done via Ansible playbook.**

Based on *Debian* 11 Bullseye x86_64 running in a Linux Container (LXC) on *Proxmox* 7.

This tutorial installs *Apt-Cacher NG*, a caching proxy for downloading packages from Debian-style software repositories. Its main principle is that a central machine hosts the proxy for a local network, and clients configure their APT setup to download through it. *Apt-Cacher NG* keeps a copy of all useful data that passes through it, and when a similar request is made, the cached copy of the data is delivered without being re-downloaded.

Since most of the containers on our *Proxmox* cluster will only have a private IP address, and since the local network used by our containers (`192.168.0.24`) is isolated (i.e. no access to or from the Internet), we require a way to update the installed packages. *Apt-Cacher NG* will serve that purpose and will also save time and bandwidth.

## Base installation

Given that the container where the *Apt-Cache NG* software is installed needs access to the Internet, we require a public IP address. In order to save them, we will be using the same LXC where our *PowerDNS* secondary server is installed (`pdns2`). We will configure the daemon to bind itself to the secondary IP address of the container (`192.168.0.254`) and it will have access to the Internet via the gateway of the public IP address:

|  |  |  |  |  |  |
|----|----|----|----|----|----|
| **Hostname** | **Interface** | **Name** | **Bridge** | **IPv4/CIDR** | **Gateway (IPv4)** |
| `pdns2` | net0 | eth0 | vmbr4002 | `192.168.0.115/24` |  |
| `pdns2` | net1 | eth1 | vmbr4001 | `116.202.120.46/28` | 116.202.120.33 |
| `pdns2` | net2 | eth2 | vmbr4002 | `192.168.0.254/24` |  |

The daemon listens on port 3142.

## Installation

Install the package from the repository:

    apt install apt-cacher-ng

If the question “Allow HTTP tunnels through Apt-Cacher NG?” arises during setup, answer negatively.

Once installed, *Apt-Cacher NG* will be set to auto-start on the system. Stop the service until we have finished configuring them:

    systemctl stop apt-cacher-ng

## Configuration

The configuration files can be found in the subdirectory `/etc/apt-cacher-ng/`. Upon installation, the setup script has already detected that we had the German Debian mirror configured in our `/etc/apt/sources.list` file and has configured the backend accordingly:

    ~# cat /etc/apt-cacher-ng/backends_debian
    http://ftp.de.debian.org/debian/

Security details to access the web-based administration panel are found inside `/etc/apt-cacher-ng/security`. We will be accessing such panel via a SSH tunnel later on this tutorial, so we need to configure a username and a password:

    AdminAuth: sysadmin:<password>

In order to leave the configuration files created by the installation script untouched, we will be creating the file `/etc/apt-cacher-ng/local.conf` with our custom configuration:

    BindAddress: 192.168.0.254

Any time the configuration is modified, the service needs to be restarted:

    systemctl restart apt-cacher-ng

## Firewall

We will open port 3142 for the local network of our containers so that all of them can make use of the proxy:

|  |  |  |  |  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|----|----|----|----|
| **Level** | **Type** | **Action** | **Macro** | **Interface** | **Protocol** | **Source** | **Source port** | **Destination** | **Destination port** | **Log level** | **Comment** |
| Container | in | ACCEPT |  |  | tcp | ipv4_private_guests |  |  | 3142 | nolog | Allow access to Apt-Cacher NG from all LXC |

Note: we cannot set the value of the interface column to `net2` because traffic comes in through the first interface `net0` when it comes from a different node in the cluster.

## Enable proxying of SSL/TLS (HTTPS) repositories

In order for SSL/TLS to work, *Apt-Cacher-NG* has to be told beforehand which domains it can connect to via the `PassThroughPattern` option in the `/etc/apt-cacher-ng/acng.conf` file. For instance, to allow it to proxy anything, we could set the option like this:

    PassThroughPattern: .*

Or, if we just want to allow our usual repositories, we could set the option like this:

    PassThroughPattern: (mirror\.hetzner\.com|ftp\.de\.debian\.org):443$

Note that, when this option is active, *Apt-Cacher-NG* will proxy the requests but not cache objects stored in these SSL/TLS repositories, as it cannot understand the encrypted traffic it is proxying.

In order to enable caching of packages and indexes retrieved via SSL/TLS repositories, we have to configure *Apt-Cacher-NG* to remap a chosen non-HTTPS repository URL to the actual HTTPS URL. To do so, create the file `/etc/apt-cacher-ng/backends_hetzner` with the following content:

    https://mirror.hetzner.com/debian/

And add the following mapping in the `/etc/apt-cacher-ng/acng.conf` file:

    Remap-hetzner: mirror.hetzner.com mirror.hetzner.de; file:backends_hetzner # Hetzner mirror

## Access control

If we want to add more security regarding who can use this proxy beyond what the firewall is already allowing, we can add the following content to the `/etc/hosts.allow` file:

    apt-cacher-ng : 192.168.0.0/24

## Local cache cleanup

As *Apt-Cacher NG* server starts to cache downloaded packages, the disk on the server will start to fill up over time. Thus we need to clean up its disk space regularly. There are two ways to do this:

1.  Via the web-based administration panel
2.  Via a cron job.

### Web-based administration panel

To access the web-based administration panel, we can install `links`, a text-mode web brower, then use it to access the URL:

    links http://192.168.0.254:3142/acng-report.html

We will need the credentials we previously configured in the file `/etc/apt-cacher-ng/security.conf`.

By using the *Start Scan and/or Expiration* button, *Apt-Cacher NG* will scan cache content and schedule any unnecessary packages to be removed from the disk.

Alternatively, we can set up an SSH tunnel and use the web broswer in our computer.

### Cron job

The `apt-cacher-ng` package provides a script that is designed to do just what we need. Edit the crontab of the `root` user and add a job such as the following one:

    0 1 * * 6 /usr/lib/apt-cacher-ng/expire-caller.pl --verbose 2>&1 | /usr/bin/logger -t apt-cacher-ng

## Client configuration

First we will add a new record to the `andromedant.com` zone so we can use a FQDN instead of an IP address when configuring the clients, then we’ll configure the clients.

Execute the following commands in the `pdns1` container to create the record apt.andromedant.com and point it to the *Apt-Cacher NG* daemon:

    pdnsutil add-record andromedant.com apt A 192.168.0.254
    pdnsutil increase-serial andromedant.com
    pdns_control notify andromedant.com

We will now have to go to each and every LXC and create the file `/etc/apt/apt.conf.d/00aptproxy` with the following configuration:

    Acquire::http::Proxy "http://apt.andromedant.com:3142";

Note: All LXC need to have their DNS configured to point at our *PowerDNS* servers, as described in the \[\[Configuration_of_PowerDNS_44_on_Debian_11_Bullseye#Client-configuration\|client configuration of such tutorial\]\].

And we are ready to use the proxy. For instance, execute the following commands:

    apt update
    apt install tree
