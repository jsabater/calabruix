# How the Proxmox cluster is set up

_Created on 2026-05-20. Last updated on 2026-05-27._

This document serves as an introduction to how things are configured and meant to be used in the Proxmox cluster. However, it does not include installation or configuration instructions. For that, check the other documents in the [Proxmox category of the wiki index](/projects/andronautic/wiki/Wiki#Proxmox).

To understand the design decisions when this cluster was configured, check the following documents, too:

* [[Installation of a Proxmox Virtual Environment 7 cluster on Hetzner]].
* [[Installation of a Proxmox Backup Server on Hetzner]].
* [[Configuration of a Proxmox Mail Gateway 7 on Debian 11 Bullseye]].
* [[Restore dump of nomad onto Proxmox]].

## Proxmox cluster

At the moment, the Proxmox cluster consists of:

* A Proxmox Virtual Environment of 10 nodes.
* A primary Proxmox Backup Server.
* A secondary Proxmox Backup Server.

The main hosting provider is [Hetzner](https://accounts.hetzner.com/), where the whole PVE cluster nodes and the primary PBS server are located. Credentials, including OTP, are available at Bitwarden. We use two locations:

* Helsinki, Findland, for the nodes that have staging environments or support tools, e.g., Matomo, Metabase, Prometheus, etc. The primary backup server is also located there.
* Falkland, Germany, for the main nodes of the PVE.

> You can see the location of each node at the [Hetzner Robot servers page](https://robot.hetzner.com/server).

In short, nodex `proxmox5` and `proxmox10`, as well as the primary PBS server `pbs2` are located in Finland, whereas the rest is in Germany.


### Access to the cluster

Access to the cluster can be done in serveral ways. The first way is via [the WebGUI](https://proxmox10.andromedant.com:8006/). Two types of users:

* The `root` account on the `pam` realm, which has different credentials for each node (available at Bitwarden, including the OTP). This is the account with the most permissions and no restrictions. You are actually logging in with the `root` account of the system.
* An administrator acoount (individual) on the `pve` realm. Available users can be seen and managed via the `Datacenter > Permissions > Users` menu option in the WebGUI, when logged in as `root@pam`. These users belong to the `sysadmin` group and have all roles, but they do not have access to the shell of the node via the WebGUI (only the `root@pam` user does).

> Any node from `proxmox1` to `proxmox10` is the same when accessing the WebGUI.

Another way to access the cluster nodes is via SSH. Each node has a different port configured, starting with `proxmox1` at `2231`, then `proxmox2` at `2232`, and so on. Allowed SSH keys are (available at Bitwarden):

* The Ansible key (ED25519 format), so playbooks executed at the Ansible Controller can have access to the nodes, e.g., to install the Prometheus PVE Exporter.
* The Andromeda Solutions key (ED25519 format), which is the master key to all servers.

> Nodes use SSH for certain operations, so the `.ssh/authorized_keys` file also includes the SSH keys of the root account of each node (different keys), in RSA format.


### Networks of the cluster

Each node has one public, static IP address and three virtual bridges, as explained in the [[Installation of a Proxmox Virtual Environment 7 cluster on Hetzner]] document. Each virtual bridge uses one virtual switch configured at the [Hetzner Robot vswitches page](https://robot.hetzner.com/vswitch/index):


* `vmbr4001` is the virtual bridge for the floating public IP addresses used by the guests.
* `vmbr4002` is the virtual bridge for the local network of the guests, in the `192.168.0.0/24` range.
* `vmbr4003` is the virtual bridge for the local network of the hosts, in the `192.168.1.0/24` range.

The local network of the guests should use the `10.0.0.0/8` network. Migration has not yet been done because:

1. It is a delicate, time-consuming process.
2. The limit has not yet been reached (there are still available IP addresses).
3. Customers should be moved to a Hetzner VPS each (including NGINX, Gunicorn, PostgreSQL and Redis).


### IP addresses of nodes

The PVE nodes have the following static, public and private IP addresses:

| Node        | Public CIDR        | Gateway         | Private CIDR      |
|-------------|--------------------|-----------------|-------------------|
| `proxmox1`  | `88.99.93.182/24`  | `88.99.93.129`  | `192.168.1.11/24` |
| `proxmox2`  | `46.4.119.240/27`  | `46.4.119.225`  | `192.168.1.12/24` |
| `proxmox3`  | `78.46.88.45/27`   | `78.46.88.33`   | `192.168.1.13/24` |
| `proxmox4`  | `178.63.0.104/26`  | `178.63.0.65`   | `192.168.1.14/24` |
| `proxmox5`  | `95.216.23.53/26`  | `95.216.23.1`   | `192.168.1.15/24` |
| `proxmox6`  | `178.63.41.48/26`  | `178.63.41.1`   | `192.168.1.16/24` |
| `proxmox7`  | `159.69.66.197/26` | `159.69.66.193` | `192.168.1.17/24` |
| `proxmox8`  | `46.4.84.154/27`   | `46.4.84.129`   | `192.168.1.18/24` |
| `proxmox9`  | `162.55.95.85`     | `162.55.95.65`  | `192.168.1.19/24` |
| `proxmox10` | `95.216.246.50`    | `95.216.246.1`  | `192.168.1.20/24` |

> Private IP addresses of nodes communicate over the `vmbr4003` virtual bridge.


### IP addresses of guests

Two subnets of floating public IP addresses for the guests are available (more can be ordered via the virtual switches control panel):

| Subnet              | Gateway          | Netmask           | Broadcast        | Usable IP addresses                  |
|---------------------|------------------|-------------------|------------------|--------------------------------------|
| `116.202.120.32/28` | `116.202.120.33` | `255.255.255.240` | `116.202.120.47` | `116.202.120.34` to `116.202.120.46` |
| `49.13.106.48/28`   | `49.13.106.49`   | `255.255.255.240` | `49.13.106.63`   | `49.13.106.50` to `49.13.106.62`     |

At the moment of writing, these floating, public IP addresses used by the guests are assigned as follows:


| IP address       | CTID | Hostname      |
|------------------|------|---------------|
| `116.202.120.34` | 118  | `pmg1`        |
| `116.202.120.35` | 102  | `nginx1`      |
| `116.202.120.36` | 202  | `tinyproxy1`  |
| `116.202.120.38` | 153  | `storm2`      |
| `116.202.120.39` | 190  | `cepheus1`    |
| `116.202.120.41` | 174  | `nginx3`      |
| `116.202.120.42` | 251  | `storm1`      |
| `116.202.120.43` | 201  | `cepheus2`    |
| `116.202.120.44` | 106  | `ansible`     |
| `116.202.120.45` | 113  | `nginx2`      |
| `116.202.120.46` | 115  | `socksproxy1` |
| `49.13.106.50`   | 239  | `pdns4`       |
| `49.13.106.51`   | 241  | `pdns6`       |
| `49.13.106.52`   | 243  | `aptcacher1`  |
| `49.13.106.53`   | 244  | `ssh1`        |
| `49.13.106.54`   | 245  | `nomad1`      |
| `49.13.106.55`   | 114  | `prometheus1` |
| `49.13.106.61`   | 103  | `mongodb2`    |


### Incoming and outgoing connections

All guests have a private IP address of the subnetwork `192.168.0.0/24` on the `net0` device  for internal communications (over the `vmbr4002`). Then some guests also have a floating, public IP address on the `net1` network device (over the `vmbr4001`).

A guest has a public IP address assigned to it for two reasons:

* Receive incoming traffic. NGINX hosts have one as they act as reverse proxies, routing traffic to upstream servers (MinIO, Gunicorn, Jetty, PHP FPM, etc).
* Send requests through the Internet. Some hosts cannot use a proxy (HTTP/SOCKS), or it makes life easier to have direct access.

There are a variety of use cases, described next:

* `prometheus1` has a public IP address so that it can access the public IP address of the nodes to pull data from the PVE exporters.
* `pmg1` needs to contact the Gmail relayhost to send emails.
* `tinyproxy1` needs to contact whatever destination a guest is trying to reach.
* `cepheus1` and `cepheus2` are internal APIs with helper methods for Popeye that require Python 3, so they need public IP addresses to access the Internet.
* `socksproxy1` is a SOCKS 4/5 proxy that was made available for Cepheus so they did not have to use a public IP address, but the migration was never done.

Regarding the NGINX reverse proxies:

* `nginx1` is the downstream server for all the Black Pearl application servers, as well as their buckets on MinIO.
* `nginx2` is the downstream server for the live environment of Popeye, including the four Gunicorn application servers as well as the NGINX web server on `nomad1`.
* `nginx3` serves everything else: Popeye (`test`), Matomo, Metabase, Grafana, and Redmine.

Regarding Popeye: 

* `nomad1` is a copy of `nomad0`, therefore it works "as it did" (self-reliant, monolithic VM with everything in it). Only three major changes were made, as described in the [[Restore dump of nomad onto Proxmox]] document:

  * Packages were upgraded to their latest versions within Ubuntu 18.04.
  * Gunicorn servers get parametres from the systemd service file.
  * The NGINX reverse proxy was moved to `nginx2`, although it still uses a local NGINX web server for the static contents.
* `storm1` and `storm2` are copies of `nomad1` but adapted to the test environment.

Neither of these three VMs use any sort of HTTP or SOCKS proxy to reach the Internet.

## Backups

Two different tools are used for backups:

1. Proxmox Backup Server.
2. BASH scripts.

Three storages are used:

1. HDD disks with a ZFS mirror on the backup servers.
2. Storage Box on Hetzner (Germany).
3. Remote disk space on BorgBase (USA).


### Proxmox Backup Server

There are two Proxmox Backup Server nodes, a primary with Hetzner in Germany and a secondary with OVH in France. Both can be accessed using two methods:

1. Via SSH, at `pbs1.andromedant.com` (OVH) and `pbs2.andromedant.com` (Hetzner), using the same keys as the PVE nodes (Ansible key and Andromeda Solutions key). Ports are, respectively, `2221` and `2222`.

2. Using the WebGUI, on port 8007, for [the primary backup server](https://pbs2.andromedant.com:8007/) and for [the secondary backup server](https://pbs1.andromedant.com:8007/). Only the `root@pam` user exists. Credentials are available at Bitwarden, including the OTP.

> Note that the primary is `pbs2` and is located at Hetzner, whereas the secondary is `pbs1` and is located at OVH.

The primary, `pbs2`, can be accessed by the PVE nodes via the private network of the nodes, `192.168.1.0/24`. This network is used for the backups, not the public IP addresses.

The secondary is connected to the primary [as a remote](https://pbs.proxmox.com/docs/managing-remotes.html#remote) and uses [a sync job](https://pbs.proxmox.com/docs/managing-remotes.html#sync-jobs) to synchronise the contents once a day, therefore acting as a duplicate. The secondary backup server is not connected to the local network of the cluster nodes, though, so synchronisation jobs happen over the public IP address.

### BASH scripts

The PostgreSQL database of the Popeye project sits on a VM, both for production and staging. A weekly backup of the production one is done using Proxmox Backup Server, but daily backups are done using a BASH script that:

1. Uses `pg_dump` to dump the whole database. A separate partition is used for the backups, mounted at `/mnt/backups/`.
2. Uses Borg over SSH (via `sshproxy1`) to copy the dump to Hetzner's Storage Box.
3. Uses Borg over SSH (via `sshproxy1`) to copy the dump to BorgBase.

The PostgreSQL server of the Black Pearl applications is `postgresql4`. This LXC also uses a BASH script for daily backups:

1. Uses `pg_dump` to dump all the databases. No separate partition at the moment.
2. Uses Borg over SSH (via `sshproxy1`) to copy the dump to Hetzner's Storage Box.
3. Uses Borg over SSH (via `sshproxy1`) to copy the dump to BorgBase.

The PostgreSQL server for the rest of services (Metabase, Metabase Warehouse, Grafana and Redmine) is `postgresql3` and it uses the same method as `postgresql4`.

Regarding MongoDB servers for Popeye, there is `mongodb2` for Popeye Live`. Daily backups of it are done using a BASH script, also following the same procedure as with `postgresql3` and `postgresql4`.

Moreover, VMs with MongoDB for both environments of Popeye exist, and the test environment already uses it. Migration of the `live` MongoDB of Popeye is pending a deletion of all the unused space. After that, daily scripts should still be used, with a weekly backup of the VM using PBS, similarly to what is being done with PostgreSQL (`postgresql01-popeye-prod`).


Finally, MySQL is, at the moment, used only for Matomo, and a daily copy of it is done using Proxmox Backup Server. Since the database sits on a ZFS pool, snapshot mode can be used.

All these scripts are automatically configured by the Ansible playbooks that set up PostgreSQL and MongoDB instances across the cluster, named `plays/setup-postgresql.yml` and `plays/setup-mongodb.yml`. Configuration of cron jobs is done according to the information in the files inside `inventory/host_vars/`.


## Ansible

The guests in the cluster are managed from the Ansible Controller, which is the LXC with id 106 and has hostname `ansible.andromedant.com` (port 22). It can only be reached from the list of IP addresses in the `management` IPSet (`Datacenter > Firewall > IPSet` and `Datacenter > Firewall > Alias`, then `Datacenter > 106 > Firewall`).

This LXC has access to all guests and nodes in the cluster via the `~/.ssh/ansible` SSH key. It serves as the orchestrator or management central point of the cluster:

* Ansible Controller. Ansible playbooks and Pyinfra scripts are executed from it.
* Bastion host. Developers that need to access the cluster use it when working from the office or from home.
* Job runner. A number of *systemd* timers are configured (see below) to perform a variety of tasks across the cluster.

When a developer needs to change its remote IP address, he changes the value of the corresponding alias in the `Datacenter > Firewall > Alias` option of the WebGUI, accessing with his named account, or using the `root@pam` account (credentials on Bitwarden).

Both Ansible and Pyinfra are available in the same repository, since the latter imports the inventory from the former. The repository name is [AndromedaSolutions/automation](https://github.com/AndromedaSolutions/automation) and has three distinct blocks:

* `pyinfra/`, with the Pyinfra projects `blackpearl/` and `popeye/`.
* `ansible/proxmox/`, with the Ansible inventory and playbooks for the guests and hosts of the Proxmox cluster.
* `ansible/filter_plugins/`, with the custom Ansible plug-ins to be used in the previous project.

### Ansible inventory

The Ansible inventory inside the `ansible/proxmox/` Ansible project is arranged as follows:

```
ansible/proxmox/
├── ansible.cfg             # Main options
├── filter_plugins          # Custom plug-ins
├── inventory               # Inventory files, one file per group
│   ├── group_vars          # Group variables
│   │   ├── all             # Special group 'all'
│   │   │   ├── vars.yml    # Variables of the special group 'all'
│   │   │   └── vault.yml   # Ansible vault
│   └── host_vars           # Host variables, one file per host
├── plays                   # Directory with all the playbooks
│   ├── files               # Custom files used by playbooks
│   ├── handlers            # Handlers for the playbooks
│   ├── tasks               # Tasks imported by playbooks
│   ├── templates           # Templates used by tasks in playbooks
│   └── vars                # Variables used in playbooks
├── requirements.txt        # Python dependencies
└── requirements.yml        # Ansible dependencies
```

> All collections used in playbooks are included by default in the Ansible version defined in the `requirements.txt` file, so the list in the `requirements.yml` is just for reference, not actually used.

Ansible inventory files inside `inventory/`, and their corresponding group variables inside `inventory/group_vars/` roughly correspond to the services run in the cluster, one file per group, where the name of the file corresponds to the name of the group defined inside, albeit it can have subgroups:

| File                        | Purpose                   | Pool
|-----------------------------|---------------------------|------------------|
| `andronautic.yml`           | Old website               | Junk             |
| `ansible.yml`               | Ansible Controller        | Cluster services |
| `aptcacher.yml`             | APT-Cacher-NG             | Cluster services |
| `beanstalk.yml`             | Beanstalkd work queues    | Popeye           |
| `blackpearl.yml`            | Black Pearl apps          | Black Pearl      |
| `cepheus.yml`               | Cepheus API               | Popeye           |
| `clickandboat.yml`          | Click and Boat API        | Popeye           |
| `grafana.yml`               | Grafana dashboards        | Analytics        |
| `loki.yml`                  | Loki server               | Analytics        |
| `matomo.yml`                | Matomo Analytics          | Analytics        |
| `metabase.yml`              | Metabase BI               | Analytics        |
| `minio.yml`                 | MinIO Object storages     | Databases        |
| `mongodb.yml`               | MongoDB servers           | Databases        |
| `mysql.yml`                 | MySQL servers             | Databases        |
| `nfs.yml`                   | NFS servers               | Databases        |
| `nginx.yml`                 | NGINX reverse proxies     | NGINX            |
| `pbs.yml`                   | Proxmox Backup servers    | Cluster services |
| `pdns.yml`                  | PowerDNS DNS servers      | Cluster services |
| `pmg.yml`                   | Proxmox Mail Gateway      | Cluster services |
| `popeye-customisations.yml` | Subdomain customisations  | Popeye           |
| `popeye.yml`                | Popeye apps               | Popeye           |
| `postgresql.yml`            | PostgreSQL servers        | Databases        |
| `prometheus.yml`            | Prometheus server         | Analytics        |
| `pve.yml`                   | Proxmox VE nodes          | Cluster services |
| `redis.yml`                 | Redis servers             | Databases        |
| `redmine.yml`               | Redmine PM apps           | Junk             |
| `socksproxy.yml`            | SOCKS proxy               | Cluster services |
| `sshproxy.yml`              | SSH proxy                 | Cluster services |
| `tinyproxy.yml`             | HTTP proxy                | Cluster services |

### Ansible playbooks

There should be at least one playbook to set up the services provided by each Ansible inventory group, but some of them have multiple playbooks, either because old versions are kept or because of the complexity and variety of the process.

All playbooks are located inside the `plays/` sub-directory. Most playbooks are split into blocks of tasks, and each block is imported from a separate file inside `plays/tasks/`, organised in sub-directories that generally match the inventory filename.

Templates used by tasks are organised in the same manner inside `plays/templates/`, and handlers are all inside `plays/handlers/`. Handlers are organised by service name or inventory group.

Playbook names are usually prefixed with a word to help understand what is their purpose. This is the list of the most important and most used playbooks, by group:

**Black Pearl**

| Playbook                               | Purpose                                             |
|----------------------------------------|-----------------------------------------------------|
| `blackpearl-cache-flush.yml`           | Flush Redis cache                                   |
| `blackpearl-cache-info.yml`            | Get Redis cache info                                |
| `blackpearl-cache-load.yml`            | Parse sitemap.xml and send GET requests to all URLs |
| `blackpearl-cert-issue.yml`            | Issue new Let's Encrypt TLS certificate             |
| `blackpearl-cert-renew.yml`            | Renew existing Let's Encrypt TLS certificate        |
| `blackpearl-delete.yml`                | Make a backup and delete an app and host            |
| `blackpearl-deploy.yml`                | Main deploy script                                  |
| `blackpearl-query.yml`                 | Execute a SQL query on the app database             |
| `blackpearl-regenerate.yml`            | Refresh zones, boats and activities                 |
| `blackpearl-setup.yml`                 | Set up the environment on a newly-provisioned LXC   |
| `setup-warehouse.yml`                  | Set up the intermediate warehouse database          |

**Cluster services**

| Playbook                               | Purpose                                             |
|----------------------------------------|-----------------------------------------------------|
| `provision.yml`                        | Provision a new guest (LXC or VM)                   |
| `configure.yml`                        | Configure a newly-provisioned guest                 |
| `update-lxc.yml`                       | Update resources of a LXC                           |
| `setup-aptcacher.yml`                  | Install and configure the APT-Cacher-NG service     |
| `setup-danted.yml`                     | Install and configure the SOCKS proxy service       |
| `setup-grafana.yml`                    | Install and configure the Grafana service           |
| `setup-loki.yml`                       | Install and configure the Loki server               |
| `setup-matomo.yml`                     | Install and configure Matomo Analytics services     |
| `setup-metabase.yml`                   | Install and configure Metabase BI service           |
| `setup-minio.yml`                      | Install and configure MinIO S3 service              |
| `setup-mongodb.yml`                    | Install and configure MongoDB servers               |
| `setup-mysql.yml`                      | Install and configure MySQL servers                 |
| `setup-nginx.yml`                      | Install and configure the NGINX reverse proxies     |
| `setup-pdns.yml`                       | Install and configure the PowerDNS server           |
| `setup-pmg.yml`                        | Install and configure Proxmox Mail Gateway server   |
| `setup-postgresql.yml`                 | Install and configure PostgreSQL servers            |
| `setup-prometheus-exporters.yml`       | Install and configure Prometheus exporters          |
| `setup-prometheus.yml`                 | Install and configure the Prometheus server         |
| `setup-promtail.yml`                   | Install and configure the Promtail agents           |
| `setup-redmine.yml`                    | Install and configure the Redmine 5 issue tracker   |
| `setup-sshproxy.yml`                   | Install and configure the SSH proxy service         |
| `setup-tinyproxy.yml`                  | Install and configure the HTTP proxy for guests     |


**Popeye**

| Playbook                               | Purpose                                                              |
|----------------------------------------|----------------------------------------------------------------------|
| `cepheus-deploy.yml`                   | Deploy a new version of Cepheus/Cetus                                |
| `popeye-customisations-cert-issue.yml` | Issue new Let's Encrypt TLS certificates for custom subdomains       |
| `popeye-customisations-cert-renew.yml` | Renew existing Let's Encrypt TLS certificates for custom subdomains  |
| `popeye-live2test-db.yml`              | Restore the last backup of the live database in the test environment |
| `popeye-live2test-media.yml`           | Synchronise all media files from live to test                        |
| `popeye-live2test-stop-services.yml`   | Stop all services on the test environment                            |
| `popeye-metabase.yml`                  | Configure a read-only user for Metabase to access the live database  |
| `popeye-migration-mongodb.yml`         | Ad-hoc migration playbook for MongoDB                                |
| `popeye-migration-postgresql.yml`      | Ad-hoc migration playbook for PostgreSQL                             |
| `popeye-nginx.yml`                     | Set up NGINX server blocks                                           |
| `setup-beanstalk.yml`                  | Set up the Beanstalkd work queue service                             |
| `setup-clickandboat.yml`               | Set up the Click & Boat API service                                  |
| `setup-redis.yml`                      | Set up the Redis cache service                                       |


**Utilities**

| Playbook                               | Purpose                                                                 |
|----------------------------------------|-------------------------------------------------------------------------|
| `certs-certificates.yml`               | List installed certs on ~/letsencrypt/etc and check their validity      |
| `certs-deploy.yml`                     | Deploy local and public domain wildcard certificates across the cluster |
| `mac-addresses-per-node.yml`           | Check used MAC addresses per node and report to Slack                   |
| `pdns-flush-zone.yml`                  | Flush a DNS zone in PowerDNS                                            |
| `pdns-restart.yml`                     | Restart the PowerDNS recursors                                          |
| `pgreports.yml`                        | Gather and publish pgBadger reports from all PostgreSQL servers         |
| `refresh-prometheus.yml`               | Update the list of hosts monitored by Prometheus                        |
| `refresh-warehouse.yml`                | Update the existing data in the Metabase Warehouse database             |

## Automated jobs

The following cron jobs and systemd timers are configured across guests in the Proxmox cluster (all in UTC), ordered by start time:

| Guest hostname             | MM HH  | Script or service                        | Purpose                                                   |
|----------------------------|--------|------------------------------------------|-----------------------------------------------------------|
| `minio1`                   | `15 0` | `backup`                                 | Back up MinIO buckets using Borg                          |
| `postgresql3`              | `00 1` | `backup`                                 | Back up PostgreSQL databases using Borg                   |
| `postgresql01-popeye-prod` | `30 1` | `backup`                                 | Back up PostgreSQL database using Borg                    |
| `postgresql4`              | `30 2` | `backup`                                 | Back up Black Pearl databases using Borg                  |
| `mongodb2`                 | `30 3` | `backup`                                 | Back up MongoDB databases using Borg                      |
| `postgresql01-popeye-prod` | `00 3` | `pgbadgerdaily`                          | Generate daily pgBadger reports                           |
| `postgresql3`              | `00 3` | `pgbadgerdaily`                          | Generate daily pgBadger reports                           |
| `postgresql4`              | `00 3` | `pgbadgerdaily`                          | Generate daily pgBadger reports                           |
| `postgresql01-popeye-prod` | `00 4` | `pgbadgermonthly`                        | Generate monthly pgBadger reports                         |
| `postgresql3`              | `00 4` | `pgbadgermonthly`                        | Generate monthly pgBadger reports                         |
| `postgresql4`              | `00 4` | `pgbadgermonthly`                        | Generate monthly pgBadger reports                         |
| `ansible1`                 | `01 0` | `mac-addresses.timer`                    | Run playbook `plays/mac-addresses-per-node.yml`           |
| `ansible1`                 | `15 4` | `certs-certificates.timer`               | Run playbook `plays/certs-certificates.yml`               |
| `ansible1`                 | `30 4` | `certbot.timer`                          | Run Certbot renewals                                      |
| `ansible1`                 | `00 5` | `pgreports.timer`                        | Run playbook `plays/pgreports.yml`                        |
| `ansible1`                 | `15 5` | `warehouse.timer`                        | Run playbook `plays/refresh-warehouse.yml`                |
| `ansible1`                 | `30 5` | `prometheus-refresh.timer`               | Run playbook `plays/refresh-prometheus.yml`               |
| `ansible1`                 | `35 5` | `popeye-customisations-cert-renew.timer` | Run playbook `plays/popeye-customisations-cert-renew.yml` |
| `ansible1`                 | `45 5` | `blackpearl-cert-renew.timer`            | Run playbook `plays/blackpearl-cert-renew.yml`            |


Most, if not all, these jobs are set up by Ansible playbooks using templates available inside `plays/templates/`.
