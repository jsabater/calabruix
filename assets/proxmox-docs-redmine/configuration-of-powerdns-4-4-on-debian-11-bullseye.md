# Configuration of PowerDNS 4.4 on Debian 11 Bullseye

*Created on 2022-04-25. Last updated: 2022-05-10.*

**This document is now deprecated. Installation is done via Ansible playbook.**

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC) on Proxmox 7.

This tutorial deploys the Domain Name System (DNS) server [PowerDNS](https://www.powerdns.com/) in a primary and secondary configuration for all other containers in the cluster to use when resolving host names, both for the local domain of the private network of containers and when accessing the Internet (e.g. to download packages). The primary and the secondary will be installed in the same fashion in two different containers which will be running on different nodes of the cluster.

## Introduction

*PowerDNS* provides two nameserver products: the Authoritative Server and the Recursor.

The [Authoritative Server](https://doc.powerdns.com/authoritative/) will answer questions about domains it knows about (e.g. `andromedant.com`), but will not go out on the net to resolve queries about other domains. When the authoritative server answers a question, it comes out of the backend database, and can be trusted as being authoritative. There is no way to pollute the cache or to confuse the daemon.

The [Recursor](https://doc.powerdns.com/recursor/), conversely, by default has no knowledge of domains itself, but will always consult other authoritative servers to answer questions given to it.

We will be using both the authoritative server and the recursor. The former will hold the forward and reverse zones for the private IP network where our containers reside. The latter will be used by the containers and will be told to use the authoritative server for the local zones and external nameservers for the rest.

We will be using *PostgreSQL* as the backend database server to store the configuration of our zone. This tutorial assumes that you already have two *PostgreSQL* servers configured in two separate LXC (`postgresql1` and `postgresql2`), running in two different nodes. Ideally, the container running *PowerDNS* should be in the same node as the *PostgreSQL* server it uses, as this will reduce latency and traffic.

Once we have installed our primary (or master) Domain Name System server, we will add a secondary (or slave) server. After that we will install and configure the recursor.

## Base installation

Default version 4.4 reached end of life, so we’ll use the repository at

https://repo.powerdns.com/

Because of the way *PowerDNS* works, as two separate daemons, and because we need both daemons to listen on port 53, we will assign two private IP addresses and one public IP address to each container:

- The first private IP address (`eth0`) will be used by the Authoritative Server.
- The second private IP address (`eth2`) will be used by the Recursor, which will also listen on the localhost.
- The public IP address (`eth1`) will be used by the Recursor to forward queries to the hosting provider nameservers.

Follow the steps in the \[\[Debian Bullseye 11 LXC base system configuration\]\] tutorial to create two LXC:

- `pdns1`: Primary (master) nameserver.
- `pdns2`: Secondary (slave) nameserver.

This table summarizes the configuration of the network interfaces:

|  |  |  |  |  |  |
|----|----|----|----|----|----|
| **Hostname** | **Interface** | **Name** | **Bridge** | **IPv4/CIDR** | **Gateway (IPv4)** |
| `pdns1` | net0 | eth0 | vmbr4002 | `192.168.0.113/24` |  |
| `pdns1` | net1 | eth1 | vmbr4001 | `116.202.120.45/28` | 116.202.120.33 |
| `pdns1` | net2 | eth2 | vmbr4002 | `192.168.0.253/24` |  |
| `pdns2` | net0 | eth0 | vmbr4002 | `192.168.0.115/24` |  |
| `pdns2` | net1 | eth1 | vmbr4001 | `116.202.120.46/28` | 116.202.120.33 |
| `pdns1` | net2 | eth2 | vmbr4002 | `192.168.0.254/24` |  |

Edit the file `/etc/hosts` on both servers (primary and secondary) and add these static entries after the `END PVE` comment:

    192.168.0.100 postgresql1.andromedant.com postgresql1
    192.168.0.104 postgresql2.andromedant.com postgresql2
    192.168.0.113 pdns1.andromedant.com
    192.168.0.115 pdns2.andromedant.com

Don’t forget to edit the files `/etc/pve/lxc/<id>.conf` and add the `mtu=1400` parameter to the end of each network interface configuration line (requires restarting the LXC afterwards).

## Installation

Install the *PowerDNS* packages for the authoritative server and the *PostgreSQL* backend. Also include the *PostgreSQL* console client:

    apt install pdns-server pdns-backend-pgsql pdns-recursor postgresql-client

Stop the *PowerDNS* services until we have finished configuring them:

    systemctl stop pdns pdns-recursor

## Disable *Systemd’s resolver*

By default, the *Debian* template used to create the LXC where *PowerDNS* is being installed leaves the *Systemd* resolver active, meaning it is listening on port 53. We can check this with the following command:

    ~# netstat --program -all --numeric | grep --word-regexp LISTEN
    tcp        0      0 0.0.0.0:5355            0.0.0.0:*               LISTEN      109/systemd-resolve 
    tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      109/systemd-resolve 
    tcp        0      0 127.0.0.1:25            0.0.0.0:*               LISTEN      279/master          
    tcp6       0      0 :::5355                 :::*                    LISTEN      109/systemd-resolve 
    tcp6       0      0 :::22                   :::*                    LISTEN      1/init              
    tcp6       0      0 ::1:25                  :::*                    LISTEN      279/master

If we check the journal (`journalctl -xe`) we will notice the following error message when *Systemd* tried to start the *PowerDNS* services upon installation of the packages:

    Unable to bind UDP socket to '0.0.0.0:53': Address already in use

So we need to stop and disable the Network Name Resolution (`systemd-resolved`) service in both the primary (`pdns1`) and secondary (`pdns2`) containers:

    systemctl disable --now systemd-resolved

## Back-end database creation

Our first step will be settting up the databases in our existing *PostgreSQL* database servers for the backends of the two authoritative servers:

|  |  |  |  |  |
|----|----|----|----|----|
| **Hostname** | **Description** | **Backend database server** | **Database name** | **Database user name** |
| `pdns1` | Primary nameserver | `postgresql1.andromedant.com` | `pdns1` | `pdns1` |
| `pdns2` | Secondary nameserver | `postgresql2.andromedant.com` | `pdns2` | `pdns2` |

### Primary nameserver

As `postgres` user, execute the following commands on `postgresql1`:

    createuser --no-createdb --no-createrole --no-superuser --pwprompt pdns1
    Enter password for new role: <password>
    Enter it again: <password>

Now create the database:

    createdb --template=template0 --encoding=UTF8 --owner=pdns1 pdns1

As `root` user, edit the file `/etc/postgresql/13/main/pg_hba.conf` to allow access to the database:

    # IPv4 local connections:
    hostssl pdns1           pdns1           192.168.0.113/32        md5
    host    all             all             127.0.0.1/32            md5

Reload the PostgreSQL server for the changes to take effect:

    systemctl reload postgresql

### Secondary nameserver

As `postgres` user, execute the following commands on `postgresqls`:

    createuser --no-createdb --no-createrole --no-superuser --pwprompt pdns2
    Enter password for new role: <password>
    Enter it again: <password>

Now create the database:

    createdb --template=template0 --encoding=UTF8 --owner=pdns2 pdns2

As `root` user, edit the file `/etc/postgresql/13/main/pg_hba.conf` to allow access to the database:

    # IPv4 local connections:
    hostssl pdns2           pdns2           192.168.0.115/32        md5
    host    all             all             127.0.0.1/32            md5

Reload the PostgreSQL server for the changes to take effect:

    systemctl reload postgresql

## Backend firewall

Create aliases for the containers with the *PowerDNS* servers using the `Datacenter: Firewall: Alias` option:

|                    |               |                            |
|--------------------|---------------|----------------------------|
| **Name**           | **IP/CIDR**   | **Comment**                |
| ipv4_private_pdns1 | 192.168.0.113 | pdns1 private IPv4 address |
| ipv4_private_pdns2 | 192.168.0.115 | pdns2 private IPv4 address |

### Primary nameserver

On the `postgresql1` LXC, enable traffic to port 5432 from the `pdns1` host:

|  |  |  |  |  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|----|----|----|----|
| **Level** | **Type** | **Action** | **Macro** | **Interface** | **Protocol** | **Source** | **Source port** | **Destination** | **Destination port** | **Log level** | **Comment** |
| Container | in | ACCEPT | PostgreSQL | net0 |  | ipv4_private_pdns1 |  |  |  | nolog | Allow access from PowerDNS 1 |

### Secondary nameserver

On the `postgresql2` LXC, enable traffic to port 5432 from the `pdns2` host:

|  |  |  |  |  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|----|----|----|----|
| **Level** | **Type** | **Action** | **Macro** | **Interface** | **Protocol** | **Source** | **Source port** | **Destination** | **Destination port** | **Log level** | **Comment** |
| Container | in | ACCEPT | PostgreSQL | net0 |  | ipv4_private_pdns2 |  |  |  | nolog | Allow access from PowerDNS 2 |

## Connection test

To test the connection to the database before diving further into the installation and configuration process, use the `psql` client.

Given that we will be using the verify-full SSL mode, we require the use of the hostname. Since our DNS system is not up and running yet, the console client will be using the static entries in the `/etc/hosts` files.

### Primary nameserver

Test the connection:

    PGSSLROOTCERT=/etc/ssl/certs/ISRG_Root_X1.pem PGSSLMODE=verify-full \
    psql --host=postgresql1.andromedant.com --user=pdns1 --password --dbname=pdns1 --port=5432

### Secondary nameserver

Test the connection:

    PGSSLROOTCERT=/etc/ssl/certs/ISRG_Root_X1.pem PGSSLMODE=verify-full \
    psql --host=postgresql2.andromedant.com --user=pdns2 --password --dbname=pdns2 --port=5432

## Database schema

The schema we will be using to populate the empty database we just created is located in the subdirectory `/usr/share/pdns-backend-pgsql/schema`, as part of the `pdns-backend-pgsql` package.

### Primary nameserver

Execute the following command at `pdns1`:

    PGSSLROOTCERT=/etc/ssl/certs/ISRG_Root_X1.pem PGSSLMODE=verify-full \
    psql --host=postgresql1.andromedant.com --user=pdns1 --password --dbname=pdns1 --port=5432 \
    --file=/usr/share/pdns-backend-pgsql/schema/schema.pgsql.sql

A number of tables and indexes will be created.

### Secondary nameserver

Execute the following command at `pdns2`:

    PGSSLROOTCERT=/etc/ssl/certs/ISRG_Root_X1.pem PGSSLMODE=verify-full \
    psql --host=postgresql2.andromedant.com --user=pdns2 --password --dbname=pdns2 --port=5432 \
    --file=/usr/share/pdns-backend-pgsql/schema/schema.pgsql.sql

## Database credentials

Using the template provided by the `pdns-backend-pgsql` package, we are going to configure the credentials for the authoritative server to access the backend.

### Primary nameserver

Copy the template file to its destination:

    cp /usr/share/doc/pdns-backend-pgsql/examples/gpgsql.conf /etc/powerdns/pdns.d/gpgsql.conf

Then edit it to look like this:

    gpgsql-dbname=pdns1
    gpgsql-extra-connection-parameters=sslmode=verify-full sslrootcert=/etc/ssl/certs/ISRG_Root_X1.pem
    gpgsql-host=postgresql1.andromedant.com
    gpgsql-password=<password>
    gpgsql-port=5432
    gpgsql-user=pdns1

And restrict access to the file:

    chmod 0640 /etc/powerdns/pdns.d/gpgsql.conf
    chgrp pdns /etc/powerdns/pdns.d/gpgsql.conf

### Secondary nameserver

Copy the template file to its destination:

    cp /usr/share/doc/pdns-backend-pgsql/examples/gpgsql.conf /etc/powerdns/pdns.d/gpgsql.conf

Then edit it to look like this:

    gpgsql-dbname=pdns2
    gpgsql-extra-connection-parameters=sslmode=verify-full sslrootcert=/etc/ssl/certs/ISRG_Root_X1.pem
    gpgsql-host=postgresql2.andromedant.com
    gpgsql-password=<password>
    gpgsql-port=5432
    gpgsql-user=pdns2

And restrict access to the file:

    chmod 0640 /etc/powerdns/pdns.d/gpgsql.conf
    chgrp pdns /etc/powerdns/pdns.d/gpgsql.conf

## Authoritative server configuration

The configuration details of the authoritative server of *PowerDNS* are in the file `/etc/powerdns/pdns.conf`. The package version of this file includes these three lines uncommented:

    ~# egrep -e '^[^#]' /etc/powerdns/pdns.conf
    include-dir=/etc/powerdns/pdns.d
    launch=
    security-poll-suffix=

Which is just fine. Explanation:

- The `include` directive allows us to load the file `/etc/powerdns/pdns.d/gpgsql.conf` with the backend details we just configured before.
- The `launch` directive instructs the server about the back-end to use. Since this directive allows concatenation of values and the files ending in `.conf` inside `pdns.d/` are loaded afterwards, the PostgreSQL (`gpgsql`) is already being loaded.
- The directive `security-poll-suffix` instructs the server to query a URL for security updates of the software. The default value is `secpoll.powerdns.com.`. If left empty, no polling takes place. Since we will be getting security updates through the *Debian* packages security mirror, this is the desired configuration.

### Mode of operation

We are going to configure our secondary server as an autosecondary (or superslave). In this [mode of operation](https://doc.powerdns.com/authoritative/modes-of-operation.html), the secondary server will accept any new zone from the primary server (i.e. an autoprimary or supermaster notification). But in order to do so, the following conditions must be met:

- Autosecondary support must be enabled (`superslave=yes`)
- The autoprimary must carry a SOA record for the notified domain (`pdnsutil add-record`).
- The autoprimary IP must be present in the `supermasters` table in the database of the secondary, along with any name that is in the NS set (`pdnsutil add-supermaster` and `pdnsutil add-record`).
- The set of NS records for the domain, as retrieved by the secondary from the autoprimary, must include the name that goes with the IP address in the supermasters table (`pdnsutil add-record`).

These conditions will be progressively met as you progress through the following sections.

### Primary nameserver

Create the `/etc/powerdns/pdns.d/proxmox.conf` file and add the following directives:

    allow-axfr-ips=192.168.0.115/32
    disable-axfr=no
    local-address=192.168.0.113
    log-dns-details=yes
    master=yes

Explanation:

- The `allow-axfr-ips` directive instructs the server about the location of the secondary nameservers (i.e. allows the use of the AFXR protocol, a query type used for the zone transfers, with the specified IP address).
- The `disable-axfr` directive tells the server not to disable the AXFR protocol (i.e. allows zone transfers to other servers).
- The `local-address` directive instructs the daemon to listen only on a specific IP address.
- The `log-dns-details` directive instructs the server to save informative-only, non-erroneous DNS details into the syslog. It is recommended to disable it in high load servers, which is not our case.
- The `master` directive tells the server to act as a primary nameserver.

### Secondary nameserver

Create the `/etc/powerdns/pdns.d/proxmox.conf` file and add the following directives:

    disable-axfr=yes
    local-address=192.168.0.115
    log-dns-details=yes
    slave=yes
    superslave=yes

Explanation:

- The `disable-axfr` directive tells the server to disable the AXFR protocol (i.e. disallows zone transfers to other servers).
- The `local-address` directive instructs the daemon to listen only on a specific IP address.
- The `log-dns-details` directive instructs the server to save informative-only, non-erroneous DNS details into the syslog.
- The `slave` directive tells the server to act as a secondary nameserver.
- The `superslave` directive tells the server to create new zones as they are received from the primary (i.e. automatic provisioning).

Note: `superslave` has been renamed to `autosecondary` in version 4.5.

## Default configuration for the SOA record

A Start Of Authority (SOA) record is a type of resource record in the Domain Name System containing administrative information about the zone, especially regarding zone transfers. The SOA record format is specified in [RFC 1035](https://datatracker.ietf.org/doc/html/rfc1035). All DNS zones need an SOA record in order to conform to IETF standards.

Example of an SOA record:

|  |  |  |
|----|----|----|
| Name | andromedant.com |  |
| Record type | SOA |  |
| MNAME | pdns1.andromedant.com | The primary nameserver for the zone |
| RNAME | hostmaster.andromedant.com | The administrator’s email address \[1\] |
| SERIAL | 1 | A version number for the SOA record |
| REFRESH | 10800 | Amount of seconds secondary servers should wait before asking primary server for updates |
| RETRY | 3600 | Amount of seconds a server should wait for asking an unresponsive primary nameserver for an update again |
| EXPIRE | 604800 | Amount of time a secondary server has to wait without getting a response from the primary before it stops responding to queries for the zone |
| TTL | 3600 | Time to live. How long the resolvers must cache a query before requesting a new one |

We will be initialising the `default-soa-content` directive so that the SOA record is correctly filled in when creating a new zone. The format of this directive is as follows:

    mname rname serial refresh retry expire ttl

### Primary nameserver

Edit the file `/etc/powerdns/pdns.d/proxmox.conf` and add the following content at the beginning:

    default-soa-content=pdns1.@ hostmaster.@ 0 10800 3600 604800 3600

### Secondary nameserver

Although we will only be creating zones in the primary nameserver and the transfer of zones is restricted to happen only from the primary to the secondary, we will be making this change also in the secondary nameserver so that, if needed, it is ready to become the primary.

Edit the file `/etc/powerdns/pdns.d/proxmox.conf` and add the following content at the beginning:

    default-soa-content=pdns2.@ hostmaster.@ 0 10800 3600 604800 3600

## Autoprimary (supermaster)

At the moment we have a primary *PowerDNS* server which is allowed to transfer zones to the IP address of our secondary nameserver (`allow-axfr-ips`), but we have not told the secondary *PowerDNS* server who to consider its master.

Execute the following command in the `pdns2` LXC:

    pdnsutil add-supermaster 192.168.0.113 pdns2.andromedant.com

This will create an entry in the `supermasters` table of the secondary server with the following data:

- The IP address of the DNS master (192.168.0.113)
- The FQDN of the slave server (`pdns2.andromedant.com`)

Be aware that each slave must have its own FQDN as second value.

Note: The `pdns_server` daemon does not need to be running for this command to work. If it were, though, we would need to restart it:

    systemctl restart pdns

Note: the command `add-supermaster` has been renamed to `add-autoprimary` in version 4.5. Two more commands, `remove-autoprimary` and `list-autoprimaries` have been added as well.

## Recursor configuration

The configuration details of the Recursor of *PowerDNS* are in the file /etc/powerdns/recursor.conf. The package version of this file includes these eight lines uncommented:

    ~# egrep -e '^[^#]' /etc/powerdns/recursor.conf 
    config-dir=/etc/powerdns
    hint-file=/usr/share/dns/root.hints
    include-dir=/etc/powerdns/recursor.d
    local-address=127.0.0.1
    lua-config-file=/etc/powerdns/recursor.lua
    public-suffix-list-file=/usr/share/publicsuffix/public_suffix_list.dat
    quiet=yes
    security-poll-suffix=

Explanation:

- The `config-dir` directive sets the base directory for the configuration files.
- The `hint-file` directive points at the file holding the list of root name servers needed to initialize the cache of Internet domain name servers.
- The `include` directive allows us to load additional configuration files located inside `/etc/powerdns/recursor.d/`.
- The `local-address` directive tells the Recursor to only listen on the localhost by default.
- The `lua-config-file` loads the *Debian* default Lua configuration file for the *PowerDNS* Recursor
- The `quiet` directive tells the Recursor not to log queries.
- The directive `security-poll-suffix` instructs the server to query a URL for security updates of the software. The default value is `secpoll.powerdns.com.`. If left empty, no polling takes place. Since we will be getting security updates through the *Debian* packages security mirror, this is the desired configuration.

In order to leave the package maintainer’s file untouched, we will be creating the file `/etc/powerdns/recursor.d/proxmox.conf` with our custom settings.

### Primary nameserver

Create the `/etc/powerdns/recursor.d/proxmox.conf` file and add the following directives:

    forward-zones=andromedant.com=192.168.0.113
    forward-zones+=0.168.192.in-addr.arpa=192.168.0.113
    forward-zones-recurse=.=185.12.64.1;185.12.64.2
    local-address=127.0.0.1,192.168.0.253

### Secondary nameserver

Create the `/etc/powerdns/recursor.d/proxmox.conf` file and add the following directives:

    forward-zones=andromedant.com=192.168.0.115
    forward-zones+=0.168.192.in-addr.arpa=192.168.0.115
    forward-zones-recurse=.=185.12.64.1;185.12.64.2
    local-address=127.0.0.1,192.168.0.254

Explanation:

- The `forward-zones` directive tells the recursor to forward the private domains to the Authoritative Server.
- The `forward-zones-recurse` directive tells the recursor which forwarders (external nameservers) to use when not asked about any other zones.
- The `local-addresses` directive tells the recursor to listen to the localhost and the specific private IP address.

Note: 185.12.64.1 and 185.12.64.2 are Hetzner’s nameservers.

## Nameserver firewall

Both authoritative servers on `pdns1` and `pdns2` need to be able to talk between themselves through port 53. Both recursors need to listen to queries from all client LXC on port 53 as well.

The *PVE Firewall* has a macro named `DNS` that includes both protocols on such port (the DNS system uses them for different purposes). For our convenience, we will be using such macro in a single firewall rule that is open to all the private IP network.

Add the following firewall rules on `pdns1` and `pdns2`:

|  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|
| **Hostname** | **Type** | **Action** | **Macro** | **Interface** | **Source** | **Log level** | **Comment** |
| `pdns1` | in | ACCEPT | DNS | net0 | ipv4_private_pdns2 | nolog | Allow zone transfers from PowerDNS 2 |
| `pdns1` | in | ACCEPT | DNS |  | ipv4_private_guests | nolog | Allow queries from all LXC |
| `pdns2` | in | ACCEPT | DNS | net0 | ipv4_private_pdns1 | nolog | Allow zone transfers from PowerDNS 1 |
| `pdns2` | in | ACCEPT | DNS |  | ipv4_private_guests | nolog | Allow queries from all LXC |

Note: due to the way the PVE Firewall works, do not set the `net2` interface in the rules allowing traffic to the recursor, as traffic seems to come through the `net0`.

## Starting the services

We are now ready to start the daemons of the Authoritative Server and the Recursor.

### Authoritative Server

Execute the following command to start the Authoritative Server (first on the primary nameserver, then on the secondary):

    systemctl start pdns

Check the status of the service:

    systemctl status pdns

Check the IP address and port it is are binded to:

    ~# netstat --program -all --numeric | grep --word-regexp LISTEN
    tcp        0      0 127.0.0.1:5300          0.0.0.0:*               LISTEN      2002/pdns_server    

Check the `syslog` to make sure the backend was loaded properly:

    ~# tail -n 20 /var/log/syslog | ccze -A
    pdns1 systemd[1]: Starting PowerDNS Authoritative Server... 
    pdns1 pdns_server[2650]: Loading '/usr/lib/x86_64-linux-gnu/pdns/libbindbackend.so' 
    pdns1 pdns_server[2650]: Loading '/usr/lib/x86_64-linux-gnu/pdns/libgpgsqlbackend.so' 
    [..]
    pdns1 pdns_server[2650]: Done launching threads, ready to distribute questions 

### Recursor

Execute the following command to start the Recursor (first on the primary nameserver, then on the secondary):

    systemctl start pdns-recursor

Check the status of the service:

    systemctl status pdns-recursor

Check the IP address and port it is are binded to:

    ~# netstat --program -all --numeric | grep --word-regexp LISTEN
    tcp        0      0 127.0.0.1:5300          0.0.0.0:*               LISTEN      2650/pdns_server    
    tcp        0      0 0.0.0.0:53              0.0.0.0:*               LISTEN      2777/pdns_recursor  
    tcp6       0      0 :::53                   :::*                    LISTEN      2777/pdns_recursor 

## Creating the forward DNS zone

We are now ready to use the included `pdnsutil` command-line utility to manage DNS zones.

### Introduction

We have two options when creating an internal DNS zone for the containers in our cluster:

1.  Use split-horizon DNS (also known as split-view DNS). This forces us to create and maintain an `andromedant.com` zone in the *PowerDNS* installation for all our internal names and use an external provider (such as *Cloudflare* or Hetzner’s) for the public DNS zone of the same name.
2.  Use a subdomain of the `andromedant.com` domain. This would ensure that our internal DNS handles all queries of our internal resources (i.e. LXC) on our private network while it forwards any request for external resources to the external DNS servers.

Given the way that we configured \[\[Configuration_of_Let’s_Encrypt’s_Certbot_on_Debian_11_Bullseye\|Certbot\]\] and \[\[Configuration_of_Ansible_210_on_Debian_11_Bullseye\|Ansible\]\] to automatically renew and deploy our wildcard certificate \*.andromedant.com on all the containers of our cluster, we will be using the spli-view option.

### Base zone and nameservers

Create the new DNS zone:

    pdnsutil create-zone andromedant.com

Create the nameservers for the zone and assign them their respective IP addresses:

    pdnsutil add-record andromedant.com pdns1 A 192.168.0.113
    pdnsutil add-record andromedant.com pdns2 A 192.168.0.115
    pdnsutil add-record andromedant.com @ NS pdns1.andromedant.com
    pdnsutil add-record andromedant.com @ NS pdns2.andromedant.com

### A records

Now we can start adding all the type-A records for all our LXC in the cluster:

    pdnsutil add-record andromedant.com postgresql1 A 192.168.0.100
    pdnsutil add-record andromedant.com mongodb1 A 192.168.0.101
    pdnsutil add-record andromedant.com webserver1 A 192.168.0.102
    pdnsutil add-record andromedant.com mongodb2 A 192.168.0.103
    pdnsutil add-record andromedant.com postgresql2 A 192.168.0.104
    pdnsutil add-record andromedant.com mysql1 A 192.168.0.105
    pdnsutil add-record andromedant.com ansible A 192.168.0.106
    pdnsutil add-record andromedant.com mysql2 A 192.168.0.107
    pdnsutil add-record andromedant.com minio1 A 192.168.0.108
    pdnsutil add-record andromedant.com postgresl3 A 192.168.0.109
    pdnsutil add-record andromedant.com mysql3 A 192.168.0.110
    pdnsutil add-record andromedant.com mongodb3 A 192.168.0.111
    pdnsutil add-record andromedant.com devel1 A 192.168.0.112
    pdnsutil add-record andromedant.com prometheus1 A 192.168.0.114

### Mail eXchange records

To create a mail exchange record, use the following command:

    pdnsutil add-record proxmox.andromedant.com mx1 A 192.168.0.1xx
    pdnsutil add-record proxmox.andromedant.com @ MX "10 mx1.andromedant.com"

### SOA record

Should we had not initialised the `default-soa-content` directive in the `/etc/powerdns/pdns.d/soa.conf` file before creating the zone, when listing the zone we would have noticed a misconfigured SOA record:

    ~# pdnsutil list-zone andromedant.com
    andromedant.com 3600 IN NS  pdns1.andromedant.com.
    andromedant.com 3600 IN SOA a.misconfigured.dns.server.invalid hostmaster.andromedant.com 0 10800 3600 604800 3600
    [..]

At the moment of writing, once the zone has been created, the only way to edit the SOA record is manually:

    pdnsutil edit-zone andromedant.com

### Serial number

Finally, increase the serial number (or version number) of the SOA record for the first time:

    ~# pdnsutil increase-serial andromedant.com
    [bindbackend] Done parsing domains, 0 rejected, 0 new, 0 removed
    SOA serial for zone andromedant.com set to 1

Now the zone is ready to be used and transferred to secondary servers:

    pdns_control notify andromedant.com

## Creating the reverse DNS zone

A reverse lookup zone is the same as the forward zone we just created before but aimed at resolving DNS queries the other way around, that is, asking for the name of an IP address.

For that, first we need to create a zone for our `192.168.0.0/24` private IP network:

    pdnsutil create-zone 0.168.192.in-addr.arpa

Add the nameservers for the newly created zone:

    pdnsutil add-record 0.168.192.in-addr.arpa @ NS pdns1.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa @ NS pdns2.andromedant.com

Add the pointer (PTR) records for the containers in the cluster to match domain names with IP addresses:

    pdnsutil add-record 0.168.192.in-addr.arpa 100 PTR postgresql1.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 101 PTR mongodb1.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 102 PTR webserver1.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 103 PTR mongodb2.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 104 PTR postgresql2.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 105 PTR mysql1.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 106 PTR ansible.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 107 PTR mysql2.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 108 PTR minio1.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 109 PTR postgresl3.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 110 PTR mysql3.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 111 PTR mongodb3.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 112 PTR devel1.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 113 PTR pdns1.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 114 PTR prometheus1.andromedant.com
    pdnsutil add-record 0.168.192.in-addr.arpa 115 PTR pdns2.andromedant.com

We can now list the zone to see how it looks like:

    pdnsutil list-zone 0.168.192.in-addr.arpa

J
