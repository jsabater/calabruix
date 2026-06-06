# Configuration of a Proxmox Mail Gateway 7 on Debian 11 Bullseye

*Created on 2022-08-02. Last updated on 2023-11-20.*

Based on Debian 11 Bullseye x86_64 running in a Linux Container (LXC) on Proxmox 7.

This tutorial deploys the [Proxmox Mail Gateway](https://www.proxmox.com/en/proxmox-mail-gateway) (\_PMG\_), a fully featured mail proxy including spam and virus detection that allows to control all email traffic from a single platform, in a LinuX Container running Debian 11 Bullseye on a Proxmox cluster.

All LXC in the Proxmox cluster will be configured to use *PMG* as a relayhost. In turn, *PMG* will be configured to relay all incoming traffic to an external relayhost, in control of the electronic mail of the domain the cluster uses, e.g. Google Suite.

    LXC -> PMG -> Google Suite

## Base system configuration

Follow the steps in the \[\[Debian Bullseye 11 LXC base system configuration\]\] tutorial to create an LXC named `pmg1`.

## Installation

*Proxmox Mail Gateway* will be installed on top of the existing Debian installation, which currently has one private IPv4 as well as one public IPv4 address.

Install some recommended packages from the [Debian non-free](https://www.debian.org/doc/debian-policy/ch-archive#the-non-free-archive-area) repository in order to support the RAR archive format:

    apt install libclamunrar p7zip-rar

Add the Proxmox repository to `/etc/apt/sources.list.d/` and its key to `/etc/apt/trusted.gpg.d/`:

    echo "deb http://download.proxmox.com/debian/pmg bullseye pmg-no-subscription" > /etc/apt/sources.list.d/pmg-install-repo.list
    wget http://download.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg

Update the packages information and install *PMG* (container version):

    apt update
    apt install proxmox-mailgateway-container

Comment the existing line in the file `/etc/apt/sources.list.d/pmg-enterprise.list`, which has been added by the installation:

    # deb https://enterprise.proxmox.com/debian/pmg bullseye pmg-enterprise

## Firewall

Create an alias for the container with the *PMG* installation using the `Datacenter: Firewall: Alias` option:

|  |  |  |
|----|----|----|
| **Name** | **IP/CIDR** | **Comment** |
| ipv4_private_pmg1 | 192.168.0.118 | Proxmox Mail Gateway 1 private IPv4 address |

Then add the following firewall rule to the container to allow access to the management WebGUI:

|  |  |  |  |  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|----|----|----|----|
| **Level** | **Type** | **Action** | **Macro** | **Interface** | **Protocol** | **Source** | **Source port** | **Destination** | **Destination port** | **Log level** | **Comment** |
| Container | in | ACCEPT |  | net1 | tcp | +ipv4_management |  |  | 8006 | nolog | Allow access to WebGUI from management IPs |

## Host certificate

Access to the web-based administration interface is always encrypted through HTTPS. Each Proxmox Mail Gateway host creates by default its own self-signed certificate, which is used for encrypted communication with the host’s `pmgproxy` service and for any API call between a user and the web-interface.

Proxmox Mail Gateway uses two different certificates:

- `/etc/pmg/pmg-api.pem`: the required certificate used for Proxmox Mail Gateway API requests and access to the WebGUI.
- `/etc/pmg/pmg-tls.pem`: the optional certificate used for SMTP TLS connections.

We will use Let’s Encrypt (ACME) using its protocol implementation inside PMG. Go to `Configuration: Certificates: ACME accounts/challenges: Add` and add an account:

- Name: Andromeda.
- Email: sysadmin@andromedant.com

We will be adding an additional challenge using DNS by using the button labelled “Add” right below the “Challenge Plugins” section:

- Plugin id: cloudflare
- Validation delay: 30
- DNS API: Cloudflare Managed DNS
- Account id: \[..\]
- Token: \[..\]
- Zone id: \[..\]

The account id and zone id can be copied from the bottom right corner of the `andromedant.com` domain overview page at [Cloudflare’s dashboard](https://dash.cloudflare.com/). The API token can be obtained (with finegrained permissions) at the [API Tokens menu option](https://dash.cloudflare.com/profile/api-tokens) of the user’s profile.

Go to `Configuration: Certificates: Certificates: ACME` and use the “Add” button to add the certificate request data:

- Challenge type: DNS
- Plug-in: cloudflare
- Domain: pmg1.andromedant.com
- Usage: API

Select the account that will be used to order the certificate by choosing “Andromeda” in the `Configuration: Certificates: Certificates: ACME: Using account", then use the `Order certificates now@ button to order the API certificate. The WebGUI will automatically reload the current page on the browser once the process is finished.

## Google Mail configuration

We need to configure Google Mail to act as a relayhost. To do so, we will use the [Route outgoing SMTP relay messages through Google](https://support.google.com/a/answer/2956491?hl=en) as reference.

Log into the [Google Admin console](https://admin.google.com/) as an administrator, then go to `Menu: Apps: Google Workspace: Gmail`, then click on the [Routing](https://admin.google.com/u/1/ac/apps/gmail/routing?hl=en) option.

Scroll down to the `SMTP relay service` option and and click `Configure`, or `Edit` if there is an existing configuration. Fill in the following options:

- Name: Proxmox Mail Gateway
- Allowed Senders: Select *Any addresses*. \[1\]
- Authentication: Tick *Only accept mail from the specified IP addresses* and add the public IP addresses in the table following this list.
- Encryption: Tick *Require TLS encryption*.

|                          |                      |
|--------------------------|----------------------|
| **Description**          | **IP address/range** |
| pmg1.andromedant.com     | 116.202.120.34       |
| proxmox1.andromedant.com | 88.99.93.182         |
| proxmox2.andromedant.com | 46.4.119.240         |
| proxmox3.andromedant.com | 78.46.88.45          |
| proxmox4.andromedant.com | 178.63.0.104         |
| proxmox5.andromedant.com | 95.216.23.53         |
| proxmox6.andromedant.com | 178.63.41.48         |
| proxmox7.andromedant.com | 159.69.66.197        |
| pbs1.andromedant.com     | 217.182.132.141      |
| pbs2.andromedant.com     | 95.216.226.36        |
| nomad0.andromedant.com   | 46.4.84.141          |

## Proxmox Mail Gateway configuration

We are going to use PMG as a relayhost for all our guests to deliver emails.

### Administrator email

First we will configure the administrator email via the `Configuration: Options: Administrator email` option, which we will set to `sysadmin`andromedant.com@.

### Sytem configuration

Go to `Configuration: Network/Time` and make sure the following options are correct:

- Time zone: Etc/UTC
- Search domain: andromedant.com
- DNS server 1: 192.168.0.253
- DNS server 2: 192.168.0.254

### Mail proxy

Go to `Configuration: Mail proxy: Relaying` and set up the default relay to Google:

- Default relay: smtp-relay.gmail.com
- Relay port: 25

https://docs.hetzner.com/cloud/servers/faq/#why-can-i-not-send-any-mails-from-my-server

Go to `Configuration: Mail proxy: Relay domains` and set up the domains that will be allowed to send emails as:

- andromedant.com
- andronautic.com

Go to `Configuration: Mail proxy: Ports` and check the existing configuration:

- *PMG* uses port 25 to deal with traffic from external servers that want to send us emails. We will not be using this port since we will only be using *PMG* as a relayhost for our LXC and nodes.
- *PMG* uses port 26 to deal with traffic from our internal network that are to be routed outside. This is the port we will be configuring on our LXC and nodes.

We will not be using DNS blacklists as we will only be using *PMG* as a relayhosts for our LXC and nodes, but if we were to we would be configuring them via `Configuration: Mail proxy: Options: DNSBL sites` and we would be using the following two services:

- Barracuda Reputation Block List, that is free to use but [requires IP registration](https://www.barracudacentral.org/account/register) on their website.
- Spamhaus, which does not require registration but you have to [follow their usage policy](https://www.spamhaus.org/organization/dnsblusage/).

For these two services to be used we we would introduce the following value in the `DNSBL sites` field:

    b.barracudacentral.org zen.spamhaus.org

Go to `Configuration: Mail proxy: Networks` to set up the IP address range that will be allowed to use *PMG* as a relayhost, i.e. the private network of the guests. Use the `Create` button to add the following entry:

- CIRD: 192.168.0.0/24
- Comment: Proxmox guests private network

\> Note: Hosts in the same subnet as Proxmox Mail Gateway can relay by default and don’t need to be added to this list. Still, we are adding them explicitly for the sake of clarity.

Go to `Configuration: Mail proxy: TLS` to force traffic to use the Transport Layer Security protocol to encrypt SMTP sessions and use certificate-based authentication. Make sure the following options are active:

- Enable TLS
- Enable TLS logging, so that information about TLS sessions and used certificates is logged via `syslog`.
- Add TLS received header, so that information about the protocol and cipher used is included, as well as the client and issuer (CommonName) into the `Received` message header.

## Configuration on the cluster nodes

The nodes of the PVE (PRoxmox Virtual Environment) and PBS (Proxmox Backup Server) clusters will not be using the Proxmox Mail Gateway as relayhost or smarthost. Instead, they will be using Google’s directly.

We will use the command `dpkg-reconfigure postfix` to change the initial configuration to the following:

- System mail name: proxmox4.andromedant.com
- SMTP relay host: smtp-relay.gmail.com:25
- Root and postmaster mail recipient: sysadmin@andromedant.com
- Other destinations to accept mail for: proxmox4.andromedant.com, localhost.andromedant.com, localhost
- Force synchronous updates on mail queue?: No
- Local networks: 127.0.0.0/8 \[::ffff:127.0.0.0\]/104 \[::1\]/128
- Mailbox size limit (bytes): 0
- Local address extension character: +
- Internet protocols to use: all

Make sure the file `/etc/aliases` contains the following entries:

    postmaster: root
    admin: root
    debian: root
    root: sysadmin@andromedant.com

Each time the `/etc/aliases` file is changed we will need to execute the following command:

    newaliases

To test that the email sent by the node is reaching its destination, we can use the `mail` command. For that, install the `mailutils` package:

    apt-get install mailutils

Also make sure that no other mail package is installed, such as `bsd-mailx`:

    apt purge bsd-mailx

Now compose and send a test email with the following command:

    mail --subject="Test from $(hostname)" --append="From: <root@$(hostname -f)>" root@$(hostname -f) <<< "This is a test message"

By default, all nodes send notifications by email using the `root`$hostname@ address, so we should be receiving notifications from now onward.

The same steps can be followed in the Proxmox Backup Server host:

- System mail name: pbs1.andromedant.com
- SMTP relay host: smtp-relay.gmail.com:25
- Root and postmaster mail recipient: sysadmin@andromedant.com
- Other destinations to accept mail for: pbs1.andromedant.com, localhost.andromedant.com, localhost
- Force synchronous updates on mail queue?: No
- Local networks: 127.0.0.0/8 \[::ffff:127.0.0.0\]/104 \[::1\]/128
- Mailbox size limit (bytes): 0
- Local address extension character: +
- Internet protocols to use: all

Then we will also have to visit the `Datastore: local: Options` menu option, and edit the `Notify user` field to set it to `backupuser`pbs@, so that notifications are sent to the email address we set when we created that user.

TODO: Deploy the wildcard certificate for `andromedant.com` to all nodes and set the following parameters in the `/etc/postfix/main.cf` file:

- smtpd_tls_cert_file=/etc/ssl/certs/andromedant.com.crt
- smtpd_tls_key_file=/etc/ssl/private/andromedant.com.key

## Configuration of LXC

Configuration of the LXC across the cluster is done via an Ansible playbook. The values used are these:

- System mail name: $(hostname -f)
- SMTP relay host: relayhost.andromedant.com:25
- Root and postmaster mail recipient: sysadmin@andromedant.com
- Other destinations to accept mail for: $(hostname -f), localhost.andromedant.com, localhost
- Force synchronous updates on mail queue?: No
- Local networks: 127.0.0.0/8 \[::ffff:127.0.0.0\]/104 \[::1\]/128
- Mailbox size limit (bytes): 0
- Local address extension character: +
- Internet protocols to use: all

Then following TLS options are also added to the `/etc/postfix/main.cf`:

    smtpd_tls_cert_file = /etc/ssl/certs/andromedant.com.crt
    smtpd_tls_key_file = /etc/ssl/private/andromedant.com.key
    smtpd_tls_security_level = may
    smtp_tls_CAfile = /etc/ssl/certs/ISRG_Root_X1.pem

Aliases in `/etc/aliases` are set as follows:

    postmaster: root
    webmaster: root
    admin: root
    debian: root
    root: sysadmin@andromedant.com
