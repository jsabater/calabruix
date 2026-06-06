# Configuration of Tinyproxy 1.10 on Debian 11 Bullseye

*Created on 2022-06-02. Last updated: 2022-09-15.*

**This document is now deprecated. Installation is done via Ansible playbook.**

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC) on Proxmox 7.

This tutorial deploys the [Tinyproxy](http://tinyproxy.github.io/) HTTP/HTTPS proxy daemon for all containers in the cluster to use when accessing the Internet. Given that most of our containers only have a private IP address in the network `192.168.0.0/24`, they will use *Tinyproxy* as their way out to the Internet when they need to download things such as packages, configuration examples and other files not available through the APT package manager.

*Tinyproxy* was designed from the ground up to be light-weight and fast, has a small footprint and requires very little in the way of system resources.

## Base installation

Given that the container where the *Tinyproxy* software is installed needs access to the Internet, we require a public IP address. In order to save them, we will be using the same LXC where our *PowerDNS* primary server is installed (`pdns1`). We will configure the daemon to bind itself to the secondary IP address of the container (`192.168.0.253`) and it will have access to the Internet via the gateway of the public IP address:

|  |  |  |  |  |  |
|----|----|----|----|----|----|
| **Hostname** | **Interface** | **Name** | **Bridge** | **IPv4/CIDR** | **Gateway (IPv4)** |
| `pdns1` | net0 | eth0 | vmbr4002 | `192.168.0.113/24` |  |
| `pdns1` | net1 | eth1 | vmbr4001 | `116.202.120.45/28` | 116.202.120.33 |
| `pdns1` | net2 | eth2 | vmbr4002 | `192.168.0.253/24` |  |

The daemon listens on port 8888 by default, but we will be using port 8080.

## Installation

Install the packages from the repository:

    apt install tinyproxy tinyproxy-bin

Once installed, *Tinyproxy* will be set to auto-start on the system. Stop the service until we have finished configuring it:

    systemctl stop tinyproxy

## Configuration

The configuration files can be found in the subdirectory `/etc/tinyproxy/`.

Edit the file `/etc/tinyproxy/tinyproxy.conf` and set up the following options:

    Port 8080
    Listen 127.0.0.1
    Listen 192.168.0.254
    Allow 127.0.0.1
    Allow 129.168.0.0/24

Any time the configuration is modified, the service needs to be restarted:

    systemctl restart tinyproxy

We can check the status of the server via *Systemd*:

    systemctl status tinyproxy

And we can also check the open ports with the following command:

    ~# netstat --program -all --numeric | grep --word-regexp LISTEN
    tcp        0      0 192.168.0.253:8080      0.0.0.0:*               LISTEN      3447/tinyproxy      
    tcp        0      0 127.0.0.1:8080          0.0.0.0:*               LISTEN      3447/tinyproxy      
    tcp        0      0 192.168.0.253:53        0.0.0.0:*               LISTEN      163/pdns_recursor   
    tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN      163/pdns_recursor   
    tcp        0      0 192.168.0.113:53        0.0.0.0:*               LISTEN      164/pdns_server     
    tcp        0      0 127.0.0.1:25            0.0.0.0:*               LISTEN      330/master          
    tcp6       0      0 :::22                   :::*                    LISTEN      1/init              
    tcp6       0      0 ::1:25                  :::*                    LISTEN      330/master

## Firewall

We will open port 8080 for the local network of our containers so that all of them can make use of the proxy:

|  |  |  |  |  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|----|----|----|----|
| **Level** | **Type** | **Action** | **Macro** | **Interface** | **Protocol** | **Source** | **Source port** | **Destination** | **Destination port** | **Log level** | **Comment** |
| Container | in | ACCEPT | Webcache |  | tcp | ipv4_private_guests |  |  |  | nolog | Allow use of Tinyproxy from any LXC |

Note: we cannot set the value of the interface column to `net2` because traffic comes in through the first interface `net0` when it comes from a different node in the cluster.

## Client configuration

First we will add a new record to the `andromedant.com` zone so we can use a FQDN instead of an IP address when configuring the clients, then we’ll configure the clients.

Execute the following commands in the `pdns1` container to create the record proxy.andromedant.com and point it to the *Tinyproxy* daemon:

    pdnsutil add-record andromedant.com proxy A 192.168.0.253
    pdnsutil increase-serial andromedant.com
    pdns_control notify andromedant.com

We will now have to go to each and every LXC and create the file `/etc/profile.d/proxy.sh` with the following content:

    URL="proxy.andromedant.com:8080"

    HTTP_PROXY=$URL
    HTTPS_PROXY=$URL
    FTP_PROXY=$URL
    http_proxy=$URL
    https_proxy=$URL
    ftp_proxy=$URL

    export HTTP_PROXY HTTPS_PROXY FTP_PROXY http_proxy https_proxy ftp_proxy

And make the file executable:

    chmod +x /etc/profile.d/proxy.sh

For the changes to become active in any LXC, log out and log back in or source the file for runtime use:

    source /etc/profile.d/proxy.sh
